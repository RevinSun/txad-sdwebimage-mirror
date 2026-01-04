/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXAdWebImageCompat.h"

#if TXAd_MAC

#import <QuartzCore/QuartzCore.h>

/// Helper method for Core Animation transition
FOUNDATION_EXPORT CAMediaTimingFunction * _Nullable TXAdTimingFunctionFromAnimationOptions(TXAdWebImageAnimationOptions options);
FOUNDATION_EXPORT CATransition * _Nullable TXAdTransitionFromAnimationOptions(TXAdWebImageAnimationOptions options);

#endif
