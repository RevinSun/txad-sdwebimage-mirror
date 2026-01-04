/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXAdWebImageDownloaderDecryptor.h"

@interface TXAdWebImageDownloaderDecryptor ()

@property (nonatomic, copy, nonnull) TXAdWebImageDownloaderDecryptorBlock block;

@end

@implementation TXAdWebImageDownloaderDecryptor

- (instancetype)initWithBlock:(TXAdWebImageDownloaderDecryptorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)decryptorWithBlock:(TXAdWebImageDownloaderDecryptorBlock)block {
    TXAdWebImageDownloaderDecryptor *decryptor = [[TXAdWebImageDownloaderDecryptor alloc] initWithBlock:block];
    return decryptor;
}

- (nullable NSData *)decryptedDataWithData:(nonnull NSData *)data response:(nullable NSURLResponse *)response {
    if (!self.block) {
        return nil;
    }
    return self.block(data, response);
}

@end

@implementation TXAdWebImageDownloaderDecryptor (Conveniences)

+ (TXAdWebImageDownloaderDecryptor *)base64Decryptor {
    static TXAdWebImageDownloaderDecryptor *decryptor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        decryptor = [TXAdWebImageDownloaderDecryptor decryptorWithBlock:^NSData * _Nullable(NSData * _Nonnull data, NSURLResponse * _Nullable response) {
            NSData *modifiedData = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
            return modifiedData;
        }];
    });
    return decryptor;
}

@end
