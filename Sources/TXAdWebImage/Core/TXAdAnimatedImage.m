/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdAnimatedImage.h"
#import "NSImage+Compatibility.h"
#import "TXAdImageCoder.h"
#import "TXAdImageCodersManager.h"
#import "TXAdImageFrame.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+Metadata.h"
#import "UIImage+MultiFormat.h"
#import "TXAdImageCoderHelper.h"
#import "TXAdImageAssetManager.h"
#import "objc/runtime.h"

static CGFloat TXAdImageScaleFromPath(NSString *string) {
    if (string.length == 0 || [string hasSuffix:@"/"]) return 1;
    NSString *name = string.stringByDeletingPathExtension;
    __block CGFloat scale = 1;
    
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"@[0-9]+\\.?[0-9]*x$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [pattern enumerateMatchesInString:name options:kNilOptions range:NSMakeRange(0, name.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        scale = [string substringWithRange:NSMakeRange(result.range.location + 1, result.range.length - 2)].doubleValue;
    }];
    
    return scale;
}

@interface TXAdAnimatedImage ()

@property (nonatomic, strong) id<TXAdAnimatedImageCoder> animatedCoder;
@property (atomic, copy) NSArray<TXAdImageFrame *> *loadedAnimatedImageFrames; // Mark as atomic to keep thread-safe
@property (nonatomic, assign, getter=isAllFramesLoaded) BOOL allFramesLoaded;

@end

@implementation TXAdAnimatedImage
@dynamic scale; // call super

#pragma mark - UIImage override method
+ (instancetype)imageNamed:(NSString *)name {
#if __has_include(<UIKit/UITraitCollection.h>)
    return [self imageNamed:name inBundle:nil compatibleWithTraitCollection:nil];
#else
    return [self imageNamed:name inBundle:nil];
#endif
}

#if __has_include(<UIKit/UITraitCollection.h>)
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
#if TXAd_VISION
    if (!traitCollection) {
        traitCollection = UITraitCollection.currentTraitCollection;
    }
#else
    if (!traitCollection) {
        traitCollection = UIScreen.mainScreen.traitCollection;
    }
#endif
    CGFloat scale = traitCollection.displayScale;
    return [self imageNamed:name inBundle:bundle scale:scale];
}
#else
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle {
    return [self imageNamed:name inBundle:bundle scale:0];
}
#endif

// 0 scale means automatically check
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle scale:(CGFloat)scale {
    if (!name) {
        return nil;
    }
    if (!bundle) {
        bundle = [NSBundle mainBundle];
    }
    TXAdImageAssetManager *assetManager = [TXAdImageAssetManager sharedAssetManager];
    TXAdAnimatedImage *image = (TXAdAnimatedImage *)[assetManager imageForName:name];
    if ([image isKindOfClass:[TXAdAnimatedImage class]]) {
        return image;
    }
    NSString *path = [assetManager getPathForName:name bundle:bundle preferredScale:&scale];
    if (!path) {
        return image;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return image;
    }
    image = [[self alloc] initWithData:data scale:scale];
    if (image) {
        [assetManager storeImage:image forName:name];
    }
    
    return image;
}

+ (instancetype)imageWithContentsOfFile:(NSString *)path {
    return [[self alloc] initWithContentsOfFile:path];
}

+ (instancetype)imageWithData:(NSData *)data {
    return [[self alloc] initWithData:data];
}

+ (instancetype)imageWithData:(NSData *)data scale:(CGFloat)scale {
    return [[self alloc] initWithData:data scale:scale];
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return nil;
    }
    CGFloat scale = TXAdImageScaleFromPath(path);
    // path extension may be useful for coder like raw-image
    NSString *fileExtensionHint = path.pathExtension; // without dot
    if (fileExtensionHint.length == 0) {
        // Ignore file extension which is empty
        fileExtensionHint = nil;
    }
    TXAdImageCoderMutableOptions *mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:1];
    mutableCoderOptions[TXAdImageCoderDecodeFileExtensionHint] = fileExtensionHint;
    return [self initWithData:data scale:scale options:[mutableCoderOptions copy]];
}

