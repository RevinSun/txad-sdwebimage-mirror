/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageCacheDefine.h"
#import "TXAdImageCodersManager.h"
#import "TXAdImageCoderHelper.h"
#import "TXAdAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "TXAdInternalMacros.h"

#import <CoreServices/CoreServices.h>

TXAdImageCoderOptions * _Nonnull TXAdGetDecodeOptionsFromContext(TXAdWebImageContext * _Nullable context, TXAdWebImageOptions options, NSString * _Nonnull cacheKey) {
    BOOL decodeFirstFrame = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageDecodeFirstFrameOnly);
    NSNumber *scaleValue = context[TXAdWebImageContextImageScaleFactor];
    CGFloat scale = scaleValue.doubleValue >= 1 ? scaleValue.doubleValue : TXAdImageScaleFactorForKey(cacheKey); // Use cache key to detect scale
    NSNumber *preserveAspectRatioValue = context[TXAdWebImageContextImagePreserveAspectRatio];
    NSValue *thumbnailSizeValue;
    BOOL shouldScaleDown = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageScaleDownLargeImages);
    NSNumber *scaleDownLimitBytesValue = context[TXAdWebImageContextImageScaleDownLimitBytes];
    if (scaleDownLimitBytesValue == nil && shouldScaleDown) {
        // Use the default limit bytes
        scaleDownLimitBytesValue = @(TXAdImageCoderHelper.defaultScaleDownLimitBytes);
    }
    if (context[TXAdWebImageContextImageThumbnailPixelSize]) {
        thumbnailSizeValue = context[TXAdWebImageContextImageThumbnailPixelSize];
    }
    NSString *typeIdentifierHint = context[TXAdWebImageContextImageTypeIdentifierHint];
    NSString *fileExtensionHint;
    if (!typeIdentifierHint) {
        // UTI has high priority
        fileExtensionHint = cacheKey.pathExtension; // without dot
        if (fileExtensionHint.length == 0) {
            // Ignore file extension which is empty
            fileExtensionHint = nil;
        }
    }
    
    // First check if user provided decode options
    TXAdImageCoderMutableOptions *mutableCoderOptions;
    if (context[TXAdWebImageContextImageDecodeOptions] != nil) {
        mutableCoderOptions = [NSMutableDictionary dictionaryWithDictionary:context[TXAdWebImageContextImageDecodeOptions]];
    } else {
        mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:6];
    }
    
    // Override individual options
    mutableCoderOptions[TXAdImageCoderDecodeFirstFrameOnly] = @(decodeFirstFrame);
    mutableCoderOptions[TXAdImageCoderDecodeScaleFactor] = @(scale);
    mutableCoderOptions[TXAdImageCoderDecodePreserveAspectRatio] = preserveAspectRatioValue;
    mutableCoderOptions[TXAdImageCoderDecodeThumbnailPixelSize] = thumbnailSizeValue;
    mutableCoderOptions[TXAdImageCoderDecodeTypeIdentifierHint] = typeIdentifierHint;
    mutableCoderOptions[TXAdImageCoderDecodeFileExtensionHint] = fileExtensionHint;
    mutableCoderOptions[TXAdImageCoderDecodeScaleDownLimitBytes] = scaleDownLimitBytesValue;
    
    return [mutableCoderOptions copy];
}

void TXAdSetDecodeOptionsToContext(TXAdWebImageMutableContext * _Nonnull mutableContext, TXAdWebImageOptions * _Nonnull mutableOptions, TXAdImageCoderOptions * _Nonnull decodeOptions) {
    if ([decodeOptions[TXAdImageCoderDecodeFirstFrameOnly] boolValue]) {
        *mutableOptions |= TXAdWebImageDecodeFirstFrameOnly;
    } else {
        *mutableOptions &= ~TXAdWebImageDecodeFirstFrameOnly;
    }
    
    mutableContext[TXAdWebImageContextImageScaleFactor] = decodeOptions[TXAdImageCoderDecodeScaleFactor];
    mutableContext[TXAdWebImageContextImagePreserveAspectRatio] = decodeOptions[TXAdImageCoderDecodePreserveAspectRatio];
    mutableContext[TXAdWebImageContextImageThumbnailPixelSize] = decodeOptions[TXAdImageCoderDecodeThumbnailPixelSize];
    mutableContext[TXAdWebImageContextImageScaleDownLimitBytes] = decodeOptions[TXAdImageCoderDecodeScaleDownLimitBytes];
    
    NSString *typeIdentifierHint = decodeOptions[TXAdImageCoderDecodeTypeIdentifierHint];
    if (!typeIdentifierHint) {
        NSString *fileExtensionHint = decodeOptions[TXAdImageCoderDecodeFileExtensionHint];
        if (fileExtensionHint) {
            typeIdentifierHint = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtensionHint, kUTTypeImage);
            // Ignore dynamic UTI
            if (UTTypeIsDynamic((__bridge CFStringRef)typeIdentifierHint)) {
                typeIdentifierHint = nil;
            }
        }
    }
    mutableContext[TXAdWebImageContextImageTypeIdentifierHint] = typeIdentifierHint;
}

UIImage * _Nullable TXAdImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, TXAdWebImageOptions options, TXAdWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(cacheKey);
    UIImage *image;
    TXAdImageCoderOptions *coderOptions = TXAdGetDecodeOptionsFromContext(context, options, cacheKey);
    BOOL decodeFirstFrame = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageDecodeFirstFrameOnly);
    CGFloat scale = [coderOptions[TXAdImageCoderDecodeScaleFactor] doubleValue];
    
    // Grab the image coder
    id<TXAdImageCoder> imageCoder = context[TXAdWebImageContextImageCoder];
    if (!imageCoder) {
        imageCoder = [TXAdImageCodersManager sharedManager];
    }
    
    if (!decodeFirstFrame) {
        Class animatedImageClass = context[TXAdWebImageContextAnimatedImageClass];
        // check whether we should use `TXAdAnimatedImage`
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(TXAdAnimatedImage)]) {
            image = [[animatedImageClass alloc] initWithData:imageData scale:scale options:coderOptions];
            if (image) {
                // Preload frames if supported
                if (options & TXAdWebImagePreloadAllFrames && [image respondsToSelector:@selector(preloadAllFrames)]) {
                    [((id<TXAdAnimatedImage>)image) preloadAllFrames];
                }
            } else {
                // Check image class matching
                if (options & TXAdWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [imageCoder decodedImageWithData:imageData options:coderOptions];
    }
    if (image) {
        TXAdImageForceDecodePolicy policy = TXAdImageForceDecodePolicyAutomatic;
        NSNumber *policyValue = context[TXAdWebImageContextImageForceDecodePolicy];
        if (policyValue != nil) {
            policy = policyValue.unsignedIntegerValue;
        }
        // TODO: Deprecated, remove in SD 6.0...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAvoidDecodeImage)) {
            policy = TXAdImageForceDecodePolicyNever;
        }
#pragma clang diagnostic pop
        image = [TXAdImageCoderHelper decodedImageWithImage:image policy:policy];
        // assign the decode options, to let manager check whether to re-decode if needed
        image.txad_decodeOptions = coderOptions;
    }
    
    return image;
}
