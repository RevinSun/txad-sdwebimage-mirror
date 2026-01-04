/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXAdWebImageCompat.h"
#import "TXAdWebImageDefine.h"

@class TXAdWebImageOptionsResult;

typedef TXAdWebImageOptionsResult * _Nullable(^TXAdWebImageOptionsProcessorBlock)(NSURL * _Nullable url, TXAdWebImageOptions options, TXAdWebImageContext * _Nullable context);

/**
 The options result contains both options and context.
 */
@interface TXAdWebImageOptionsResult : NSObject

/**
 WebCache options.
 */
@property (nonatomic, assign, readonly) TXAdWebImageOptions options;

/**
 Context options.
 */
@property (nonatomic, copy, readonly, nullable) TXAdWebImageContext *context;

/**
 Create a new options result.

 @param options options
 @param context context
 @return The options result contains both options and context.
 */
- (nonnull instancetype)initWithOptions:(TXAdWebImageOptions)options context:(nullable TXAdWebImageContext *)context;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new  NS_UNAVAILABLE;

@end

/**
 This is the protocol for options processor.
 Options processor can be used, to control the final result for individual image request's `TXAdWebImageOptions` and `TXAdWebImageContext`
 Implements the protocol to have a global control for each indivadual image request's option.
 */
@protocol TXAdWebImageOptionsProcessor <NSObject>

/**
 Return the processed options result for specify image URL, with its options and context

 @param url The URL to the image
 @param options A mask to specify options to use for this request
 @param context A context contains different options to perform specify changes or processes, see `TXAdWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 @return The processed result, contains both options and context
 */
- (nullable TXAdWebImageOptionsResult *)processedResultForURL:(nullable NSURL *)url
                                                    options:(TXAdWebImageOptions)options
                                                    context:(nullable TXAdWebImageContext *)context;

@end

/**
 A options processor class with block.
 */
@interface TXAdWebImageOptionsProcessor : NSObject<TXAdWebImageOptionsProcessor>

- (nonnull instancetype)initWithBlock:(nonnull TXAdWebImageOptionsProcessorBlock)block;
+ (nonnull instancetype)optionsProcessorWithBlock:(nonnull TXAdWebImageOptionsProcessorBlock)block;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new  NS_UNAVAILABLE;

@end
