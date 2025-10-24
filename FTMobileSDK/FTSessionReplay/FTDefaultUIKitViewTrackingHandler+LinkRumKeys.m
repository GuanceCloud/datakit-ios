//
//  FTDefaultUIKitViewTrackingHandler+LinkRumKeys.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/10/21.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDefaultUIKitViewTrackingHandler+LinkRumKeys.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTWKWebViewHandler+Private.h"
@interface FTDefaultUIKitViewTrackingHandler()
@end
@implementation FTDefaultUIKitViewTrackingHandler (LinkRumKeys)

- (FTRUMView *)createRUMView:(UIViewController *)viewController{
    FTRUMView *rumView = [[FTRUMView alloc]initWithViewName:viewController.ft_viewControllerName];
    NSDictionary *linked = [[FTWKWebViewHandler sharedInstance].linkRumInfos objectForKey:viewController];
    if (linked){
        rumView.property = linked;
    }
    return rumView;
}
@end
