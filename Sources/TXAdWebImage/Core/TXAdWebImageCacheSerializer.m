/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageCacheSerializer.h"

@interface TXAdWebImageCacheSerializer ()

@property (nonatomic, copy, nonnull) TXAdWebImageCacheSerializerBlock block;

@end

@implementation TXAdWebImageCacheSerializer

- (instancetype)initWithBlock:(TXAdWebImageCacheSerializerBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheSerializerWithBlock:(TXAdWebImageCacheSerializerBlock)block {
    TXAdWebImageCacheSerializer *cacheSerializer = [[TXAdWebImageCacheSerializer alloc] initWithBlock:block];
    return cacheSerializer;
}

- (NSData *)cacheDataWithImage:(UIImage *)image originalData:(NSData *)data imageURL:(nullable NSURL *)imageURL {
    if (!self.block) {
        return nil;
    }
    return self.block(image, data, imageURL);
}

@end
