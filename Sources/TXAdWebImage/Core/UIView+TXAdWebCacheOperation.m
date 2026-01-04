/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+TXAdWebCacheOperation.h"
#import "objc/runtime.h"

// key is strong, value is weak because operation instance is retained by TXAdWebImageManager's runningOperations property
// we should use lock to keep thread-safe because these method may not be accessed from main queue
typedef NSMapTable<NSString *, id<TXAdWebImageOperation>> TXAdOperationsDictionary;

@implementation UIView (WebCacheOperation)

- (TXAdOperationsDictionary *)txad_operationDictionary {
    @synchronized(self) {
        TXAdOperationsDictionary *operations = objc_getAssociatedObject(self, @selector(txad_operationDictionary));
        if (operations) {
            return operations;
        }
        operations = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        objc_setAssociatedObject(self, @selector(txad_operationDictionary), operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operations;
    }
}

- (nullable id<TXAdWebImageOperation>)txad_imageLoadOperationForKey:(nullable NSString *)key  {
    id<TXAdWebImageOperation> operation;
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    TXAdOperationsDictionary *operationDictionary = [self txad_operationDictionary];
    @synchronized (self) {
        operation = [operationDictionary objectForKey:key];
    }
    return operation;
}

- (void)txad_setImageLoadOperation:(nullable id<TXAdWebImageOperation>)operation forKey:(nullable NSString *)key {
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    if (operation) {
        TXAdOperationsDictionary *operationDictionary = [self txad_operationDictionary];
        @synchronized (self) {
            [operationDictionary setObject:operation forKey:key];
        }
    }
}

- (void)txad_cancelImageLoadOperationWithKey:(nullable NSString *)key {
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    // Cancel in progress downloader from queue
    TXAdOperationsDictionary *operationDictionary = [self txad_operationDictionary];
    id<TXAdWebImageOperation> operation;
    
    @synchronized (self) {
        operation = [operationDictionary objectForKey:key];
    }
    if (operation) {
        if ([operation respondsToSelector:@selector(cancel)]) {
            [operation cancel];
        }
        @synchronized (self) {
            [operationDictionary removeObjectForKey:key];
        }
    }
}

- (void)txad_removeImageLoadOperationWithKey:(nullable NSString *)key {
    if (!key) {
        key = NSStringFromClass(self.class);
    }
    TXAdOperationsDictionary *operationDictionary = [self txad_operationDictionary];
    @synchronized (self) {
        [operationDictionary removeObjectForKey:key];
    }
}

@end
