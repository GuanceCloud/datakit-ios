//
//  FTDefaultUIKitViewTrackingHandler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/6.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDefaultUIKitViewTrackingHandler.h"
#import "UIViewController+FTAutoTrack.h"

@implementation FTDefaultUIKitViewTrackingHandler
- (nullable FTRUMView *)rumViewForViewController:(UIViewController *)viewController{
    if (!viewController.parentViewController ||
        [viewController.parentViewController isKindOfClass:[UITabBarController class]] ||
        [viewController.parentViewController isKindOfClass:[UINavigationController class]] ||
        [viewController.parentViewController isKindOfClass:[UISplitViewController class]]) {
        
        if([self shouldTrackViewController:viewController]){
            return [[FTRUMView alloc]initWithViewName:viewController.ft_viewControllerName];
        }
    }
    return nil;
}
- (BOOL)shouldTrackViewController:(UIViewController *)viewController{
    return ![viewController isBlackListContainsViewController];
}
@end
