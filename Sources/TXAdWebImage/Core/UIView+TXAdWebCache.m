/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+TXAdWebCache.h"
#import "objc/runtime.h"
#import "UIView+TXAdWebCacheOperation.h"
#import "TXAdWebImageError.h"
#import "TXAdInternalMacros.h"
#import "TXAdWebImageTransitionInternal.h"
#import "TXAdImageCache.h"

const int64_t TXAdWebImageProgressUnitCountUnknown = 1LL;

@implementation UIView (WebCache)

- (nullable NSString *)txad_latestOperationKey {
    return objc_getAssociatedObject(self, @selector(txad_latestOperationKey));
}

- (void)setSd_latestOperationKey:(NSString * _Nullable)txad_latestOperationKey {
    objc_setAssociatedObject(self, @selector(txad_latestOperationKey), txad_latestOperationKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

#pragma mark - State

- (NSURL *)txad_imageURL {
    return [self txad_imageLoadStateForKey:self.txad_latestOperationKey].url;
}

- (NSProgress *)txad_imageProgress {
    TXAdWebImageLoadState *loadState = [self txad_imageLoadStateForKey:self.txad_latestOperationKey];
    NSProgress *progress = loadState.progress;
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.txad_imageProgress = progress;
    }
    return progress;
}

- (void)setSd_imageProgress:(NSProgress *)txad_imageProgress {
    if (!txad_imageProgress) {
        return;
    }
    TXAdWebImageLoadState *loadState = [self txad_imageLoadStateForKey:self.txad_latestOperationKey];
    if (!loadState) {
        loadState = [TXAdWebImageLoadState new];
    }
    loadState.progress = txad_imageProgress;
    [self txad_setImageLoadState:loadState forKey:self.txad_latestOperationKey];
}

- (nullable id<TXAdWebImageOperation>)txad_internalSetImageWithURL:(nullable NSURL *)url
                                              placeholderImage:(nullable UIImage *)placeholder
                                                       options:(TXAdWebImageOptions)options
                                                       context:(nullable TXAdWebImageContext *)context
                                                 setImageBlock:(nullable TXAdSetImageBlock)setImageBlock
                                                      progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                                                     completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    
    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    //  if url is NSString and shouldUseWeakMemoryCache is true, [cacheKeyForURL:context] will crash. just for a  global protect.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    if (context) {
        // copy to avoid mutable object
        context = [context copy];
    } else {
        context = [NSDictionary dictionary];
    }
    NSString *validOperationKey = context[TXAdWebImageContextSetImageOperationKey];
    if (!validOperationKey) {
        // pass through the operation key to downstream, which can used for tracing operation or image view class
        validOperationKey = NSStringFromClass([self class]);
        TXAdWebImageMutableContext *mutableContext = [context mutableCopy];
        mutableContext[TXAdWebImageContextSetImageOperationKey] = validOperationKey;
        context = [mutableContext copy];
    }
    self.txad_latestOperationKey = validOperationKey;
    if (!(TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAvoidAutoCancelImage))) {
        // cancel previous loading for the same set-image operation key by default
        [self txad_cancelImageLoadOperationWithKey:validOperationKey];
    }
    TXAdWebImageLoadState *loadState = [self txad_imageLoadStateForKey:validOperationKey];
    if (!loadState) {
        loadState = [TXAdWebImageLoadState new];
    }
    loadState.url = url;
    [self txad_setImageLoadState:loadState forKey:validOperationKey];
    
    TXAdWebImageManager *manager = context[TXAdWebImageContextCustomManager];
    if (!manager) {
        manager = [TXAdWebImageManager sharedManager];
    } else {
        // remove this manager to avoid retain cycle (manger -> loader -> operation -> context -> manager)
        TXAdWebImageMutableContext *mutableContext = [context mutableCopy];
        mutableContext[TXAdWebImageContextCustomManager] = nil;
        context = [mutableContext copy];
    }
    
    BOOL shouldUseWeakCache = NO;
    if ([manager.imageCache isKindOfClass:TXAdImageCache.class]) {
        shouldUseWeakCache = ((TXAdImageCache *)manager.imageCache).config.shouldUseWeakMemoryCache;
    }
    if (!(options & TXAdWebImageDelayPlaceholder)) {
        if (shouldUseWeakCache) {
            NSString *key = [manager cacheKeyForURL:url context:context];
            // call memory cache to trigger weak cache sync logic, ignore the return value and go on normal query
            // this unfortunately will cause twice memory cache query, but it's fast enough
            // in the future the weak cache feature may be re-design or removed
            [((TXAdImageCache *)manager.imageCache) imageFromMemoryCacheForKey:key];
        }
        dispatch_main_async_safe(^{
            [self txad_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:TXAdImageCacheTypeNone imageURL:url];
        });
    }
    
    id <TXAdWebImageOperation> operation = nil;
    
    if (url) {
        // reset the progress
        NSProgress *imageProgress = loadState.progress;
        if (imageProgress) {
            imageProgress.totalUnitCount = 0;
            imageProgress.completedUnitCount = 0;
        }
        
#if TXAd_UIKIT || TXAd_MAC
        // check and start image indicator
        [self txad_startImageIndicator];
        id<TXAdWebImageIndicator> imageIndicator = self.txad_imageIndicator;
#endif
        
        TXAdImageLoaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            if (imageProgress) {
                imageProgress.totalUnitCount = expectedSize;
                imageProgress.completedUnitCount = receivedSize;
            }
#if TXAd_UIKIT || TXAd_MAC
            if ([imageIndicator respondsToSelector:@selector(updateIndicatorProgress:)]) {
                double progress = 0;
                if (expectedSize != 0) {
                    progress = (double)receivedSize / expectedSize;
                }
                progress = MAX(MIN(progress, 1), 0); // 0.0 - 1.0
                dispatch_async(dispatch_get_main_queue(), ^{
                    [imageIndicator updateIndicatorProgress:progress];
                });
            }
#endif
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        @weakify(self);
        operation = [manager loadImageWithURL:url options:options context:context progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, TXAdImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            @strongify(self);
            if (!self) { return; }
            // if the progress not been updated, mark it to complete state
            if (imageProgress && finished && !error && imageProgress.totalUnitCount == 0 && imageProgress.completedUnitCount == 0) {
                imageProgress.totalUnitCount = TXAdWebImageProgressUnitCountUnknown;
                imageProgress.completedUnitCount = TXAdWebImageProgressUnitCountUnknown;
            }
            
#if TXAd_UIKIT || TXAd_MAC
            // check and stop image indicator
            if (finished) {
                [self txad_stopImageIndicator];
            }
#endif
            
            BOOL shouldCallCompletedBlock = finished || (options & TXAdWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & TXAdWebImageAvoidAutoSetImage)) ||
                                      (!image && !(options & TXAdWebImageDelayPlaceholder)));
            TXAdWebImageNoParamsBlock callCompletedBlockClosure = ^{
                if (!self) { return; }
                if (!shouldNotSetImage) {
                    [self txad_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, data, error, cacheType, finished, url);
                }
            };
            
            // case 1a: we got an image, but the TXAdWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the TXAdWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClosure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the TXAdWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & TXAdWebImageDelayPlaceholder) {
                // case 2b: we got no image and the TXAdWebImageDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
