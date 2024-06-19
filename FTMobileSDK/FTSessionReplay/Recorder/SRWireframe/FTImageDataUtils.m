//
//  FTImageDataUtils.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTImageDataUtils.h"
#import "NSData+FTHelper.h"
@interface FTImageDataUtils()
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, assign) NSUInteger desiredMaxBytesSize;
@end
@implementation FTImageDataUtils
-(instancetype)init{
    self = [super init];
    if(self){
        _imageCache = [[NSCache alloc]init];
        _desiredMaxBytesSize = 10 * 1024;
    }
    return self;
}
- (NSString *)imageContentBase64String:(UIImage *)image{
    return [self imageContentBase64String:image tintColor:nil];
}
- (NSString *)imageContentBase64String:(UIImage *)image tintColor:(nullable UIColor *)color{
    @autoreleasepool {
        if(image == nil){
            return @"";
        }
        NSString *identifier = [@(image.hash) stringValue];
        if(color != nil){
            identifier = [identifier stringByAppendingFormat:@"%lu",(unsigned long)color.hash];
        }
        NSString *imageStr = [self.imageCache valueForKey:identifier];
        if(!imageStr){
            if (@available(iOS 13.0, *)) {
                if (image.isSymbolImage) {
                    image = [image imageWithTintColor:color];
                }
            }
            NSData *imageData = [self smartCompress:image];
            imageStr = imageData.ft_imageDataToSting;
            [self.imageCache setObject:imageStr forKey:identifier];
        }
        return imageStr;
    }
}
- (NSData *)smartCompress:(UIImage *)image{
    NSData *compressData = UIImagePNGRepresentation(image);
    if (compressData.length < self.desiredMaxBytesSize) {
        return compressData;
    }
    double scale = sqrt(compressData.length / self.desiredMaxBytesSize);
    CGSize size = CGSizeMake(image.size.width*scale, image.size.height*scale);
    UIGraphicsBeginImageContext(size);
    UIImage *scaleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    compressData = UIImagePNGRepresentation(scaleImage);
    if(compressData.length < self.desiredMaxBytesSize){
        return compressData;
    }
    CGFloat compressionQuality = 1;
    CGFloat max = 1;
    CGFloat min = 0;
    for (int i=0;i<6;i++) {
        compressionQuality = (max + min) * 0.5;
        compressData = UIImageJPEGRepresentation(scaleImage, compressionQuality);
        if(compressData.length < self.desiredMaxBytesSize * 0.9){
            min = compressionQuality;
        }else if (compressData.length > self.desiredMaxBytesSize){
            max = compressionQuality;
        }else{
            break;
        }
    }
    return compressData;
}
@end
