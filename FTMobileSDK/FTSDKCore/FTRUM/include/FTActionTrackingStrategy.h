//
//  FTActionTrackingStrategy.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_TV || TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import "FTRUMAction.h"
NS_ASSUME_NONNULL_BEGIN

/// iOS: The strategy deciding if a given RUM Action should be recorded.
@protocol FTUITouchRUMActionsStrategy <NSObject>

/// The strategy deciding if the RUM Action should be recorded.
/// @param targetView an instance of the `UIView` which received the action.
/// @return RUM Action if it should be recorded, `nil` otherwise.
- (nullable FTRUMAction *)rumActionWithTargetView:(UIView *)targetView;

@end

/// TVOS: The strategy deciding if a given RUM Action should be recorded.
@protocol FTUIPressRUMActionsStrategy <NSObject>

/// The strategy deciding if the RUM Action should be recorded.
/// @param type the `UIPressType` which received the action.
/// @param targetView an instance of the `UIView` which received the action.
/// @return RUM Action if it should be recorded, `nil` otherwise.
- (nullable FTRUMAction *)rumActionWithPressType:(UIPressType)type targetView:(UIView *)targetView;

@end

#if TARGET_OS_TV
typedef id<FTUIPressRUMActionsStrategy> FTActionTrackingStrategy;
#elif TARGET_OS_IOS
typedef id<FTUITouchRUMActionsStrategy> FTActionTrackingStrategy;
#endif

NS_ASSUME_NONNULL_END
#endif
