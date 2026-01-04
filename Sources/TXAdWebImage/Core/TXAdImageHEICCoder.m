/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXAdImageHEICCoder.h"
#import "TXAdImageIOAnimatedCoderInternal.h"

// These constants are available from iOS 13+ and Xcode 11. This raw value is used for toolchain and firmware compatibility
static NSString * kTXAdCGImagePropertyHEICSDictionary = @"{HEICS}";
static NSString * kTXAdCGImagePropertyHEICSLoopCount = @"LoopCount";
static NSString * kTXAdCGImagePropertyHEICSDelayTime = @"DelayTime";
static NSString * kTXAdCGImagePropertyHEICSUnclampedDelayTime = @"UnclampedDelayTime";

@implementation TXAdImageHEICCoder

+ (void)initialize {
    if (@available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)) {
        // Use TXAdK instead of raw value
        kTXAdCGImagePropertyHEICSDictionary = (__bridge NSString *)kCGImagePropertyHEICSDictionary;
        kTXAdCGImagePropertyHEICSLoopCount = (__bridge NSString *)kCGImagePropertyHEICSLoopCount;
        kTXAdCGImagePropertyHEICSDelayTime = (__bridge NSString *)kCGImagePropertyHEICSDelayTime;
        kTXAdCGImagePropertyHEICSUnclampedDelayTime = (__bridge NSString *)kCGImagePropertyHEICSUnclampedDelayTime;
    }
}

+ (instancetype)sharedCoder {
    static TXAdImageHEICCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[TXAdImageHEICCoder alloc] init];
    });
    return coder;
}

#pragma mark - TXAdImageCoder

- (BOOL)canDecodeFromData:(nullable NSData *)data {
    switch ([NSData txad_imageFormatForImageData:data]) {
        case TXAdImageFormatHEIC:
            // Check HEIC decoding compatibility
            return [self.class canDecodeFromFormat:TXAdImageFormatHEIC];
        case TXAdImageFormatHEIF:
            // Check HEIF decoding compatibility
            return [self.class canDecodeFromFormat:TXAdImageFormatHEIF];
        default:
            return NO;
    }
}

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return [self canDecodeFromData:data];
}

- (BOOL)canEncodeToFormat:(TXAdImageFormat)format {
    switch (format) {
        case TXAdImageFormatHEIC:
            // Check HEIC encoding compatibility
            return [self.class canEncodeToFormat:TXAdImageFormatHEIC];
        case TXAdImageFormatHEIF:
            // Check HEIF encoding compatibility
            return [self.class canEncodeToFormat:TXAdImageFormatHEIF];
        default:
            return NO;
    }
}

#pragma mark - Subclass Override

+ (TXAdImageFormat)imageFormat {
    return TXAdImageFormatHEIC;
}

+ (NSString *)imageUTType {
    // See: https://nokiatech.github.io/heif/technical.html
    // Actually HEIC has another concept called `non-timed Image Sequence`, which can be encoded using `public.heic`
    // But current TXAdWebImage does not has this design, I don't know whether there are use case for this
    // So we just replace and always use `timed Image Sequence`, means, animated image for encoding
    return (__bridge NSString *)kTXAdUTTypeHEICS;
}

+ (NSString *)dictionaryProperty {
    return kTXAdCGImagePropertyHEICSDictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return kTXAdCGImagePropertyHEICSUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return kTXAdCGImagePropertyHEICSDelayTime;
}

+ (NSString *)loopCountProperty {
    return kTXAdCGImagePropertyHEICSLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 0;
}

@end