#if TXAd_UIKIT || TXAd_MAC
            // check whether we should use the image transition
            TXAdWebImageTransition *transition = nil;
            BOOL shouldUseTransition = NO;
            if (options & TXAdWebImageForceTransition) {
                // Always
                shouldUseTransition = YES;
            } else if (cacheType == TXAdImageCacheTypeNone) {
                // From network
                shouldUseTransition = YES;
            } else {
                // From disk (and, user don't use sync query)
                if (cacheType == TXAdImageCacheTypeMemory) {
                    shouldUseTransition = NO;
                } else if (cacheType == TXAdImageCacheTypeDisk) {
                    if (options & TXAdWebImageQueryMemoryDataSync || options & TXAdWebImageQueryDiskDataSync) {
                        shouldUseTransition = NO;
                    } else {
                        shouldUseTransition = YES;
                    }
                } else {
                    // Not valid cache type, fallback
                    shouldUseTransition = NO;
                }
            }
            if (finished && shouldUseTransition) {
                transition = self.txad_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
#if TXAd_UIKIT || TXAd_MAC
                [self txad_setImage:targetImage imageData:targetData options:options basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL callback:callCompletedBlockClosure];
#else
                [self txad_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:cacheType imageURL:imageURL];
                callCompletedBlockClosure();
#endif
            });
        }];
        [self txad_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
#if TXAd_UIKIT || TXAd_MAC
        [self txad_stopImageIndicator];
#endif
        if (completedBlock) {
            dispatch_main_async_safe(^{
                NSError *error = [NSError errorWithDomain:TXAdWebImageErrorDomain code:TXAdWebImageErrorInvalidURL userInfo:@{NSLocalizedDescriptionKey : @"Image url is nil"}];
                completedBlock(nil, nil, error, TXAdImageCacheTypeNone, YES, url);
            });
        }
    }
    
    return operation;
}

