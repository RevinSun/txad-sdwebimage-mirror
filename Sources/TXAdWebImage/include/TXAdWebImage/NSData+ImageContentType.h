/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXAdWebImageCompat.h"

/**
 You can use switch case like normal enum. It's also recommended to add a default case. You should not assume anything about the raw value.
 For custom coder plugin, it can also extern the enum for supported format. See `TXAdImageCoder` for more detailed information.
 */
typedef NSInteger TXAdImageFormat NS_TYPED_EXTENSIBLE_ENUM;
static const TXAdImageFormat TXAdImageFormatUndefined = -1;
static const TXAdImageFormat TXAdImageFormatJPEG      = 0;
static const TXAdImageFormat TXAdImageFormatPNG       = 1;
static const TXAdImageFormat TXAdImageFormatGIF       = 2;
static const TXAdImageFormat TXAdImageFormatTIFF      = 3;
static const TXAdImageFormat TXAdImageFormatWebP      = 4;
static const TXAdImageFormat TXAdImageFormatHEIC      = 5;
static const TXAdImageFormat TXAdImageFormatHEIF      = 6;
static const TXAdImageFormat TXAdImageFormatPDF       = 7;
static const TXAdImageFormat TXAdImageFormatSVG       = 8;
static const TXAdImageFormat TXAdImageFormatBMP       = 9;
static const TXAdImageFormat TXAdImageFormatRAW       = 10;

/**
 NSData category about the image content type and UTI.
 */
@interface NSData (ImageContentType)

/**
 *  Return image format
 *
 *  @param data the input image data
 *
 *  @return the image format as `TXAdImageFormat` (enum)
 */
+ (TXAdImageFormat)txad_imageFormatForImageData:(nullable NSData *)data;

/**
 *  Convert TXAdImageFormat to UTType
 *
 *  @param format Format as TXAdImageFormat
 *  @return The UTType as CFStringRef
 *  @note For unknown format, `kTXAdUTTypeImage` abstract type will return
 */
+ (nonnull CFStringRef)txad_UTTypeFromImageFormat:(TXAdImageFormat)format CF_RETURNS_NOT_RETAINED NS_SWIFT_NAME(txad_UTType(from:));

/**
 *  Convert UTType to TXAdImageFormat
 *
 *  @param uttype The UTType as CFStringRef
 *  @return The Format as TXAdImageFormat
 *  @note For unknown type, `TXAdImageFormatUndefined` will return
 */
+ (TXAdImageFormat)txad_imageFormatFromUTType:(nonnull CFStringRef)uttype;

@end
