/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageCompat.h"

#if TXAd_MAC

#import "UIImage+Transform.h"

@interface NSBezierPath (TXAdRoundedCorners)

/**
 Convenience way to create a bezier path with the specify rounding corners on macOS. Same as the one on `UIBezierPath`.
 */
+ (nonnull instancetype)txad_bezierPathWithRoundedRect:(NSRect)rect byRoundingCorners:(TXAdRectCorner)corners cornerRadius:(CGFloat)cornerRadius;

@end

#endif
