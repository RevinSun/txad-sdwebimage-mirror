/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageCacheKeyFilter.h"

@interface TXAdWebImageCacheKeyFilter ()

@property (nonatomic, copy, nonnull) TXAdWebImageCacheKeyFilterBlock block;

@end

@implementation TXAdWebImageCacheKeyFilter

- (instancetype)initWithBlock:(TXAdWebImageCacheKeyFilterBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheKeyFilterWithBlock:(TXAdWebImageCacheKeyFilterBlock)block {
    TXAdWebImageCacheKeyFilter *cacheKeyFilter = [[TXAdWebImageCacheKeyFilter alloc] initWithBlock:block];
    return cacheKeyFilter;
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!self.block) {
        return nil;
    }
    return self.block(url);
}

@end
