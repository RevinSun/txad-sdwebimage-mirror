/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageManager.h"
#import "TXAdImageCache.h"
#import "TXAdWebImageDownloader.h"
#import "UIImage+Metadata.h"
#import "TXAdAssociatedObject.h"
#import "TXAdWebImageError.h"
#import "TXAdInternalMacros.h"
#import "TXAdCallbackQueue.h"

static id<TXAdImageCache> _defaultImageCache;
static id<TXAdImageLoader> _defaultImageLoader;

@interface TXAdWebImageCombinedOperation ()

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (strong, nonatomic, readwrite, nullable) id<TXAdWebImageOperation> loaderOperation;
@property (strong, nonatomic, readwrite, nullable) id<TXAdWebImageOperation> cacheOperation;
@property (weak, nonatomic, nullable) TXAdWebImageManager *manager;

@end

@interface TXAdWebImageManager () {
    TXAd_LOCK_DECLARE(_failedURLsLock); // a lock to keep the access to `failedURLs` thread-safe
    TXAd_LOCK_DECLARE(_runningOperationsLock); // a lock to keep the access to `runningOperations` thread-safe
}

@property (strong, nonatomic, readwrite, nonnull) TXAdImageCache *imageCache;
@property (strong, nonatomic, readwrite, nonnull) id<TXAdImageLoader> imageLoader;
@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;
@property (strong, nonatomic, nonnull) NSMutableSet<TXAdWebImageCombinedOperation *> *runningOperations;

@end

@implementation TXAdWebImageManager

+ (id<TXAdImageCache>)defaultImageCache {
    return _defaultImageCache;
}

+ (void)setDefaultImageCache:(id<TXAdImageCache>)defaultImageCache {
    if (defaultImageCache && ![defaultImageCache conformsToProtocol:@protocol(TXAdImageCache)]) {
        return;
    }
    _defaultImageCache = defaultImageCache;
}

+ (id<TXAdImageLoader>)defaultImageLoader {
    return _defaultImageLoader;
}

+ (void)setDefaultImageLoader:(id<TXAdImageLoader>)defaultImageLoader {
    if (defaultImageLoader && ![defaultImageLoader conformsToProtocol:@protocol(TXAdImageLoader)]) {
        return;
    }
    _defaultImageLoader = defaultImageLoader;
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    id<TXAdImageCache> cache = [[self class] defaultImageCache];
    if (!cache) {
        cache = [TXAdImageCache sharedImageCache];
    }
    id<TXAdImageLoader> loader = [[self class] defaultImageLoader];
    if (!loader) {
        loader = [TXAdWebImageDownloader sharedDownloader];
    }
    return [self initWithCache:cache loader:loader];
}

- (nonnull instancetype)initWithCache:(nonnull id<TXAdImageCache>)cache loader:(nonnull id<TXAdImageLoader>)loader {
    if ((self = [super init])) {
        _imageCache = cache;
        _imageLoader = loader;
        _failedURLs = [NSMutableSet new];
        TXAd_LOCK_INIT(_failedURLsLock);
        _runningOperations = [NSMutableSet new];
        TXAd_LOCK_INIT(_runningOperationsLock);
    }
    return self;
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<TXAdWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    return key;
}

