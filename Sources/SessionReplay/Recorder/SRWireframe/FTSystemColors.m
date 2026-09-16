//
//  FTSystemColors.m
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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTSystemColors.h"
#import "FTSRUtils.h"

#import "FTSessionReplayPlatform.h"
@implementation FTSystemColors
#if TARGET_OS_IOS
/// The track of a slider.
+ (NSString *)systemFillColorStr{
    return [FTSRUtils colorHexString:[UIColor systemFillColor].CGColor];
}
/// The background of a switch.
+ (NSString *)secondarySystemFillColorStr{
    return [FTSRUtils colorHexString:[UIColor secondarySystemFillColor].CGColor];
}
/// Input fields, search bars, buttons.
+ (NSString *)tertiarySystemFillColorStr{
    return [FTSRUtils colorHexString:[UIColor tertiarySystemFillColor].CGColor];
}
+ (NSString *)tertiarySystemBackgroundColorStr{
    return [FTSRUtils colorHexString:[UIColor tertiarySystemBackgroundColor].CGColor];
}
+ (NSString *)secondarySystemGroupedBackgroundColorStr{
    return [FTSRUtils colorHexString:[UIColor secondarySystemGroupedBackgroundColor].CGColor];
}
+ (UIColor *)systemBackground{
    return [UIColor systemBackgroundColor];
}
+ (NSString *)systemBackgroundColorStr{
    return [FTSRUtils colorHexString:self.systemBackground.CGColor];
}
+ (UIColor *)labelColor{
    return [UIColor labelColor];
}
+ (NSString *)labelColorStr{
    return [FTSRUtils colorHexString:[self labelColor].CGColor];
}
+ (NSString *)placeholderTextColorStr{
    return [FTSRUtils colorHexString:[UIColor placeholderTextColor].CGColor];
}
+ (NSString *)tintColorStr{
    return [FTSRUtils colorHexString:[UIColor tintColor].CGColor];
}
+ (NSString *)systemGreenColorStr{
    return [FTSRUtils colorHexString:[UIColor systemGreenColor].CGColor];
}
+ (NSString *)clearColorStr{
    return [FTSRUtils colorHexString:[UIColor clearColor].CGColor];
}
#elif TARGET_OS_OSX
+ (NSString *)systemFillColorStr {
    return @"#78788033";
}
+ (NSString *)secondarySystemFillColorStr {
    return @"#78788029";
}
+ (NSString *)tertiarySystemFillColorStr {
    return @"#7676801F";
}
+ (NSString *)tertiarySystemBackgroundColorStr {
    return @"#FFFFFFFF";
}
+ (NSString *)secondarySystemGroupedBackgroundColorStr {
    return @"#FFFFFFFF";
}
+ (FTSRPlatformColor *)systemBackground {
    return NSColor.windowBackgroundColor;
}
+ (NSString *)systemBackgroundColorStr {
    return @"#ECECECFF";
}
+ (FTSRPlatformColor *)labelColor {
    return NSColor.labelColor;
}
+ (NSString *)labelColorStr {
    return @"#000000FF";
}
+ (NSString *)placeholderTextColorStr {
    return @"#3C3C434C";
}
+ (NSString *)tintColorStr {
    return @"#007AFFFF";
}
+ (NSString *)systemGreenColorStr {
    return @"#34C759FF";
}
+ (NSString *)clearColorStr {
    return @"#00000000";
}
#endif
@end

#endif
