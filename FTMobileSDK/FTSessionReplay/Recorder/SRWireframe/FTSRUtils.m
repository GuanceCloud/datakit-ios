//
//  FTSRUtils.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/8.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRUtils.h"
CGRect FTCGRectScaleAspectFitRect(CGSize size,CGSize contentSize){
    CGFloat imageAspectRatio = contentSize.height / contentSize.width;
    CGFloat x, y, width, height;
    CGFloat aspectRatio = size.width > 0 ? size.height / size.width : 0;
    if (imageAspectRatio > aspectRatio) {
        height = size.height;
        width = height / imageAspectRatio;
        x = (size.width / 2) - (width / 2);
        y = 0;
    } else {
        width = size.width;
        height = width * imageAspectRatio;
        x = 0;
        y = (size.height / 2) - (height / 2);
    }
    return CGRectMake(x, y, width, height);
}
CGRect FTCGRectScaleAspectFillRect(CGSize size,CGSize contentSize){
    CGFloat scale;
    if ((contentSize.width - size.width) < (contentSize.height - size.height)) {
        scale = size.width / contentSize.width;
    } else {
        scale = size.height / contentSize.height;
    }
    CGSize rSize = CGSizeMake(contentSize.width * scale, contentSize.height * scale);
    return CGRectMake(
                      (size.width - rSize.width) / 2,
                      (size.height - rSize.height) / 2,
                      rSize.width,
                      rSize.height
                      );
}
CGRect FTCGRectFitWithContentMode(CGRect rect, CGSize contentSize, UIViewContentMode mode) {
    if(rect.size.width>0&&rect.size.height>0&&contentSize.width>0&&contentSize.height>0){
        switch (mode) {
            case UIViewContentModeScaleAspectFit:{
                CGRect actualContentRect = FTCGRectScaleAspectFitRect(rect.size, contentSize);
                return CGRectMake(rect.origin.x+actualContentRect.origin.x,
                                  rect.origin.y+actualContentRect.origin.y,
                                  actualContentRect.size.width,
                                  actualContentRect.size.width);
            }
            case UIViewContentModeScaleAspectFill:
            {
                CGRect actualContentRect = FTCGRectScaleAspectFillRect(rect.size, contentSize);
                return CGRectMake(rect.origin.x+actualContentRect.origin.x,
                                  rect.origin.y+actualContentRect.origin.y,
                                  actualContentRect.size.width,
                                  actualContentRect.size.width);
            }
            case UIViewContentModeRedraw:
            case UIViewContentModeCenter: {
                return CGRectMake(rect.origin.x + (rect.size.width - contentSize.width) / 2,
                                  rect.origin.y + (rect.size.height - contentSize.height) / 2,
                                  contentSize.width,
                                  contentSize.height);
            }
            case UIViewContentModeTop: {
                CGRectMake(rect.origin.x + (rect.size.width - contentSize.width) / 2,
                           rect.origin.y,
                           contentSize.width,
                           contentSize.height
                           );
            }
            case UIViewContentModeBottom: {
                CGRectMake(rect.origin.x + (rect.size.width - contentSize.width) / 2,
                           rect.origin.y + (rect.size.height - contentSize.height),
                           contentSize.width,
                           contentSize.height
                           );
            }
            case UIViewContentModeLeft: {
                return CGRectMake(rect.origin.x,
                                  rect.origin.y + (rect.size.height - contentSize.height) / 2,
                                  contentSize.width,
                                  contentSize.height);
                
            }
            case UIViewContentModeRight: {
                return CGRectMake(rect.origin.x + (rect.size.width - contentSize.width),
                                  rect.origin.y + (rect.size.height - contentSize.height) / 2,
                                  contentSize.width,
                                  contentSize.height);
            }
            case UIViewContentModeTopLeft: {
                return CGRectMake(rect.origin.x,
                                  rect.origin.y,
                                  contentSize.width,
                                  contentSize.height
                                  );
            }
            case UIViewContentModeTopRight: {
                return CGRectMake(rect.origin.x + (rect.size.width - contentSize.width),
                                   rect.origin.y,
                                   contentSize.width,
                                   contentSize.height
                                   );
            }
            case UIViewContentModeBottomLeft: {
                return CGRectMake(rect.origin.x,
                                  rect.origin.y+(rect.size.height - contentSize.height),
                                  contentSize.width,
                                  contentSize.height);
            }
            case UIViewContentModeBottomRight: {
                return CGRectMake(rect.origin.x+(rect.size.width - contentSize.width),
                                  rect.origin.y+(rect.size.height - contentSize.height),
                                  contentSize.width,
                                  contentSize.height);
            }
            case UIViewContentModeScaleToFill:
            default: {
                return rect;
            }
        }
    }
    return CGRectZero;
}
CGRect FTCGRectPutInside(CGRect oriRect, CGRect inRect, HorizontalAlignment horizontal,VerticalAlignment vertical){
    CGRect new = oriRect;
    switch (horizontal) {
        case HorizontalAlignmentLeft:
            new.origin.x = CGRectGetMinX(inRect);
            break;
        case HorizontalAlignmentRight:
            new.origin.x = CGRectGetMaxX(inRect) - new.size.width;
            break;
        case HorizontalAlignmentCenter:
            new.origin.x = CGRectGetMinX(inRect) + (inRect.size.width-new.size.width)*0.5;
            break;
    }
    
    switch (vertical) {
        case VerticalAlignmentTop:
            new.origin.y = CGRectGetMinY(inRect);
            break;
        case VerticalAlignmentBottom:
            new.origin.y = CGRectGetMaxY(inRect) - new.size.height;
            break;
        case VerticalAlignmentMiddle:
            new.origin.y = CGRectGetMinY(inRect) + (inRect.size.height - new.size.height)*0.5;
            break;
    }
    return new;
}
CGFloat FTCGSizeAspectRatio(CGSize size){
    if(size.width > 0){
        return size.height / size.width;
    }
    return 0;
    
}

