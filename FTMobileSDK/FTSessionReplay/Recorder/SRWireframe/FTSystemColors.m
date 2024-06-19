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
        return @"#7676801F";
    }
}
+ (NSString *)tertiarySystemBackgroundColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tertiarySystemBackgroundColor].CGColor];
    } else {
        return @"#FFFFFFFF";
    }
}
+ (NSString *)secondarySystemGroupedBackgroundColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor secondarySystemGroupedBackgroundColor].CGColor];
    } else {
        return @"#FFFFFFFF";
    }
}
+ (CGColorRef)systemBackgroundCGColor{
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor].CGColor;
    } else {
        return [UIColor colorWithRed:255 / 255 green:255 / 255 blue:255 / 255 alpha:1].CGColor;
    }
}
+ (NSString *)systemBackgroundColor{
    return [FTSRUtils colorHexString:self.systemBackgroundCGColor];
}
+ (CGColorRef)labelColorCGColor{
    if (@available(iOS 13.0, *)) {
        return [UIColor labelColor].CGColor;
    }else{
        return [UIColor colorWithRed:0/ 255 green:0 / 255 blue:0 / 255 alpha:1].CGColor;
    }
}
+ (NSString *)labelColor{
    return [FTSRUtils colorHexString:[self labelColorCGColor]];
}
+ (NSString *)placeholderTextColor{
    if (@available(iOS 13.0, *)) {
        return [FTSRUtils colorHexString:[UIColor placeholderTextColor].CGColor];
    } else {
        return @"#3C3C434C";
    }
}
+ (NSString *)tintColor{
    if (@available(iOS 15.0, *)) {
        return [FTSRUtils colorHexString:[UIColor tintColor].CGColor];
    } else {
        return @"#007AFFFF";
    }
}
+ (NSString *)systemGreenColor{
    return [FTSRUtils colorHexString:[UIColor systemGreenColor].CGColor];
}
+ (NSString *)clearColor{
    return [FTSRUtils colorHexString:[UIColor clearColor].CGColor];
}
@end
