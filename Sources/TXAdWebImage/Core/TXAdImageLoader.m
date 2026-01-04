/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageLoader.h"
#import "TXAdWebImageCacheKeyFilter.h"
#import "TXAdImageCodersManager.h"
#import "TXAdImageCoderHelper.h"
#import "TXAdAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "TXAdInternalMacros.h"
#import "TXAdImageCacheDefine.h"
#import "objc/runtime.h"

TXAdWebImageContextOption const TXAdWebImageContextLoaderCachedImage = @"loaderCachedImage";

static void * TXAdImageLoaderProgressiveCoderKey = &TXAdImageLoaderProgressiveCoderKey;

id<TXAdProgressiveImageCoder> TXAdImageLoaderGetProgressiveCoder(id<TXAdWebImageOperation> operation) {
    NSCParameterAssert(operation);
    return objc_getAssociatedObject(operation, TXAdImageLoaderProgressiveCoderKey);
}

void TXAdImageLoaderSetProgressiveCoder(id<TXAdWebImageOperation> operation, id<TXAdProgressiveImageCoder> progressiveCoder) {
    NSCParameterAssert(operation);
    objc_setAssociatedObject(operation, TXAdImageLoaderProgressiveCoderKey, progressiveCoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

UIImage * _Nullable TXAdImageLoaderDecodeImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, TXAdWebImageOptions options, TXAdWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    
    UIImage *image;
    id<TXAdWebImageCacheKeyFilter> cacheKeyFilter = context[TXAdWebImageContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
    TXAdImageCoderOptions *coderOptions = TXAdGetDecodeOptionsFromContext(context, options, cacheKey);
    BOOL decodeFirstFrame = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageDecodeFirstFrameOnly);
    CGFloat scale = [coderOptions[TXAdImageCoderDecodeScaleFactor] doubleValue];
    
    // Grab the image coder
    id<TXAdImageCoder> imageCoder = context[TXAdWebImageContextImageCoder];
    if (!imageCoder) {
        imageCoder = [TXAdImageCodersManager sharedManager];
    }
    
    if (!decodeFirstFrame) {
        // check whether we should use `TXAdAnimatedImage`
        Class animatedImageClass = context[TXAdWebImageContextAnimatedImageClass];
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

UIImage * _Nullable TXAdImageLoaderDecodeProgressiveImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, BOOL finished,  id<TXAdWebImageOperation> _Nonnull operation, TXAdWebImageOptions options, TXAdWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    NSCParameterAssert(operation);
    
    UIImage *image;
    id<TXAdWebImageCacheKeyFilter> cacheKeyFilter = context[TXAdWebImageContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
    TXAdImageCoderOptions *coderOptions = TXAdGetDecodeOptionsFromContext(context, options, cacheKey);
    BOOL decodeFirstFrame = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageDecodeFirstFrameOnly);
    CGFloat scale = [coderOptions[TXAdImageCoderDecodeScaleFactor] doubleValue];
    
    // Grab the progressive image coder
    id<TXAdProgressiveImageCoder> progressiveCoder = TXAdImageLoaderGetProgressiveCoder(operation);
    if (!progressiveCoder) {
        id<TXAdProgressiveImageCoder> imageCoder = context[TXAdWebImageContextImageCoder];
        // Check the progressive coder if provided
        if ([imageCoder respondsToSelector:@selector(initIncrementalWithOptions:)]) {
            progressiveCoder = [[[imageCoder class] alloc] initIncrementalWithOptions:coderOptions];
        } else {
            // We need to create a new instance for progressive decoding to avoid conflicts
            for (id<TXAdImageCoder> coder in [TXAdImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
                if ([coder conformsToProtocol:@protocol(TXAdProgressiveImageCoder)] &&
                    [((id<TXAdProgressiveImageCoder>)coder) canIncrementalDecodeFromData:imageData]) {
                    progressiveCoder = [[[coder class] alloc] initIncrementalWithOptions:coderOptions];
                    break;
                }
            }
        }
        TXAdImageLoaderSetProgressiveCoder(operation, progressiveCoder);
    }
    // If we can't find any progressive coder, disable progressive download
    if (!progressiveCoder) {
        return nil;
    }
    
    [progressiveCoder updateIncrementalData:imageData finished:finished];
    if (!decodeFirstFrame) {
        // check whether we should use `TXAdAnimatedImage`
        Class animatedImageClass = context[TXAdWebImageContextAnimatedImageClass];
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(TXAdAnimatedImage)] && [progressiveCoder respondsToSelector:@selector(animatedImageFrameAtIndex:)]) {
            image = [[animatedImageClass alloc] initWithAnimatedCoder:(id<TXAdAnimatedImageCoder>)progressiveCoder scale:scale];
            if (image) {
                // Progressive decoding does not preload frames
            } else {
                // Check image class matching
                if (options & TXAdWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [progressiveCoder incrementalDecodedImageWithOptions:coderOptions];
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
        // mark the image as progressive (completed one are not mark as progressive)
        image.txad_isIncremental = !finished;
    }
    
    return image;
}