- (nullable NSString *)originalCacheKeyForURL:(nullable NSURL *)url context:(nullable TXAdWebImageContext *)context {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<TXAdWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (context[TXAdWebImageContextCacheKeyFilter]) {
        cacheKeyFilter = context[TXAdWebImageContextCacheKeyFilter];
    }
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    return key;
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url context:(nullable TXAdWebImageContext *)context {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<TXAdWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (context[TXAdWebImageContextCacheKeyFilter]) {
        cacheKeyFilter = context[TXAdWebImageContextCacheKeyFilter];
    }
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    // Thumbnail Key Appending
    NSValue *thumbnailSizeValue = context[TXAdWebImageContextImageThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
        CGSize thumbnailSize = CGSizeZero;
#if TXAd_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
#else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
#endif
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = context[TXAdWebImageContextImagePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        key = TXAdThumbnailedKeyForKey(key, thumbnailSize, preserveAspectRatio);
    }
    
    // Transformer Key Appending
    id<TXAdImageTransformer> transformer = self.transformer;
    if (context[TXAdWebImageContextImageTransformer]) {
        transformer = context[TXAdWebImageContextImageTransformer];
        if ([transformer isEqual:NSNull.null]) {
            transformer = nil;
        }
    }
    if (transformer) {
        key = TXAdTransformedKeyForKey(key, transformer.transformerKey);
    }
    
    return key;
}

- (TXAdWebImageCombinedOperation *)loadImageWithURL:(NSURL *)url options:(TXAdWebImageOptions)options progress:(TXAdImageLoaderProgressBlock)progressBlock completed:(TXAdInternalCompletionBlock)completedBlock {
    return [self loadImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (TXAdWebImageCombinedOperation *)loadImageWithURL:(nullable NSURL *)url
                                          options:(TXAdWebImageOptions)options
                                          context:(nullable TXAdWebImageContext *)context
                                         progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                                        completed:(nonnull TXAdInternalCompletionBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[TXAdWebImagePrefetcher prefetchURLs] instead");

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    TXAdWebImageCombinedOperation *operation = [TXAdWebImageCombinedOperation new];
    operation.manager = self;

    BOOL isFailedUrl = NO;
    if (url) {
        TXAd_LOCK(_failedURLsLock);
        isFailedUrl = [self.failedURLs containsObject:url];
        TXAd_UNLOCK(_failedURLsLock);
    }
    
    // Preprocess the options and context arg to decide the final the result for manager
    TXAdWebImageOptionsResult *result = [self processedResultForURL:url options:options context:context];

    if (url.absoluteString.length == 0 || (!(options & TXAdWebImageRetryFailed) && isFailedUrl)) {
        NSString *description = isFailedUrl ? @"Image url is blacklisted" : @"Image url is nil";
        NSInteger code = isFailedUrl ? TXAdWebImageErrorBlackListed : TXAdWebImageErrorInvalidURL;
        [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:TXAdWebImageErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : description}] queue:result.context[TXAdWebImageContextCallbackQueue] url:url];
        return operation;
    }

    TXAd_LOCK(_runningOperationsLock);
    [self.runningOperations addObject:operation];
    TXAd_UNLOCK(_runningOperationsLock);
    
    // Start the entry to load image from cache, the longest steps are below
    // Steps without transformer:
    // 1. query image from cache, miss
    // 2. download data and image
    // 3. store image to cache
    
    // Steps with transformer:
    // 1. query transformed image from cache, miss
    // 2. query original image from cache, miss
    // 3. download data and image
    // 4. do transform in CPU
    // 5. store original image to cache
    // 6. store transformed image to cache
    [self callCacheProcessForOperation:operation url:url options:result.options context:result.context progress:progressBlock completed:completedBlock];

    return operation;
}

- (void)cancelAll {
    TXAd_LOCK(_runningOperationsLock);
    NSSet<TXAdWebImageCombinedOperation *> *copiedOperations = [self.runningOperations copy];
    TXAd_UNLOCK(_runningOperationsLock);
    [copiedOperations makeObjectsPerformSelector:@selector(cancel)]; // This will call `safelyRemoveOperationFromRunning:` and remove from the array
}

- (BOOL)isRunning {
    BOOL isRunning = NO;
    TXAd_LOCK(_runningOperationsLock);
    isRunning = (self.runningOperations.count > 0);
    TXAd_UNLOCK(_runningOperationsLock);
    return isRunning;
}

- (void)removeFailedURL:(NSURL *)url {
    if (!url) {
        return;
    }
    TXAd_LOCK(_failedURLsLock);
    [self.failedURLs removeObject:url];
    TXAd_UNLOCK(_failedURLsLock);
}

- (void)removeAllFailedURLs {
    TXAd_LOCK(_failedURLsLock);
    [self.failedURLs removeAllObjects];
    TXAd_UNLOCK(_failedURLsLock);
}

#pragma mark - Private

// Query normal cache process
- (void)callCacheProcessForOperation:(nonnull TXAdWebImageCombinedOperation *)operation
                                 url:(nonnull NSURL *)url
                             options:(TXAdWebImageOptions)options
                             context:(nullable TXAdWebImageContext *)context
                            progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                           completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    // Grab the image cache to use
    id<TXAdImageCache> imageCache = context[TXAdWebImageContextImageCache];
    if (!imageCache) {
        imageCache = self.imageCache;
    }
    // Get the query cache type
    TXAdImageCacheType queryCacheType = TXAdImageCacheTypeAll;
    if (context[TXAdWebImageContextQueryCacheType]) {
        queryCacheType = [context[TXAdWebImageContextQueryCacheType] integerValue];
    }
    
    // Check whether we should query cache
    BOOL shouldQueryCache = !TXAd_OPTIONS_CONTAINS(options, TXAdWebImageFromLoaderOnly);
    if (shouldQueryCache) {
        // transformed cache key
        NSString *key = [self cacheKeyForURL:url context:context];
        // to avoid the TXAdImageCache's sync logic use the mismatched cache key
        // we should strip the `thumbnail` related context
        TXAdWebImageMutableContext *mutableContext = [context mutableCopy];
        mutableContext[TXAdWebImageContextImageThumbnailPixelSize] = nil;
        mutableContext[TXAdWebImageContextImagePreserveAspectRatio] = nil;
        @weakify(operation);
        operation.cacheOperation = [imageCache queryImageForKey:key options:options context:mutableContext cacheType:queryCacheType completion:^(UIImage * _Nullable cachedImage, NSData * _Nullable cachedData, TXAdImageCacheType cacheType) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:TXAdWebImageErrorDomain code:TXAdWebImageErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during querying the cache"}] queue:context[TXAdWebImageContextCallbackQueue] url:url];
                [self safelyRemoveOperationFromRunning:operation];
                return;
            } else if (!cachedImage) {
                NSString *originKey = [self originalCacheKeyForURL:url context:context];
                BOOL mayInOriginalCache = ![key isEqualToString:originKey];
                // Have a chance to query original cache instead of downloading, then applying transform
                // Thumbnail decoding is done inside TXAdImageCache's decoding part, which does not need post processing for transform
                if (mayInOriginalCache) {
                    [self callOriginalCacheProcessForOperation:operation url:url options:options context:context progress:progressBlock completed:completedBlock];
                    return;
                }
            }
            // Continue download process
            [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:cachedImage cachedData:cachedData cacheType:cacheType progress:progressBlock completed:completedBlock];
        }];
    } else {
        // Continue download process
        [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:TXAdImageCacheTypeNone progress:progressBlock completed:completedBlock];
    }
}

