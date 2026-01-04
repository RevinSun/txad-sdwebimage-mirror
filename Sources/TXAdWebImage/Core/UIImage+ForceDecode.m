/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+ForceDecode.h"
#import "TXAdImageCoderHelper.h"
#import "objc/runtime.h"
#import "NSImage+Compatibility.h"

@implementation UIImage (ForceDecode)

- (BOOL)txad_isDecoded {
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_isDecoded));
    return [value boolValue];
}

- (void)setSd_isDecoded:(BOOL)txad_isDecoded {
    objc_setAssociatedObject(self, @selector(txad_isDecoded), @(txad_isDecoded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (nullable UIImage *)txad_decodedImageWithImage:(nullable UIImage *)image {
    if (!image) {
        return nil;
    }
    return [TXAdImageCoderHelper decodedImageWithImage:image];
}

+ (nullable UIImage *)txad_decodedAndScaledDownImageWithImage:(nullable UIImage *)image {
    return [self txad_decodedAndScaledDownImageWithImage:image limitBytes:0];
}

+ (nullable UIImage *)txad_decodedAndScaledDownImageWithImage:(nullable UIImage *)image limitBytes:(NSUInteger)bytes {
    if (!image) {
        return nil;
    }
    return [TXAdImageCoderHelper decodedAndScaledDownImageWithImage:image limitBytes:bytes];
}

@end
