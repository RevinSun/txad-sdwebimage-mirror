/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Laurin Brandner
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+GIF.h"
#import "TXAdImageGIFCoder.h"

@implementation UIImage (GIF)

+ (nullable UIImage *)txad_imageWithGIFData:(nullable NSData *)data {
    if (!data) {
        return nil;
    }
    return [[TXAdImageGIFCoder sharedCoder] decodedImageWithData:data options:0];
}

@end
