/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageCache.h"
#import "TXAdInternalMacros.h"
#import "NSImage+Compatibility.h"
#import "TXAdImageCodersManager.h"
#import "TXAdImageCoderHelper.h"
#import "TXAdAnimatedImage.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+Metadata.h"
#import "UIImage+ExtendedCacheData.h"
#import "TXAdCallbackQueue.h"
#import "TXAdImageTransformer.h" // TODO, remove this

// TODO, remove this
static BOOL TXAdIsThumbnailKey(NSString *key) {
    if ([key rangeOfString:@"-Thumbnail("].location != NSNotFound) {
        return YES;
    }
    return NO;
}

@interface TXAdImageCacheToken ()

@property (nonatomic, strong, nullable, readwrite) NSString *key;
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, copy, nullable) TXAdImageCacheQueryCompletionBlock doneBlock;
@property (nonatomic, strong, nullable) TXAdCallbackQueue *callbackQueue;

@end

@implementation TXAdImageCacheToken

-(instancetype)initWithDoneBlock:(nullable TXAdImageCacheQueryCompletionBlock)doneBlock {
    self = [super init];
    if (self) {
        self.doneBlock = doneBlock;
    }
    return self;
}

- (void)cancel {
    @synchronized (self) {
        if (self.isCancelled) {
            return;
        }
        self.cancelled = YES;
        
        TXAdImageCacheQueryCompletionBlock doneBlock = self.doneBlock;
        self.doneBlock = nil;
        if (doneBlock) {
            [(self.callbackQueue ?: TXAdCallbackQueue.mainQueue) async:^{
                doneBlock(nil, nil, TXAdImageCacheTypeNone);
            }];
        }
    }
}

@end

static NSString * _defaultDiskCacheDirectory;

@interface TXAdImageCache ()

#pragma mark - Properties
@property (nonatomic, strong, readwrite, nonnull) id<TXAdMemoryCache> memoryCache;
@property (nonatomic, strong, readwrite, nonnull) id<TXAdDiskCache> diskCache;
@property (nonatomic, copy, readwrite, nonnull) TXAdImageCacheConfig *config;
@property (nonatomic, copy, readwrite, nonnull) NSString *diskCachePath;
@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

@end


@implementation TXAdImageCache

#pragma mark - Singleton, init, dealloc

+ (nonnull instancetype)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

