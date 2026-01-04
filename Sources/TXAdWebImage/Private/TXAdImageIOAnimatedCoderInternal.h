/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import "TXAdImageIOAnimatedCoder.h"

// AVFileTypeHEIC/AVFileTypeHEIF is defined in AVFoundation via iOS 11, we use this without import AVFoundation
#define kTXAdUTTypeHEIC  ((__bridge CFStringRef)@"public.heic")
#define kTXAdUTTypeHEIF  ((__bridge CFStringRef)@"public.heif")
// HEIC Sequence (Animated Image)
#define kTXAdUTTypeHEICS ((__bridge CFStringRef)@"public.heics")
// kTXAdUTTypeWebP seems not defined in public UTI framework, Apple use the hardcode string, we define them :)
#define kTXAdUTTypeWebP  ((__bridge CFStringRef)@"org.webmproject.webp")

#define kTXAdUTTypeImage ((__bridge CFStringRef)@"public.image")
#define kTXAdUTTypeJPEG  ((__bridge CFStringRef)@"public.jpeg")
#define kTXAdUTTypePNG   ((__bridge CFStringRef)@"public.png")
#define kTXAdUTTypeTIFF  ((__bridge CFStringRef)@"public.tiff")
#define kTXAdUTTypeSVG   ((__bridge CFStringRef)@"public.svg-image")
#define kTXAdUTTypeGIF   ((__bridge CFStringRef)@"com.compuserve.gif")
#define kTXAdUTTypePDF   ((__bridge CFStringRef)@"com.adobe.pdf")
#define kTXAdUTTypeBMP   ((__bridge CFStringRef)@"com.microsoft.bmp")
#define kTXAdUTTypeRAW   ((__bridge CFStringRef)@"public.camera-raw-image")

@interface TXAdImageIOAnimatedCoder ()

+ (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index source:(nonnull CGImageSourceRef)source;
+ (NSUInteger)imageLoopCountWithSource:(nonnull CGImageSourceRef)source;
+ (nullable UIImage *)createFrameAtIndex:(NSUInteger)index source:(nonnull CGImageSourceRef)source scale:(CGFloat)scale preserveAspectRatio:(BOOL)preserveAspectRatio thumbnailSize:(CGSize)thumbnailSize lazyDecode:(BOOL)lazyDecode animatedImage:(BOOL)animatedImage;
+ (BOOL)canEncodeToFormat:(TXAdImageFormat)format;
+ (BOOL)canDecodeFromFormat:(TXAdImageFormat)format;

@end