// Query original cache process
- (void)callOriginalCacheProcessForOperation:(nonnull TXAdWebImageCombinedOperation *)operation
                                         url:(nonnull NSURL *)url
                                     options:(TXAdWebImageOptions)options
                                     context:(nullable TXAdWebImageContext *)context
                                    progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                                   completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    // Grab the image cache to use, choose standalone original cache firstly
    id<TXAdImageCache> imageCache = context[TXAdWebImageContextOriginalImageCache];
    if (!imageCache) {
        // if no standalone cache available, use default cache
        imageCache = context[TXAdWebImageContextImageCache];
        if (!imageCache) {
            imageCache = self.imageCache;
        }
    }
    // Get the original query cache type
    TXAdImageCacheType originalQueryCacheType = TXAdImageCacheTypeDisk;
    if (context[TXAdWebImageContextOriginalQueryCacheType]) {
        originalQueryCacheType = [context[TXAdWebImageContextOriginalQueryCacheType] integerValue];
    }
    
    // Check whether we should query original cache
    BOOL shouldQueryOriginalCache = (originalQueryCacheType != TXAdImageCacheTypeNone);
    if (shouldQueryOriginalCache) {
        // Get original cache key generation without transformer
        NSString *key = [self originalCacheKeyForURL:url context:context];
        @weakify(operation);
        operation.cacheOperation = [imageCache queryImageForKey:key options:options context:context cacheType:originalQueryCacheType completion:^(UIImage * _Nullable cachedImage, NSData * _Nullable cachedData, TXAdImageCacheType cacheType) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:TXAdWebImageErrorDomain code:TXAdWebImageErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during querying the cache"}] queue:context[TXAdWebImageContextCallbackQueue] url:url];
                [self safelyRemoveOperationFromRunning:operation];
                return;
            } else if (!cachedImage) {
                // Original image cache miss. Continue download process
                [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:TXAdImageCacheTypeNone progress:progressBlock completed:completedBlock];
                return;
            }
                        
            // Skip downloading and continue transform process, and ignore .refreshCached option for now
            [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:cachedImage originalData:cachedData cacheType:cacheType finished:YES completed:completedBlock];
            
            [self safelyRemoveOperationFromRunning:operation];
        }];
    } else {
        // Continue download process
        [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:TXAdImageCacheTypeNone progress:progressBlock completed:completedBlock];
    }
}

