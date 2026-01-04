/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import <os/lock.h>
#import <libkern/OSAtomic.h>
#import <os/log.h>
#import "SDmetamacros.h"

#define TXAd_USE_OS_UNFAIR_LOCK TARGET_OS_MACCATALYST ||\
    (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_10_0) ||\
    (__MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_12) ||\
    (__TV_OS_VERSION_MIN_REQUIRED >= __TVOS_10_0) ||\
    (__WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_3_0)

#ifndef TXAd_LOCK_DECLARE
#if TXAd_USE_OS_UNFAIR_LOCK
#define TXAd_LOCK_DECLARE(lock) os_unfair_lock lock
#else
#define TXAd_LOCK_DECLARE(lock) os_unfair_lock lock API_AVAILABLE(ios(10.0), tvos(10), watchos(3), macos(10.12)); \
OSSpinLock lock##_deprecated;
#endif
#endif

#ifndef TXAd_LOCK_DECLARE_STATIC
#if TXAd_USE_OS_UNFAIR_LOCK
#define TXAd_LOCK_DECLARE_STATIC(lock) static os_unfair_lock lock
#else
#define TXAd_LOCK_DECLARE_STATIC(lock) static os_unfair_lock lock API_AVAILABLE(ios(10.0), tvos(10), watchos(3), macos(10.12)); \
static OSSpinLock lock##_deprecated;
#endif
#endif

#ifndef TXAd_LOCK_INIT
#if TXAd_USE_OS_UNFAIR_LOCK
#define TXAd_LOCK_INIT(lock) lock = OS_UNFAIR_LOCK_INIT
#else
#define TXAd_LOCK_INIT(lock) if (@available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *)) lock = OS_UNFAIR_LOCK_INIT; \
else lock##_deprecated = OS_SPINLOCK_INIT;
#endif
#endif