+ (NSString *)defaultDiskCacheDirectory {
    if (!_defaultDiskCacheDirectory) {
        _defaultDiskCacheDirectory = [[self userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.TXAdImageCache"];
    }
    return _defaultDiskCacheDirectory;
}

+ (void)setDefaultDiskCacheDirectory:(NSString *)defaultDiskCacheDirectory {
    _defaultDiskCacheDirectory = [defaultDiskCacheDirectory copy];
}

- (instancetype)init {
    return [self initWithNamespace:@"default"];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns {
    return [self initWithNamespace:ns diskCacheDirectory:nil];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory {
    return [self initWithNamespace:ns diskCacheDirectory:directory config:TXAdImageCacheConfig.defaultCacheConfig];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory
                                   config:(nullable TXAdImageCacheConfig *)config {
    if ((self = [super init])) {
        NSAssert(ns, @"Cache namespace should not be nil");
        
        if (!config) {
            config = TXAdImageCacheConfig.defaultCacheConfig;
        }
        _config = [config copy];
        
        // Create IO queue
        dispatch_queue_attr_t ioQueueAttributes = _config.ioQueueAttributes;
        _ioQueue = dispatch_queue_create("com.hackemist.TXAdImageCache.ioQueue", ioQueueAttributes);
        NSAssert(_ioQueue, @"The IO queue should not be nil. Your configured `ioQueueAttributes` may be wrong");
        
        // Init the memory cache
        NSAssert([config.memoryCacheClass conformsToProtocol:@protocol(TXAdMemoryCache)], @"Custom memory cache class must conform to `TXAdMemoryCache` protocol");
        _memoryCache = [[config.memoryCacheClass alloc] initWithConfig:_config];
        
        // Init the disk cache
        if (!directory) {
            // Use default disk cache directory
            directory = [self.class defaultDiskCacheDirectory];
        }
        _diskCachePath = [directory stringByAppendingPathComponent:ns];
        
        NSAssert([config.diskCacheClass conformsToProtocol:@protocol(TXAdDiskCache)], @"Custom disk cache class must conform to `TXAdDiskCache` protocol");
        _diskCache = [[config.diskCacheClass alloc] initWithCachePath:_diskCachePath config:_config];
        
        // Check and migrate disk cache directory if need
        [self migrateDiskCacheDirectory];

#if TXAd_UIKIT
        // Subscribe to app events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
#if TXAd_MAC
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cache paths

- (nullable NSString *)cachePathForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    return [self.diskCache cachePathForKey:key];
}

+ (nullable NSString *)userCacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

- (void)migrateDiskCacheDirectory {
    if ([self.diskCache isKindOfClass:[TXAdDiskCache class]]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // ~/Library/Caches/com.hackemist.TXAdImageCache/default/
            NSString *newDefaultPath = [[[self.class userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.TXAdImageCache"] stringByAppendingPathComponent:@"default"];
            // ~/Library/Caches/default/com.hackemist.TXAdWebImageCache.default/
            NSString *oldDefaultPath = [[[self.class userCacheDirectory] stringByAppendingPathComponent:@"default"] stringByAppendingPathComponent:@"com.hackemist.TXAdWebImageCache.default"];
            dispatch_async(self.ioQueue, ^{
                [((TXAdDiskCache *)self.diskCache) moveCacheDirectoryFromPath:oldDefaultPath toPath:newDefaultPath];
            });
        });
    }
}

#pragma mark - Store Ops

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key options:0 context:nil cacheType:TXAdImageCacheTypeAll completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key options:0 context:nil cacheType:(toDisk ? TXAdImageCacheTypeAll : TXAdImageCacheTypeMemory) completion:completionBlock];
}

- (void)storeImageData:(nullable NSData *)imageData
                forKey:(nullable NSString *)key
            completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    [self storeImage:nil imageData:imageData forKey:key options:0 context:nil cacheType:TXAdImageCacheTypeAll completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:(toDisk ? TXAdImageCacheTypeAll : TXAdImageCacheTypeMemory) completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
           options:(TXAdWebImageOptions)options
           context:(nullable TXAdWebImageContext *)context
         cacheType:(TXAdImageCacheType)cacheType
        completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    if ((!image && !imageData) || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    BOOL toMemory = cacheType == TXAdImageCacheTypeMemory || cacheType == TXAdImageCacheTypeAll;
    BOOL toDisk = cacheType == TXAdImageCacheTypeDisk || cacheType == TXAdImageCacheTypeAll;
    // if memory cache is enabled
    if (image && toMemory && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = image.txad_memoryCost;
        [self.memoryCache setObject:image forKey:key cost:cost];
    }
    
    if (!toDisk) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    NSData *data = imageData;
    if (!data && [image respondsToSelector:@selector(animatedImageData)]) {
        // If image is custom animated image class, prefer its original animated data
        data = [((id<TXAdAnimatedImage>)image) animatedImageData];
    }
    TXAdCallbackQueue *queue = context[TXAdWebImageContextCallbackQueue];
    if (!data && image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Check image's associated image format, may return .undefined
            TXAdImageFormat format = image.txad_imageFormat;
            if (format == TXAdImageFormatUndefined) {
                // If image is animated, use GIF (APNG may be better, but has bugs before macOS 10.14)
                if (image.txad_imageFrameCount > 1) {
                    format = TXAdImageFormatGIF;
                } else {
                    // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                    format = [TXAdImageCoderHelper CGImageContainsAlpha:image.CGImage] ? TXAdImageFormatPNG : TXAdImageFormatJPEG;
                }
            }
            NSData *encodedData = [[TXAdImageCodersManager sharedManager] encodedDataWithImage:image format:format options:context[TXAdWebImageContextImageEncodeOptions]];
            dispatch_async(self.ioQueue, ^{
                [self _storeImageDataToDisk:encodedData forKey:key];
                [self _archivedDataWithImage:image forKey:key];
                if (completionBlock) {
                    [(queue ?: TXAdCallbackQueue.mainQueue) async:^{
                        completionBlock();
                    }];
                }
            });
        });
    } else {
        dispatch_async(self.ioQueue, ^{
            [self _storeImageDataToDisk:data forKey:key];
            [self _archivedDataWithImage:image forKey:key];
            if (completionBlock) {
                [(queue ?: TXAdCallbackQueue.mainQueue) async:^{
                    completionBlock();
                }];
            }
        });
    }
}

- (void)_archivedDataWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    // Check extended data
    id extendedObject = image.txad_extendedObject;
    if (![extendedObject conformsToProtocol:@protocol(NSCoding)]) {
        return;
    }
    NSData *extendedData;
    if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
        NSError *error;
        extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject requiringSecureCoding:NO error:&error];
        if (error) {
            TXAd_LOG("NSKeyedArchiver archive failed with error: %@", error);
        }
    } else {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            TXAd_LOG("NSKeyedArchiver archive failed with exception: %@", exception);
        }
    }
    if (extendedData) {
        [self.diskCache setExtendedData:extendedData forKey:key];
    }
}

