/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXAdWebImageCompat.h"
#import "TXAdWebImageOperation.h"
#import "TXAdWebImageDefine.h"
#import "TXAdImageCoder.h"

/// Image Cache Type
typedef NS_ENUM(NSInteger, TXAdImageCacheType) {
    /**
     * For query and contains op in response, means the image isn't available in the image cache
     * For op in request, this type is not available and take no effect.
     */
    TXAdImageCacheTypeNone,
    /**
     * For query and contains op in response, means the image was obtained from the disk cache.
     * For op in request, means process only disk cache.
     */
    TXAdImageCacheTypeDisk,
    /**
     * For query and contains op in response, means the image was obtained from the memory cache.
     * For op in request, means process only memory cache.
     */
    TXAdImageCacheTypeMemory,
    /**
     * For query and contains op in response, this type is not available and take no effect.
     * For op in request, means process both memory cache and disk cache.
     */
    TXAdImageCacheTypeAll
};

typedef void(^TXAdImageCacheCheckCompletionBlock)(BOOL isInCache);
typedef void(^TXAdImageCacheQueryDataCompletionBlock)(NSData * _Nullable data);
typedef void(^TXAdImageCacheCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);
typedef NSString * _Nullable (^TXAdImageCacheAdditionalCachePathBlock)(NSString * _Nonnull key);
typedef void(^TXAdImageCacheQueryCompletionBlock)(UIImage * _Nullable image, NSData * _Nullable data, TXAdImageCacheType cacheType);
typedef void(^TXAdImageCacheContainsCompletionBlock)(TXAdImageCacheType containsCacheType);

/**
 This is the built-in decoding process for image query from cache.
 @note If you want to implement your custom loader with `queryImageForKey:options:context:completion:` API, but also want to keep compatible with TXAdWebImage's behavior, you'd better use this to produce image.
 
 @param imageData The image data from the cache. Should not be nil
 @param cacheKey The image cache key from the input. Should not be nil
 @param options The options arg from the input
 @param context The context arg from the input
 @return The decoded image for current image data query from cache
 */
FOUNDATION_EXPORT UIImage * _Nullable TXAdImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, TXAdWebImageOptions options, TXAdWebImageContext * _Nullable context);

/// Get the decode options from the loading context options and cache key. This is the built-in translate between the web loading part to the decoding part (which does not depends on).
/// @param context The context arg from the input
/// @param options The options arg from the input
/// @param cacheKey The image cache key from the input. Should not be nil
FOUNDATION_EXPORT TXAdImageCoderOptions * _Nonnull TXAdGetDecodeOptionsFromContext(TXAdWebImageContext * _Nullable context, TXAdWebImageOptions options, NSString * _Nonnull cacheKey);

/// Set the decode options to the loading context options. This is the built-in translate between the web loading part from the decoding part (which does not depends on).
/// @param mutableContext The context arg to override
/// @param mutableOptions The options arg to override
/// @param decodeOptions The image decoding options
FOUNDATION_EXPORT void TXAdSetDecodeOptionsToContext(TXAdWebImageMutableContext * _Nonnull mutableContext, TXAdWebImageOptions * _Nonnull mutableOptions, TXAdImageCoderOptions * _Nonnull decodeOptions);

/**
 This is the image cache protocol to provide custom image cache for `TXAdWebImageManager`.
 Though the best practice to custom image cache, is to write your own class which conform `TXAdMemoryCache` or `TXAdDiskCache` protocol for `TXAdImageCache` class (See more on `TXAdImageCacheConfig.memoryCacheClass & TXAdImageCacheConfig.diskCacheClass`).
 However, if your own cache implementation contains more advanced feature beyond `TXAdImageCache` itself, you can consider to provide this instead. For example, you can even use a cache manager like `TXAdImageCachesManager` to register multiple caches.
 */
@protocol TXAdImageCache <NSObject>

