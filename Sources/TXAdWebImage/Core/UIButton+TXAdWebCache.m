/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIButton+TXAdWebCache.h"

#if TXAd_UIKIT

#import "objc/runtime.h"
#import "UIView+TXAdWebCacheOperation.h"
#import "UIView+TXAdWebCacheState.h"
#import "UIView+TXAdWebCache.h"
#import "TXAdInternalMacros.h"

@implementation UIButton (WebCache)

#pragma mark - Image

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state {
    [self txad_setImageWithURL:url forState:state placeholderImage:nil options:0 completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder {
    [self txad_setImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options {
    [self txad_setImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context {
    [self txad_setImageWithURL:url forState:state placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url forState:state placeholderImage:nil options:0 completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options progress:(nullable TXAdImageLoaderProgressBlock)progressBlock completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setImageWithURL:url forState:state placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)txad_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
          placeholderImage:(nullable UIImage *)placeholder
                   options:(TXAdWebImageOptions)options
                   context:(nullable TXAdWebImageContext *)context
                  progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                 completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    TXAdWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[TXAdWebImageContextSetImageOperationKey] = [self txad_imageOperationKeyForState:state];
    @weakify(self);
    [self txad_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, TXAdImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           [self setImage:image forState:state];
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXAdImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Background Image

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:nil options:0 completed:nil];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:nil];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:nil options:0 completed:completedBlock];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:completedBlock];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options progress:(nullable TXAdImageLoaderProgressBlock)progressBlock completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)txad_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                    placeholderImage:(nullable UIImage *)placeholder
                             options:(TXAdWebImageOptions)options
                             context:(nullable TXAdWebImageContext *)context
                            progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                           completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    TXAdWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[TXAdWebImageContextSetImageOperationKey] = [self txad_backgroundImageOperationKeyForState:state];
    @weakify(self);
    [self txad_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, TXAdImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           [self setBackgroundImage:image forState:state];
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXAdImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Cancel

- (void)txad_cancelImageLoadForState:(UIControlState)state {
    [self txad_cancelImageLoadOperationWithKey:[self txad_imageOperationKeyForState:state]];
}

- (void)txad_cancelBackgroundImageLoadForState:(UIControlState)state {
    [self txad_cancelImageLoadOperationWithKey:[self txad_backgroundImageOperationKeyForState:state]];
}

#pragma mark - State

- (NSString *)txad_imageOperationKeyForState:(UIControlState)state {
    return [NSString stringWithFormat:@"UIButtonImageOperation%lu", (unsigned long)state];
}

- (NSString *)txad_backgroundImageOperationKeyForState:(UIControlState)state {
    return [NSString stringWithFormat:@"UIButtonBackgroundImageOperation%lu", (unsigned long)state];
}

- (NSURL *)txad_currentImageURL {
    NSURL *url = [self txad_imageURLForState:self.state];
    if (!url) {
        [self txad_imageURLForState:UIControlStateNormal];
    }
    return url;
}

- (NSURL *)txad_imageURLForState:(UIControlState)state {
    return [self txad_imageLoadStateForKey:[self txad_imageOperationKeyForState:state]].url;
}
#pragma mark - Background State

- (NSURL *)txad_currentBackgroundImageURL {
    NSURL *url = [self txad_backgroundImageURLForState:self.state];
    if (!url) {
        url = [self txad_backgroundImageURLForState:UIControlStateNormal];
    }
    return url;
}

- (NSURL *)txad_backgroundImageURLForState:(UIControlState)state {
    return [self txad_imageLoadStateForKey:[self txad_backgroundImageOperationKeyForState:state]].url;
}

@end

#endif