- (void)txad_cancelLatestImageLoad {
    [self txad_cancelImageLoadOperationWithKey:self.txad_latestOperationKey];
}

- (void)txad_cancelCurrentImageLoad {
    [self txad_cancelImageLoadOperationWithKey:self.txad_latestOperationKey];
}

// Set image logic without transition (like placeholder and watchOS)
- (void)txad_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(TXAdSetImageBlock)setImageBlock cacheType:(TXAdImageCacheType)cacheType imageURL:(NSURL *)imageURL {
#if TXAd_UIKIT || TXAd_MAC
    [self txad_setImage:image imageData:imageData options:0 basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:nil cacheType:cacheType imageURL:imageURL callback:nil];
#else
    // watchOS does not support view transition. Simplify the logic
    if (setImageBlock) {
        setImageBlock(image, imageData, cacheType, imageURL);
    } else if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        [imageView setImage:image];
    }
#endif
}

// Set image logic with transition
#if TXAd_UIKIT || TXAd_MAC
- (void)txad_setImage:(UIImage *)image imageData:(NSData *)imageData options:(TXAdWebImageOptions)options basedOnClassOrViaCustomSetImageBlock:(TXAdSetImageBlock)setImageBlock transition:(TXAdWebImageTransition *)transition cacheType:(TXAdImageCacheType)cacheType imageURL:(NSURL *)imageURL callback:(TXAdWebImageNoParamsBlock)callback {
    UIView *view = self;
    TXAdSetImageBlock finalSetImageBlock;
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, TXAdImageCacheType setCacheType, NSURL *setImageURL) {
            imageView.image = setImage;
        };
    }
#if TXAd_UIKIT
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, TXAdImageCacheType setCacheType, NSURL *setImageURL) {
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
#endif
#if TXAd_MAC
    else if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, TXAdImageCacheType setCacheType, NSURL *setImageURL) {
            button.image = setImage;
        };
    }
#endif
    
    BOOL waitTransition = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageWaitTransition);
    if (transition) {
        NSString *originalOperationKey = view.txad_latestOperationKey;

#if TXAd_UIKIT
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            if (!view.txad_latestOperationKey || ![originalOperationKey isEqualToString:view.txad_latestOperationKey]) {
                return;
            }
            // 0 duration to let UIKit render placeholder and prepares block
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL tempFinished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                if (!view.txad_latestOperationKey || ![originalOperationKey isEqualToString:view.txad_latestOperationKey]) {
                    return;
                }
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:^(BOOL finished) {
                if (!view.txad_latestOperationKey || ![originalOperationKey isEqualToString:view.txad_latestOperationKey]) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(finished);
                }
                if (waitTransition) {
                    if (callback) {
                        callback();
                    }
                }
            }];
        }];