- (instancetype)initWithData:(NSData *)data {
    return [self initWithData:data scale:1];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale {
    return [self initWithData:data scale:scale options:nil];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale options:(TXAdImageCoderOptions *)options {
    if (!data || data.length == 0) {
        return nil;
    }
    // Vector image does not supported, guard firstly
    TXAdImageFormat format = [NSData txad_imageFormatForImageData:data];
    if (format == TXAdImageFormatSVG || format == TXAdImageFormatPDF) {
        return nil;
    }
    
    id<TXAdAnimatedImageCoder> animatedCoder = nil;
    TXAdImageCoderMutableOptions *mutableCoderOptions;
    if (options != nil) {
        mutableCoderOptions = [NSMutableDictionary dictionaryWithDictionary:options];
    } else {
        mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    mutableCoderOptions[TXAdImageCoderDecodeScaleFactor] = @(scale);
    options = [mutableCoderOptions copy];
    for (id<TXAdImageCoder>coder in [TXAdImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
        if ([coder conformsToProtocol:@protocol(TXAdAnimatedImageCoder)]) {
            if ([coder canDecodeFromData:data]) {
                animatedCoder = [[[coder class] alloc] initWithAnimatedImageData:data options:options];
                break;
            }
        }
    }
    if (animatedCoder) {
        // Animated Image
        return [self initWithAnimatedCoder:animatedCoder scale:scale];
    } else {
        // Static Image (Before 5.19 this code path return nil)
        UIImage *image = [[TXAdImageCodersManager sharedManager] decodedImageWithData:data options:options];
        if (!image) {
            return nil;
        }
        // Vector image does not supported, guard secondly
        if (image.txad_isVector) {
            return nil;
        }
#if TXAd_MAC
        self = [super initWithCGImage:image.CGImage scale:MAX(scale, 1) orientation:kCGImagePropertyOrientationUp];
#else
        self = [super initWithCGImage:image.CGImage scale:MAX(scale, 1) orientation:image.imageOrientation];
#endif
        return self;
    }
}

- (instancetype)initWithAnimatedCoder:(id<TXAdAnimatedImageCoder>)animatedCoder scale:(CGFloat)scale {
    if (!animatedCoder) {
        return nil;
    }
    UIImage *image = [animatedCoder animatedImageFrameAtIndex:0];
    if (!image) {
        return nil;
    }
#if TXAd_MAC
    self = [super initWithCGImage:image.CGImage scale:MAX(scale, 1) orientation:kCGImagePropertyOrientationUp];
#else
    self = [super initWithCGImage:image.CGImage scale:MAX(scale, 1) orientation:image.imageOrientation];
#endif
    if (self) {
        // Only keep the animated coder if frame count > 1, save RAM usage for non-animated image format (APNG/WebP)
        if (animatedCoder.animatedImageFrameCount > 1) {
            _animatedCoder = animatedCoder;
        }
    }
    return self;
}

- (TXAdImageFormat)animatedImageFormat {
    return [NSData txad_imageFormatForImageData:self.animatedImageData];
}

#pragma mark - Preload
- (void)preloadAllFrames {
    if (!_animatedCoder) {
        return;
    }
    if (!self.isAllFramesLoaded) {
        NSMutableArray<TXAdImageFrame *> *frames = [NSMutableArray arrayWithCapacity:self.animatedImageFrameCount];
        for (size_t i = 0; i < self.animatedImageFrameCount; i++) {
            UIImage *image = [self animatedImageFrameAtIndex:i];
            NSTimeInterval duration = [self animatedImageDurationAtIndex:i];
            TXAdImageFrame *frame = [TXAdImageFrame frameWithImage:image duration:duration]; // through the image should be nonnull, used as nullable for `animatedImageFrameAtIndex:`
            [frames addObject:frame];
        }
        self.loadedAnimatedImageFrames = frames;
        self.allFramesLoaded = YES;
    }
}

- (void)unloadAllFrames {
    if (!_animatedCoder) {
        return;
    }
    if (self.isAllFramesLoaded) {
        self.loadedAnimatedImageFrames = nil;
        self.allFramesLoaded = NO;
    }
}

#pragma mark - NSSecureCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        NSData *animatedImageData = [aDecoder decodeObjectOfClass:[NSData class] forKey:NSStringFromSelector(@selector(animatedImageData))];
        if (!animatedImageData) {
            return self;
        }
        CGFloat scale = self.scale;
        id<TXAdAnimatedImageCoder> animatedCoder = nil;
        for (id<TXAdImageCoder>coder in [TXAdImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
            if ([coder conformsToProtocol:@protocol(TXAdAnimatedImageCoder)]) {
                if ([coder canDecodeFromData:animatedImageData]) {
                    animatedCoder = [[[coder class] alloc] initWithAnimatedImageData:animatedImageData options:@{TXAdImageCoderDecodeScaleFactor : @(scale)}];
                    break;
                }
            }
        }
        if (!animatedCoder) {
            return self;
        }
        if (animatedCoder.animatedImageFrameCount > 1) {
            _animatedCoder = animatedCoder;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    NSData *animatedImageData = self.animatedImageData;
    if (animatedImageData) {
        [aCoder encodeObject:animatedImageData forKey:NSStringFromSelector(@selector(animatedImageData))];
    }
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - TXAdAnimatedImageProvider

- (NSData *)animatedImageData {
    return [self.animatedCoder animatedImageData];
}

- (NSUInteger)animatedImageLoopCount {
    return [self.animatedCoder animatedImageLoopCount];
}

- (NSUInteger)animatedImageFrameCount {
    return [self.animatedCoder animatedImageFrameCount];
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    if (index >= self.animatedImageFrameCount) {
        return nil;
    }
    if (self.isAllFramesLoaded) {
        TXAdImageFrame *frame = [self.loadedAnimatedImageFrames objectAtIndex:index];
        return frame.image;
    }
    return [self.animatedCoder animatedImageFrameAtIndex:index];
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    if (index >= self.animatedImageFrameCount) {
        return 0;
    }
    if (self.isAllFramesLoaded) {
        TXAdImageFrame *frame = [self.loadedAnimatedImageFrames objectAtIndex:index];
        return frame.duration;
    }
    return [self.animatedCoder animatedImageDurationAtIndex:index];
}

@end

@implementation TXAdAnimatedImage (MemoryCacheCost)

- (NSUInteger)txad_memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(txad_memoryCost));
    if (value != nil) {
        return value.unsignedIntegerValue;
    }
    
    CGImageRef imageRef = self.CGImage;
    if (!imageRef) {
        return 0;
    }
    NSUInteger bytesPerFrame = CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);
    NSUInteger frameCount = 1;
    if (self.isAllFramesLoaded) {
        frameCount = self.animatedImageFrameCount;
    }
    frameCount = frameCount > 0 ? frameCount : 1;
    NSUInteger cost = bytesPerFrame * frameCount;
    return cost;
}

@end

@implementation TXAdAnimatedImage (Metadata)

- (BOOL)txad_isAnimated {
    return self.animatedImageFrameCount > 1;
}

- (NSUInteger)txad_imageLoopCount {
    return self.animatedImageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)txad_imageLoopCount {
    return;
}

- (NSUInteger)txad_imageFrameCount {
    NSUInteger frameCount = self.animatedImageFrameCount;
    if (frameCount > 1) {
        return frameCount;
    } else {
        return 1;
    }
}

- (TXAdImageFormat)txad_imageFormat {
    NSData *animatedImageData = self.animatedImageData;
    if (animatedImageData) {
        return [NSData txad_imageFormatForImageData:animatedImageData];
    } else {
        return [super txad_imageFormat];
    }
}

- (void)setSd_imageFormat:(TXAdImageFormat)txad_imageFormat {
    return;
}

- (BOOL)txad_isVector {
    return NO;
}

@end

@implementation TXAdAnimatedImage (MultiFormat)

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
    return [[self alloc] initWithData:data scale:scale options:@{TXAdImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)}];
}

- (nullable NSData *)txad_imageData {
    NSData *imageData = self.animatedImageData;
    if (imageData) {
        return imageData;
    } else {
        return [self txad_imageDataAsFormat:self.animatedImageFormat];
    }
}

- (nullable NSData *)txad_imageDataAsFormat:(TXAdImageFormat)imageFormat {
    return [self txad_imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)txad_imageDataAsFormat:(TXAdImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self txad_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)txad_imageDataAsFormat:(TXAdImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    // Protect when user input the imageFormat == self.animatedImageFormat && compressionQuality == 1
    // This should be treated as grabbing `self.animatedImageData` as well :)
    NSData *imageData;
    if (imageFormat == self.animatedImageFormat && compressionQuality == 1) {
        imageData = self.animatedImageData;
    }
    if (imageData) return imageData;
    
    TXAdImageCoderOptions *options = @{TXAdImageCoderEncodeCompressionQuality : @(compressionQuality), TXAdImageCoderEncodeFirstFrameOnly : @(firstFrameOnly)};
    NSUInteger frameCount = self.animatedImageFrameCount;
    if (frameCount <= 1) {
        // Static image
        imageData = [TXAdImageCodersManager.sharedManager encodedDataWithImage:self format:imageFormat options:options];
    }
    if (imageData) return imageData;
    
    NSUInteger loopCount = self.animatedImageLoopCount;
    // Keep animated image encoding, loop each frame.
    NSMutableArray<TXAdImageFrame *> *frames = [NSMutableArray arrayWithCapacity:frameCount];
    for (size_t i = 0; i < frameCount; i++) {
        UIImage *image = [self animatedImageFrameAtIndex:i];
        NSTimeInterval duration = [self animatedImageDurationAtIndex:i];
        TXAdImageFrame *frame = [TXAdImageFrame frameWithImage:image duration:duration];
        [frames addObject:frame];
    }
    imageData = [TXAdImageCodersManager.sharedManager encodedDataWithFrames:frames loopCount:loopCount format:imageFormat options:options];
    return imageData;
}

@end