- (void)storeImageToMemory:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    NSUInteger cost = image.txad_memoryCost;
    [self.memoryCache setObject:image forKey:key cost:cost];
}

- (void)storeImageDataToDisk:(nullable NSData *)imageData
                      forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    dispatch_sync(self.ioQueue, ^{
        [self _storeImageDataToDisk:imageData forKey:key];
    });
}

// Make sure to call from io queue by caller
- (void)_storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    [self.diskCache setData:imageData forKey:key];
}

#pragma mark - Query and Retrieve Ops

- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable TXAdImageCacheCheckCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        BOOL exists = [self _diskImageDataExistsWithKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    
    __block BOOL exists = NO;
    dispatch_sync(self.ioQueue, ^{
        exists = [self _diskImageDataExistsWithKey:key];
    });
    
    return exists;
}

// Make sure to call from io queue by caller
- (BOOL)_diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    
    return [self.diskCache containsDataForKey:key];
}

- (void)diskImageDataQueryForKey:(NSString *)key completion:(TXAdImageCacheQueryDataCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSData *imageData = [self diskImageDataBySearchingAllPathsForKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(imageData);
            });
        }
    });
}

- (nullable NSData *)diskImageDataForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    __block NSData *imageData = nil;
    dispatch_sync(self.ioQueue, ^{
        imageData = [self diskImageDataBySearchingAllPathsForKey:key];
    });
    
    return imageData;
}

- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key {
    return [self.memoryCache objectForKey:key];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key {
    return [self imageFromDiskCacheForKey:key options:0 context:nil];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key options:(TXAdImageCacheOptions)options context:(nullable TXAdWebImageContext *)context {
    if (!key) {
        return nil;
    }
    NSData *data = [self diskImageDataForKey:key];
    UIImage *diskImage = [self diskImageForKey:key data:data options:options context:context];
    
    BOOL shouldCacheToMemory = YES;
    if (context[TXAdWebImageContextStoreCacheType]) {
        TXAdImageCacheType cacheType = [context[TXAdWebImageContextStoreCacheType] integerValue];
        shouldCacheToMemory = (cacheType == TXAdImageCacheTypeAll || cacheType == TXAdImageCacheTypeMemory);
    }
    if (shouldCacheToMemory) {
        // check if we need sync logic
        [self _syncDiskToMemoryWithImage:diskImage forKey:key];
    }

    return diskImage;
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key {
    return [self imageFromCacheForKey:key options:0 context:nil];
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key options:(TXAdImageCacheOptions)options context:(nullable TXAdWebImageContext *)context {
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        if (options & TXAdImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            if (image.txad_imageFrameCount > 1) {
#if TXAd_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & TXAdImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[TXAdWebImageContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }
    
    // Since we don't need to query imageData, return image if exist
    if (image) {
        return image;
    }
    
    // Second check the disk cache...
    image = [self imageFromDiskCacheForKey:key options:options context:context];
    return image;
}

- (nullable NSData *)diskImageDataBySearchingAllPathsForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    
    NSData *data = [self.diskCache dataForKey:key];
    if (data) {
        return data;
    }
    
    // Addtional cache path for custom pre-load cache
    if (self.additionalCachePathBlock) {
        NSString *filePath = self.additionalCachePathBlock(key);
        if (filePath) {
            data = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
        }
    }

    return data;
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    NSData *data = [self diskImageDataForKey:key];
    return [self diskImageForKey:key data:data options:0 context:nil];
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key data:(nullable NSData *)data options:(TXAdImageCacheOptions)options context:(TXAdWebImageContext *)context {
    if (!data) {
        return nil;
    }
    UIImage *image = TXAdImageCacheDecodeImageData(data, key, [[self class] imageOptionsFromCacheOptions:options], context);
    [self _unarchiveObjectWithImage:image forKey:key];
    return image;
}

- (void)_syncDiskToMemoryWithImage:(UIImage *)diskImage forKey:(NSString *)key {
    // earily check
    if (!self.config.shouldCacheImagesInMemory) {
        return;
    }
    if (!diskImage) {
        return;
    }
    // The disk -> memory sync logic, which should only store thumbnail image with thumbnail key
    // However, caller (like TXAdWebImageManager) will query full key, with thumbnail size, and get thubmnail image
    // We should add a check here, currently it's a hack
    if (diskImage.txad_isThumbnail && !TXAdIsThumbnailKey(key)) {
        TXAdImageCoderOptions *options = diskImage.txad_decodeOptions;
        CGSize thumbnailSize = CGSizeZero;
        NSValue *thumbnailSizeValue = options[TXAdImageCoderDecodeThumbnailPixelSize];
        if (thumbnailSizeValue != nil) {
    #if TXAd_MAC
            thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
            thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
        }
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = options[TXAdImageCoderDecodePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        // Calculate the actual thumbnail key
        NSString *thumbnailKey = TXAdThumbnailedKeyForKey(key, thumbnailSize, preserveAspectRatio);
        // Override the sync key
        key = thumbnailKey;
    }
    NSUInteger cost = diskImage.txad_memoryCost;
    [self.memoryCache setObject:diskImage forKey:key cost:cost];
}

- (void)_unarchiveObjectWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    // Check extended data
    NSData *extendedData = [self.diskCache extendedDataForKey:key];
    if (!extendedData) {
        return;
    }
    id extendedObject;
    if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
        NSError *error;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:extendedData error:&error];
        unarchiver.requiresSecureCoding = NO;
        extendedObject = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
        if (error) {
            TXAd_LOG("NSKeyedUnarchiver unarchive failed with error: %@", error);
        }
    } else {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            extendedObject = [NSKeyedUnarchiver unarchiveObjectWithData:extendedData];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            TXAd_LOG("NSKeyedUnarchiver unarchive failed with exception: %@", exception);
        }
    }
    image.txad_extendedObject = extendedObject;
}

- (nullable TXAdImageCacheToken *)queryCacheOperationForKey:(NSString *)key done:(TXAdImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:0 done:doneBlock];
}

- (nullable TXAdImageCacheToken *)queryCacheOperationForKey:(NSString *)key options:(TXAdImageCacheOptions)options done:(TXAdImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:options context:nil done:doneBlock];
}

- (nullable TXAdImageCacheToken *)queryCacheOperationForKey:(nullable NSString *)key options:(TXAdImageCacheOptions)options context:(nullable TXAdWebImageContext *)context done:(nullable TXAdImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:options context:context cacheType:TXAdImageCacheTypeAll done:doneBlock];
}

