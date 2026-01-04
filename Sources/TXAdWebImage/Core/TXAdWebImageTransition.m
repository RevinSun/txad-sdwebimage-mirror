/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageTransition.h"

#if TXAd_UIKIT || TXAd_MAC

#if TXAd_MAC
#import "TXAdWebImageTransitionInternal.h"
#import "TXAdInternalMacros.h"

CAMediaTimingFunction * TXAdTimingFunctionFromAnimationOptions(TXAdWebImageAnimationOptions options) {
    if (TXAd_OPTIONS_CONTAINS(TXAdWebImageAnimationOptionCurveLinear, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    } else if (TXAd_OPTIONS_CONTAINS(TXAdWebImageAnimationOptionCurveEaseIn, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    } else if (TXAd_OPTIONS_CONTAINS(TXAdWebImageAnimationOptionCurveEaseOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    } else if (TXAd_OPTIONS_CONTAINS(TXAdWebImageAnimationOptionCurveEaseInOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    } else {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    }
}

CATransition * TXAdTransitionFromAnimationOptions(TXAdWebImageAnimationOptions options) {
    if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionCrossDissolve)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionFade;
        return trans;
    } else if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionFlipFromLeft)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromLeft;
        return trans;
    } else if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionFlipFromRight)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromRight;
        return trans;
    } else if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionFlipFromTop)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionFlipFromBottom)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionCurlUp)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (TXAd_OPTIONS_CONTAINS(options, TXAdWebImageAnimationOptionTransitionCurlDown)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else {
        return nil;
    }
}
#endif

@implementation TXAdWebImageTransition

- (instancetype)init {
    self = [super init];
    if (self) {
        self.duration = 0.5;
    }
    return self;
}

@end

@implementation TXAdWebImageTransition (Conveniences)

+ (TXAdWebImageTransition *)fadeTransition {
    return [self fadeTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)fadeTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionCrossDissolve;
#endif
    return transition;
}

+ (TXAdWebImageTransition *)flipFromLeftTransition {
    return [self flipFromLeftTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)flipFromLeftTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionFlipFromLeft;
#endif
    return transition;
}

+ (TXAdWebImageTransition *)flipFromRightTransition {
    return [self flipFromRightTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)flipFromRightTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionFlipFromRight;
#endif
    return transition;
}

+ (TXAdWebImageTransition *)flipFromTopTransition {
    return [self flipFromTopTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)flipFromTopTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromTop | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionFlipFromTop;
#endif
    return transition;
}

+ (TXAdWebImageTransition *)flipFromBottomTransition {
    return [self flipFromBottomTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)flipFromBottomTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromBottom | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionFlipFromBottom;
#endif
    return transition;
}

+ (TXAdWebImageTransition *)curlUpTransition {
    return [self curlUpTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)curlUpTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlUp | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionCurlUp;
#endif
    return transition;
}

+ (TXAdWebImageTransition *)curlDownTransition {
    return [self curlDownTransitionWithDuration:0.5];
}

+ (TXAdWebImageTransition *)curlDownTransitionWithDuration:(NSTimeInterval)duration {
    TXAdWebImageTransition *transition = [TXAdWebImageTransition new];
    transition.duration = duration;
#if TXAd_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlDown | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = TXAdWebImageAnimationOptionTransitionCurlDown;
#endif
    transition.duration = duration;
    return transition;
}

@end

#endif
