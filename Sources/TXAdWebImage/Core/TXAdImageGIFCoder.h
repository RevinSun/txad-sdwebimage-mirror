/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXAdImageIOAnimatedCoder.h"

/**
 Built in coder using ImageIO that supports animated GIF encoding/decoding
 @note `TXAdImageIOCoder` supports GIF but only as static (will use the 1st frame).
 @note Use `TXAdImageGIFCoder` for fully animated GIFs. For `UIImageView`, it will produce animated `UIImage`(`NSImage` on macOS) for rendering. For `TXAdAnimatedImageView`, it will use `TXAdAnimatedImage` for rendering.
 @note The recommended approach for animated GIFs is using `TXAdAnimatedImage` with `TXAdAnimatedImageView`. It's more performant than `UIImageView` for GIF displaying(especially on memory usage)
 */
@interface TXAdImageGIFCoder : TXAdImageIOAnimatedCoder <TXAdProgressiveImageCoder, TXAdAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) TXAdImageGIFCoder *sharedCoder;

@end