- (nullable TXAdImageCacheToken *)queryCacheOperationForKey:(nullable NSString *)key options:(TXAdImageCacheOptions)options context:(nullable TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)queryCacheType done:(nullable TXAdImageCacheQueryCompletionBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, TXAdImageCacheTypeNone);
        }
        return nil;
    }
    // Invalid cache type
    if (queryCacheType == TXAdImageCacheTypeNone) {
        if (doneBlock) {
            doneBlock(nil, nil, TXAdImageCacheTypeNone);
        }
        return nil;
    }
    
    // First check the in-memory cache...
    UIImage *image;
    if (queryCacheType != TXAdImageCacheTypeDisk) {
        image = [self imageFromMemoryCacheForKey:key];
    }
    
    if (image) {
        if (options & TXAdImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            if (image.txad_imageFrameCount > 1) {
#if TXAd_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & TXAdImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[TXAdWebImageContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }

    BOOL shouldQueryMemoryOnly = (queryCacheType == TXAdImageCacheTypeMemory) || (image && !(options & TXAdImageCacheQueryMemoryData));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, TXAdImageCacheTypeMemory);
        }
        return nil;
    }
    
    // Second check the disk cache...
    TXAdCallbackQueue *queue = context[TXAdWebImageContextCallbackQueue];
    TXAdImageCacheToken *operation = [[TXAdImageCacheToken alloc] initWithDoneBlock:doneBlock];
    operation.key = key;
    operation.callbackQueue = queue;
    // Check whether we need to synchronously query disk
    // 1. in-memory cache hit & memoryDataSync
    // 2. in-memory cache miss & diskDataSync
    BOOL shouldQueryDiskSync = ((image && options & TXAdImageCacheQueryMemoryDataSync) ||
                                (!image && options & TXAdImageCacheQueryDiskDataSync));
    NSData* (^queryDiskDataBlock)(void) = ^NSData* {
        @synchronized (operation) {
            if (operation.isCancelled) {
                return nil;
            }
        }
        
        return [self diskImageDataBySearchingAllPathsForKey:key];
    };
    
    UIImage* (^queryDiskImageBlock)(NSData*) = ^UIImage*(NSData* diskData) {
        @synchronized (operation) {
            if (operation.isCancelled) {
                return nil;
            }
        }
        
        UIImage *diskImage;
        if (image) {
            // the image is from in-memory cache, but need image data
            diskImage = image;
        } else if (diskData) {
            BOOL shouldCacheToMemory = YES;
            if (context[TXAdWebImageContextStoreCacheType]) {
                TXAdImageCacheType cacheType = [context[TXAdWebImageContextStoreCacheType] integerValue];
                shouldCacheToMemory = (cacheType == TXAdImageCacheTypeAll || cacheType == TXAdImageCacheTypeMemory);
            }
            // Special case: If user query image in list for the same URL, to avoid decode and write **same** image object into disk cache multiple times, we query and check memory cache here again.
            if (shouldCacheToMemory && self.config.shouldCacheImagesInMemory) {
                diskImage = [self.memoryCache objectForKey:key];
            }
            // decode image data only if in-memory cache missed
            if (!diskImage) {
                diskImage = [self diskImageForKey:key data:diskData options:options context:context];
                // check if we need sync logic
                if (shouldCacheToMemory) {
                    [self _syncDiskToMemoryWithImage:diskImage forKey:key];
                }
            }
        }
        return diskImage;
    };
    
    // Query in ioQueue to keep IO-safe
    if (shouldQueryDiskSync) {
        __block NSData* diskData;
        __block UIImage* diskImage;
        dispatch_sync(self.ioQueue, ^{
            diskData = queryDiskDataBlock();
            diskImage = queryDiskImageBlock(diskData);
        });
        if (doneBlock) {
            doneBlock(diskImage, diskData, TXAdImageCacheTypeDisk);
        }
    } else {
        dispatch_async(self.ioQueue, ^{
            NSData* diskData = queryDiskDataBlock();
            UIImage* diskImage = queryDiskImageBlock(diskData);
            @synchronized (operation) {
                if (operation.isCancelled) {
                    return;
                }
            }
            if (doneBlock) {
                [(queue ?: TXAdCallbackQueue.mainQueue) async:^{
                    // Dispatch from IO queue to main queue need time, user may call cancel during the dispatch timing
                    // This check is here to avoid double callback (one is from `TXAdImageCacheToken` in sync)
                    @synchronized (operation) {
                        if (operation.isCancelled) {
                            return;
                        }
                    }
                    doneBlock(diskImage, diskData, TXAdImageCacheTypeDisk);
                }];
            }
        });
    }
    
    return operation;
}

