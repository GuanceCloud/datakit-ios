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
+ (NSString *)systemFillColorStr{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor systemFillColor].CGColor];
    } else {
        return @"#78788033";
    }
}
/// The background of a switch.
+ (NSString *)secondarySystemFillColorStr{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor secondarySystemFillColor].CGColor];
    } else {
        return @"#78788029";
    }
}
/// Input fields, search bars, buttons.
+ (NSString *)tertiarySystemFillColorStr{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tertiarySystemFillColor].CGColor];
    } else {
        return @"#7676801F";
    }
}
+ (NSString *)tertiarySystemBackgroundColorStr{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tertiarySystemBackgroundColor].CGColor];
    } else {
        return @"#FFFFFFFF";
    }
}
+ (NSString *)secondarySystemGroupedBackgroundColorStr{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor secondarySystemGroupedBackgroundColor].CGColor];
    } else {
        return @"#FFFFFFFF";
    }
}
+ (UIColor *)systemBackground{
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    } else {
        return [UIColor colorWithRed:255 / 255 green:255 / 255 blue:255 / 255 alpha:1];
    }
}
+ (NSString *)systemBackgroundColorStr{
    return [FTSRUtils colorHexString:self.systemBackground.CGColor];
}
+ (UIColor *)labelColor{
    if (@available(iOS 13.0, *)) {
        return [UIColor labelColor];
    }else{
        return [UIColor colorWithRed:0/ 255 green:0 / 255 blue:0 / 255 alpha:1];
    }
}
+ (NSString *)labelColorStr{
    return [FTSRUtils colorHexString:[self labelColor].CGColor];
}
+ (NSString *)placeholderTextColorStr{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor placeholderTextColor].CGColor];
    } else {
        return @"#3C3C434C";
    }
}
+ (NSString *)tintColorStr{
    if (@available(iOS 15.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tintColor].CGColor];
    } else {
        return @"#007AFFFF";
    }
}
+ (NSString *)systemGreenColorStr{
    return [FTSRUtils colorHexString:[UIColor systemGreenColor].CGColor];
}
+ (NSString *)clearColorStr{
    return [FTSRUtils colorHexString:[UIColor clearColor].CGColor];
}
@end
