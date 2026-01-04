/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXAdImageAWebPCoder.h"
#import "TXAdImageIOAnimatedCoderInternal.h"

// These constants are available from iOS 14+ and Xcode 12. This raw value is used for toolchain and firmware compatibility
static NSString * kTXAdCGImagePropertyWebPDictionary = @"{WebP}";
static NSString * kTXAdCGImagePropertyWebPLoopCount = @"LoopCount";
static NSString * kTXAdCGImagePropertyWebPDelayTime = @"DelayTime";
static NSString * kTXAdCGImagePropertyWebPUnclampedDelayTime = @"UnclampedDelayTime";

@implementation TXAdImageAWebPCoder

+ (void)initialize {
#if __IPHONE_14_0 || __TVOS_14_0 || __MAC_11_0 || __WATCHOS_7_0
    // Xcode 12
    if (@available(iOS 14, tvOS 14, macOS 11, watchOS 7, *)) {
        // Use TXAdK instead of raw value
        kTXAdCGImagePropertyWebPDictionary = (__bridge NSString *)kCGImagePropertyWebPDictionary;
        kTXAdCGImagePropertyWebPLoopCount = (__bridge NSString *)kCGImagePropertyWebPLoopCount;
        kTXAdCGImagePropertyWebPDelayTime = (__bridge NSString *)kCGImagePropertyWebPDelayTime;
        kTXAdCGImagePropertyWebPUnclampedDelayTime = (__bridge NSString *)kCGImagePropertyWebPUnclampedDelayTime;
    }
#endif
}

+ (instancetype)sharedCoder {
    static TXAdImageAWebPCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[TXAdImageAWebPCoder alloc] init];
    });
    return coder;
}

#pragma mark - TXAdImageCoder

- (BOOL)canDecodeFromData:(nullable NSData *)data {
    switch ([NSData txad_imageFormatForImageData:data]) {
        case TXAdImageFormatWebP:
            // Check WebP decoding compatibility
            return [self.class canDecodeFromFormat:TXAdImageFormatWebP];
        default:
            return NO;
    }
}

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return [self canDecodeFromData:data];
}

- (BOOL)canEncodeToFormat:(TXAdImageFormat)format {
    switch (format) {
        case TXAdImageFormatWebP:
            // Check WebP encoding compatibility
            return [self.class canEncodeToFormat:TXAdImageFormatWebP];
        default:
            return NO;
    }
}

#pragma mark - Subclass Override

+ (TXAdImageFormat)imageFormat {
    return TXAdImageFormatWebP;
}

+ (NSString *)imageUTType {
    return (__bridge NSString *)kTXAdUTTypeWebP;
}

+ (NSString *)dictionaryProperty {
    return kTXAdCGImagePropertyWebPDictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return kTXAdCGImagePropertyWebPUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return kTXAdCGImagePropertyWebPDelayTime;
}

+ (NSString *)loopCountProperty {
    return kTXAdCGImagePropertyWebPLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 0;
}

@end
