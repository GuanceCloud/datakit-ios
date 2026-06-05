//
//  FTSRUtils.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/8.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
typedef enum FTSRPrivacy:NSUInteger FTSRPrivacy;
typedef NS_ENUM(NSUInteger,HorizontalAlignment){
    HorizontalAlignmentLeft,
    HorizontalAlignmentRight,
    HorizontalAlignmentCenter,
};
typedef NS_ENUM(NSUInteger,VerticalAlignment){
    VerticalAlignmentTop,
    VerticalAlignmentBottom,
    VerticalAlignmentMiddle,
};
NS_ASSUME_NONNULL_BEGIN
CGRect FTCGRectFitWithContentMode(CGRect rect, CGSize size, UIViewContentMode mode);
CGRect FTCGRectPutInside(CGRect oriRect, CGRect inRect, HorizontalAlignment horizontal,VerticalAlignment vertical);

CGFloat FTCGSizeAspectRatio(CGSize size);
@interface FTSRColorSnapshot : NSObject
@property (nonatomic, readonly, nullable) CGColorRef cgColor;
@property (nonatomic, readonly) CGFloat alpha;
@property (nonatomic, copy, readonly, nullable) NSString *hexString;
+ (nullable instancetype)snapshotWithColor:(nullable UIColor *)color traitCollection:(nullable UITraitCollection *)traitCollection;
+ (nullable instancetype)snapshotWithCGColor:(nullable CGColorRef)cgColor;
@end

@interface FTSRUtils : NSObject
+ (NSString *)colorHexString:(CGColorRef)color;
+ (BOOL)isSensitiveText:(id<UITextInputTraits>)textInputTraits;
+ (nullable CGColorRef)safeCast:(CGColorRef)cgColor;
+ (CGFloat)getCGColorAlpha:(CGColorRef)color;
+ (nullable NSString *)getTextStyleTruncationMode:(NSLineBreakMode)lineBreakMode;
@end

NS_ASSUME_NONNULL_END