#pragma mark - Remove Ops

- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable TXAdWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable TXAdWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromMemory:YES fromDisk:fromDisk withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromMemory:(BOOL)fromMemory fromDisk:(BOOL)fromDisk withCompletion:(nullable TXAdWebImageNoParamsBlock)completion {
    if (!key) {
        return;
    }

    if (fromMemory && self.config.shouldCacheImagesInMemory) {
        [self.memoryCache removeObjectForKey:key];
    }

    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [self.diskCache removeDataForKey:key];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion) {
        completion();
    }
}

- (void)removeImageFromMemoryForKey:(NSString *)key {
    if (!key) {
        return;
    }
    
    [self.memoryCache removeObjectForKey:key];
}

- (void)removeImageFromDiskForKey:(NSString *)key {
    if (!key) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self _removeImageFromDiskForKey:key];
    });
}

// Make sure to call from io queue by caller
- (void)_removeImageFromDiskForKey:(NSString *)key {
    if (!key) {
        return;
    }
    
    [self.diskCache removeDataForKey:key];
}

#pragma mark - Cache clean Ops

- (void)clearMemory {
    [self.memoryCache removeAllObjects];
}

- (void)clearDiskOnCompletion:(nullable TXAdWebImageNoParamsBlock)completion {
    dispatch_async(self.ioQueue, ^{
        [self.diskCache removeAllData];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        [self.diskCache removeExpiredData];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

#pragma mark - UIApplicationWillTerminateNotification

#if TXAd_UIKIT || TXAd_MAC
- (void)applicationWillTerminate:(NSNotification *)notification {
    // On iOS/macOS, the async opeartion to remove exipred data will be terminated quickly
    // Try using the sync operation to ensure we reomve the exipred data
    if (!self.config.shouldRemoveExpiredDataWhenTerminate) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self.diskCache removeExpiredData];
    });
}
#endif

#pragma mark - UIApplicationDidEnterBackgroundNotification

#if TXAd_UIKIT
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (!self.config.shouldRemoveExpiredDataWhenEnterBackground) {
        return;
    }
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}
#endif

#pragma mark - Cache Info

- (NSUInteger)totalDiskSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        size = [self.diskCache totalSize];
    });
    return size;
}

- (NSUInteger)totalDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        count = [self.diskCache totalCount];
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(nullable TXAdImageCacheCalculateSizeBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = [self.diskCache totalCount];
        NSUInteger totalSize = [self.diskCache totalSize];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

#pragma mark - Helper
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (TXAdWebImageOptions)imageOptionsFromCacheOptions:(TXAdImageCacheOptions)cacheOptions {
    TXAdWebImageOptions options = 0;
    if (cacheOptions & TXAdImageCacheScaleDownLargeImages) options |= TXAdWebImageScaleDownLargeImages;
    if (cacheOptions & TXAdImageCacheDecodeFirstFrameOnly) options |= TXAdWebImageDecodeFirstFrameOnly;
    if (cacheOptions & TXAdImageCachePreloadAllFrames) options |= TXAdWebImagePreloadAllFrames;
    if (cacheOptions & TXAdImageCacheAvoidDecodeImage) options |= TXAdWebImageAvoidDecodeImage;
    if (cacheOptions & TXAdImageCacheMatchAnimatedImageClass) options |= TXAdWebImageMatchAnimatedImageClass;
    
    return options;
}
#pragma clang diagnostic pop

@end

@implementation TXAdImageCache (TXAdImageCache)

#pragma mark - TXAdImageCache

- (id<TXAdWebImageOperation>)queryImageForKey:(NSString *)key options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context completion:(nullable TXAdImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:TXAdImageCacheTypeAll completion:completionBlock];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (id<TXAdWebImageOperation>)queryImageForKey:(NSString *)key options:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context cacheType:(TXAdImageCacheType)cacheType completion:(nullable TXAdImageCacheQueryCompletionBlock)completionBlock {
    TXAdImageCacheOptions cacheOptions = 0;
    if (options & TXAdWebImageQueryMemoryData) cacheOptions |= TXAdImageCacheQueryMemoryData;
    if (options & TXAdWebImageQueryMemoryDataSync) cacheOptions |= TXAdImageCacheQueryMemoryDataSync;
    if (options & TXAdWebImageQueryDiskDataSync) cacheOptions |= TXAdImageCacheQueryDiskDataSync;
    if (options & TXAdWebImageScaleDownLargeImages) cacheOptions |= TXAdImageCacheScaleDownLargeImages;
    if (options & TXAdWebImageAvoidDecodeImage) cacheOptions |= TXAdImageCacheAvoidDecodeImage;
    if (options & TXAdWebImageDecodeFirstFrameOnly) cacheOptions |= TXAdImageCacheDecodeFirstFrameOnly;
    if (options & TXAdWebImagePreloadAllFrames) cacheOptions |= TXAdImageCachePreloadAllFrames;
    if (options & TXAdWebImageMatchAnimatedImageClass) cacheOptions |= TXAdImageCacheMatchAnimatedImageClass;
    
    return [self queryCacheOperationForKey:key options:cacheOptions context:context cacheType:cacheType done:completionBlock];
}
#pragma clang diagnostic pop

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(nullable NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:cacheType completion:completionBlock];
}