// Download process
- (void)callDownloadProcessForOperation:(nonnull TXAdWebImageCombinedOperation *)operation
                                    url:(nonnull NSURL *)url
                                options:(TXAdWebImageOptions)options
                                context:(TXAdWebImageContext *)context
                            cachedImage:(nullable UIImage *)cachedImage
                             cachedData:(nullable NSData *)cachedData
                              cacheType:(TXAdImageCacheType)cacheType
                               progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                              completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    // Mark the cache operation end
    @synchronized (operation) {
        operation.cacheOperation = nil;
    }
    
    // Grab the image loader to use
    id<TXAdImageLoader> imageLoader = context[TXAdWebImageContextImageLoader];
    if (!imageLoader) {
        imageLoader = self.imageLoader;
    }
    
    // Check whether we should download image from network
    BOOL shouldDownload = !TXAd_OPTIONS_CONTAINS(options, TXAdWebImageFromCacheOnly);
    shouldDownload &= (!cachedImage || options & TXAdWebImageRefreshCached);
    shouldDownload &= (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url]);
    if ([imageLoader respondsToSelector:@selector(canRequestImageForURL:options:context:)]) {
        shouldDownload &= [imageLoader canRequestImageForURL:url options:options context:context];
    } else {
        shouldDownload &= [imageLoader canRequestImageForURL:url];
    }
    if (shouldDownload) {
        if (cachedImage && options & TXAdWebImageRefreshCached) {
            // If image was found in the cache but TXAdWebImageRefreshCached is provided, notify about the cached image
            // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
            [self callCompletionBlockForOperation:operation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES queue:context[TXAdWebImageContextCallbackQueue] url:url];
            // Pass the cached image to the image loader. The image loader should check whether the remote image is equal to the cached image.
            TXAdWebImageMutableContext *mutableContext;
            if (context) {
                mutableContext = [context mutableCopy];
            } else {
                mutableContext = [NSMutableDictionary dictionary];
            }
            mutableContext[TXAdWebImageContextLoaderCachedImage] = cachedImage;
            context = [mutableContext copy];
        }
        
        @weakify(operation);
        operation.loaderOperation = [imageLoader requestImageWithURL:url options:options context:context progress:progressBlock completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:TXAdWebImageErrorDomain code:TXAdWebImageErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during sending the request"}] queue:context[TXAdWebImageContextCallbackQueue] url:url];
            } else if (cachedImage && options & TXAdWebImageRefreshCached && [error.domain isEqualToString:TXAdWebImageErrorDomain] && error.code == TXAdWebImageErrorCacheNotModified) {
                // Image refresh hit the NSURLCache cache, do not call the completion block
            } else if ([error.domain isEqualToString:TXAdWebImageErrorDomain] && error.code == TXAdWebImageErrorCancelled) {
                // Download operation cancelled by user before sending the request, don't block failed URL
                [self callCompletionBlockForOperation:operation completion:completedBlock error:error queue:context[TXAdWebImageContextCallbackQueue] url:url];
            } else if (error) {
                [self callCompletionBlockForOperation:operation completion:completedBlock error:error queue:context[TXAdWebImageContextCallbackQueue] url:url];
                BOOL shouldBlockFailedURL = [self shouldBlockFailedURLWithURL:url error:error options:options context:context];
                
                if (shouldBlockFailedURL) {
                    TXAd_LOCK(self->_failedURLsLock);
                    [self.failedURLs addObject:url];
                    TXAd_UNLOCK(self->_failedURLsLock);
                }
            } else {
                if ((options & TXAdWebImageRetryFailed)) {
                    TXAd_LOCK(self->_failedURLsLock);
                    [self.failedURLs removeObject:url];
                    TXAd_UNLOCK(self->_failedURLsLock);
                }
                // Continue transform process
                [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:downloadedImage originalData:downloadedData cacheType:TXAdImageCacheTypeNone finished:finished completed:completedBlock];
            }
            
            if (finished) {
                [self safelyRemoveOperationFromRunning:operation];
            }
        }];
    } else if (cachedImage) {
        [self callCompletionBlockForOperation:operation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES queue:context[TXAdWebImageContextCallbackQueue] url:url];
        [self safelyRemoveOperationFromRunning:operation];
    } else {
        // Image not in cache and download disallowed by delegate
        [self callCompletionBlockForOperation:operation completion:completedBlock image:nil data:nil error:nil cacheType:TXAdImageCacheTypeNone finished:YES queue:context[TXAdWebImageContextCallbackQueue] url:url];
        [self safelyRemoveOperationFromRunning:operation];
    }
}

