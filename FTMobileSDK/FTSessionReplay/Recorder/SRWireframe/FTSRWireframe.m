//
//  FTSRWireframe.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRWireframe.h"
#import <UIKit/UIKit.h>
#import "FTViewAttributes.h"
#import "FTTouchCircle.h"
#import "FTSRUtils.h"
@implementation FTSRShapeBorder
- (instancetype)initWithColor:(NSString *)color width:(CGFloat)width {
    if(!color && !width){
        return nil;
    }
    self = [super init];
    if(self){
        _color = color;
        _width = width;
    }
    return self;
}
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToShapeBorder:object];
}
-(BOOL)isEqualToShapeBorder:(FTSRShapeBorder *)object{
    BOOL haveEqualColor = (!self.color && !object.color) || [self.color isEqualToString:object.color];
    return  self.width == object.width && haveEqualColor;
}
@end
@implementation FTSRContentClip
-(instancetype)initWithLeft:(int)left top:(int)top right:(int)right bottom:(int)bottom{
    self = [super init];
    if(self){
        _left = left;
        _bottom = bottom;
        _right = right;
        _top = top;
    }
    return self;
}
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToContentClip:object];
}
-(BOOL)isEqualToContentClip:(FTSRContentClip *)object{
    return  self.bottom == object.bottom && self.top == object.top && self.left == object.left && self.right == object.right;
}
@end
@implementation FTSRShapeStyle