@required
/**
 Query the cached image from image cache for given key. The operation can be used to cancel the query.
 If image is cached in memory, completion is called synchronously, else asynchronously and depends on the options arg (See `TXAdWebImageQueryDiskSync`)

 @param key The image cache key
 @param options A mask to specify options to use for this query
 @param context A context contains different options to perform specify changes or processes, see `TXAdWebImageContextOption`. This hold the extra objects which `options` enum can not hold. Pass `.callbackQueue` to control callback queue
 @param completionBlock The completion block. Will not get called if the operation is cancelled
 @return The operation for this query
 */
- (nullable id<TXAdWebImageOperation>)queryImageForKey:(nullable NSString *)key
                                             options:(TXAdWebImageOptions)options
                                             context:(nullable TXAdWebImageContext *)context
                                          completion:(nullable TXAdImageCacheQueryCompletionBlock)completionBlock API_DEPRECATED_WITH_REPLACEMENT("queryImageForKey:options:context:cacheType:completion:", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

@optional
/**
 Query the cached image from image cache for given key. The operation can be used to cancel the query.
 If image is cached in memory, completion is called synchronously, else asynchronously and depends on the options arg (See `TXAdWebImageQueryDiskSync`)

 @param key The image cache key
 @param options A mask to specify options to use for this query
 @param context A context contains different options to perform specify changes or processes, see `TXAdWebImageContextOption`. This hold the extra objects which `options` enum can not hold. Pass `.callbackQueue` to control callback queue
 @param cacheType Specify where to query the cache from. By default we use `.all`, which means both memory cache and disk cache. You can choose to query memory only or disk only as well. Pass `.none` is invalid and callback with nil immediately.
 @param completionBlock The completion block. Will not get called if the operation is cancelled
 @return The operation for this query
 */
- (nullable id<TXAdWebImageOperation>)queryImageForKey:(nullable NSString *)key
                                             options:(TXAdWebImageOptions)options
                                             context:(nullable TXAdWebImageContext *)context
                                           cacheType:(TXAdImageCacheType)cacheType
                                          completion:(nullable TXAdImageCacheQueryCompletionBlock)completionBlock;

@required
/**
 Store the image into image cache for the given key. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param image The image to store
 @param imageData The image data to be used for disk storage
 @param key The image cache key
 @param cacheType The image store op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
         cacheType:(TXAdImageCacheType)cacheType
        completion:(nullable TXAdWebImageNoParamsBlock)completionBlock API_DEPRECATED_WITH_REPLACEMENT("storeImage:imageData:forKey:options:context:cacheType:completion:", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

@optional
/**
 Store the image into image cache for the given key. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param image The image to store
 @param imageData The image data to be used for disk storage
 @param key The image cache key
 @param options A mask to specify options to use for this store
 @param context The context options to use. Pass `.callbackQueue` to control callback queue
 @param cacheType The image store op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
           options:(TXAdWebImageOptions)options
           context:(nullable TXAdWebImageContext *)context
         cacheType:(TXAdImageCacheType)cacheType
        completion:(nullable TXAdWebImageNoParamsBlock)completionBlock;

#pragma mark - Deprecated because TXAdWebImageManager does not use these APIs
/**
 Remove the image from image cache for the given key. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param key The image cache key
 @param cacheType The image remove op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)removeImageForKey:(nullable NSString *)key
                cacheType:(TXAdImageCacheType)cacheType
               completion:(nullable TXAdWebImageNoParamsBlock)completionBlock API_DEPRECATED("No longer use. Cast to cache instance and call its API", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

/**
 Check if image cache contains the image for the given key (does not load the image). If image is cached in memory, completion is called synchronously, else asynchronously.

 @param key The image cache key
 @param cacheType The image contains op cache type
 @param completionBlock A block executed after the operation is finished.
 */
- (void)containsImageForKey:(nullable NSString *)key
                  cacheType:(TXAdImageCacheType)cacheType
                 completion:(nullable TXAdImageCacheContainsCompletionBlock)completionBlock API_DEPRECATED("No longer use. Cast to cache instance and call its API", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

/**
 Clear all the cached images for image cache. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param cacheType The image clear op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)clearWithCacheType:(TXAdImageCacheType)cacheType
                completion:(nullable TXAdWebImageNoParamsBlock)completionBlock API_DEPRECATED("No longer use. Cast to cache instance and call its API", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

@end
