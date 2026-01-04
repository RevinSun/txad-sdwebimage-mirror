/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXAdWebImageCompat.h"

/**
 A loading state to manage View Category which contains multiple states. Like UIImgeView.image && UIImageView.highlightedImage
 @code
 TXAdWebImageLoadState *loadState = [self txad_imageLoadStateForKey:@keypath(self, highlitedImage)];
 NSProgress *highlitedImageProgress = loadState.progress;
 @endcode
 */
@interface TXAdWebImageLoadState : NSObject

/**
 Image loading URL
 */
@property (nonatomic, strong, nullable) NSURL *url;
/**
 Image loading progress. The unit count is the received size and excepted size of download.
 */
@property (nonatomic, strong, nullable) NSProgress *progress;

@end

/**
 These methods are used for WebCache view which have multiple states for image loading, for example, `UIButton` or `UIImageView.highlightedImage`
 It maitain the state container for per-operation, make it possible for control and check each image loading operation's state.
 @note For developer who want to add TXAdWebImage View Category support for their own stateful class, learn more on Wiki.
 */
@interface UIView (WebCacheState)

/**
 Get the image loading state container for specify operation key

 @param key key for identifying the operations
 @return The image loading state container
 */
- (nullable TXAdWebImageLoadState *)txad_imageLoadStateForKey:(nullable NSString *)key;

/**
 Set the image loading state container for specify operation key

 @param state The image loading state container
 @param key key for identifying the operations
 */
- (void)txad_setImageLoadState:(nullable TXAdWebImageLoadState *)state forKey:(nullable NSString *)key;

/**
 Rmove the image loading state container for specify operation key

 @param key key for identifying the operations
 */
- (void)txad_removeImageLoadStateForKey:(nullable NSString *)key;

@end
