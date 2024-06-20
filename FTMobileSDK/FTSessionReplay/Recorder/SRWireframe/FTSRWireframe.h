//
//  FTSRWireframe.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRBaseFrame.h"
NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTViewAttributes;
@interface FTSRShapeBorder : FTSRBaseFrame
@property (nonatomic, copy) NSString *color;
@property (nonatomic, assign) CGFloat width;
-(instancetype)initWithColor:(NSString *)color width:(CGFloat)width;
@end

@interface FTSRContentClip : FTSRBaseFrame
@property (nonatomic, assign) int bottom;
@property (nonatomic, assign) int left;
@property (nonatomic, assign) int right;
@property (nonatomic, assign) int top;
-(instancetype)initWithLeft:(float)left top:(float)top right:(float)right bottom:(float)bottom;
@end

@interface FTSRShapeStyle : FTSRBaseFrame
@property (nonatomic, copy) NSString *backgroundColor;
@property (nonatomic, strong) NSNumber *cornerRadius;
@property (nonatomic, strong) NSNumber *opacity;
-(instancetype)initWithBackgroundColor:(nullable NSString *)color cornerRadius:(nullable NSNumber *)cornerRadius opacity:(NSNumber *)opacity;
@end

@interface FTAlignment : FTSRBaseFrame
// left、right、center
@property (nonatomic, copy) NSString *horizontal;
// top、bottom、center
@property (nonatomic, copy) NSString *vertical;
-(instancetype)initWithTextAlignment:(NSTextAlignment)alignment vertical:(NSString *)vertical;
@end
@interface FTSRTextPosition : FTSRBaseFrame
@property (nonatomic, strong) FTAlignment *alignment;
@property (nonatomic, strong) FTSRContentClip *padding;
@end

@interface FTSRTextStyle : FTSRBaseFrame
@property (nonatomic, assign) int size;
@property (nonatomic, copy) NSString *color;
@property (nonatomic, copy) NSString *family;
- (instancetype)initWithSize:(int)size color:(NSString *)color family:(nullable NSString *)family;
@end
#pragma mark ========== FTSRWireframe ==========
@interface FTSRWireframe : FTSRBaseFrame
/// 唯一标识
@property (nonatomic, assign) int identifier;
// 不要改为 int ,使用 NSNumber 是为了update比较时可以置为 nil
/// 在根视图的 frame.origin.x
@property (nonatomic) NSNumber *x;
/// 在根视图的 frame.origin.y
@property (nonatomic) NSNumber *y;
/// UI 控件的宽度
@property (nonatomic) NSNumber *width;
/// UI 控件的高度
@property (nonatomic) NSNumber *height;
/// 控件类型
@property (nonatomic, copy) NSString *type;
/// 裁剪信息
@property (nonatomic, strong) FTSRContentClip *clip;

-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame;
-(FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame;

@end

@interface FTSRShapeWireframe : FTSRWireframe
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame backgroundColor:(nullable NSString *)color cornerRadius:(nullable NSNumber *)cornerRadius opacity:(nullable NSNumber *)opacity;
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame attributes:(nullable FTViewAttributes *)attributes;
@end
@interface FTSRTextWireframe : FTSRWireframe
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) FTSRTextPosition *textPosition;
@property (nonatomic, strong) FTSRTextStyle *textStyle;
@end
@interface FTSRImageWireframe : FTSRWireframe
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *resourceId;
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
@end
@interface FTSRPlaceholderWireframe : FTSRWireframe
@property (nonatomic, copy, nullable) NSString *label;
- (instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame label:(nullable NSString *)label;
@end
NS_ASSUME_NONNULL_END
