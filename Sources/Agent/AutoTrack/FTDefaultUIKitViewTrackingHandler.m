//
//  FTDefaultUIKitViewTrackingHandler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/6.
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV
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
#endif
