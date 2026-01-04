/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
* (c) Fabrice Aneche
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "UIImage+ExtendedCacheData.h"
#import <objc/runtime.h>

@implementation UIImage (ExtendedCacheData)

- (id<NSObject, NSCoding>)txad_extendedObject {
    return objc_getAssociatedObject(self, @selector(txad_extendedObject));
}

- (void)setSd_extendedObject:(id<NSObject, NSCoding>)txad_extendedObject {
    objc_setAssociatedObject(self, @selector(txad_extendedObject), txad_extendedObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