// Transform process
- (void)callTransformProcessForOperation:(nonnull TXAdWebImageCombinedOperation *)operation
                                     url:(nonnull NSURL *)url
                                 options:(TXAdWebImageOptions)options
                                 context:(TXAdWebImageContext *)context
                           originalImage:(nullable UIImage *)originalImage
                            originalData:(nullable NSData *)originalData
                               cacheType:(TXAdImageCacheType)cacheType
                                finished:(BOOL)finished
                               completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    id<TXAdImageTransformer> transformer = context[TXAdWebImageContextImageTransformer];
    if ([transformer isEqual:NSNull.null]) {
        transformer = nil;
    }
    // transformer check
    BOOL shouldTransformImage = originalImage && transformer;
    shouldTransformImage = shouldTransformImage && (!originalImage.txad_isAnimated || (options & TXAdWebImageTransformAnimatedImage));
    shouldTransformImage = shouldTransformImage && (!originalImage.txad_isVector || (options & TXAdWebImageTransformVectorImage));
    // thumbnail check
    BOOL isThumbnail = originalImage.txad_isThumbnail;
    NSData *cacheData = originalData;
    UIImage *cacheImage = originalImage;
    if (isThumbnail) {
        cacheData = nil; // thumbnail don't store full size data
        originalImage = nil; // thumbnail don't have full size image
    }
    
    if (shouldTransformImage) {
        // transformed cache key
        NSString *key = [self cacheKeyForURL:url context:context];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Case that transformer on thumbnail, which this time need full pixel image
            UIImage *transformedImage = [transformer transformedImageWithImage:cacheImage forKey:key];
            if (transformedImage) {
                // We need keep some metadata from the full size image when needed
                // Because most of our transformer does not care about these information
                BOOL preserveImageMetadata = YES;
                if ([transformer respondsToSelector:@selector(preserveImageMetadata)]) {
                    preserveImageMetadata = transformer.preserveImageMetadata;
                }
                if (preserveImageMetadata) {
                    TXAdImageCopyAssociatedObject(cacheImage, transformedImage);
                }
                // Mark the transformed
                transformedImage.txad_isTransformed = YES;
                [self callStoreOriginCacheProcessForOperation:operation url:url options:options context:context originalImage:originalImage cacheImage:transformedImage originalData:originalData cacheData:nil cacheType:cacheType finished:finished completed:completedBlock];
            } else {
                [self callStoreOriginCacheProcessForOperation:operation url:url options:options context:context originalImage:originalImage cacheImage:cacheImage originalData:originalData cacheData:cacheData cacheType:cacheType finished:finished completed:completedBlock];
            }
        });
    } else {
        [self callStoreOriginCacheProcessForOperation:operation url:url options:options context:context originalImage:originalImage cacheImage:cacheImage originalData:originalData cacheData:cacheData cacheType:cacheType finished:finished completed:completedBlock];
    }
}

