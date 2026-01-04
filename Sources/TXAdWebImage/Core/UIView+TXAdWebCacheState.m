/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+TXAdWebCacheState.h"
#import "objc/runtime.h"

typedef NSMutableDictionary<NSString *, TXAdWebImageLoadState *> TXAdStatesDictionary;

@implementation TXAdWebImageLoadState

@end

@implementation UIView (WebCacheState)

- (TXAdStatesDictionary *)txad_imageLoadStateDictionary {
    TXAdStatesDictionary *states = objc_getAssociatedObject(self, @selector(txad_imageLoadStateDictionary));
    if (!states) {
        states = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, @selector(txad_imageLoadStateDictionary), states, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return states;
}

- (TXAdWebImageLoadState *)txad_imageLoadStateForKey:(NSString *)key {
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    @synchronized(self) {
        return [self.txad_imageLoadStateDictionary objectForKey:key];
    }
}

- (void)txad_setImageLoadState:(TXAdWebImageLoadState *)state forKey:(NSString *)key {
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    @synchronized(self) {
        self.txad_imageLoadStateDictionary[key] = state;
    }
}

- (void)txad_removeImageLoadStateForKey:(NSString *)key {
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    @synchronized(self) {
        self.txad_imageLoadStateDictionary[key] = nil;
    }
}

@end
