//
//  FTSystemColors.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

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
