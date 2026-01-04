/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageCompat.h"

#if TXAd_UIKIT

#import "TXAdWebImageManager.h"

/**
 * Integrates TXAdWebImage async downloading and caching of remote images with UIImageView for highlighted state.
 */
@interface UIImageView (HighlightedWebCache)

#pragma mark - Highlighted Image

/**
 * Get the current highlighted image URL.
 */
@property (nonatomic, strong, readonly, nullable) NSURL *txad_currentHighlightedImageURL;

/**
 * Set the imageView `highlightedImage` with an `url`.
 *
 * The download is asynchronous and cached.
 *
 * @param url The url for the image.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url NS_REFINED_FOR_SWIFT;

/**
 * Set the imageView `highlightedImage` with an `url` and custom options.
 *
 * The download is asynchronous and cached.
 *
 * @param url     The url for the image.
 * @param options The options to use when downloading the image. @see TXAdWebImageOptions for the possible values.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(TXAdWebImageOptions)options NS_REFINED_FOR_SWIFT;

/**
 * Set the imageView `highlightedImage` with an `url`, custom options and context.
 *
 * The download is asynchronous and cached.
 *
 * @param url     The url for the image.
 * @param options The options to use when downloading the image. @see TXAdWebImageOptions for the possible values.
 * @param context     A context contains different options to perform specify changes or processes, see `TXAdWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(TXAdWebImageOptions)options
                              context:(nullable TXAdWebImageContext *)context;

/**
 * Set the imageView `highlightedImage` with an `url`.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                            completed:(nullable TXAdExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;

/**
 * Set the imageView `highlightedImage` with an `url` and custom options.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param options        The options to use when downloading the image. @see TXAdWebImageOptions for the possible values.
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(TXAdWebImageOptions)options
                            completed:(nullable TXAdExternalCompletionBlock)completedBlock;

/**
 * Set the imageView `highlightedImage` with an `url` and custom options.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param options        The options to use when downloading the image. @see TXAdWebImageOptions for the possible values.
 * @param progressBlock  A block called while image is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(TXAdWebImageOptions)options
                             progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                            completed:(nullable TXAdExternalCompletionBlock)completedBlock;

/**
 * Set the imageView `highlightedImage` with an `url`, custom options and context.
 *
 * The download is asynchronous and cached.
 *
 * @param url            The url for the image.
 * @param options        The options to use when downloading the image. @see TXAdWebImageOptions for the possible values.
 * @param context     A context contains different options to perform specify changes or processes, see `TXAdWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 * @param progressBlock  A block called while image is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called when operation has been completed. This block has no return value
 *                       and takes the requested UIImage as first parameter. In case of error the image parameter
 *                       is nil and the second parameter may contain an NSError. The third parameter is a Boolean
 *                       indicating if the image was retrieved from the local cache or from the network.
 *                       The fourth parameter is the original image url.
 */
- (void)txad_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(TXAdWebImageOptions)options
                              context:(nullable TXAdWebImageContext *)context
                             progress:(nullable TXAdImageLoaderProgressBlock)progressBlock
                            completed:(nullable TXAdExternalCompletionBlock)completedBlock;

/**
 * Cancel the current highlighted image load (for `UIImageView.highlighted`)
 * @note For normal image, use `txad_cancelCurrentImageLoad`
 */
- (void)txad_cancelCurrentHighlightedImageLoad;

@end

#endif
