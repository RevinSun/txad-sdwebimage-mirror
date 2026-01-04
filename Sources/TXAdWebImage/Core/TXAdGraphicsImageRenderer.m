/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXAdGraphicsImageRenderer.h"
#import "TXAdImageGraphics.h"

@interface TXAdGraphicsImageRendererFormat ()
#if TXAd_UIKIT
@property (nonatomic, strong) UIGraphicsImageRendererFormat *uiformat API_AVAILABLE(ios(10.0), tvos(10.0));
#endif
@end

@implementation TXAdGraphicsImageRendererFormat
@synthesize scale = _scale;
@synthesize opaque = _opaque;
@synthesize preferredRange = _preferredRange;

#pragma mark - Property
- (CGFloat)scale {
#if TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        return self.uiformat.scale;
    } else {
        return _scale;
    }
#else
    return _scale;
#endif
}

- (void)setScale:(CGFloat)scale {
#if TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        self.uiformat.scale = scale;
    } else {
        _scale = scale;
    }
#else
    _scale = scale;
#endif
}

- (BOOL)opaque {
#if TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        return self.uiformat.opaque;
    } else {
        return _opaque;
    }
#else
    return _opaque;
#endif
}

- (void)setOpaque:(BOOL)opaque {
#if TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        self.uiformat.opaque = opaque;
    } else {
        _opaque = opaque;
    }
#else
    _opaque = opaque;
#endif
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (TXAdGraphicsImageRendererFormatRange)preferredRange {
#if TXAd_VISION
  return (TXAdGraphicsImageRendererFormatRange)self.uiformat.preferredRange;
#elif TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        if (@available(iOS 12.0, tvOS 12.0, *)) {
            return (TXAdGraphicsImageRendererFormatRange)self.uiformat.preferredRange;
        } else {
            BOOL prefersExtendedRange = self.uiformat.prefersExtendedRange;
            if (prefersExtendedRange) {
                return TXAdGraphicsImageRendererFormatRangeExtended;
            } else {
                return TXAdGraphicsImageRendererFormatRangeStandard;
            }
        }
    } else {
        return _preferredRange;
    }
#else
    return _preferredRange;
#endif
}

- (void)setPreferredRange:(TXAdGraphicsImageRendererFormatRange)preferredRange {
#if TXAd_VISION
  self.uiformat.preferredRange = (UIGraphicsImageRendererFormatRange)preferredRange;
#elif TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        if (@available(iOS 12.0, tvOS 12.0, *)) {
            self.uiformat.preferredRange = (UIGraphicsImageRendererFormatRange)preferredRange;
        } else {
            switch (preferredRange) {
                case TXAdGraphicsImageRendererFormatRangeExtended:
                    self.uiformat.prefersExtendedRange = YES;
                    break;
                case TXAdGraphicsImageRendererFormatRangeStandard:
                    self.uiformat.prefersExtendedRange = NO;
                default:
                    // Automatic means default
                    break;
            }
        }
    } else {
        _preferredRange = preferredRange;
    }
#else
    _preferredRange = preferredRange;
#endif
}
#pragma clang diagnostic pop

