/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+MemoryCacheCost.h"
#import "objc/runtime.h"
#import "NSImage+Compatibility.h"

FOUNDATION_STATIC_INLINE NSUInteger TXAdMemoryCacheCostForImage(UIImage *image) {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return 0;
    }
    NSUInteger bytesPerFrame = CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);
    NSUInteger frameCount;
#if TXAd_MAC
    frameCount = 1;
#elif TXAd_UIKIT || TXAd_WATCH
    // Filter the same frame in `_UIAnimatedImage`.
    frameCount = image.images.count > 1 ? [NSSet setWithArray:image.images].count : 1;
#endif
    NSUInteger cost = bytesPerFrame * frameCount;
    return cost;
}

@implementation UIImage (MemoryCacheCost)

- (NSUInteger)txad_memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_memoryCost));
    NSUInteger memoryCost;
    if (value != nil) {
        memoryCost = [value unsignedIntegerValue];
    } else {
        memoryCost = TXAdMemoryCacheCostForImage(self);
    }
    return memoryCost;
}

- (void)setSd_memoryCost:(NSUInteger)txad_memoryCost {
    objc_setAssociatedObject(self, @selector(txad_memoryCost), @(txad_memoryCost), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
