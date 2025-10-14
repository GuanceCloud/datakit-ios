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
#import "FTSRUtils.h"
#import "FTTouchSnapshot.h"

NSString * const FT_DEFAULT_COLOR = @"#FF0000FF";
CGFloat  const FT_DEFAULT_FONT_SIZE = 10;
NSString * const FT_DEFAULT_FONT_FAMILY = @"-apple-system, BlinkMacSystemFont, 'Roboto', sans-serif";
static FTSRContentClip * useNewClipIfDifferentThanOld(FTSRContentClip *new,FTSRContentClip *old){
    if (!old) return new;
    if ([old isEqual:new]) return nil;
    
    FTSRContentClip *clip = [[FTSRContentClip alloc]init];
    clip.top = (new.top == nil && old.top != nil) ? @(0) : new.top;
    clip.bottom = (new.bottom == nil && old.bottom != nil) ? @(0) : new.bottom;
    clip.left = (new.left == nil && old.left != nil) ? @(0) : new.left;
    clip.right = (new.right == nil && old.right != nil) ? @(0) : new.right;
    return clip;
}
static id useNewObjectIfDifferentThanOld(id new, id old){
    return [new isEqual:old] ? nil : new;
}
static BOOL objectIsEqual(id new,id old){
    return (new == nil && old == nil) || [new isEqual:old];
}
@implementation FTSRShapeBorder
- (instancetype)initWithColor:(NSString *)color width:(CGFloat)width {
    if(!color || width<=0){
        return nil;
    }
    self = [super init];
    if(self){
        _color = color;
        _width = width;
    }
    return self;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTSRShapeBorder *object = (FTSRShapeBorder *)baseFrame;
    BOOL haveEqualColor = objectIsEqual(self.color,object.color);
    return  self.width == object.width && haveEqualColor;
}
@end
@implementation FTSRContentClip
-(instancetype)initWithFrame:(CGRect)frame clip:(CGRect)clip{
    self = [super init];
    if(self){
        CGRect intersection = CGRectIntersection(frame, clip);
        if (CGRectIsEmpty(intersection)) {
            _bottom = nil;
            _left = @(roundf(frame.size.width));
            _right = nil;
            _top = @(roundf(frame.size.height));
        }else{
            CGFloat top = CGRectGetMinY(intersection) - CGRectGetMinY(frame);
            CGFloat left = CGRectGetMinX(intersection) - CGRectGetMinX(frame);
            CGFloat bottom = CGRectGetMaxY(frame) - CGRectGetMaxY(intersection);
            CGFloat right = CGRectGetMaxX(frame) - CGRectGetMaxX(intersection);
            if(top == 0 && left == 0 && bottom == 0 && right == 0){
                return nil;
            }
            _bottom = bottom==0?nil:@(roundf(bottom));
            _left = left==0?nil:@(roundf(left));
            _top = top==0?nil:@(roundf(top));
            _right = right==0?nil:@(roundf(right));
        }
    }
    return self;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTSRContentClip *object = (FTSRContentClip *)baseFrame;
    BOOL haveEqualLeft = objectIsEqual(self.left,object.left);
    BOOL haveEqualTop = objectIsEqual(self.top,object.top);
    BOOL haveEqualRight = objectIsEqual(self.right,object.right);
    BOOL haveEqualBottom = objectIsEqual(self.bottom,object.bottom);
    return haveEqualLeft && haveEqualTop && haveEqualRight && haveEqualBottom;
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
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTSRShapeStyle *object = (FTSRShapeStyle *)baseFrame;
    BOOL haveEqualColor = objectIsEqual(self.backgroundColor,object.backgroundColor);
    BOOL haveEqualCornerRadius = objectIsEqual(self.cornerRadius,object.cornerRadius);
    BOOL haveEqualOpacity = objectIsEqual(self.opacity,object.opacity);
    return  haveEqualCornerRadius && haveEqualColor && haveEqualOpacity;
}
@end
@implementation FTPadding

