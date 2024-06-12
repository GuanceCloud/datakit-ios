//
//  FTSystemColors.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSystemColors.h"
#import "FTSRUtils.h"

#import <UIKit/UIKit.h>
@implementation FTSystemColors
/// The track of a slider.
+ (NSString *)systemFillColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor systemFillColor].CGColor];
    } else {
        return @"#78788033";
    }
}
/// The background of a switch.
+ (NSString *)secondarySystemFillColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor secondarySystemFillColor].CGColor];
    } else {
        return @"#78788029";
    }
}
/// Input fields, search bars, buttons.
+ (NSString *)tertiarySystemFillColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tertiarySystemFillColor].CGColor];
    } else {
        return @"#7676801f";
    }
}
+ (NSString *)tertiarySystemBackgroundColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tertiarySystemBackgroundColor].CGColor];
    } else {
        return @"#ffffffff";
    }
}
+ (NSString *)secondarySystemGroupedBackgroundColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor secondarySystemGroupedBackgroundColor].CGColor];
    } else {
        return @"#ffffffff";
    }
}
+ (NSString *)systemBackgroundColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor systemBackgroundColor].CGColor];
    } else {
        return @"#ffffffff";
    }
}
+ (NSString *)labelColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor labelColor].CGColor];
    } else {
        return @"#000000ff";
    }
}
+ (NSString *)placeholderTextColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor placeholderTextColor].CGColor];
    } else {
        return @"#3c3c434c";
    }
}
+ (NSString *)tintColor{
    if (@available(iOS 15.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tintColor].CGColor];
    } else {
        return @"#007affff";
    }
}
+ (NSString *)systemGreenColor{
    return [FTSRUtils colorHexString:[UIColor systemGreenColor].CGColor];
}
+ (NSString *)clearColor{
    return [FTSRUtils colorHexString:[UIColor clearColor].CGColor];
}
@end
