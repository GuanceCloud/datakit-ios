//
//  UIImage+FTSRIdentifier.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "UIImage+FTSRIdentifier.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

static int bitsPerComponent = 8;
static char *srIdentifierKey = "FTSRIdentifierKey";

@implementation UIImage (FTSRIdentify)
-(void)setSrIdentifier:(NSString *)srIdentifier{
    objc_setAssociatedObject(self, &srIdentifierKey, srIdentifier, OBJC_ASSOCIATION_RETAIN);
}
- (NSString *)srIdentifier{
    NSString *hash = objc_getAssociatedObject(self, &srIdentifierKey);
    if(hash && hash.length>0){
        return hash;
    }
    NSString *newHash = [self ft_md5Digest] ?: [NSString stringWithFormat:@"%lu", (unsigned long)self.hash];
    self.srIdentifier = newHash;
    return newHash;
}
- (NSString *)ft_md5Digest {
    CGImageRef cgImage = self.CGImage;
    if (!cgImage) {
        return nil;
    }

    // original size
    CGSize size = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
    
    CGFloat ratio = MAX(1, MAX(size.width / 100.0, size.height / 100.0));
    
    CGRect rect = CGRectMake(
        0,
        0,
        size.width / ratio,
        size.height / ratio
    );

    // create grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault;
    CGContextRef context = CGBitmapContextCreate(
        NULL,
        rect.size.width,
        rect.size.height,
        bitsPerComponent,
        0,
        colorSpace,
        bitmapInfo
    );

    CGColorSpaceRelease(colorSpace);

    if (!context) {
        return nil;
    }

    // low quality interpolation
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    // draw image
    CGContextDrawImage(context, rect, cgImage);

    void *rawData = CGBitmapContextGetData(context);
    if (!rawData) {
        CGContextRelease(context);
        return nil;
    }

    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(context);
    size_t height = CGBitmapContextGetHeight(context);
    size_t length = bytesPerRow * height;

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(rawData, (CC_LONG)length, digest);

    CGContextRelease(context);
    // convert digest to hex string
    NSMutableString *md5String = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x", digest[i]];
    }

    return md5String;
}

- (NSData *)ft_pngDataWithTintColor:(UIColor *)tintColor{
    return [self ft_scaledDownToApproximateSize:CGSizeMake(1000, 1000) tintColor:tintColor];
}

- (NSData *)ft_scaledDownToApproximateSize:(CGSize)maxSize tintColor:(UIColor *)tintColor{
    CGFloat ratio = MAX(1.0, MAX(self.size.width / maxSize.width, self.size.height / maxSize.height));
    if (tintColor == nil && ratio <= 1) {
        return UIImagePNGRepresentation(self);
    }
    CGSize scaledSize = CGSizeMake(self.size.width / ratio, self.size.height / ratio);
    CGRect drawRect = CGRectZero;
    drawRect.size = scaledSize;
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:scaledSize];
    NSData *pngData = [renderer PNGDataWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        if (tintColor) {
            [tintColor setFill];
            UIRectFill(drawRect);
        }
        
        [self drawInRect:drawRect blendMode:kCGBlendModeDestinationIn alpha:1.0];
    }];
    
    return pngData;
}
- (UIImage *)ft_scaledImage:(CGFloat)scale tint:(UIColor *)tint{
    CGSize size = CGSizeMake(self.size.width*scale, self.size.height*scale);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGRect drawRect = CGRectMake(0, 0, size.width, size.height);
    if(tint){
        [tint setFill];
        UIRectFill(drawRect);
    }
    [self drawInRect:drawRect blendMode:kCGBlendModeSourceIn alpha:1.0];
    UIImage *scaleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaleImage;
}
@end
