/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageCacheConfig.h"
#import "TXAdMemoryCache.h"
#import "TXAdDiskCache.h"

static TXAdImageCacheConfig *_defaultCacheConfig;
static const NSInteger kDefaultCacheMaxDiskAge = 60 * 60 * 24 * 7; // 1 week

@implementation TXAdImageCacheConfig

+ (TXAdImageCacheConfig *)defaultCacheConfig {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultCacheConfig = [TXAdImageCacheConfig new];
    });
    return _defaultCacheConfig;
}

- (instancetype)init {
    if (self = [super init]) {
        _shouldDisableiCloud = YES;
        _shouldCacheImagesInMemory = YES;
        _shouldUseWeakMemoryCache = NO;
        _shouldRemoveExpiredDataWhenEnterBackground = YES;
        _shouldRemoveExpiredDataWhenTerminate = YES;
        _diskCacheReadingOptions = 0;
        _diskCacheWritingOptions = NSDataWritingAtomic;
        _maxDiskAge = kDefaultCacheMaxDiskAge;
        _maxDiskSize = 0;
        _diskCacheExpireType = TXAdImageCacheConfigExpireTypeModificationDate;
        _fileManager = nil;
        if (@available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)) {
            _ioQueueAttributes = DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL; // DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM
        } else {
            _ioQueueAttributes = DISPATCH_QUEUE_SERIAL; // NULL
        }
        _memoryCacheClass = [TXAdMemoryCache class];
        _diskCacheClass = [TXAdDiskCache class];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    TXAdImageCacheConfig *config = [[[self class] allocWithZone:zone] init];
    config.shouldDisableiCloud = self.shouldDisableiCloud;
    config.shouldCacheImagesInMemory = self.shouldCacheImagesInMemory;
    config.shouldUseWeakMemoryCache = self.shouldUseWeakMemoryCache;
    config.shouldRemoveExpiredDataWhenEnterBackground = self.shouldRemoveExpiredDataWhenEnterBackground;
    config.shouldRemoveExpiredDataWhenTerminate = self.shouldRemoveExpiredDataWhenTerminate;
    config.diskCacheReadingOptions = self.diskCacheReadingOptions;
    config.diskCacheWritingOptions = self.diskCacheWritingOptions;
    config.maxDiskAge = self.maxDiskAge;
    config.maxDiskSize = self.maxDiskSize;
    config.maxMemoryCost = self.maxMemoryCost;
    config.maxMemoryCount = self.maxMemoryCount;
    config.diskCacheExpireType = self.diskCacheExpireType;
    config.fileManager = self.fileManager; // NSFileManager does not conform to NSCopying, just pass the reference
    config.ioQueueAttributes = self.ioQueueAttributes; // Pass the reference
    config.memoryCacheClass = self.memoryCacheClass;
    config.diskCacheClass = self.diskCacheClass;
    
    return config;
}

@end
