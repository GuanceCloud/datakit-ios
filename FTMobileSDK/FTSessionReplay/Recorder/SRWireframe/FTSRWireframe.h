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
@property (nonatomic, copy, nullable) NSString *color;
@property (nonatomic, assign) CGFloat width;
-(instancetype)initWithColor:(nullable NSString *)color width:(CGFloat)width;
@end

@interface FTSRContentClip : FTSRBaseFrame
// 不要改为 int ,使用 NSNumber 是因为 bottom 和 right 可能为空
@property (nonatomic, strong, nullable) NSNumber *bottom;
@property (nonatomic, strong, nullable) NSNumber *left;
@property (nonatomic, strong, nullable) NSNumber *right;
@property (nonatomic, strong, nullable) NSNumber *top;
-(instancetype)initWithFrame:(CGRect)frame clip:(CGRect)clip;
@end

@interface FTSRShapeStyle : FTSRBaseFrame
@property (nonatomic, copy) NSString *backgroundColor;
@property (nonatomic, strong) NSNumber *cornerRadius;
@property (nonatomic, strong) NSNumber *opacity;
-(instancetype)initWithBackgroundColor:(nullable NSString *)color cornerRadius:(nullable NSNumber *)cornerRadius opacity:(NSNumber *)opacity;
@end

@interface FTPadding : FTSRBaseFrame
@property (nonatomic, assign) NSNumber *bottom;
@property (nonatomic, assign) NSNumber *left;
@property (nonatomic, assign) NSNumber *right;
@property (nonatomic, assign) NSNumber *top;
-(instancetype)initWithLeft:(float)left top:(float)top right:(float)right bottom:(float)bottom;
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
@property (nonatomic, strong) FTPadding *padding;
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
@property (nonatomic, strong,nullable) FTSRContentClip *clip;

-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame;
-(nullable FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError **)error;

@end

@interface FTSRShapeWireframe : FTSRWireframe
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
-(instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame clip:(CGRect)clip backgroundColor:(nullable NSString *)color cornerRadius:(nullable NSNumber *)cornerRadius opacity:(nullable NSNumber *)opacity;
-(instancetype)initWithIdentifier:(int)identifier attributes:(nullable FTViewAttributes *)attributes;
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
@property (nonatomic) BOOL isEmpty;
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
@end
@interface FTSRPlaceholderWireframe : FTSRWireframe
@property (nonatomic, copy, nullable) NSString *label;
- (instancetype)initWithIdentifier:(int)identifier frame:(CGRect)frame label:(nullable NSString *)label;
@end
NS_ASSUME_NONNULL_END
