/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageIOCoder.h"
#import "TXAdImageCoderHelper.h"
#import "NSImage+Compatibility.h"
#import "UIImage+Metadata.h"
#import "TXAdImageGraphics.h"
#import "TXAdImageIOAnimatedCoderInternal.h"

#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>

// Specify File Size for lossy format encoding, like JPEG
static NSString * kTXAdCGImageDestinationRequestedFileSize = @"kCGImageDestinationRequestedFileSize";

@implementation TXAdImageIOCoder {
    size_t _width, _height;
    CGImagePropertyOrientation _orientation;
    CGImageSourceRef _imageSource;
    CGFloat _scale;
    BOOL _finished;
    BOOL _preserveAspectRatio;
    CGSize _thumbnailSize;
    BOOL _lazyDecode;
}

- (void)dealloc {
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
#if TXAd_UIKIT
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    if (_imageSource) {
        CGImageSourceRemoveCacheAtIndex(_imageSource, 0);
    }
}

+ (instancetype)sharedCoder {
    static TXAdImageIOCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[TXAdImageIOCoder alloc] init];
    });
    return coder;
}

#pragma mark - Bitmap PDF representation
+ (UIImage *)createBitmapPDFWithData:(nonnull NSData *)data pageNumber:(NSUInteger)pageNumber targetSize:(CGSize)targetSize preserveAspectRatio:(BOOL)preserveAspectRatio {
    NSParameterAssert(data);
    UIImage *image;
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    if (!provider) {
        return nil;
    }
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    if (!document) {
        return nil;
    }
    
    // `CGPDFDocumentGetPage` page number is 1-indexed.
    CGPDFPageRef page = CGPDFDocumentGetPage(document, pageNumber + 1);
    if (!page) {
        CGPDFDocumentRelease(document);
        return nil;
    }
    
    CGPDFBox box = kCGPDFMediaBox;
    CGRect rect = CGPDFPageGetBoxRect(page, box);
    CGRect targetRect = rect;
    if (!CGSizeEqualToSize(targetSize, CGSizeZero)) {
        targetRect = CGRectMake(0, 0, targetSize.width, targetSize.height);
    }
    
    CGFloat xRatio = targetRect.size.width / rect.size.width;
    CGFloat yRatio = targetRect.size.height / rect.size.height;
    CGFloat xScale = preserveAspectRatio ? MIN(xRatio, yRatio) : xRatio;
    CGFloat yScale = preserveAspectRatio ? MIN(xRatio, yRatio) : yRatio;
    
    // `CGPDFPageGetDrawingTransform` will only scale down, but not scale up, so we need calculate the actual scale again
    CGRect drawRect = CGRectMake( 0, 0, targetRect.size.width / xScale, targetRect.size.height / yScale);
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(xScale, yScale);
    CGAffineTransform transform = CGPDFPageGetDrawingTransform(page, box, drawRect, 0, preserveAspectRatio);
    
    TXAdGraphicsBeginImageContextWithOptions(targetRect.size, NO, 0);
    CGContextRef context = TXAdGraphicsGetCurrentContext();
    
#if TXAd_UIKIT || TXAd_WATCH
    // Core Graphics coordinate system use the bottom-left, UIKit use the flipped one
    CGContextTranslateCTM(context, 0, targetRect.size.height);
    CGContextScaleCTM(context, 1, -1);
#endif
    
    CGContextConcatCTM(context, scaleTransform);
    CGContextConcatCTM(context, transform);
    
    CGContextDrawPDFPage(context, page);
    
    image = TXAdGraphicsGetImageFromCurrentImageContext();
    TXAdGraphicsEndImageContext();
    
    CGPDFDocumentRelease(document);
    
    return image;
}

