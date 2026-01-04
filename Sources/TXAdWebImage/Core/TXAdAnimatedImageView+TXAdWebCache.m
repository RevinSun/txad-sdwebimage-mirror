/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdAnimatedImageView+TXAdWebCache.h"

#if TXAd_UIKIT || TXAd_MAC

#import "UIView+TXAdWebCache.h"
#import "TXAdAnimatedImage.h"

@implementation TXAdAnimatedImageView (WebCache)

- (void)txad_setImageWithURL:(nullable NSURL *)url {
    [self txad_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self txad_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options {
    [self txad_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context {
    [self txad_setImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options progress:(nullable TXAdImageLoaderProgressBlock)progressBlock completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(TXAdWebImageOptions)options
                   context:(nullable TXAdWebImageContext *)context
                  progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                 completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    Class animatedImageClass = [TXAdAnimatedImage class];
    TXAdWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[TXAdWebImageContextAnimatedImageClass] = animatedImageClass;
    [self txad_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXAdImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

@end

#endif
