/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSButton+TXAdWebCache.h"

#if TXAd_MAC

#import "objc/runtime.h"
#import "UIView+TXAdWebCacheOperation.h"
#import "UIView+TXAdWebCacheState.h"
#import "UIView+TXAdWebCache.h"
#import "TXAdInternalMacros.h"

@implementation NSButton (WebCache)

#pragma mark - Image

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
    [self txad_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:context
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(NSImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXAdImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Alternate Image

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url {
    [self txad_setAlternateImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self txad_setAlternateImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options {
    [self txad_setAlternateImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context {
    [self txad_setAlternateImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setAlternateImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setAlternateImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setAlternateImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(TXAdWebImageOptions)options progress:(nullable TXAdImageLoaderProgressBlock)progressBlock completed:(nullable TXAdExternalCompletionBlock)completedBlock {
    [self txad_setAlternateImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)txad_setAlternateImageWithURL:(nullable NSURL *)url
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
    mutableContext[TXAdWebImageContextSetImageOperationKey] = @keypath(self, alternateImage);
    @weakify(self);
    [self txad_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(NSImage * _Nullable image, NSData * _Nullable imageData, TXAdImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           self.alternateImage = image;
                       }
                            progress:progressBlock
                           completed:^(NSImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXAdImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Cancel

- (void)txad_cancelCurrentImageLoad {
    [self txad_cancelImageLoadOperationWithKey:nil];
}

- (void)txad_cancelCurrentAlternateImageLoad {
    [self txad_cancelImageLoadOperationWithKey:@keypath(self, alternateImage)];
}

#pragma mark - State

- (NSURL *)txad_currentImageURL {
    return [self txad_imageLoadStateForKey:nil].url;
}

#pragma mark - Alternate State

- (NSURL *)txad_currentAlternateImageURL {
    return [self txad_imageLoadStateForKey:@keypath(self, alternateImage)].url;
}

@end

#endif
