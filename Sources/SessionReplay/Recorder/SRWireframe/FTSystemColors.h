//
//  FTSystemColors.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/28.
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

NS_ASSUME_NONNULL_BEGIN

@interface FTSystemColors : NSObject
/// The track of a slider.
+ (NSString *)systemFillColorStr;
/// The background of a switch.
+ (NSString *)secondarySystemFillColorStr;
/// Input fields, search bars, buttons.
+ (NSString *)tertiarySystemFillColorStr;
+ (NSString *)tertiarySystemBackgroundColorStr;
+ (NSString *)secondarySystemGroupedBackgroundColorStr;
+ (UIColor *)systemBackground;

+ (NSString *)systemBackgroundColorStr;
+ (UIColor *)labelColor;
+ (NSString *)labelColorStr;
+ (NSString *)placeholderTextColorStr;
+ (NSString *)tintColorStr;
+ (NSString *)systemGreenColorStr;
+ (NSString *)clearColorStr;
@end

NS_ASSUME_NONNULL_END

#endif