-(instancetype)initWithLeft:(float)left top:(float)top right:(float)right bottom:(float)bottom{
    self = [super init];
    if(self){
        _left = @(roundf(left));
        _bottom = @(roundf(bottom));
        _right = @(roundf(right));
        _top = @(roundf(top));
    }
    return self;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTPadding *object = (FTPadding *)baseFrame;
    BOOL haveEqualLeft = objectIsEqual(self.left,object.left);
    BOOL haveEqualTop = objectIsEqual(self.top,object.top);
    BOOL haveEqualRight = objectIsEqual(self.right,object.right);
    BOOL haveEqualBottom = objectIsEqual(self.bottom,object.bottom);
    return haveEqualLeft && haveEqualTop && haveEqualRight && haveEqualBottom;
}
@end
@implementation FTAlignment
- (instancetype)initWithTextAlignment:(NSTextAlignment)alignment vertical:(NSString *)vertical{
    self = [super init];
    if(self){
        if(!vertical){
            _vertical = @"center";
        }else{
            _vertical = vertical;
        }
        switch (alignment) {
            case NSTextAlignmentRight:
                _horizontal = @"right";
                break;
            case NSTextAlignmentCenter:
                _horizontal = @"center";
                break;
            case NSTextAlignmentLeft:
                _horizontal = @"left";
            default:
                _horizontal = @"left";
                break;
        }
    }
    return self;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTAlignment *object = (FTAlignment *)baseFrame;
    BOOL haveEqualVertical = objectIsEqual(self.vertical,object.vertical);
    BOOL haveEqualHorizontal = objectIsEqual(self.horizontal,object.horizontal);
    return  haveEqualVertical &&  haveEqualHorizontal;
}
@end
@implementation FTSRTextPosition
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTSRTextPosition *object = (FTSRTextPosition *)baseFrame;
    BOOL haveEqualAlignment = objectIsEqual(self.alignment,object.alignment);
    BOOL haveEqualPadding = objectIsEqual(self.padding,object.padding);
    return  haveEqualAlignment && haveEqualPadding;
}
@end
@implementation FTSRTextStyle
- (instancetype)initWithSize:(int)size color:(NSString *)color family:(NSString *)family{
    self = [super init];
    if(self){
        _size = size?:FT_DEFAULT_FONT_SIZE;
        _color = color?:FT_DEFAULT_COLOR;
        _family = family?:FT_DEFAULT_FONT_FAMILY;
    }
    return self;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTSRTextStyle *object = (FTSRTextStyle *)baseFrame;
    BOOL haveEqualColor = objectIsEqual(self.color,object.color);
    BOOL haveEqualFamily = objectIsEqual(self.family,object.family);
    return  haveEqualColor && haveEqualFamily && self.size == object.size;
}
@end
@implementation FTSRWireframe
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame{
    self = [super init];
    if(self){
        self.identifier = identifier;
        CGFloat width = roundf(frame.size.width);
        self.width = width == 0 ? @(frame.size.width):@(width);
        CGFloat height = roundf(frame.size.height);
        self.height = height == 0 ? @(frame.size.height):@(height);
        self.x = @(roundf(CGRectGetMinX(frame)));
        self.y = @(roundf(CGRectGetMinY(frame)));
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError *__autoreleasing  _Nullable * _Nullable)error{
    if ([self isEqual:newWireFrame]) return nil;
    
    if(![newWireFrame isKindOfClass:[self class]] || ![newWireFrame.type isEqualToString:self.type]){
        NSString *failureReason =
        [NSString stringWithFormat:@"FTSRWireframe validation errors: %@ is not Equal to %@",
         self.type,newWireFrame.type];
        if(error){
            *error = [NSError errorWithDomain:@"com.ft.session-replay" code:-100 userInfo:@{NSLocalizedDescriptionKey:failureReason}];
        }
        return nil;
    }
    //Use new clip when old clip doesn't exist
    self.clip = useNewClipIfDifferentThanOld(newWireFrame.clip, self.clip);
    self.width = useNewObjectIfDifferentThanOld(newWireFrame.width,self.width);
    self.height = useNewObjectIfDifferentThanOld(newWireFrame.height,self.height);
    self.x = useNewObjectIfDifferentThanOld(newWireFrame.x,self.x);
    self.y = useNewObjectIfDifferentThanOld(newWireFrame.y,self.y);
    return self;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    FTSRWireframe *object = (FTSRWireframe *)baseFrame;
    BOOL haveEqualClip = objectIsEqual(self.clip,object.clip);
    BOOL haveEqualWidth= objectIsEqual(self.width,object.width);
    BOOL haveEqualHeight= objectIsEqual(self.height,object.height);
    BOOL haveEqualX = objectIsEqual(self.x,object.x);
    BOOL haveEqualY = objectIsEqual(self.y,object.y);
    return haveEqualClip && haveEqualWidth && haveEqualHeight && haveEqualX && haveEqualY && self.identifier == object.identifier;
}
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"identifier":@"id",
    }];
    return keyMapper;
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
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"shape";
    }
    return self;
}
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame clip:(CGRect)clip backgroundColor:(NSString *)color cornerRadius:(NSNumber *)cornerRadius opacity:(NSNumber *)opacity{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"shape";
        _shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:color cornerRadius:cornerRadius opacity:opacity];
    }
    return self;
}
-(instancetype)initWithIdentifier:(int64_t)identifier attributes:(FTViewAttributes *)attributes{
    self = [super initWithIdentifier:identifier frame:attributes.frame];
    if(self){
        self.type = @"shape";
        if (attributes){
            FTSRShapeBorder *border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:attributes.layerBorderColor]  width:attributes.layerBorderWidth];
            FTSRShapeStyle *backgroundStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:attributes.backgroundColor.CGColor] cornerRadius:@(attributes.layerCornerRadius) opacity:@(attributes.alpha)];
            self.border = border;
            self.clip = [[FTSRContentClip alloc]initWithFrame:attributes.frame clip:attributes.clip];
            self.shapeStyle = backgroundStyle;
        }
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError *__autoreleasing  _Nullable * _Nullable)error{
    FTSRWireframe *baseWire = [super compareWithNewWireFrame:newWireFrame error:error];
    if(!baseWire || *error){
        return nil;
    }
    FTSRShapeWireframe *snapWireframe = (FTSRShapeWireframe *)baseWire;
    FTSRShapeWireframe *newWire = (FTSRShapeWireframe *)newWireFrame;
    snapWireframe.border = useNewObjectIfDifferentThanOld(newWire.border,self.border);
    snapWireframe.shapeStyle = useNewObjectIfDifferentThanOld(newWire.shapeStyle,self.shapeStyle);
    return snapWireframe;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame {
    if (![super isEqualToBaseFrame:baseFrame]) return NO;
    FTSRShapeWireframe *object = (FTSRShapeWireframe *)baseFrame;
    BOOL isBorderEqual = objectIsEqual(self.border,object.border);
    BOOL isShapeStyleEqual = objectIsEqual(self.shapeStyle,object.shapeStyle);
    return isBorderEqual && isShapeStyleEqual;
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
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"text";
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError *__autoreleasing  _Nullable * _Nullable)error{
    FTSRWireframe *baseWire = [super compareWithNewWireFrame:newWireFrame error:error];
    if(!baseWire || *error){
        return nil;
    }
    FTSRTextWireframe *textWireframe = (FTSRTextWireframe *)baseWire;
    FTSRTextWireframe *newWire = (FTSRTextWireframe *)newWireFrame;
    textWireframe.text = useNewObjectIfDifferentThanOld(newWire.text,self.text);
    textWireframe.textPosition = useNewObjectIfDifferentThanOld(newWire.textPosition,self.textPosition);
    textWireframe.textStyle = useNewObjectIfDifferentThanOld(newWire.textStyle,self.textStyle);
    textWireframe.border = useNewObjectIfDifferentThanOld(newWire.border,self.border);
    textWireframe.shapeStyle = useNewObjectIfDifferentThanOld(newWire.shapeStyle,self.shapeStyle);
    return textWireframe;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame{
    if (![super isEqualToBaseFrame:baseFrame]) return NO;
    FTSRTextWireframe *object = (FTSRTextWireframe *)baseFrame;
    BOOL isTextEqual = objectIsEqual(self.text,object.text);
    BOOL isBorderEqual = objectIsEqual(self.border,object.border);
    BOOL isShapeStyleEqual = objectIsEqual(self.shapeStyle,object.shapeStyle);
    BOOL isTextPositionEqual = objectIsEqual(self.textPosition,object.textPosition);
    BOOL isTextStyleEqual = objectIsEqual(self.textStyle,object.textStyle);
    return isTextEqual && isBorderEqual && isShapeStyleEqual && isTextPositionEqual && isTextStyleEqual;
}
@end
@implementation FTSRImageWireframe
-(instancetype)init{
    return [self initWithIdentifier:0 frame:CGRectZero];
}
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame {
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"image";
        self.mimeType = @"png";
        // TODO: Remove when imageData synchronization is supported
        self.isEmpty = YES;
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError *__autoreleasing  _Nullable * _Nullable)error{
    FTSRWireframe *baseWire = [super compareWithNewWireFrame:newWireFrame error:error];
    if(!baseWire || *error){
        return nil;
    }
    FTSRImageWireframe *imageWireframe = (FTSRImageWireframe *)baseWire;
    FTSRImageWireframe *newWire = (FTSRImageWireframe *)newWireFrame;
    imageWireframe.mimeType = useNewObjectIfDifferentThanOld(newWire.mimeType,self.mimeType);
    imageWireframe.resourceId = useNewObjectIfDifferentThanOld(newWire.resourceId,self.resourceId);
    imageWireframe.border = useNewObjectIfDifferentThanOld(newWire.border,self.border);
    imageWireframe.shapeStyle = useNewObjectIfDifferentThanOld(newWire.shapeStyle,self.shapeStyle);
    return imageWireframe;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame{
    if (![super isEqualToBaseFrame:baseFrame]) return NO;
    FTSRImageWireframe *object = (FTSRImageWireframe *)baseFrame;
    BOOL isMimeTypeEqual = objectIsEqual(self.mimeType,object.mimeType);
    BOOL isResourceIdEqual = objectIsEqual(self.resourceId,object.resourceId);
    BOOL isBorderEqual = objectIsEqual(self.border,object.border);
    BOOL isShapeStyleEqual = objectIsEqual(self.shapeStyle,object.shapeStyle);
    return isMimeTypeEqual && isResourceIdEqual && isBorderEqual && isShapeStyleEqual;
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
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame{
    return [self initWithIdentifier:identifier frame:frame label:nil];
}
- (instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame label:(NSString *)label{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"placeholder";
        _label = label;
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError *__autoreleasing  _Nullable * _Nullable)error{
    FTSRWireframe *baseWire = [super compareWithNewWireFrame:newWireFrame error:error];
    if(!baseWire || *error){
        return nil;
    }
    FTSRPlaceholderWireframe *placeholder = (FTSRPlaceholderWireframe *)baseWire;
    FTSRPlaceholderWireframe *newWire = (FTSRPlaceholderWireframe *)newWireFrame;
    placeholder.label = useNewObjectIfDifferentThanOld(newWire.label,self.label);
    return placeholder;
}
- (BOOL)isEqualToBaseFrame:(FTSRBaseFrame *)baseFrame{
    if (![super isEqualToBaseFrame:baseFrame]) return NO;
    FTSRPlaceholderWireframe *object = (FTSRPlaceholderWireframe *)baseFrame;
    BOOL isLabelEqual = objectIsEqual(self.label,object.label);
    return isLabelEqual;
}
@end

@implementation FTSRWebViewWireframe

-(instancetype)init{
    self = [super init];
    if(self){
        self.type = @"webview";
    }
    return self;
}
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame{
    self = [super initWithIdentifier:identifier frame:frame];
    if(self){
        self.type = @"webview";
    }
    return self;
}
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError *__autoreleasing  _Nullable * _Nullable)error{
    if ([self isEqual:newWireFrame]){
        return nil;
    }
    FTSRWireframe *wire = [super compareWithNewWireFrame:newWireFrame error:error];
    if(*error){
        return nil;
    }
    FTSRWebViewWireframe *webView = (FTSRWebViewWireframe *)wire;
    FTSRWebViewWireframe *newWeb = (FTSRWebViewWireframe *)newWireFrame;
    webView.isVisible = useNewObjectIfDifferentThanOld(newWeb.isVisible,self.isVisible);
    webView.border = useNewObjectIfDifferentThanOld(newWeb.border,self.border);
    webView.shapeStyle = useNewObjectIfDifferentThanOld(newWeb.shapeStyle,self.shapeStyle);
    return webView;
}
-(BOOL)isEqualToWebViewWireframe:(FTSRWebViewWireframe *)object{
    if(!object){
        return NO;
    }
    BOOL isSlotIdEqual = objectIsEqual(self.slotId,object.slotId);
    BOOL isVisibleEqual = objectIsEqual(self.isVisible,object.isVisible);
    return isSlotIdEqual && isVisibleEqual && [super isEqual:object];
}
-(BOOL)isEqual:(id)object{
    if(self == object){
        return YES;
    }
    if (![object isKindOfClass:self.class]){
        return NO;
    }
    return [self isEqualToWebViewWireframe:object];
}
@end
