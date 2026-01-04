/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdWebImageCompat.h"

@class TXAdAsyncBlockOperation;
typedef void (^TXAdAsyncBlock)(TXAdAsyncBlockOperation * __nonnull asyncOperation);

/// A async block operation, success after you call `completer` (not like `NSBlockOperation` which is for sync block, success on return)
@interface TXAdAsyncBlockOperation : NSOperation

- (nonnull instancetype)initWithBlock:(nonnull TXAdAsyncBlock)block;
+ (nonnull instancetype)blockOperationWithBlock:(nonnull TXAdAsyncBlock)block;
- (void)complete;

@end