- (instancetype)initWithBackgroundColor:(NSString *)color cornerRadius:(NSNumber *)cornerRadius opacity:(NSNumber *)opacity {
    if(color == nil){
        return nil;
    }
    self = [super init];
    if(self){
        _backgroundColor = color;
        _cornerRadius = cornerRadius;
        _opacity = opacity;
    }
    return self;
}
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToShapeStyle:object];
}
-(BOOL)isEqualToShapeStyle:(FTSRShapeStyle *)object{
    BOOL haveEqualColor = (!self.backgroundColor && !object.backgroundColor) || [self.backgroundColor isEqualToString:object.backgroundColor];
    return  self.cornerRadius == object.cornerRadius && haveEqualColor && self.opacity == object.opacity;
}
@end
@implementation FTAlignment
- (instancetype)initWithTextAlignment:(NSTextAlignment)alignment horizontal:(NSString *)horizontal{
    self = [super init];
    if(self){
        if(!horizontal){
            _horizontal = @"center";
        }else{
            _horizontal = horizontal;
        }
        switch (alignment) {
            case NSTextAlignmentRight:
                _vertical = @"right";
                break;
            case NSTextAlignmentCenter:
                _vertical = @"center";
                break;
            case NSTextAlignmentLeft:
                _vertical = @"left";
            default:
                _vertical = @"left";
                break;
        }
    }
    return self;
}
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToAlignment:object];
}
-(BOOL)isEqualToAlignment:(FTAlignment *)object{
    BOOL haveEqualVertical = (!self.vertical && !object.vertical) || [self.vertical isEqualToString:object.vertical];
    BOOL haveEqualHorizontal = (!self.horizontal && !object.horizontal) || [self.horizontal isEqualToString:object.horizontal];
    return  haveEqualVertical &&  haveEqualHorizontal;
}
@end
@implementation FTSRTextPosition
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToTextPosition:object];
}
-(BOOL)isEqualToTextPosition:(FTSRTextPosition *)object{
    BOOL haveEqualAlignment = (!self.alignment && !object.alignment) || [self.alignment isEqual:object.alignment];
    BOOL haveEqualPadding = (!self.padding && !object.padding) || [self.padding isEqual:object.padding];
    return  haveEqualAlignment && haveEqualPadding;
}
@end
@implementation FTSRTextStyle
- (instancetype)initWithSize:(int)size color:(NSString *)color family:(NSString *)family{
    self = [super init];
    if(self){
        _size = size;
        _color = color;
        _family = family;
    }
    return self;
}
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToTextStyle:object];
}
-(BOOL)isEqualToTextStyle:(FTSRTextStyle *)object{
    BOOL haveEqualColor = (!self.color && !object.color) || [self.color isEqual:object.color];
    BOOL haveEqualFamily = (!self.family && !object.family) || [self.family isEqual:object.family];
    return  haveEqualColor && haveEqualFamily && self.size == object.size;
}
@end
@implementation FTSRWireframe
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame{
    self = [self init];
    if(self){
        self.identifier = identifier;
        self.width = @(frame.size.width);
        self.height = @(frame.size.height);
        self.x = @(CGRectGetMinX(frame));
        self.y = @(CGRectGetMinY(frame));
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame{
    self.identifier = self.identifier;
    self.clip = [self.clip isEqual:newWireFrame.clip]?nil:newWireFrame.clip;
    self.width = [self.width isEqualToNumber:newWireFrame.width]?nil:newWireFrame.width;
    self.height = [self.height isEqualToNumber:newWireFrame.height]?nil:newWireFrame.height;
    self.x = [self.x isEqualToNumber:newWireFrame.x]?nil:newWireFrame.x;
    self.y = [self.y isEqualToNumber:newWireFrame.y]?nil:newWireFrame.y;
    return self;
}
@end
@implementation FTSRShapeWireframe
-(instancetype)init{
    self = [super init];
    if(self){
        self.type = @"shape";
    }
    return self;
}
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame{
    return [self initWithIdentifier:identifier frame:frame attributes:nil];
}
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame backgroundColor:(NSString *)color cornerRadius:(NSNumber *)cornerRadius opacity:(NSNumber *)opacity{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"shape";
        _shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:color cornerRadius:cornerRadius opacity:opacity];
    }
    return self;
}
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame attributes:(FTViewAttributes *)attributes{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"shape";
        if (attributes){
            FTSRShapeBorder *border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:attributes.layerBorderColor]  width:attributes.layerBorderWidth];
            FTSRShapeStyle *backgroundStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:attributes.backgroundColor] cornerRadius:@(attributes.layerCornerRadius) opacity:@(attributes.alpha)];
            self.border = border;
            self.shapeStyle = backgroundStyle;
        }
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame{
    if (self == newWireFrame){
        return nil;
    }
    if (![newWireFrame isKindOfClass:FTSRShapeWireframe.class]){
        return nil;
    }
    if(self.identifier != newWireFrame.identifier){
        return nil;
    }
    FTSRWireframe *wire = [super compareWithNewWireFrame:newWireFrame];
    FTSRShapeWireframe *snapWireframe = (FTSRShapeWireframe *)wire;
    FTSRShapeWireframe *newWire = (FTSRShapeWireframe *)newWireFrame;
    snapWireframe.border = [self.border isEqual:newWire.border]?nil:newWire.border;
    snapWireframe.shapeStyle = [self.shapeStyle isEqual:newWire.shapeStyle]?nil:newWire.shapeStyle;
    return snapWireframe;
}
@end
@implementation FTSRTextWireframe
-(instancetype)init{
    self = [super init];
    if(self){
        self.type = @"text";
    }
    return self;
}
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"text";
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame{
    if (self == newWireFrame){
        return nil;
    }
    if (![newWireFrame isKindOfClass:FTSRTextWireframe.class]){
        return nil;
    }
    if(self.identifier != newWireFrame.identifier){
        return nil;
    }
    FTSRWireframe *wire = [super compareWithNewWireFrame:newWireFrame];
    FTSRTextWireframe *textWireframe = (FTSRTextWireframe *)wire;
    FTSRTextWireframe *newWire = (FTSRTextWireframe *)newWireFrame;
    textWireframe.text = [self.text isEqualToString:newWire.text]?nil:newWire.text;
    textWireframe.textPosition = [self.textPosition isEqual:newWire.textPosition]?nil:newWire.textPosition;
    textWireframe.textStyle = [self.textStyle isEqual:newWire.textStyle]?nil:newWire.textStyle;
    textWireframe.border = [self.border isEqual:newWire.border]?nil:newWire.border;
    textWireframe.shapeStyle = [self.shapeStyle isEqual:newWire.shapeStyle]?nil:newWire.shapeStyle;
    return textWireframe;
}
@end
@implementation FTSRImageWireframe
-(instancetype)init{
    self = [super init];
    if(self){
        self.type = @"image";
    }
    return self;
}
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame {
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"image";
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame{
    if (self == newWireFrame){
        return nil;
    }
    if (![newWireFrame isKindOfClass:FTSRImageWireframe.class]){
        return nil;
    }
    if(self.identifier != newWireFrame.identifier){
        return nil;
    }
    FTSRWireframe *wire = [super compareWithNewWireFrame:newWireFrame];
    FTSRImageWireframe *imageWireframe = (FTSRImageWireframe *)wire;
    FTSRImageWireframe *newWire = (FTSRImageWireframe *)newWireFrame;
    imageWireframe.mimeType = [self.mimeType isEqualToString:newWire.mimeType]?nil:newWire.mimeType;
    imageWireframe.base64 = [self.base64 isEqualToString:newWire.base64]?nil:newWire.base64;
    imageWireframe.border = [self.border isEqual:newWire.border]?nil:newWire.border;
    imageWireframe.shapeStyle = [self.shapeStyle isEqual:newWire.shapeStyle]?nil:newWire.shapeStyle;
    return imageWireframe;
}
@end
@implementation FTSRPlaceholderWireframe
-(instancetype)init{
    self = [super init];
    if(self){
        self.type = @"placeholder";
    }
    return self;
}
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame{
    return [self initWithIdentifier:identifier frame:frame label:nil];
}
- (instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame label:(NSString *)label{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"placeholder";
        _label = label;
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame{
    if (self == newWireFrame){
        return nil;
    }
    if (![newWireFrame isKindOfClass:FTSRPlaceholderWireframe.class]){
        return nil;
    }
    if(self.identifier != newWireFrame.identifier){
        return nil;
    }
    FTSRWireframe *wire = [super compareWithNewWireFrame:newWireFrame];
    FTSRPlaceholderWireframe *placeholder = (FTSRPlaceholderWireframe *)wire;
    FTSRPlaceholderWireframe *newWire = (FTSRPlaceholderWireframe *)newWireFrame;
    placeholder.label = [self.label isEqualToString:newWire.label]?nil:newWire.label;
    return placeholder;
}
@end