#ifndef TXAd_LOCK
#if TXAd_USE_OS_UNFAIR_LOCK
#define TXAd_LOCK(lock) os_unfair_lock_lock(&lock)
#else
#define TXAd_LOCK(lock) if (@available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *)) os_unfair_lock_lock(&lock); \
else OSSpinLockLock(&lock##_deprecated);
#endif
#endif

#ifndef TXAd_UNLOCK
#if TXAd_USE_OS_UNFAIR_LOCK
#define TXAd_UNLOCK(lock) os_unfair_lock_unlock(&lock)
#else
#define TXAd_UNLOCK(lock) if (@available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *)) os_unfair_lock_unlock(&lock); \
else OSSpinLockUnlock(&lock##_deprecated);
#endif
#endif

#ifndef TXAd_OPTIONS_CONTAINS
#define TXAd_OPTIONS_CONTAINS(options, value) (((options) & (value)) == (value))
#endif

#ifndef TXAd_CSTRING
#define TXAd_CSTRING(str) #str
#endif

#ifndef TXAd_NSSTRING
#define TXAd_NSSTRING(str) @(TXAd_CSTRING(str))
#endif

#ifndef TXAd_SEL_SPI
#define TXAd_SEL_SPI(name) NSSelectorFromString([NSString stringWithFormat:@"_%@", TXAd_NSSTRING(name)])
#endif

FOUNDATION_EXPORT os_log_t txad_getDefaultLog(void);

#ifndef TXAd_LOG
#define TXAd_LOG(_log, ...) if (@available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)) os_log(txad_getDefaultLog(), _log, ##__VA_ARGS__); \
else NSLog(@(_log), ##__VA_ARGS__);
#endif

#ifndef weakify
#define weakify(...) \
txad_keywordify \
metamacro_foreach_cxt(txad_weakify_,, __weak, __VA_ARGS__)
#endif

#ifndef strongify
#define strongify(...) \
txad_keywordify \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
metamacro_foreach(txad_strongify_,, __VA_ARGS__) \
_Pragma("clang diagnostic pop")
#endif

#define txad_weakify_(INDEX, CONTEXT, VAR) \
CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);

#define txad_strongify_(INDEX, VAR) \
__strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);

#if DEBUG
#define txad_keywordify autoreleasepool {}
#else
#define txad_keywordify try {} @catch (...) {}
#endif

#ifndef onExit
#define onExit \
txad_keywordify \
__strong txad_cleanupBlock_t metamacro_concat(txad_exitBlock_, __LINE__) __attribute__((cleanup(txad_executeCleanupBlock), unused)) = ^
#endif

typedef void (^txad_cleanupBlock_t)(void);

#if defined(__cplusplus)
extern "C" {
#endif
    void txad_executeCleanupBlock (__strong txad_cleanupBlock_t *block);
#if defined(__cplusplus)
}
#endif

/**
 * \@keypath allows compile-time verification of key paths. Given a real object
 * receiver and key path:
 *
 * @code

NSString *UTF8StringPath = @keypath(str.lowercaseString.UTF8String);
// => @"lowercaseString.UTF8String"

NSString *versionPath = @keypath(NSObject, version);
// => @"version"

NSString *lowercaseStringPath = @keypath(NSString.new, lowercaseString);
// => @"lowercaseString"

 * @endcode
 *
 * ... the macro returns an \c NSString containing all but the first path
 * component or argument (e.g., @"lowercaseString.UTF8String", @"version").
 *
 * In addition to simply creating a key path, this macro ensures that the key
 * path is valid at compile-time (causing a syntax error if not), and supports
 * refactoring, such that changing the name of the property will also update any
 * uses of \@keypath.
 */
#define keypath(...) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-repeated-use-of-weak\"") \
    (NO).boolValue ? ((NSString * _Nonnull)nil) : ((NSString * _Nonnull)@(cStringKeypath(__VA_ARGS__))) \
    _Pragma("clang diagnostic pop") \

#define cStringKeypath(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(keypath1(__VA_ARGS__))(keypath2(__VA_ARGS__))

#define keypath1(PATH) \
    (((void)(NO && ((void)PATH, NO)), \
    ({ char *__extobjckeypath__ = strchr(# PATH, '.'); NSCAssert(__extobjckeypath__, @"Provided key path is invalid."); __extobjckeypath__ + 1; })))

#define keypath2(OBJ, PATH) \
    (((void)(NO && ((void)OBJ.PATH, NO)), # PATH))

/**
 * \@collectionKeypath allows compile-time verification of key paths across collections NSArray/NSSet etc. Given a real object
 * receiver, collection object receiver and related keypaths:
 *
 * @code
 
 NSString *employeesFirstNamePath = @collectionKeypath(department.employees, Employee.new, firstName)
 // => @"employees.firstName"
 
 NSString *employeesFirstNamePath = @collectionKeypath(Department.new, employees, Employee.new, firstName)
 // => @"employees.firstName"

 * @endcode
 *
 */
#define collectionKeypath(...) \
    metamacro_if_eq(3, metamacro_argcount(__VA_ARGS__))(collectionKeypath3(__VA_ARGS__))(collectionKeypath4(__VA_ARGS__))

#define collectionKeypath3(PATH, COLLECTION_OBJECT, COLLECTION_PATH) \
    (YES).boolValue ? (NSString * _Nonnull)@((const char * _Nonnull)[[NSString stringWithFormat:@"%s.%s", cStringKeypath(PATH), cStringKeypath(COLLECTION_OBJECT, COLLECTION_PATH)] UTF8String]) : (NSString * _Nonnull)nil

#define collectionKeypath4(OBJ, PATH, COLLECTION_OBJECT, COLLECTION_PATH) \
    (YES).boolValue ? (NSString * _Nonnull)@((const char * _Nonnull)[[NSString stringWithFormat:@"%s.%s", cStringKeypath(OBJ, PATH), cStringKeypath(COLLECTION_OBJECT, COLLECTION_PATH)] UTF8String]) : (NSString * _Nonnull)nil