#pragma mark - Decode
- (BOOL)canDecodeFromData:(nullable NSData *)data {
    return YES;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable TXAdImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    CGFloat scale = 1;
    NSNumber *scaleFactor = options[TXAdImageCoderDecodeScaleFactor];
    if (scaleFactor != nil) {
        scale = MAX([scaleFactor doubleValue], 1) ;
    }
    
    CGSize thumbnailSize = CGSizeZero;
    NSValue *thumbnailSizeValue = options[TXAdImageCoderDecodeThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
#if TXAd_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
#else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
#endif
    }
    
    BOOL preserveAspectRatio = YES;
    NSNumber *preserveAspectRatioValue = options[TXAdImageCoderDecodePreserveAspectRatio];
    if (preserveAspectRatioValue != nil) {
        preserveAspectRatio = preserveAspectRatioValue.boolValue;
    }
    
    // Check vector format
    if ([NSData txad_imageFormatForImageData:data] == TXAdImageFormatPDF) {
        // History before iOS 16, ImageIO can decode PDF with rasterization size, but can't ever :(
        // So, use CoreGraphics to decode PDF (copy code from TXAdWebImagePDFCoder, may do refactor in the future)
        UIImage *image;
        NSUInteger pageNumber = 0; // Still use first page, may added options is user want
#if TXAd_MAC
        // If don't use thumbnail, prefers the built-in generation of vector image
        // macOS's `NSImage` supports PDF built-in rendering
        if (thumbnailSize.width == 0 || thumbnailSize.height == 0) {
            NSPDFImageRep *imageRep = [[NSPDFImageRep alloc] initWithData:data];
            if (imageRep) {
                imageRep.currentPage = pageNumber;
                image = [[NSImage alloc] initWithSize:imageRep.size];
                [image addRepresentation:imageRep];
                image.txad_imageFormat = TXAdImageFormatPDF;
                return image;
            }
        }
#endif
        image = [self.class createBitmapPDFWithData:data pageNumber:pageNumber targetSize:thumbnailSize preserveAspectRatio:preserveAspectRatio];
        image.txad_imageFormat = TXAdImageFormatPDF;
        return image;
    }
    
    BOOL lazyDecode = YES; // Defaults YES for static image coder
    NSNumber *lazyDecodeValue = options[TXAdImageCoderDecodeUseLazyDecoding];
    if (lazyDecodeValue != nil) {
        lazyDecode = lazyDecodeValue.boolValue;
    }
    
    NSString *typeIdentifierHint = options[TXAdImageCoderDecodeTypeIdentifierHint];
    if (!typeIdentifierHint) {
        // Check file extension and convert to UTI, from: https://stackoverflow.com/questions/1506251/getting-an-uniform-type-identifier-for-a-given-extension
        NSString *fileExtensionHint = options[TXAdImageCoderDecodeFileExtensionHint];
        if (fileExtensionHint) {
            typeIdentifierHint = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtensionHint, kUTTypeImage);
            // Ignore dynamic UTI
            if (UTTypeIsDynamic((__bridge CFStringRef)typeIdentifierHint)) {
                typeIdentifierHint = nil;
            }
        }
    } else if ([typeIdentifierHint isEqual:NSNull.null]) {
        // Hack if user don't want to imply file extension
        typeIdentifierHint = nil;
    }
    
    NSDictionary *creatingOptions = nil;
    if (typeIdentifierHint) {
        creatingOptions = @{(__bridge NSString *)kCGImageSourceTypeIdentifierHint : typeIdentifierHint};
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)creatingOptions);
    if (!source) {
        // Try again without UTType hint, the call site from user may provide the wrong UTType
        source = CGImageSourceCreateWithData((__bridge CFDataRef)data, nil);
    }
    if (!source) {
        return nil;
    }
    
    CFStringRef uttype = CGImageSourceGetType(source);
    TXAdImageFormat imageFormat = [NSData txad_imageFormatFromUTType:uttype];
    
    UIImage *image = [TXAdImageIOAnimatedCoder createFrameAtIndex:0 source:source scale:scale preserveAspectRatio:preserveAspectRatio thumbnailSize:thumbnailSize lazyDecode:lazyDecode animatedImage:NO];
    CFRelease(source);
    
    image.txad_imageFormat = imageFormat;
    return image;
}

#pragma mark - Progressive Decode

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return [self canDecodeFromData:data];
}

- (instancetype)initIncrementalWithOptions:(nullable TXAdImageCoderOptions *)options {
    self = [super init];
    if (self) {
        _imageSource = CGImageSourceCreateIncremental(NULL);
        CGFloat scale = 1;
        NSNumber *scaleFactor = options[TXAdImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = MAX([scaleFactor doubleValue], 1);
        }
        _scale = scale;
        CGSize thumbnailSize = CGSizeZero;
        NSValue *thumbnailSizeValue = options[TXAdImageCoderDecodeThumbnailPixelSize];
        if (thumbnailSizeValue != nil) {
    #if TXAd_MAC
            thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
            thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
        }
        _thumbnailSize = thumbnailSize;
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = options[TXAdImageCoderDecodePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        _preserveAspectRatio = preserveAspectRatio;
        BOOL lazyDecode = YES; // Defaults YES for static image coder
        NSNumber *lazyDecodeValue = options[TXAdImageCoderDecodeUseLazyDecoding];
        if (lazyDecodeValue != nil) {
            lazyDecode = lazyDecodeValue.boolValue;
        }
        _lazyDecode = lazyDecode;
#if TXAd_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
    }
    return self;
}

- (void)updateIncrementalData:(NSData *)data finished:(BOOL)finished {
    if (_finished) {
        return;
    }
    _finished = finished;
    
    // The following code is from http://www.cocoaintheshell.com/2011/05/progressive-images-download-imageio/
    // Thanks to the author @Nyx0uf
    
    // Update the data source, we must pass ALL the data, not just the new bytes
    CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)data, finished);
    
    if (_width + _height == 0) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, NULL);
        if (properties) {
            NSInteger orientationValue = 1;
            CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_height);
            val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_width);
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) CFNumberGetValue(val, kCFNumberNSIntegerType, &orientationValue);
            CFRelease(properties);
            
            // When we draw to Core Graphics, we lose orientation information,
            // which means the image below born of initWithCGIImage will be
            // oriented incorrectly sometimes. (Unlike the image born of initWithData
            // in didCompleteWithError.) So save it here and pass it on later.
            _orientation = (CGImagePropertyOrientation)orientationValue;
        }
    }
}

