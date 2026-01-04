/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+MultiFormat.h"
#import "TXAdImageCodersManager.h"
#import "TXAdAnimatedImageRep.h"
#import "UIImage+Metadata.h"

@implementation UIImage (MultiFormat)

+ (nullable UIImage *)txad_imageWithData:(nullable NSData *)data {
    return [self txad_imageWithData:data scale:1];
}

+ (nullable UIImage *)txad_imageWithData:(nullable NSData *)data scale:(CGFloat)scale {
    return [self txad_imageWithData:data scale:scale firstFrameOnly:NO];
}

+ (nullable UIImage *)txad_imageWithData:(nullable NSData *)data scale:(CGFloat)scale firstFrameOnly:(BOOL)firstFrameOnly {
    if (!data) {
        return nil;
    }
    TXAdImageCoderOptions *options = @{TXAdImageCoderDecodeScaleFactor : @(MAX(scale, 1)), TXAdImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)};
    return [[TXAdImageCodersManager sharedManager] decodedImageWithData:data options:options];
}

- (nullable NSData *)txad_imageData {
#if TXAd_MAC
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    // Check weak animated data firstly
    if ([imageRep isKindOfClass:[TXAdAnimatedImageRep class]]) {
        TXAdAnimatedImageRep *animatedImageRep = (TXAdAnimatedImageRep *)imageRep;
        NSData *imageData = [animatedImageRep animatedImageData];
        if (imageData) {
            return imageData;
        }
    }
#endif
    return [self txad_imageDataAsFormat:self.txad_imageFormat];
}

- (nullable NSData *)txad_imageDataAsFormat:(TXAdImageFormat)imageFormat {
    return [self txad_imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)txad_imageDataAsFormat:(TXAdImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self txad_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)txad_imageDataAsFormat:(TXAdImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    TXAdImageCoderOptions *options = @{TXAdImageCoderEncodeCompressionQuality : @(compressionQuality), TXAdImageCoderEncodeFirstFrameOnly : @(firstFrameOnly)};
    return [[TXAdImageCodersManager sharedManager] encodedDataWithImage:self format:imageFormat options:options];
}

@end
