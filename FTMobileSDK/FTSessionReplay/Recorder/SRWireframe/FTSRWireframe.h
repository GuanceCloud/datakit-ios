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
// Don't change to int, use NSNumber because bottom and right may be null
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
@property (nonatomic, strong) NSNumber *bottom;
@property (nonatomic, strong) NSNumber *left;
@property (nonatomic, strong) NSNumber *right;
@property (nonatomic, strong) NSNumber *top;
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
/// Unique identifier
@property (nonatomic, assign) int64_t identifier;
// Don't change to int, use NSNumber so it can be set to nil during update comparison
/// frame.origin.x in root view
@property (nonatomic) NSNumber *x;
/// frame.origin.y in root view
@property (nonatomic) NSNumber *y;
/// UI control width
@property (nonatomic) NSNumber *width;
/// UI control height
@property (nonatomic) NSNumber *height;
/// Control type
@property (nonatomic, copy) NSString *type;
/// Clip information
@property (nonatomic, strong,nullable) FTSRContentClip *clip;

-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame;
-(nullable FTSRWireframe *)compareWithNewWireFrame:(FTSRWireframe *)newWireFrame error:(NSError **)error;

@end

@interface FTSRShapeWireframe : FTSRWireframe
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
-(instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame clip:(CGRect)clip backgroundColor:(nullable NSString *)color cornerRadius:(nullable NSNumber *)cornerRadius opacity:(nullable NSNumber *)opacity;
-(instancetype)initWithIdentifier:(int64_t)identifier attributes:(nullable FTViewAttributes *)attributes;
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
- (instancetype)initWithIdentifier:(int64_t)identifier frame:(CGRect)frame label:(nullable NSString *)label;
@end
@interface FTSRWebViewWireframe : FTSRWireframe
@property (nonatomic, strong) FTSRShapeBorder *border;
@property (nonatomic, strong) FTSRShapeStyle *shapeStyle;
@property (nonatomic, strong) NSNumber *isVisible;
@property (nonatomic, copy) NSString *slotId;
@end
NS_ASSUME_NONNULL_END
