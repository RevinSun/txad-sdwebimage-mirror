/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageCodersManager.h"
#import "TXAdImageIOCoder.h"
#import "TXAdImageGIFCoder.h"
#import "TXAdImageAPNGCoder.h"
#import "TXAdImageHEICCoder.h"
#import "TXAdInternalMacros.h"

@interface TXAdImageCodersManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<TXAdImageCoder>> *imageCoders;

@end

@implementation TXAdImageCodersManager {
    TXAd_LOCK_DECLARE(_codersLock);
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // initialize with default coders
        _imageCoders = [NSMutableArray arrayWithArray:@[[TXAdImageIOCoder sharedCoder], [TXAdImageGIFCoder sharedCoder], [TXAdImageAPNGCoder sharedCoder]]];
        TXAd_LOCK_INIT(_codersLock);
    }
    return self;
}

- (NSArray<id<TXAdImageCoder>> *)coders {
    TXAd_LOCK(_codersLock);
    NSArray<id<TXAdImageCoder>> *coders = [_imageCoders copy];
    TXAd_UNLOCK(_codersLock);
    return coders;
}

- (void)setCoders:(NSArray<id<TXAdImageCoder>> *)coders {
    TXAd_LOCK(_codersLock);
    [_imageCoders removeAllObjects];
    if (coders.count) {
        [_imageCoders addObjectsFromArray:coders];
    }
    TXAd_UNLOCK(_codersLock);
}

#pragma mark - Coder IO operations

- (void)addCoder:(nonnull id<TXAdImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(TXAdImageCoder)]) {
        return;
    }
    TXAd_LOCK(_codersLock);
    [_imageCoders addObject:coder];
    TXAd_UNLOCK(_codersLock);
}

- (void)removeCoder:(nonnull id<TXAdImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(TXAdImageCoder)]) {
        return;
    }
    TXAd_LOCK(_codersLock);
    [_imageCoders removeObject:coder];
    TXAd_UNLOCK(_codersLock);
}

#pragma mark - TXAdImageCoder
- (BOOL)canDecodeFromData:(NSData *)data {
    NSArray<id<TXAdImageCoder>> *coders = self.coders;
    for (id<TXAdImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canEncodeToFormat:(TXAdImageFormat)format {
    NSArray<id<TXAdImageCoder>> *coders = self.coders;
    for (id<TXAdImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable TXAdImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    UIImage *image;
    NSArray<id<TXAdImageCoder>> *coders = self.coders;
    for (id<TXAdImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            image = [coder decodedImageWithData:data options:options];
            break;
        }
    }
    
    return image;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(TXAdImageFormat)format options:(nullable TXAdImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    NSArray<id<TXAdImageCoder>> *coders = self.coders;
    for (id<TXAdImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format options:options];
        }
    }
    return nil;
}

- (NSData *)encodedDataWithFrames:(NSArray<TXAdImageFrame *> *)frames loopCount:(NSUInteger)loopCount format:(TXAdImageFormat)format options:(TXAdImageCoderOptions *)options {
    if (!frames || frames.count < 1) {
        return nil;
    }
    NSArray<id<TXAdImageCoder>> *coders = self.coders;
    for (id<TXAdImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            if ([coder respondsToSelector:@selector(encodedDataWithFrames:loopCount:format:options:)]) {
                return [coder encodedDataWithFrames:frames loopCount:loopCount format:format options:options];
            }
        }
    }
    return nil;
}

@end