- (instancetype)init {
    self = [super init];
    if (self) {
#if TXAd_UIKIT
        if (@available(iOS 10.0, tvOS 10.10, *)) {
            UIGraphicsImageRendererFormat *uiformat = [[UIGraphicsImageRendererFormat alloc] init];
            self.uiformat = uiformat;
        } else {
#endif
#if TXAd_VISION
            CGFloat screenScale = UITraitCollection.currentTraitCollection.displayScale;
#elif TXAd_WATCH
            CGFloat screenScale = [WKInterfaceDevice currentDevice].screenScale;
#elif TXAd_UIKIT
            CGFloat screenScale = [UIScreen mainScreen].scale;
#elif TXAd_MAC
            NSScreen *mainScreen = nil;
            if (@available(macOS 10.12, *)) {
                mainScreen = [NSScreen mainScreen];
            } else {
                mainScreen = [NSScreen screens].firstObject;
            }
            CGFloat screenScale = mainScreen.backingScaleFactor ?: 1.0f;
#endif
            self.scale = screenScale;
            self.opaque = NO;
#if TXAd_UIKIT
        }
#endif
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (instancetype)initForMainScreen {
    self = [super init];
    if (self) {
#if TXAd_UIKIT
        if (@available(iOS 10.0, tvOS 10.0, *)) {
            UIGraphicsImageRendererFormat *uiformat;
            // iOS 11.0.0 GM does have `preferredFormat`, but iOS 11 betas did not (argh!)
            if ([UIGraphicsImageRenderer respondsToSelector:@selector(preferredFormat)]) {
                uiformat = [UIGraphicsImageRendererFormat preferredFormat];
            } else {
                uiformat = [UIGraphicsImageRendererFormat defaultFormat];
            }
            self.uiformat = uiformat;
        } else {
#endif
#if TXAd_VISION
            CGFloat screenScale = UITraitCollection.currentTraitCollection.displayScale;
#elif TXAd_WATCH
            CGFloat screenScale = [WKInterfaceDevice currentDevice].screenScale;
#elif TXAd_UIKIT
            CGFloat screenScale = [UIScreen mainScreen].scale;
#elif TXAd_MAC
            NSScreen *mainScreen = nil;
            if (@available(macOS 10.12, *)) {
                mainScreen = [NSScreen mainScreen];
            } else {
                mainScreen = [NSScreen screens].firstObject;
            }
            CGFloat screenScale = mainScreen.backingScaleFactor ?: 1.0f;
#endif
            self.scale = screenScale;
            self.opaque = NO;
#if TXAd_UIKIT
        }
#endif
    }
    return self;
}
#pragma clang diagnostic pop

+ (instancetype)preferredFormat {
    TXAdGraphicsImageRendererFormat *format = [[TXAdGraphicsImageRendererFormat alloc] initForMainScreen];
    return format;
}

@end

@interface TXAdGraphicsImageRenderer ()
@property (nonatomic, assign) CGSize size;
@property (nonatomic, strong) TXAdGraphicsImageRendererFormat *format;
#if TXAd_UIKIT
@property (nonatomic, strong) UIGraphicsImageRenderer *uirenderer API_AVAILABLE(ios(10.0), tvos(10.0));
#endif
@end

@implementation TXAdGraphicsImageRenderer

- (instancetype)initWithSize:(CGSize)size {
    return [self initWithSize:size format:TXAdGraphicsImageRendererFormat.preferredFormat];
}

- (instancetype)initWithSize:(CGSize)size format:(TXAdGraphicsImageRendererFormat *)format {
    NSParameterAssert(format);
    self = [super init];
    if (self) {
        self.size = size;
        self.format = format;
#if TXAd_UIKIT
        if (@available(iOS 10.0, tvOS 10.0, *)) {
            UIGraphicsImageRendererFormat *uiformat = format.uiformat;
            self.uirenderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:uiformat];
        }
#endif
    }
    return self;
}

- (UIImage *)imageWithActions:(NS_NOESCAPE TXAdGraphicsImageDrawingActions)actions {
    NSParameterAssert(actions);
#if TXAd_UIKIT
    if (@available(iOS 10.0, tvOS 10.0, *)) {
        UIGraphicsImageDrawingActions uiactions = ^(UIGraphicsImageRendererContext *rendererContext) {
            if (actions) {
                actions(rendererContext.CGContext);
            }
        };
        return [self.uirenderer imageWithActions:uiactions];
    } else {
#endif
        TXAdGraphicsBeginImageContextWithOptions(self.size, self.format.opaque, self.format.scale);
        CGContextRef context = TXAdGraphicsGetCurrentContext();
        if (actions) {
            actions(context);
        }
        UIImage *image = TXAdGraphicsGetImageFromCurrentImageContext();
        TXAdGraphicsEndImageContext();
        return image;
#if TXAd_UIKIT
    }
#endif
}

@end
