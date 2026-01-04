/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdAsyncBlockOperation.h"
#import "TXAdInternalMacros.h"

@interface TXAdAsyncBlockOperation ()

@property (nonatomic, copy, nonnull) TXAdAsyncBlock executionBlock;

@end

@implementation TXAdAsyncBlockOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (nonnull instancetype)initWithBlock:(nonnull TXAdAsyncBlock)block {
    self = [super init];
    if (self) {
        self.executionBlock = block;
    }
    return self;
}

+ (nonnull instancetype)blockOperationWithBlock:(nonnull TXAdAsyncBlock)block {
    TXAdAsyncBlockOperation *operation = [[TXAdAsyncBlockOperation alloc] initWithBlock:block];
    return operation;
}

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            return;
        }
        self.finished = NO;
        self.executing = YES;
    }
    TXAdAsyncBlock executionBlock = self.executionBlock;
    if (executionBlock) {
        @weakify(self);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @strongify(self);
            if (!self) return;
            executionBlock(self);
        });
    }
}

- (void)cancel {
    @synchronized (self) {
        [super cancel];
        if (self.isExecuting) {
            self.executing = NO;
            self.finished = YES;
        }
    }
}

 
- (void)complete {
    @synchronized (self) {
        if (self.isExecuting) {
            self.finished = YES;
            self.executing = NO;
        }
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isAsynchronous {
    return YES;
}

@end
