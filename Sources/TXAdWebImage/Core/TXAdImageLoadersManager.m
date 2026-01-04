/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageLoadersManager.h"
#import "TXAdWebImageDownloader.h"
#import "TXAdInternalMacros.h"

@interface TXAdImageLoadersManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<TXAdImageLoader>> *imageLoaders;

@end

@implementation TXAdImageLoadersManager {
    TXAd_LOCK_DECLARE(_loadersLock);
}

+ (TXAdImageLoadersManager *)sharedManager {
    static dispatch_once_t onceToken;
    static TXAdImageLoadersManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[TXAdImageLoadersManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // initialize with default image loaders
        _imageLoaders = [NSMutableArray arrayWithObject:[TXAdWebImageDownloader sharedDownloader]];
        TXAd_LOCK_INIT(_loadersLock);
    }
    return self;
}

- (NSArray<id<TXAdImageLoader>> *)loaders {
    TXAd_LOCK(_loadersLock);
    NSArray<id<TXAdImageLoader>>* loaders = [_imageLoaders copy];
    TXAd_UNLOCK(_loadersLock);
    return loaders;
}

- (void)setLoaders:(NSArray<id<TXAdImageLoader>> *)loaders {
    TXAd_LOCK(_loadersLock);
    [_imageLoaders removeAllObjects];
    if (loaders.count) {
        [_imageLoaders addObjectsFromArray:loaders];
    }
    TXAd_UNLOCK(_loadersLock);
}

#pragma mark - Loader Property

- (void)addLoader:(id<TXAdImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(TXAdImageLoader)]) {
        return;
    }
    TXAd_LOCK(_loadersLock);
    [_imageLoaders addObject:loader];
    TXAd_UNLOCK(_loadersLock);
}

- (void)removeLoader:(id<TXAdImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(TXAdImageLoader)]) {
        return;
    }
    TXAd_LOCK(_loadersLock);
    [_imageLoaders removeObject:loader];
    TXAd_UNLOCK(_loadersLock);
}

#pragma mark - TXAdImageLoader

- (BOOL)canRequestImageForURL:(nullable NSURL *)url {
    return [self canRequestImageForURL:url options:0 context:nil];
}

- (BOOL)canRequestImageForURL:(NSURL *)url options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context {
    NSArray<id<TXAdImageLoader>> *loaders = self.loaders;
    for (id<TXAdImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader respondsToSelector:@selector(canRequestImageForURL:options:context:)]) {
            if ([loader canRequestImageForURL:url options:options context:context]) {
                return YES;
            }
        } else {
            if ([loader canRequestImageForURL:url]) {
                return YES;
            }
        }
    }
    return NO;
}

- (id<TXAdWebImageOperation>)requestImageWithURL:(NSURL *)url options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context progress:(TXAdImageLoaderProgressBlock)progressBlock completed:(TXAdImageLoaderCompletedBlock)completedBlock {
    if (!url) {
        return nil;
    }
    NSArray<id<TXAdImageLoader>> *loaders = self.loaders;
    for (id<TXAdImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader requestImageWithURL:url options:options context:context progress:progressBlock completed:completedBlock];
        }
    }
    return nil;
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error {
    NSArray<id<TXAdImageLoader>> *loaders = self.loaders;
    for (id<TXAdImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    return NO;
}

@end
