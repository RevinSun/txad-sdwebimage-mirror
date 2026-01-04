/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageCachesManager.h"
#import "TXAdImageCachesManagerOperation.h"
#import "TXAdImageCache.h"
#import "TXAdInternalMacros.h"

@interface TXAdImageCachesManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<TXAdImageCache>> *imageCaches;

@end

@implementation TXAdImageCachesManager {
    TXAd_LOCK_DECLARE(_cachesLock);
}

+ (TXAdImageCachesManager *)sharedManager {
    static dispatch_once_t onceToken;
    static TXAdImageCachesManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[TXAdImageCachesManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryOperationPolicy = TXAdImageCachesManagerOperationPolicySerial;
        self.storeOperationPolicy = TXAdImageCachesManagerOperationPolicyHighestOnly;
        self.removeOperationPolicy = TXAdImageCachesManagerOperationPolicyConcurrent;
        self.containsOperationPolicy = TXAdImageCachesManagerOperationPolicySerial;
        self.clearOperationPolicy = TXAdImageCachesManagerOperationPolicyConcurrent;
        // initialize with default image caches
        _imageCaches = [NSMutableArray arrayWithObject:[TXAdImageCache sharedImageCache]];
        TXAd_LOCK_INIT(_cachesLock);
    }
    return self;
}

- (NSArray<id<TXAdImageCache>> *)caches {
    TXAd_LOCK(_cachesLock);
    NSArray<id<TXAdImageCache>> *caches = [_imageCaches copy];
    TXAd_UNLOCK(_cachesLock);
    return caches;
}

- (void)setCaches:(NSArray<id<TXAdImageCache>> *)caches {
    TXAd_LOCK(_cachesLock);
    [_imageCaches removeAllObjects];
    if (caches.count) {
        [_imageCaches addObjectsFromArray:caches];
    }
    TXAd_UNLOCK(_cachesLock);
}

#pragma mark - Cache IO operations

- (void)addCache:(id<TXAdImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(TXAdImageCache)]) {
        return;
    }
    TXAd_LOCK(_cachesLock);
    [_imageCaches addObject:cache];
    TXAd_UNLOCK(_cachesLock);
}

- (void)removeCache:(id<TXAdImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(TXAdImageCache)]) {
        return;
    }
    TXAd_LOCK(_cachesLock);
    [_imageCaches removeObject:cache];
    TXAd_UNLOCK(_cachesLock);
}

#pragma mark - TXAdImageCache

- (id<TXAdWebImageOperation>)queryImageForKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context completion:(TXAdImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:TXAdImageCacheTypeAll completion:completionBlock];
}

- (id<TXAdWebImageOperation>)queryImageForKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)cacheType completion:(TXAdImageCacheQueryCompletionBlock)completionBlock {
    if (!key) {
        return nil;
    }
    NSArray<id<TXAdImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return nil;
    } else if (count == 1) {
        return [caches.firstObject queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
    }
    switch (self.queryOperationPolicy) {
        case TXAdImageCachesManagerOperationPolicyHighestOnly: {
            id<TXAdImageCache> cache = caches.lastObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyLowestOnly: {
            id<TXAdImageCache> cache = caches.firstObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyConcurrent: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        case TXAdImageCachesManagerOperationPolicySerial: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        default:
            return nil;
            break;
    }
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:cacheType completion:completionBlock];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<TXAdImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.storeOperationPolicy) {
        case TXAdImageCachesManagerOperationPolicyHighestOnly: {
            id<TXAdImageCache> cache = caches.lastObject;
            [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyLowestOnly: {
            id<TXAdImageCache> cache = caches.firstObject;
            [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyConcurrent: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentStoreImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXAdImageCachesManagerOperationPolicySerial: {
            [self serialStoreImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)removeImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<TXAdImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject removeImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.removeOperationPolicy) {
        case TXAdImageCachesManagerOperationPolicyHighestOnly: {
            id<TXAdImageCache> cache = caches.lastObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyLowestOnly: {
            id<TXAdImageCache> cache = caches.firstObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyConcurrent: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXAdImageCachesManagerOperationPolicySerial: {
            [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdImageCacheContainsCompletionBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<TXAdImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject containsImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case TXAdImageCachesManagerOperationPolicyHighestOnly: {
            id<TXAdImageCache> cache = caches.lastObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyLowestOnly: {
            id<TXAdImageCache> cache = caches.firstObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyConcurrent: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXAdImageCachesManagerOperationPolicySerial: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        default:
            break;
    }
}

- (void)clearWithCacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock {
    NSArray<id<TXAdImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject clearWithCacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case TXAdImageCachesManagerOperationPolicyHighestOnly: {
            id<TXAdImageCache> cache = caches.lastObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyLowestOnly: {
            id<TXAdImageCache> cache = caches.firstObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case TXAdImageCachesManagerOperationPolicyConcurrent: {
            TXAdImageCachesManagerOperation *operation = [TXAdImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXAdImageCachesManagerOperationPolicySerial: {
            [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

#pragma mark - Concurrent Operation

- (void)concurrentQueryImageForKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)queryCacheType completion:(TXAdImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXAdImageCache> cache in enumerator) {
        [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXAdImageCacheType cacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (image) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(image, data, cacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(nil, nil, TXAdImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXAdImageCache> cache in enumerator) {
        [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentRemoveImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXAdImageCache> cache in enumerator) {
        [cache removeImageForKey:key cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentContainsImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXAdImageCache> cache in enumerator) {
        [cache containsImageForKey:key cacheType:cacheType completion:^(TXAdImageCacheType containsCacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (containsCacheType != TXAdImageCacheTypeNone) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(containsCacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(TXAdImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentClearWithCacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXAdImageCache> cache in enumerator) {
        [cache clearWithCacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

#pragma mark - Serial Operation

- (void)serialQueryImageForKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)queryCacheType completion:(TXAdImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<TXAdImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(nil, nil, TXAdImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXAdImageCacheType cacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (image) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(image, data, cacheType);
            }
            return;
        }
        // Next
        [self serialQueryImageForKey:key options:options context:context cacheType:queryCacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<TXAdImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache storeImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialStoreImage:image imageData:imageData forKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialRemoveImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<TXAdImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache removeImageForKey:key cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialContainsImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(TXAdImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator operation:(TXAdImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<TXAdImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(TXAdImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache containsImageForKey:key cacheType:cacheType completion:^(TXAdImageCacheType containsCacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (containsCacheType != TXAdImageCacheTypeNone) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(containsCacheType);
            }
            return;
        }
        // Next
        [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialClearWithCacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXAdImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<TXAdImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache clearWithCacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

@end