#elif TXAd_MAC
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull prepareContext) {
            if (!view.txad_latestOperationKey || ![originalOperationKey isEqualToString:view.txad_latestOperationKey]) {
                return;
            }
            // 0 duration to let AppKit render placeholder and prepares block
            prepareContext.duration = 0;
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                if (!view.txad_latestOperationKey || ![originalOperationKey isEqualToString:view.txad_latestOperationKey]) {
                    return;
                }
                context.duration = transition.duration;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                CAMediaTimingFunction *timingFunction = transition.timingFunction;
#pragma clang diagnostic pop
                if (!timingFunction) {
                    timingFunction = TXAdTimingFunctionFromAnimationOptions(transition.animationOptions);
                }
                context.timingFunction = timingFunction;
                context.allowsImplicitAnimation = TXAd_OPTIONS_CONTAINS(transition.animationOptions, TXAdWebImageAnimationOptionAllowsImplicitAnimation);
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                CATransition *trans = TXAdTransitionFromAnimationOptions(transition.animationOptions);
                if (trans) {
                    [view.layer addAnimation:trans forKey:kCATransition];
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completionHandler:^{
                if (!view.txad_latestOperationKey || ![originalOperationKey isEqualToString:view.txad_latestOperationKey]) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(YES);
                }
                if (waitTransition) {
                    if (callback) {
                        callback();
                    }
                }
            }];
        }];
#endif
        if (!waitTransition) {
            if (callback) {
                callback();
            }
        }
    } else {
        if (finalSetImageBlock) {
            finalSetImageBlock(image, imageData, cacheType, imageURL);
            // TODO, in 6.0
            // for `waitTransition`, the `setImageBlock` will provide a extra `completionHandler` params
            // Execute `callback` only after that completionHandler is called
            if (waitTransition) {
                if (callback) {
                    callback();
                }
            }
        }
        if (!waitTransition) {
            if (callback) {
                callback();
            }
        }
    }
}
#endif

- (void)txad_setNeedsLayout {
#if TXAd_UIKIT
    [self setNeedsLayout];
#elif TXAd_MAC
    [self setNeedsLayout:YES];
#elif TXAd_WATCH
    // Do nothing because WatchKit automatically layout the view after property change
#endif
}

#if TXAd_UIKIT || TXAd_MAC

#pragma mark - Image Transition
- (TXAdWebImageTransition *)txad_imageTransition {
    return objc_getAssociatedObject(self, @selector(txad_imageTransition));
}

- (void)setSd_imageTransition:(TXAdWebImageTransition *)txad_imageTransition {
    objc_setAssociatedObject(self, @selector(txad_imageTransition), txad_imageTransition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Indicator
- (id<TXAdWebImageIndicator>)txad_imageIndicator {
    return objc_getAssociatedObject(self, @selector(txad_imageIndicator));
}

- (void)setSd_imageIndicator:(id<TXAdWebImageIndicator>)txad_imageIndicator {
    // Remove the old indicator view
    id<TXAdWebImageIndicator> previousIndicator = self.txad_imageIndicator;
    [previousIndicator.indicatorView removeFromSuperview];
    
    objc_setAssociatedObject(self, @selector(txad_imageIndicator), txad_imageIndicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add the new indicator view
    UIView *view = txad_imageIndicator.indicatorView;
    if (CGRectEqualToRect(view.frame, CGRectZero)) {
        view.frame = self.bounds;
    }
    // Center the indicator view
#if TXAd_MAC
    [view setFrameOrigin:CGPointMake(round((NSWidth(self.bounds) - NSWidth(view.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(view.frame)) / 2))];
#else
    view.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
#endif
    view.hidden = NO;
    [self addSubview:view];
}

- (void)txad_startImageIndicator {
    id<TXAdWebImageIndicator> imageIndicator = self.txad_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator startAnimatingIndicator];
    });
}

- (void)txad_stopImageIndicator {
    id<TXAdWebImageIndicator> imageIndicator = self.txad_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator stopAnimatingIndicator];
    });
}

#endif

@end
