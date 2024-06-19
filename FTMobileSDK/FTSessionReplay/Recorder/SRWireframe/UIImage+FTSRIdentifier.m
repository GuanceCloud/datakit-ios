//
//  UIImage+FTSRIdentifier.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "UIImage+FTSRIdentifier.h"
#import <objc/runtime.h>
#import "NSData+FTHelper.h"

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
    NSString *newHash = [self ft_computeHash];
    self.srIdentifier = newHash;
    return newHash;
}
- (NSString *)ft_computeHash{
    NSData *imageData = UIImagePNGRepresentation(self);
    if(imageData&&imageData.length>0){
        return [imageData ft_md5HashChecksum];
    }
    return @"";
}
- (NSData *)ft_scaledDownToApproximateSize:(NSUInteger)maxSize tintColor:(UIColor *)tintColor{
    NSData *compressData = UIImagePNGRepresentation(self);
    if (compressData.length < maxSize && tintColor == nil) {
        return compressData;
    }
    double scale = MIN(1,sqrt(maxSize/compressData.length));
    
    UIImage *scaleImage = [self ft_scaledImage:scale tint:tintColor];
    compressData = UIImagePNGRepresentation(scaleImage);
    if(compressData.length < maxSize){
        return compressData;
    }
    CGFloat compressionQuality = 1;
    CGFloat max = 1;
    CGFloat min = 0;
    for (int i=0;i<6;i++) {
        compressionQuality = (max + min) * 0.5;
        compressData = UIImageJPEGRepresentation(scaleImage, compressionQuality);
        if(compressData.length < maxSize * 0.9){
            min = compressionQuality;
        }else if (compressData.length > maxSize){
            max = compressionQuality;
        }else{
            break;
        }
    }
    return compressData;
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
