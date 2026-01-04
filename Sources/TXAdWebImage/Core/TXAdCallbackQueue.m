/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */


#import "TXAdCallbackQueue.h"

@interface TXAdCallbackQueue ()

@property (nonatomic, strong, nonnull) dispatch_queue_t queue;

@end

static void * TXAdCallbackQueueKey = &TXAdCallbackQueueKey;
static void TXAdReleaseBlock(void *context) {
    CFRelease(context);
}

static void TXAdSafeExecute(TXAdCallbackQueue *callbackQueue, dispatch_block_t _Nonnull block, BOOL async) {
    // Extendc gcd queue's life cycle
    dispatch_queue_t queue = callbackQueue.queue;
    // Special handle for main queue label only (custom queue can have the same label)
    const char *label = dispatch_queue_get_label(queue);
    if (label && label == dispatch_queue_get_label(dispatch_get_main_queue())) {
        const char *currentLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
        if (label == currentLabel) {
            block();
            return;
        }
    }
    // Check specific to detect queue equal
    void *specific = dispatch_queue_get_specific(queue, TXAdCallbackQueueKey);
    if (specific && CFGetTypeID(specific) == CFUUIDGetTypeID()) {
        void *currentSpecific = dispatch_get_specific(TXAdCallbackQueueKey);
        if (currentSpecific && CFGetTypeID(currentSpecific) == CFUUIDGetTypeID() && CFEqual(specific, currentSpecific)) {
            block();
            return;
        }
    }
    if (async) {
        dispatch_async(queue, block);
    } else {
        dispatch_sync(queue, block);
    }
}

@implementation TXAdCallbackQueue

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self) {
        NSCParameterAssert(queue);
        CFUUIDRef UUID = CFUUIDCreate(kCFAllocatorDefault);
        dispatch_queue_set_specific(queue, TXAdCallbackQueueKey, (void *)UUID, TXAdReleaseBlock);
        _queue = queue;
    }
    return self;
}

+ (TXAdCallbackQueue *)mainQueue {
    static dispatch_once_t onceToken;
    static TXAdCallbackQueue *queue;
    dispatch_once(&onceToken, ^{
        queue = [[TXAdCallbackQueue alloc] initWithDispatchQueue:dispatch_get_main_queue()];
    });
    return queue;
}

+ (TXAdCallbackQueue *)currentQueue {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    TXAdCallbackQueue *queue = [[TXAdCallbackQueue alloc] initWithDispatchQueue:dispatch_get_current_queue()];
#pragma clang diagnostic pop
    return queue;
}

+ (TXAdCallbackQueue *)globalQueue {
    TXAdCallbackQueue *queue = [[TXAdCallbackQueue alloc] initWithDispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    return queue;
}

- (void)sync:(nonnull dispatch_block_t)block {
    switch (self.policy) {
        case TXAdCallbackPolicySafeExecute:
            TXAdSafeExecute(self, block, NO);
            break;
        case TXAdCallbackPolicyDispatch:
            dispatch_sync(self.queue, block);
            break;
        case TXAdCallbackPolicyInvoke:
            block();
            break;
        default:
            TXAdSafeExecute(self, block, NO);
            break;
    }
}

- (void)async:(nonnull dispatch_block_t)block {
    switch (self.policy) {
        case TXAdCallbackPolicySafeExecute:
            TXAdSafeExecute(self, block, YES);
            break;
        case TXAdCallbackPolicyDispatch:
            dispatch_async(self.queue, block);
            break;
        case TXAdCallbackPolicyInvoke:
            block();
            break;
        default:
            TXAdSafeExecute(self, block, YES);
            break;
    }
}

@end
