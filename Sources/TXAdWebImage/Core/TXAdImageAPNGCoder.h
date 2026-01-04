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
 Built in coder using ImageIO that supports APNG encoding/decoding
 */
@interface TXAdImageAPNGCoder : TXAdImageIOAnimatedCoder <TXAdProgressiveImageCoder, TXAdAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) TXAdImageAPNGCoder *sharedCoder;

@end
