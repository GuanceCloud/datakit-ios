//
//  FTActionTrackingHandler.h
//
//  Created by hulilei on 2025/7/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#ifndef FTActionTrackingHandler_h
#define FTActionTrackingHandler_h

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if TARGET_OS_TV || TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import "FTRUMAction.h"
NS_ASSUME_NONNULL_BEGIN
/// App launch type
typedef NS_ENUM(NSUInteger, FTLaunchType) {
    /// Hot launch
    FTLaunchHot,
    /// Cold launch
    FTLaunchCold,
    /// Warm launch, system preloads before APP launch
    FTLaunchWarm
};

/// iOS: The handler deciding if a given RUM Action should be recorded.
@protocol FTUITouchRUMActionsHandler <NSObject>

/// Deciding if the RUM Action should be recorded.
/// @param targetView an instance of the `UIView` which received the action.
/// @return RUM Action if it should be recorded, `nil` otherwise.
- (nullable FTRUMAction *)rumActionWithTargetView:(UIView *)targetView;


/// Deciding if the RUM Launch Action should be recorded.
/// @param type launch type
/// @return RUM Action if it should be recorded, `nil` otherwise.
- (nullable FTRUMAction *)rumLaunchActionWithLaunchType:(FTLaunchType)type;
@end

/// TVOS: The handler deciding if a given RUM Action should be recorded.
@protocol FTUIPressRUMActionsHandler <NSObject>

/// The handler deciding if the RUM Action should be recorded.
/// @param type the `UIPressType` which received the action.
/// @param targetView an instance of the `UIView` which received the action.
/// @return RUM Action if it should be recorded, `nil` otherwise.
- (nullable FTRUMAction *)rumActionWithPressType:(UIPressType)type targetView:(UIView *)targetView;

/// Deciding if the RUM Launch Action should be recorded.
/// @param type launch type
/// @return RUM Action if it should be recorded, `nil` otherwise.
- (nullable FTRUMAction *)rumLaunchActionWithLaunchType:(FTLaunchType)type;
@end

#if TARGET_OS_TV
typedef id<FTUIPressRUMActionsHandler> FTActionTrackingHandler;
#elif TARGET_OS_IOS
typedef id<FTUITouchRUMActionsHandler> FTActionTrackingHandler;
#endif

NS_ASSUME_NONNULL_END
#endif

#endif