// Store origin cache process
- (void)callStoreOriginCacheProcessForOperation:(nonnull TXAdWebImageCombinedOperation *)operation
                                            url:(nonnull NSURL *)url
                                        options:(TXAdWebImageOptions)options
                                        context:(TXAdWebImageContext *)context
                                  originalImage:(nullable UIImage *)originalImage
                                     cacheImage:(nullable UIImage *)cacheImage
                                   originalData:(nullable NSData *)originalData
                                      cacheData:(nullable NSData *)cacheData
                                      cacheType:(TXAdImageCacheType)cacheType
                                       finished:(BOOL)finished
                                      completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    // Grab the image cache to use, choose standalone original cache firstly
    id<TXAdImageCache> imageCache = context[TXAdWebImageContextOriginalImageCache];
    if (!imageCache) {
        // if no standalone cache available, use default cache
        imageCache = context[TXAdWebImageContextImageCache];
        if (!imageCache) {
            imageCache = self.imageCache;
        }
    }
    // the original store image cache type
    TXAdImageCacheType originalStoreCacheType = TXAdImageCacheTypeDisk;
    if (context[TXAdWebImageContextOriginalStoreCacheType]) {
        originalStoreCacheType = [context[TXAdWebImageContextOriginalStoreCacheType] integerValue];
    }
    id<TXAdWebImageCacheSerializer> cacheSerializer = context[TXAdWebImageContextCacheSerializer];
    
    // If the original cacheType is disk, since we don't need to store the original data again
    // Strip the disk from the originalStoreCacheType
    if (cacheType == TXAdImageCacheTypeDisk) {
        if (originalStoreCacheType == TXAdImageCacheTypeDisk) originalStoreCacheType = TXAdImageCacheTypeNone;
        if (originalStoreCacheType == TXAdImageCacheTypeAll) originalStoreCacheType = TXAdImageCacheTypeMemory;
    }
    
    // Get original cache key generation without transformer
    NSString *key = [self originalCacheKeyForURL:url context:context];
    if (finished && cacheSerializer && (originalStoreCacheType == TXAdImageCacheTypeDisk || originalStoreCacheType == TXAdImageCacheTypeAll)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData *newOriginalData = [cacheSerializer cacheDataWithImage:originalImage originalData:originalData imageURL:url];
            // Store original image and data
            [self storeImage:originalImage imageData:newOriginalData forKey:key options:options context:context imageCache:imageCache cacheType:originalStoreCacheType finished:finished completion:^{
                // Continue store cache process, transformed data is nil
                [self callStoreCacheProcessForOperation:operation url:url options:options context:context image:cacheImage data:cacheData cacheType:cacheType finished:finished completed:completedBlock];
            }];
        });
    } else {
        // Store original image and data
        [self storeImage:originalImage imageData:originalData forKey:key options:options context:context imageCache:imageCache cacheType:originalStoreCacheType finished:finished completion:^{
            // Continue store cache process, transformed data is nil
            [self callStoreCacheProcessForOperation:operation url:url options:options context:context image:cacheImage data:cacheData cacheType:cacheType finished:finished completed:completedBlock];
        }];
    }
}