@implementation FTSRUtils
+ (NSString *)colorHexString:(CGColorRef)color {
    if(color == nil){
        return nil;
    }
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    static NSString *stringFormat = @"%02X%02X%02X";
    NSString *hex = nil;
    if (count == 2) {
        NSUInteger white = roundf(components[0] * 255.0f);
        hex = [NSString stringWithFormat:stringFormat, white, white, white];
    } else if (count == 4) {
        hex = [NSString stringWithFormat:stringFormat,
               (NSUInteger)roundf(components[0] * 255.0f),
               (NSUInteger)roundf(components[1] * 255.0f),
               (NSUInteger)roundf(components[2] * 255.0f)];
    }
    if (hex) {
        CGFloat alpha = CGColorGetAlpha(color);
        hex = [hex stringByAppendingFormat:@"%02lX",
               (unsigned long)(alpha * 255.0 + 0.5)];
    }
    return [NSString stringWithFormat:@"#%@",hex];;
}
+ (BOOL)isSensitiveText:(id<UITextInputTraits>)textInputTraits{
    if (textInputTraits.isSecureTextEntry) {
        return YES;
    }
    UITextContentType contentType = textInputTraits.textContentType;
    if(contentType&&contentType.length>0){
        static NSSet *sensitiveContentTypes = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet * mutableSet  = [[NSMutableSet alloc]initWithArray:@[
                UITextContentTypeEmailAddress,
                UITextContentTypeTelephoneNumber,
                UITextContentTypeAddressCity,
                UITextContentTypeAddressState,
                UITextContentTypeAddressCityAndState,
                UITextContentTypeFullStreetAddress,
                UITextContentTypeStreetAddressLine1,
                UITextContentTypeStreetAddressLine2,
                UITextContentTypePostalCode,
                UITextContentTypeCreditCardNumber,
            ]];
            if (@available(iOS 11.0, *)) {
                [mutableSet addObject:UITextContentTypePassword];
            }
            if (@available(iOS 12.0, *)) {
                [mutableSet addObject:UITextContentTypeNewPassword];
                [mutableSet addObject:UITextContentTypeOneTimeCode];
            }
            sensitiveContentTypes = mutableSet;
        });
        return [sensitiveContentTypes containsObject:contentType];
    }
    return NO;
}
+ (nullable CGColorRef)safeCast:(CGColorRef)cgColor{
    if(cgColor == nil){
        return nil;
    }
    if(CFGetTypeID(cgColor) == CGColorGetTypeID()){
        return cgColor;
    }
    return nil;
}
+ (CGFloat)getCGColorAlpha:(CGColorRef)color{
    if(color == nil){
        return 0;
    }
    size_t count = CGColorGetNumberOfComponents(color);
    if (count==4||count==2){
        return CGColorGetAlpha(color);
    }
    return 0;
}
@end
