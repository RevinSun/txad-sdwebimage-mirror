/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImageView+HighlightedWebCache.h"

#if TXAd_UIKIT

#import "UIView+TXAdWebCacheOperation.h"
#import "UIView+TXAdWebCacheState.h"
#import "UIView+TXAdWebCache.h"
#import "TXAdInternalMacros.h"

@implementation UIImageView (HighlightedWebCache)

- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url {
    [self txad_setHighlightedImageWithURL:url options:0 progress:nil completed:nil];
}

- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url options:(TXAdWebImageOptions)options {
    [self txad_setHighlightedImageWithURL:url options:options progress:nil completed:nil];
}

- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context {
    [self txad_setHighlightedImageWithURL:url options:options context:context progress:nil completed:nil];
}

- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setHighlightedImageWithURL:url options:0 progress:nil completed:completedBlock];
}

- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url options:(TXAdWebImageOptions)options completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setHighlightedImageWithURL:url options:options progress:nil completed:completedBlock];
}

- (void)txad_setHighlightedImageWithURL:(NSURL *)url options:(TXAdWebImageOptions)options progress:(nullable TXAdImageLoaderProgressBlock)progressBlock completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setHighlightedImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(TXAdWebImageOptions)options
                              context:(nullable TXAdWebImageContext *)context
                             progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                            completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    @weakify(self);
    TXAdWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[TXAdWebImageContextSetImageOperationKey] = @keypath(self, highlightedImage);
    [self txad_internalSetImageWithURL:url
                    placeholderImage:nil
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, TXAdImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           self.highlightedImage = image;
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXAdImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Highlighted State

- (NSURL *)txad_currentHighlightedImageURL {
    return [self txad_imageLoadStateForKey:@keypath(self, highlightedImage)].url;
}

- (void)txad_cancelCurrentHighlightedImageLoad {
    return [self txad_cancelImageLoadOperationWithKey:@keypath(self, highlightedImage)];
}

@end

#endif