- (void)removeImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(nullable TXAdWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case TXAdImageCacheTypeNone: {
            [self removeImageForKey:key fromMemory:NO fromDisk:NO withCompletion:completionBlock];
        }
            break;
        case TXAdImageCacheTypeMemory: {
            [self removeImageForKey:key fromMemory:YES fromDisk:NO withCompletion:completionBlock];
        }
            break;
        case TXAdImageCacheTypeDisk: {
            [self removeImageForKey:key fromMemory:NO fromDisk:YES withCompletion:completionBlock];
        }
            break;
        case TXAdImageCacheTypeAll: {
            [self removeImageForKey:key fromMemory:YES fromDisk:YES withCompletion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(TXAdImageCacheType)cacheType completion:(nullable TXAdImageCacheContainsCompletionBlock)completionBlock {
    switch (cacheType) {
        case TXAdImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock(TXAdImageCacheTypeNone);
            }
        }
            break;
        case TXAdImageCacheTypeMemory: {
            BOOL isInMemoryCache = ([self imageFromMemoryCacheForKey:key] != nil);
            if (completionBlock) {
                completionBlock(isInMemoryCache ? TXAdImageCacheTypeMemory : TXAdImageCacheTypeNone);
            }
        }
            break;
        case TXAdImageCacheTypeDisk: {
            [self diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
                if (completionBlock) {
                    completionBlock(isInDiskCache ? TXAdImageCacheTypeDisk : TXAdImageCacheTypeNone);
                }
            }];
        }
            break;
        case TXAdImageCacheTypeAll: {
            BOOL isInMemoryCache = ([self imageFromMemoryCacheForKey:key] != nil);
            if (isInMemoryCache) {
                if (completionBlock) {
                    completionBlock(TXAdImageCacheTypeMemory);
                }
                return;
            }
            [self diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
                if (completionBlock) {
                    completionBlock(isInDiskCache ? TXAdImageCacheTypeDisk : TXAdImageCacheTypeNone);
                }
            }];
        }
            break;
        default:
            if (completionBlock) {
                completionBlock(TXAdImageCacheTypeNone);
            }
            break;
    }
}

- (void)clearWithCacheType:(TXAdImageCacheType)cacheType completion:(TXAdWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case TXAdImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case TXAdImageCacheTypeMemory: {
            [self clearMemory];
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case TXAdImageCacheTypeDisk: {
            [self clearDiskOnCompletion:completionBlock];
        }
            break;
        case TXAdImageCacheTypeAll: {
            [self clearMemory];
            [self clearDiskOnCompletion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

@end

