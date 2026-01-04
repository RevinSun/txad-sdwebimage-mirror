/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageOptionsProcessor.h"

@interface TXAdWebImageOptionsResult ()

@property (nonatomic, assign) TXAdWebImageOptions options;
@property (nonatomic, copy, nullable) TXAdWebImageContext *context;

@end

@implementation TXAdWebImageOptionsResult

- (instancetype)initWithOptions:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context {
    self = [super init];
    if (self) {
        self.options = options;
        self.context = context;
    }
    return self;
}

@end

@interface TXAdWebImageOptionsProcessor ()

@property (nonatomic, copy, nonnull) TXAdWebImageOptionsProcessorBlock block;

@end

@implementation TXAdWebImageOptionsProcessor

- (instancetype)initWithBlock:(TXAdWebImageOptionsProcessorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)optionsProcessorWithBlock:(TXAdWebImageOptionsProcessorBlock)block {
    TXAdWebImageOptionsProcessor *optionsProcessor = [[TXAdWebImageOptionsProcessor alloc] initWithBlock:block];
    return optionsProcessor;
}

- (TXAdWebImageOptionsResult *)processedResultForURL:(NSURL *)url options:(TXAdWebImageOptions)options context:(TXAdWebImageContext *)context {
    if (!self.block) {
        return nil;
    }
    return self.block(url, options, context);
}

@end