- (UIImage *)incrementalDecodedImageWithOptions:(TXAdImageCoderOptions *)options {
    UIImage *image;
    
    if (_width + _height > 0) {
        // Create the image
        CGFloat scale = _scale;
        NSNumber *scaleFactor = options[TXAdImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = MAX([scaleFactor doubleValue], 1);
        }
        image = [TXAdImageIOAnimatedCoder createFrameAtIndex:0 source:_imageSource scale:scale preserveAspectRatio:_preserveAspectRatio thumbnailSize:_thumbnailSize lazyDecode:_lazyDecode animatedImage:NO];
        if (image) {
            CFStringRef uttype = CGImageSourceGetType(_imageSource);
            image.txad_imageFormat = [NSData txad_imageFormatFromUTType:uttype];
        }
    }
    
    return image;
}

#pragma mark - Encode
- (BOOL)canEncodeToFormat:(TXAdImageFormat)format {
    return YES;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(TXAdImageFormat)format options:(nullable TXAdImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        // Earily return, supports CGImage only
        return nil;
    }
    
    if (format == TXAdImageFormatUndefined) {
        BOOL hasAlpha = [TXAdImageCoderHelper CGImageContainsAlpha:imageRef];
        if (hasAlpha) {
            format = TXAdImageFormatPNG;
        } else {
            format = TXAdImageFormatJPEG;
        }
    }
    
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData txad_UTTypeFromImageFormat:format];
    
    // Create an image destination.
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, 1, NULL);
    if (!imageDestination) {
        // Handle failure.
        return nil;
    }
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
#if TXAd_UIKIT || TXAd_WATCH
    CGImagePropertyOrientation exifOrientation = [TXAdImageCoderHelper exifOrientationFromImageOrientation:image.imageOrientation];
#else
    CGImagePropertyOrientation exifOrientation = kCGImagePropertyOrientationUp;
#endif
    properties[(__bridge NSString *)kCGImagePropertyOrientation] = @(exifOrientation);
    // Encoding Options
    double compressionQuality = 1;
    if (options[TXAdImageCoderEncodeCompressionQuality]) {
        compressionQuality = [options[TXAdImageCoderEncodeCompressionQuality] doubleValue];
    }
    properties[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = @(compressionQuality);
    CGColorRef backgroundColor = [options[TXAdImageCoderEncodeBackgroundColor] CGColor];
    if (backgroundColor) {
        properties[(__bridge NSString *)kCGImageDestinationBackgroundColor] = (__bridge id)(backgroundColor);
    }
    CGSize maxPixelSize = CGSizeZero;
    NSValue *maxPixelSizeValue = options[TXAdImageCoderEncodeMaxPixelSize];
    if (maxPixelSizeValue != nil) {
#if TXAd_MAC
        maxPixelSize = maxPixelSizeValue.sizeValue;
#else
        maxPixelSize = maxPixelSizeValue.CGSizeValue;
#endif
    }
    CGFloat pixelWidth = (CGFloat)CGImageGetWidth(imageRef);
    CGFloat pixelHeight = (CGFloat)CGImageGetHeight(imageRef);
    CGFloat finalPixelSize = 0;
    BOOL encodeFullImage = maxPixelSize.width == 0 || maxPixelSize.height == 0 || pixelWidth == 0 || pixelHeight == 0 || (pixelWidth <= maxPixelSize.width && pixelHeight <= maxPixelSize.height);
    if (!encodeFullImage) {
        // Thumbnail Encoding
        CGFloat pixelRatio = pixelWidth / pixelHeight;
        CGFloat maxPixelSizeRatio = maxPixelSize.width / maxPixelSize.height;
        if (pixelRatio > maxPixelSizeRatio) {
            finalPixelSize = MAX(maxPixelSize.width, maxPixelSize.width / pixelRatio);
        } else {
            finalPixelSize = MAX(maxPixelSize.height, maxPixelSize.height * pixelRatio);
        }
        properties[(__bridge NSString *)kCGImageDestinationImageMaxPixelSize] = @(finalPixelSize);
    }
    NSUInteger maxFileSize = [options[TXAdImageCoderEncodeMaxFileSize] unsignedIntegerValue];
    if (maxFileSize > 0) {
        properties[kTXAdCGImageDestinationRequestedFileSize] = @(maxFileSize);
        // Remove the quality if we have file size limit
        properties[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = nil;
    }
    BOOL embedThumbnail = NO;
    if (options[TXAdImageCoderEncodeEmbedThumbnail]) {
        embedThumbnail = [options[TXAdImageCoderEncodeEmbedThumbnail] boolValue];
    }
    properties[(__bridge NSString *)kCGImageDestinationEmbedThumbnail] = @(embedThumbnail);
    
    // Add your image to the destination.
    CGImageDestinationAddImage(imageDestination, imageRef, (__bridge CFDictionaryRef)properties);
    
    // Finalize the destination.
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        // Handle failure.
        imageData = nil;
    }
    
    CFRelease(imageDestination);
    
    return [imageData copy];
}

@end
