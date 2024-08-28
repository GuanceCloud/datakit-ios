//
//  FTSRUtils.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/8.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRUtils.h"

CGRect FTCGRectFitWithContentMode(CGRect rect, CGSize size, UIViewContentMode mode) {
    rect = CGRectStandardize(rect);
    size.width = size.width < 0 ? -size.width : size.width;
    size.height = size.height < 0 ? -size.height : size.height;
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    switch (mode) {
        case UIViewContentModeScaleAspectFit:
        case UIViewContentModeScaleAspectFill: {
            if (rect.size.width < 0.01 || rect.size.height < 0.01 ||
                size.width < 0.01 || size.height < 0.01) {
                rect.origin = center;
                rect.size = CGSizeZero;
            } else {
                CGFloat scale;
                if (mode == UIViewContentModeScaleAspectFit) {
                    if (size.width / size.height < rect.size.width / rect.size.height) {
                        scale = rect.size.height / size.height;
                    } else {
                        scale = rect.size.width / size.width;
                    }
                } else {
                    if (size.width / size.height < rect.size.width / rect.size.height) {
                        scale = rect.size.width / size.width;
                    } else {
                        scale = rect.size.height / size.height;
                    }
                }
                size.width *= scale;
                size.height *= scale;
                rect.size = size;
                rect.origin = CGPointMake(center.x - size.width * 0.5, center.y - size.height * 0.5);
            }
        } break;
        case UIViewContentModeCenter: {
            rect.size = size;
            rect.origin = CGPointMake(center.x - size.width * 0.5, center.y - size.height * 0.5);
        } break;
        case UIViewContentModeTop: {
            rect.origin.x = center.x - size.width * 0.5;
            rect.size = size;
        } break;
        case UIViewContentModeBottom: {
            rect.origin.x = center.x - size.width * 0.5;
            rect.origin.y += rect.size.height - size.height;
            rect.size = size;
        } break;
        case UIViewContentModeLeft: {
            rect.origin.y = center.y - size.height * 0.5;
            rect.size = size;
        } break;
        case UIViewContentModeRight: {
            rect.origin.y = center.y - size.height * 0.5;
            rect.origin.x += rect.size.width - size.width;
            rect.size = size;
        } break;
        case UIViewContentModeTopLeft: {
            rect.size = size;
        } break;
        case UIViewContentModeTopRight: {
            rect.origin.x += rect.size.width - size.width;
            rect.size = size;
        } break;
        case UIViewContentModeBottomLeft: {
            rect.origin.y += rect.size.height - size.height;
            rect.size = size;
        } break;
        case UIViewContentModeBottomRight: {
            rect.origin.x += rect.size.width - size.width;
            rect.origin.y += rect.size.height - size.height;
            rect.size = size;
        } break;
        case UIViewContentModeScaleToFill:
        case UIViewContentModeRedraw:
        default: {
            rect = rect;
        }
    }
    return rect;
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
        CGFloat alpha = CGColorGetAlpha(color);;
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
@end