// Store normal cache process
- (void)callStoreCacheProcessForOperation:(nonnull TXAdWebImageCombinedOperation *)operation
                                      url:(nonnull NSURL *)url
                                  options:(TXAdWebImageOptions)options
                                  context:(TXAdWebImageContext *)context
                                    image:(nullable UIImage *)image
                                     data:(nullable NSData *)data
                                cacheType:(TXAdImageCacheType)cacheType
                                 finished:(BOOL)finished
                                completed:(nullable TXAdInternalCompletionBlock)completedBlock {
    // Grab the image cache to use
    id<TXAdImageCache> imageCache = context[TXAdWebImageContextImageCache];
    if (!imageCache) {
        imageCache = self.imageCache;
    }
    // the target image store cache type
    TXAdImageCacheType storeCacheType = TXAdImageCacheTypeAll;
    if (context[TXAdWebImageContextStoreCacheType]) {
        storeCacheType = [context[TXAdWebImageContextStoreCacheType] integerValue];
    }
    id<TXAdWebImageCacheSerializer> cacheSerializer = context[TXAdWebImageContextCacheSerializer];
    
    // transformed cache key
    NSString *key = [self cacheKeyForURL:url context:context];
    if (finished && cacheSerializer && (storeCacheType == TXAdImageCacheTypeDisk || storeCacheType == TXAdImageCacheTypeAll)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData *newData = [cacheSerializer cacheDataWithImage:image originalData:data imageURL:url];
            // Store image and data
            [self storeImage:image imageData:newData forKey:key options:options context:context imageCache:imageCache cacheType:storeCacheType finished:finished completion:^{
                [self callCompletionBlockForOperation:operation completion:completedBlock image:image data:data error:nil cacheType:cacheType finished:finished queue:context[TXAdWebImageContextCallbackQueue] url:url];
            }];
        });
    } else {
        // Store image and data
        [self storeImage:image imageData:data forKey:key options:options context:context imageCache:imageCache cacheType:storeCacheType finished:finished completion:^{
            [self callCompletionBlockForOperation:operation completion:completedBlock image:image data:data error:nil cacheType:cacheType finished:finished queue:context[TXAdWebImageContextCallbackQueue] url:url];
        }];
    }
}

#pragma mark - Helper

