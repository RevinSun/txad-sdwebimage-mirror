/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+Metadata.h"
#import "NSImage+Compatibility.h"
#import "TXAdInternalMacros.h"
#import "objc/runtime.h"

@implementation UIImage (Metadata)

#if TXAd_UIKIT || TXAd_WATCH

- (NSUInteger)txad_imageLoopCount {
    NSUInteger imageLoopCount = 0;
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_imageLoopCount));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageLoopCount = value.unsignedIntegerValue;
    }
    return imageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)txad_imageLoopCount {
    NSNumber *value = @(txad_imageLoopCount);
    objc_setAssociatedObject(self, @selector(txad_imageLoopCount), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)txad_imageFrameCount {
    NSArray<UIImage *> *animatedImages = self.images;
    if (!animatedImages || animatedImages.count <= 1) {
        return 1;
    }
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_imageFrameCount));
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value unsignedIntegerValue];
    }
    __block NSUInteger frameCount = 1;
    __block UIImage *previousImage = animatedImages.firstObject;
    [animatedImages enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
        // ignore first
        if (idx == 0) {
            return;
        }
        if (![image isEqual:previousImage]) {
            frameCount++;
        }
        previousImage = image;
    }];
    objc_setAssociatedObject(self, @selector(txad_imageFrameCount), @(frameCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return frameCount;
}

- (BOOL)txad_isAnimated {
    return (self.images != nil);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
- (BOOL)txad_isVector {
    if (@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
        // Xcode 11 supports symbol image, keep Xcode 10 compatible currently
        SEL SymbolSelector = NSSelectorFromString(@"isSymbolImage");
        if ([self respondsToSelector:SymbolSelector] && [self performSelector:SymbolSelector]) {
            return YES;
        }
        // SVG
        SEL SVGSelector = TXAd_SEL_SPI(CGSVGDocument);
        if ([self respondsToSelector:SVGSelector] && [self performSelector:SVGSelector]) {
            return YES;
        }
    }
    if (@available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
        // PDF
        SEL PDFSelector = TXAd_SEL_SPI(CGPDFPage);
        if ([self respondsToSelector:PDFSelector] && [self performSelector:PDFSelector]) {
            return YES;
        }
    }
    return NO;
}
#pragma clang diagnostic pop

#else

- (NSUInteger)txad_imageLoopCount {
    NSUInteger imageLoopCount = 0;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        imageLoopCount = [[bitmapImageRep valueForProperty:NSImageLoopCount] unsignedIntegerValue];
    }
    return imageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)txad_imageLoopCount {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        [bitmapImageRep setProperty:NSImageLoopCount withValue:@(txad_imageLoopCount)];
    }
}

- (NSUInteger)txad_imageFrameCount {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        return [[bitmapImageRep valueForProperty:NSImageFrameCount] unsignedIntegerValue];
    }
    return 1;
}

- (BOOL)txad_isAnimated {
    BOOL isAnimated = NO;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (bitmapImageRep) {
        NSUInteger frameCount = [[bitmapImageRep valueForProperty:NSImageFrameCount] unsignedIntegerValue];
        isAnimated = frameCount > 1 ? YES : NO;
    }
    return isAnimated;
}

- (BOOL)txad_isVector {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    // This may returns a NSProxy, so don't use `class` to check
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    if ([imageRep isKindOfClass:[NSPDFImageRep class]]) {
        return YES;
    }
    if ([imageRep isKindOfClass:[NSEPSImageRep class]]) {
        return YES;
    }
    Class NSSVGImageRepClass = NSClassFromString([NSString stringWithFormat:@"_%@", TXAd_NSSTRING(NSSVGImageRep)]);
    if ([imageRep isKindOfClass:NSSVGImageRepClass]) {
        return YES;
    }
    return NO;
}

#endif

- (TXAdImageFormat)txad_imageFormat {
    TXAdImageFormat imageFormat = TXAdImageFormatUndefined;
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_imageFormat));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageFormat = value.integerValue;
        return imageFormat;
    }
    // Check CGImage's UTType, may return nil for non-Image/IO based image
    CFStringRef uttype = CGImageGetUTType(self.CGImage);
    imageFormat = [NSData txad_imageFormatFromUTType:uttype];
    return imageFormat;
}

- (void)setSd_imageFormat:(TXAdImageFormat)txad_imageFormat {
    objc_setAssociatedObject(self, @selector(txad_imageFormat), @(txad_imageFormat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setSd_isIncremental:(BOOL)txad_isIncremental {
    objc_setAssociatedObject(self, @selector(txad_isIncremental), @(txad_isIncremental), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)txad_isIncremental {
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_isIncremental));
    return value.boolValue;
}

- (void)setSd_isTransformed:(BOOL)txad_isTransformed {
    objc_setAssociatedObject(self, @selector(txad_isTransformed), @(txad_isTransformed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)txad_isTransformed {
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_isTransformed));
    return value.boolValue;
}

- (void)setSd_decodeOptions:(TXAdImageCoderOptions *)txad_decodeOptions {
    objc_setAssociatedObject(self, @selector(txad_decodeOptions), txad_decodeOptions, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(BOOL)txad_isThumbnail {
    CGSize thumbnailSize = CGSizeZero;
    NSValue *thumbnailSizeValue = self.txad_decodeOptions[TXAdImageCoderDecodeThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
    #if TXAd_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
    }
    return thumbnailSize.width > 0 && thumbnailSize.height > 0;
}

- (TXAdImageCoderOptions *)txad_decodeOptions {
    TXAdImageCoderOptions *value = objc_getAssociatedObject(self, @selector(txad_decodeOptions));
    if ([value isKindOfClass:NSDictionary.class]) {
        return value;
    }
    return nil;
}

@end
