//
//  FTActionTrackingHandler.h
//
//  Created by hulilei on 2025/7/30.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
/// Platform-specific handler that decides whether automatically detected RUM actions are recorded.
typedef id<FTUIPressRUMActionsHandler> FTActionTrackingHandler;
#elif TARGET_OS_IOS
/// Platform-specific handler that decides whether automatically detected RUM actions are recorded.
typedef id<FTUITouchRUMActionsHandler> FTActionTrackingHandler;
#endif

NS_ASSUME_NONNULL_END
#else
NS_ASSUME_NONNULL_BEGIN

@protocol FTUITouchRUMActionsHandler <NSObject>
@end

@protocol FTUIPressRUMActionsHandler <NSObject>
@end

/// Placeholder action tracking handler for platforms without UIKit action tracking.
typedef id FTActionTrackingHandler;

NS_ASSUME_NONNULL_END
#endif

#endif