- (void)safelyRemoveOperationFromRunning:(nullable TXAdWebImageCombinedOperation*)operation {
    if (!operation) {
        return;
    }
    TXAd_LOCK(_runningOperationsLock);
    [self.runningOperations removeObject:operation];
    TXAd_UNLOCK(_runningOperationsLock);
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)data
            forKey:(nullable NSString *)key
           options:(TXAdWebImageOptions)options
           context:(nullable TXAdWebImageContext *)context
        imageCache:(nonnull id<TXAdImageCache>)imageCache
         cacheType:(TXAdImageCacheType)cacheType
          finished:(BOOL)finished
        completion:(nullable TXAdWebImageNoParamsBlock)completion {
    BOOL waitStoreCache = TXAd_OPTIONS_CONTAINS(options, TXAdWebImageWaitStoreCache);
    // Ignore progressive data cache
    if (!finished) {
        if (completion) {
            completion();
        }
        return;
    }
    // Check whether we should wait the store cache finished. If not, callback immediately
    if ([imageCache respondsToSelector:@selector(storeImage:imageData:forKey:options:context:cacheType:completion:)]) {
        [imageCache storeImage:image imageData:data forKey:key options:options context:context cacheType:cacheType completion:^{
            if (waitStoreCache) {
                if (completion) {
                    completion();
                }
            }
        }];
    } else {
        [imageCache storeImage:image imageData:data forKey:key cacheType:cacheType completion:^{
            if (waitStoreCache) {
                if (completion) {
                    completion();
                }
            }
        }];
    }
    if (!waitStoreCache) {
        if (completion) {
            completion();
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable TXAdWebImageCombinedOperation*)operation
                             completion:(nullable TXAdInternalCompletionBlock)completionBlock
                                  error:(nullable NSError *)error
                                  queue:(nullable TXAdCallbackQueue *)queue
                                    url:(nullable NSURL *)url {
    [self callCompletionBlockForOperation:operation completion:completionBlock image:nil data:nil error:error cacheType:TXAdImageCacheTypeNone finished:YES queue:queue url:url];
}

- (void)callCompletionBlockForOperation:(nullable TXAdWebImageCombinedOperation*)operation
                             completion:(nullable TXAdInternalCompletionBlock)completionBlock
                                  image:(nullable UIImage *)image
                                   data:(nullable NSData *)data
                                  error:(nullable NSError *)error
                              cacheType:(TXAdImageCacheType)cacheType
                               finished:(BOOL)finished
                                  queue:(nullable TXAdCallbackQueue *)queue
                                    url:(nullable NSURL *)url {
    if (completionBlock) {
        [(queue ?: TXAdCallbackQueue.mainQueue) async:^{
            completionBlock(image, data, error, cacheType, finished, url);
        }];
    }
}

- (BOOL)shouldBlockFailedURLWithURL:(nonnull NSURL *)url
                              error:(nonnull NSError *)error
                            options:(TXAdWebImageOptions)options
                            context:(nullable TXAdWebImageContext *)context {
    id<TXAdImageLoader> imageLoader = context[TXAdWebImageContextImageLoader];
    if (!imageLoader) {
        imageLoader = self.imageLoader;
    }
    // Check whether we should block failed url
    BOOL shouldBlockFailedURL;
    if ([self.delegate respondsToSelector:@selector(imageManager:shouldBlockFailedURL:withError:)]) {
        shouldBlockFailedURL = [self.delegate imageManager:self shouldBlockFailedURL:url withError:error];
    } else {
        if ([imageLoader respondsToSelector:@selector(shouldBlockFailedURLWithURL:error:options:context:)]) {
            shouldBlockFailedURL = [imageLoader shouldBlockFailedURLWithURL:url error:error options:options context:context];
        } else {
            shouldBlockFailedURL = [imageLoader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    
    return shouldBlockFailedURL;
}

- (TXAdWebImageOptionsResult *)processedResultForURL:(NSURL *)url options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context {
    TXAdWebImageOptionsResult *result;
    TXAdWebImageMutableContext *mutableContext = [TXAdWebImageMutableContext dictionary];
    
    // Image Transformer from manager
    if (!context[TXAdWebImageContextImageTransformer]) {
        id<TXAdImageTransformer> transformer = self.transformer;
        [mutableContext setValue:transformer forKey:TXAdWebImageContextImageTransformer];
    }
    // Cache key filter from manager
    if (!context[TXAdWebImageContextCacheKeyFilter]) {
        id<TXAdWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
        [mutableContext setValue:cacheKeyFilter forKey:TXAdWebImageContextCacheKeyFilter];
    }
    // Cache serializer from manager
    if (!context[TXAdWebImageContextCacheSerializer]) {
        id<TXAdWebImageCacheSerializer> cacheSerializer = self.cacheSerializer;
        [mutableContext setValue:cacheSerializer forKey:TXAdWebImageContextCacheSerializer];
    }
    
    if (mutableContext.count > 0) {
        if (context) {
            [mutableContext addEntriesFromDictionary:context];
        }
        context = [mutableContext copy];
    }
    
    // Apply options processor
    if (self.optionsProcessor) {
        result = [self.optionsProcessor processedResultForURL:url options:options context:context];
    }
    if (!result) {
        // Use default options result
        result = [[TXAdWebImageOptionsResult alloc] initWithOptions:options context:context];
    }
    
    return result;
}

@end


@implementation TXAdWebImageCombinedOperation

- (BOOL)isCancelled {
    // Need recursive lock (user's cancel block may check isCancelled), do not use TXAd_LOCK
    @synchronized (self) {
        return _cancelled;
    }
}

- (void)cancel {
    // Need recursive lock (user's cancel block may check isCancelled), do not use TXAd_LOCK
    @synchronized(self) {
        if (_cancelled) {
            return;
        }
        _cancelled = YES;
        if (self.cacheOperation) {
            [self.cacheOperation cancel];
            self.cacheOperation = nil;
        }
        if (self.loaderOperation) {
            [self.loaderOperation cancel];
            self.loaderOperation = nil;
        }
        [self.manager safelyRemoveOperationFromRunning:self];
    }
}

@end
