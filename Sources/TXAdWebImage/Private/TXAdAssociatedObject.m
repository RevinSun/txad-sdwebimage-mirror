/*
* This file is part of the TXAdWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXAdAssociatedObject.h"
#import "UIImage+Metadata.h"
#import "UIImage+ExtendedCacheData.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+ForceDecode.h"

void TXAdImageCopyAssociatedObject(UIImage * _Nullable source, UIImage * _Nullable target) {
    if (!source || !target) {
        return;
    }
    // Image Metadata
    target.txad_isIncremental = source.txad_isIncremental;
    target.txad_isTransformed = source.txad_isTransformed;
    target.txad_decodeOptions = source.txad_decodeOptions;
    target.txad_imageLoopCount = source.txad_imageLoopCount;
    target.txad_imageFormat = source.txad_imageFormat;
    // Force Decode
    target.txad_isDecoded = source.txad_isDecoded;
    // Extended Cache Data
    target.txad_extendedObject = source.txad_extendedObject;
}
