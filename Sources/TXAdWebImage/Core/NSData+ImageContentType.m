/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSData+ImageContentType.h"
#if TXAd_MAC
#import <CoreServices/CoreServices.h>
#else
#import <MobileCoreServices/MobileCoreServices.h>
#endif
#import "TXAdImageIOAnimatedCoderInternal.h"

#define kSVGTagEnd @"</svg>"

@implementation NSData (ImageContentType)

+ (TXAdImageFormat)txad_imageFormatForImageData:(nullable NSData *)data {
    if (!data) {
        return TXAdImageFormatUndefined;
    }
    
    // File signatures table: http://www.garykessler.net/library/file_sigs.html
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return TXAdImageFormatJPEG;
        case 0x89:
            return TXAdImageFormatPNG;
        case 0x47:
            return TXAdImageFormatGIF;
        case 0x49:
        case 0x4D:
            return TXAdImageFormatTIFF;
        case 0x42:
            return TXAdImageFormatBMP;
        case 0x52: {
            if (data.length >= 12) {
                //RIFF....WEBP
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
                if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                    return TXAdImageFormatWebP;
                }
            }
            break;
        }
        case 0x00: {
            if (data.length >= 12) {
                //....ftypheic ....ftypheix ....ftyphevc ....ftyphevx
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(4, 8)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"ftypheic"]
                    || [testString isEqualToString:@"ftypheix"]
                    || [testString isEqualToString:@"ftyphevc"]
                    || [testString isEqualToString:@"ftyphevx"]) {
                    return TXAdImageFormatHEIC;
                }
                //....ftypmif1 ....ftypmsf1
                if ([testString isEqualToString:@"ftypmif1"] || [testString isEqualToString:@"ftypmsf1"]) {
                    return TXAdImageFormatHEIF;
                }
            }
            break;
        }
        case 0x25: {
            if (data.length >= 4) {
                //%PDF
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(1, 3)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"PDF"]) {
                    return TXAdImageFormatPDF;
                }
            }
            break;
        }
        case 0x3C: {
            // Check end with SVG tag
            if ([data rangeOfData:[kSVGTagEnd dataUsingEncoding:NSUTF8StringEncoding] options:NSDataSearchBackwards range: NSMakeRange(data.length - MIN(100, data.length), MIN(100, data.length))].location != NSNotFound) {
                return TXAdImageFormatSVG;
            }
            break;
        }
    }
    return TXAdImageFormatUndefined;
}

+ (nonnull CFStringRef)txad_UTTypeFromImageFormat:(TXAdImageFormat)format {
    CFStringRef UTType;
    switch (format) {
        case TXAdImageFormatJPEG:
            UTType = kTXAdUTTypeJPEG;
            break;
        case TXAdImageFormatPNG:
            UTType = kTXAdUTTypePNG;
            break;
        case TXAdImageFormatGIF:
            UTType = kTXAdUTTypeGIF;
            break;
        case TXAdImageFormatTIFF:
            UTType = kTXAdUTTypeTIFF;
            break;
        case TXAdImageFormatWebP:
            UTType = kTXAdUTTypeWebP;
            break;
        case TXAdImageFormatHEIC:
            UTType = kTXAdUTTypeHEIC;
            break;
        case TXAdImageFormatHEIF:
            UTType = kTXAdUTTypeHEIF;
            break;
        case TXAdImageFormatPDF:
            UTType = kTXAdUTTypePDF;
            break;
        case TXAdImageFormatSVG:
            UTType = kTXAdUTTypeSVG;
            break;
        case TXAdImageFormatBMP:
            UTType = kTXAdUTTypeBMP;
            break;
        case TXAdImageFormatRAW:
            UTType = kTXAdUTTypeRAW;
            break;
        default:
            // default is kUTTypeImage abstract type
            UTType = kTXAdUTTypeImage;
            break;
    }
    return UTType;
}

+ (TXAdImageFormat)txad_imageFormatFromUTType:(CFStringRef)uttype {
    if (!uttype) {
        return TXAdImageFormatUndefined;
    }
    TXAdImageFormat imageFormat;
    if (CFStringCompare(uttype, kTXAdUTTypeJPEG, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatJPEG;
    } else if (CFStringCompare(uttype, kTXAdUTTypePNG, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatPNG;
    } else if (CFStringCompare(uttype, kTXAdUTTypeGIF, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatGIF;
    } else if (CFStringCompare(uttype, kTXAdUTTypeTIFF, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatTIFF;
    } else if (CFStringCompare(uttype, kTXAdUTTypeWebP, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatWebP;
    } else if (CFStringCompare(uttype, kTXAdUTTypeHEIC, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatHEIC;
    } else if (CFStringCompare(uttype, kTXAdUTTypeHEIF, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatHEIF;
    } else if (CFStringCompare(uttype, kTXAdUTTypePDF, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatPDF;
    } else if (CFStringCompare(uttype, kTXAdUTTypeSVG, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatSVG;
    } else if (CFStringCompare(uttype, kTXAdUTTypeBMP, 0) == kCFCompareEqualTo) {
        imageFormat = TXAdImageFormatBMP;
    } else if (UTTypeConformsTo(uttype, kTXAdUTTypeRAW)) {
        imageFormat = TXAdImageFormatRAW;
    } else {
        imageFormat = TXAdImageFormatUndefined;
    }
    return imageFormat;
}

@end
