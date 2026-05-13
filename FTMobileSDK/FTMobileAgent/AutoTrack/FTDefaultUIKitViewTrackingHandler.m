//
//  FTDefaultUIKitViewTrackingHandler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/6.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDefaultUIKitViewTrackingHandler.h"
#import "UIViewController+FTAutoTrack.h"

static BOOL FTViewControllerIsFromSwiftUIBundle(UIViewController *viewController) {
    NSBundle *bundle = [NSBundle bundleForClass:viewController.class];
    return [bundle.bundleURL.lastPathComponent isEqualToString:@"SwiftUI.framework"];
}

@implementation FTDefaultUIKitViewTrackingHandler
- (nullable FTRUMView *)rumViewForViewController:(UIViewController *)viewController{
    if (!viewController.parentViewController ||
        [viewController.parentViewController isKindOfClass:[UITabBarController class]] ||
        [viewController.parentViewController isKindOfClass:[UINavigationController class]] ||
        [viewController.parentViewController isKindOfClass:[UISplitViewController class]]) {
        
        if([self shouldTrackViewController:viewController]){
            return [self createRUMView:viewController];
        }
    }
    return nil;
}
- (BOOL)shouldTrackViewController:(UIViewController *)viewController{
    return !FTViewControllerIsFromSwiftUIBundle(viewController) && ![viewController isBlackListContainsViewController];
}

- (FTRUMView *)createRUMView:(UIViewController *)viewController{
    return [[FTRUMView alloc]initWithViewName:viewController.ft_viewControllerName];
}
@end


@implementation FTDefaultSwiftUIViewTrackingHandler

-(FTRUMView *)rumViewForExtractedViewName:(NSString *)extractedViewName{
    return [[FTRUMView alloc]initWithViewName:extractedViewName];
}
@end
