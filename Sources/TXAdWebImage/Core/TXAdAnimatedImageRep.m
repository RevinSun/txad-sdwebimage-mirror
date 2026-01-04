/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdAnimatedImageRep.h"

#if TXAd_MAC

#import "TXAdImageIOAnimatedCoderInternal.h"
#import "TXAdImageGIFCoder.h"
#import "TXAdImageAPNGCoder.h"
#import "TXAdImageHEICCoder.h"
#import "TXAdImageAWebPCoder.h"

@interface TXAdAnimatedImageRep ()
/// This wrap the animated image frames for legacy animated image coder API (`encodedDataWithImage:`).
@property (nonatomic, readwrite, weak) NSArray<TXAdImageFrame *> *frames;
@property (nonatomic, assign, readwrite) TXAdImageFormat animatedImageFormat;
@end

@implementation TXAdAnimatedImageRep {
    CGImageSourceRef _imageSource;
}

- (void)dealloc {
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
}

- (instancetype)copyWithZone:(NSZone *)zone {
    TXAdAnimatedImageRep *imageRep = [super copyWithZone:zone];
    // super will copy all ivars
    if (imageRep->_imageSource) {
        CFRetain(imageRep->_imageSource);
    }
    return imageRep;
}

// `NSBitmapImageRep`'s `imageRepWithData:` is not designed initializer
+ (instancetype)imageRepWithData:(NSData *)data {
    TXAdAnimatedImageRep *imageRep = [[TXAdAnimatedImageRep alloc] initWithData:data];
    return imageRep;
}

// We should override init method for `NSBitmapImageRep` to do initialize about animated image format
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (instancetype)initWithData:(NSData *)data {
    self = [super initWithData:data];
    if (self) {
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef) data, NULL);
        if (!imageSource) {
            return self;
        }
        _imageSource = imageSource;
        NSUInteger frameCount = CGImageSourceGetCount(imageSource);
        if (frameCount <= 1) {
            return self;
        }
        CFStringRef type = CGImageSourceGetType(imageSource);
        if (!type) {
            return self;
        }
        _animatedImageData = data; // CGImageSource will retain the data internally, no extra copy
        TXAdImageFormat format = TXAdImageFormatUndefined;
        if (CFStringCompare(type, kTXAdUTTypeGIF, 0) == kCFCompareEqualTo) {
            // GIF
            // Fix the `NSBitmapImageRep` GIF loop count calculation issue
            // Which will use 0 when there are no loop count information metadata in GIF data
            format = TXAdImageFormatGIF;
            NSUInteger loopCount = [TXAdImageGIFCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else if (CFStringCompare(type, kTXAdUTTypePNG, 0) == kCFCompareEqualTo) {
            // APNG
            // Do initialize about frame count, current frame/duration and loop count
            format = TXAdImageFormatPNG;
            [self setProperty:NSImageFrameCount withValue:@(frameCount)];
            [self setProperty:NSImageCurrentFrame withValue:@(0)];
            NSUInteger loopCount = [TXAdImageAPNGCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else if (CFStringCompare(type, kTXAdUTTypeHEICS, 0) == kCFCompareEqualTo) {
            // HEIC
            // Do initialize about frame count, current frame/duration and loop count
            format = TXAdImageFormatHEIC;
            [self setProperty:NSImageFrameCount withValue:@(frameCount)];
            [self setProperty:NSImageCurrentFrame withValue:@(0)];
            NSUInteger loopCount = [TXAdImageHEICCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else if (CFStringCompare(type, kTXAdUTTypeWebP, 0) == kCFCompareEqualTo) {
            // WebP
            // Do initialize about frame count, current frame/duration and loop count
            format = TXAdImageFormatWebP;
            [self setProperty:NSImageFrameCount withValue:@(frameCount)];
            [self setProperty:NSImageCurrentFrame withValue:@(0)];
            NSUInteger loopCount = [TXAdImageAWebPCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else {
            format = [NSData txad_imageFormatForImageData:data];
        }
        _animatedImageFormat = format;
    }
    return self;
}

// `NSBitmapImageRep` will use `kCGImagePropertyGIFDelayTime` whenever you call `setProperty:withValue:` with `NSImageCurrentFrame` to change the current frame. We override it and use the actual `kCGImagePropertyGIFUnclampedDelayTime` if need.
- (void)setProperty:(NSBitmapImageRepPropertyKey)property withValue:(id)value {
    [super setProperty:property withValue:value];
    if ([property isEqualToString:NSImageCurrentFrame]) {
        // Access the image source
        CGImageSourceRef imageSource = _imageSource;
        if (!imageSource) {
            return;
        }
        // Check format type
        CFStringRef type = CGImageSourceGetType(imageSource);
        if (!type) {
            return;
        }
        NSUInteger index = [value unsignedIntegerValue];
        NSTimeInterval frameDuration = 0;
        if (CFStringCompare(type, kTXAdUTTypeGIF, 0) == kCFCompareEqualTo) {
            // GIF
            frameDuration = [TXAdImageGIFCoder frameDurationAtIndex:index source:imageSource];
        } else if (CFStringCompare(type, kTXAdUTTypePNG, 0) == kCFCompareEqualTo) {
            // APNG
            frameDuration = [TXAdImageAPNGCoder frameDurationAtIndex:index source:imageSource];
        } else if (CFStringCompare(type, kTXAdUTTypeHEICS, 0) == kCFCompareEqualTo) {
            // HEIC
            frameDuration = [TXAdImageHEICCoder frameDurationAtIndex:index source:imageSource];
        } else if (CFStringCompare(type, kTXAdUTTypeWebP, 0) == kCFCompareEqualTo) {
            // WebP
            frameDuration = [TXAdImageAWebPCoder frameDurationAtIndex:index source:imageSource];
        }
        if (!frameDuration) {
            return;
        }
        // Reset super frame duration with the actual frame duration
        [super setProperty:NSImageCurrentFrameDuration withValue:@(frameDuration)];
    }
}
#pragma clang diagnostic pop

@end

#endif
