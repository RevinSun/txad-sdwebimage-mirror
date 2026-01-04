/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageDefine.h"
#import "UIImage+Metadata.h"
#import "NSImage+Compatibility.h"
#import "TXAdAnimatedImage.h"
#import "TXAdAssociatedObject.h"

#pragma mark - Image scale

static inline NSArray<NSNumber *> * _Nonnull TXAdImageScaleFactors(void) {
    return @[@2, @3];
}

inline CGFloat TXAdImageScaleFactorForKey(NSString * _Nullable key) {
    CGFloat scale = 1;
    if (!key) {
        return scale;
    }
    // Now all OS supports retina display scale system
    {
        // a@2x.png -> 8
        if (key.length >= 8) {
            // Fast check
            BOOL isURL = [key hasPrefix:@"http://"] || [key hasPrefix:@"https://"];
            for (NSNumber *scaleFactor in TXAdImageScaleFactors()) {
                // @2x. for file name and normal url
                NSString *fileScale = [NSString stringWithFormat:@"@%@x.", scaleFactor];
                if ([key containsString:fileScale]) {
                    scale = scaleFactor.doubleValue;
                    return scale;
                }
                if (isURL) {
                    // %402x. for url encode
                    NSString *urlScale = [NSString stringWithFormat:@"%%40%@x.", scaleFactor];
                    if ([key containsString:urlScale]) {
                        scale = scaleFactor.doubleValue;
                        return scale;
                    }
                }
            }
        }
    }
    return scale;
}

inline UIImage * _Nullable TXAdScaledImageForKey(NSString * _Nullable key, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    CGFloat scale = TXAdImageScaleFactorForKey(key);
    return TXAdScaledImageForScaleFactor(scale, image);
}

inline UIImage * _Nullable TXAdScaledImageForScaleFactor(CGFloat scale, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    if (scale <= 1) {
        return image;
    }
    if (scale == image.scale) {
        return image;
    }
    UIImage *scaledImage;
    // Check TXAdAnimatedImage support for shortcut
    if ([image.class conformsToProtocol:@protocol(TXAdAnimatedImage)]) {
        if ([image respondsToSelector:@selector(animatedCoder)]) {
            id<TXAdAnimatedImageCoder> coder = [(id<TXAdAnimatedImage>)image animatedCoder];
            if (coder) {
                scaledImage = [[image.class alloc] initWithAnimatedCoder:coder scale:scale];
            }
        } else {
            // Some class impl does not support `animatedCoder`, keep for compatibility
            NSData *data = [(id<TXAdAnimatedImage>)image animatedImageData];
            if (data) {
                scaledImage = [[image.class alloc] initWithData:data scale:scale];
            }
        }
    }
    if (scaledImage) {
        TXAdImageCopyAssociatedObject(image, scaledImage);
        return scaledImage;
    }
    if (image.txad_isAnimated) {
        UIImage *animatedImage;
#if TXAd_UIKIT || TXAd_WATCH
        // `UIAnimatedImage` images share the same size and scale.
        NSArray<UIImage *> *images = image.images;
        NSMutableArray<UIImage *> *scaledImages = [NSMutableArray arrayWithCapacity:images.count];
        
        for (UIImage *tempImage in images) {
            UIImage *tempScaledImage = [[UIImage alloc] initWithCGImage:tempImage.CGImage scale:scale orientation:tempImage.imageOrientation];
            [scaledImages addObject:tempScaledImage];
        }
        
        animatedImage = [UIImage animatedImageWithImages:scaledImages duration:image.duration];
#else
        // Animated GIF for `NSImage` need to grab `NSBitmapImageRep`;
        NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
        NSImageRep *imageRep = [image bestRepresentationForRect:imageRect context:nil hints:nil];
        NSBitmapImageRep *bitmapImageRep;
        if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapImageRep = (NSBitmapImageRep *)imageRep;
        }
        if (bitmapImageRep) {
            NSSize size = NSMakeSize(image.size.width / scale, image.size.height / scale);
            animatedImage = [[NSImage alloc] initWithSize:size];
            bitmapImageRep.size = size;
            [animatedImage addRepresentation:bitmapImageRep];
        }
#endif
        scaledImage = animatedImage;
    } else {
#if TXAd_UIKIT || TXAd_WATCH
        scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
#else
        scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:kCGImagePropertyOrientationUp];
#endif
    }
    if (scaledImage) {
        TXAdImageCopyAssociatedObject(image, scaledImage);
        return scaledImage;
    }
    
    return nil;
}

#pragma mark - Context option

TXAdWebImageContextOption const TXAdWebImageContextSetImageOperationKey = @"setImageOperationKey";
TXAdWebImageContextOption const TXAdWebImageContextCustomManager = @"customManager";
TXAdWebImageContextOption const TXAdWebImageContextCallbackQueue = @"callbackQueue";
TXAdWebImageContextOption const TXAdWebImageContextImageCache = @"imageCache";
TXAdWebImageContextOption const TXAdWebImageContextImageLoader = @"imageLoader";
TXAdWebImageContextOption const TXAdWebImageContextImageCoder = @"imageCoder";
TXAdWebImageContextOption const TXAdWebImageContextImageTransformer = @"imageTransformer";
TXAdWebImageContextOption const TXAdWebImageContextImageForceDecodePolicy = @"imageForceDecodePolicy";
TXAdWebImageContextOption const TXAdWebImageContextImageDecodeOptions = @"imageDecodeOptions";
TXAdWebImageContextOption const TXAdWebImageContextImageScaleFactor = @"imageScaleFactor";
TXAdWebImageContextOption const TXAdWebImageContextImagePreserveAspectRatio = @"imagePreserveAspectRatio";
TXAdWebImageContextOption const TXAdWebImageContextImageThumbnailPixelSize = @"imageThumbnailPixelSize";
TXAdWebImageContextOption const TXAdWebImageContextImageTypeIdentifierHint = @"imageTypeIdentifierHint";
TXAdWebImageContextOption const TXAdWebImageContextImageScaleDownLimitBytes = @"imageScaleDownLimitBytes";
TXAdWebImageContextOption const TXAdWebImageContextImageEncodeOptions = @"imageEncodeOptions";
TXAdWebImageContextOption const TXAdWebImageContextQueryCacheType = @"queryCacheType";
TXAdWebImageContextOption const TXAdWebImageContextStoreCacheType = @"storeCacheType";
TXAdWebImageContextOption const TXAdWebImageContextOriginalQueryCacheType = @"originalQueryCacheType";
TXAdWebImageContextOption const TXAdWebImageContextOriginalStoreCacheType = @"originalStoreCacheType";
TXAdWebImageContextOption const TXAdWebImageContextOriginalImageCache = @"originalImageCache";
TXAdWebImageContextOption const TXAdWebImageContextAnimatedImageClass = @"animatedImageClass";
TXAdWebImageContextOption const TXAdWebImageContextDownloadRequestModifier = @"downloadRequestModifier";
TXAdWebImageContextOption const TXAdWebImageContextDownloadResponseModifier = @"downloadResponseModifier";
TXAdWebImageContextOption const TXAdWebImageContextDownloadDecryptor = @"downloadDecryptor";
TXAdWebImageContextOption const TXAdWebImageContextCacheKeyFilter = @"cacheKeyFilter";
TXAdWebImageContextOption const TXAdWebImageContextCacheSerializer = @"cacheSerializer";
