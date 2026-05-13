//
//  FTDefaultActionTrackingHandler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/6.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDefaultActionTrackingHandler.h"
#import "FTConstants.h"
#import "UIView+FTAutoTrack.h"

@implementation FTDefaultActionTrackingHandler

- (nullable FTRUMAction *)rumActionWithTargetView:(nonnull UIView *)targetView { 
    return [[FTRUMAction alloc]initWithActionName:targetView.ft_actionName];
}

- (nullable FTRUMAction *)rumLaunchActionWithLaunchType:(FTLaunchType)type {
    NSString *actionName = nil;
    switch (type) {
        case FTLaunchHot:
            actionName = @"app_hot_start";
            break;
        case FTLaunchCold:
            actionName = @"app_cold_start";
            break;
        case FTLaunchWarm:
            actionName = @"app_warm_start";
            break;
    }
    return [[FTRUMAction alloc]initWithActionName:actionName];
}

- (nullable FTRUMAction *)rumActionWithPressType:(UIPressType)type targetView:(nonnull UIView *)targetView { 
    NSString *actionName;
    switch (type) {
        case UIPressTypeSelect:
            actionName = targetView.ft_actionName;
            break;
        case UIPressTypeMenu:
            actionName = @"[menu]";
            break;
        case UIPressTypePlayPause:
            actionName = @"[play-pause]";
            break;
        default:
            return nil;
    }
    return [[FTRUMAction alloc]initWithActionName:actionName];
}

@end

#if TARGET_OS_IOS
@implementation FTDefaultSwiftUIActionTrackingHandler

- (nullable FTRUMAction *)rumActionWithSwiftUIComponentName:(NSString *)componentName {
    if (componentName.length == 0) {
        return nil;
    }
    return [[FTRUMAction alloc] initWithActionName:componentName];
}

@end
#endif
