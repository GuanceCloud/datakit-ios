//
//  FTSystemColors.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSystemColors : NSObject
/// The track of a slider.
+ (NSString *)systemFillColor;
/// The background of a switch.
+ (NSString *)secondarySystemFillColor;
/// Input fields, search bars, buttons.
+ (NSString *)tertiarySystemFillColor;
+ (NSString *)tertiarySystemBackgroundColor;
+ (NSString *)secondarySystemGroupedBackgroundColor;
+ (NSString *)systemBackgroundColor;
+ (NSString *)labelColor;
+ (NSString *)placeholderTextColor;
+ (NSString *)tintColor;
+ (NSString *)systemGreenColor;
+ (NSString *)clearColor;
@end

NS_ASSUME_NONNULL_END
