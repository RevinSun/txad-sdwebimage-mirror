/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdImageFrame.h"

@interface TXAdImageFrame ()

@property (nonatomic, strong, readwrite, nonnull) UIImage *image;
@property (nonatomic, readwrite, assign) NSTimeInterval duration;

@end

@implementation TXAdImageFrame

- (instancetype)initWithImage:(UIImage *)image duration:(NSTimeInterval)duration {
    self = [super init];
    if (self) {
        _image = image;
        _duration = duration;
    }
    return self;
}

+ (instancetype)frameWithImage:(UIImage *)image duration:(NSTimeInterval)duration {
    TXAdImageFrame *frame = [[TXAdImageFrame alloc] initWithImage:image duration:duration];
    return frame;
}

@end
