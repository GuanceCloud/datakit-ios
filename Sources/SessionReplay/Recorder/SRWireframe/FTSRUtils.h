//
//  FTSRUtils.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/8.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

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

#endif
