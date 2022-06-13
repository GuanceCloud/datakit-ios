//
//  UIApplication+AutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIApplication+FTAutoTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "UIView+FTAutoTrack.h"
@implementation UIApplication (FTAutoTrack)
-(BOOL)dataflux_sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event{
    [self ftTrack:action to:target from:sender forEvent:event];
    return [self dataflux_sendAction:action to:target from:sender forEvent:event];
}
- (void)ftTrack:(SEL)action to:(id)target from:(id )sender forEvent:(UIEvent *)event {
   //过滤 底部导航 与 顶部导航 多余的点击事件，采集 UITabBarButton 与 _UIButtonBarButton
    if ([sender isKindOfClass:UITabBarItem.class] || [sender isKindOfClass:UIBarButtonItem.class]) {
        return;
    }
    if ([target isKindOfClass:UIViewController.class]) {
        if([target isBlackListContainsViewController]){
            return;
        }
    }
    if(![sender isKindOfClass:UIView.class]){
        return;
    }
    UIView *view = (UIView *)sender;
    if ([sender isKindOfClass:UISwitch.class] || [sender isKindOfClass:UIStepper.class] ||
        [sender isKindOfClass:UIPageControl.class]||[sender isKindOfClass:[UISegmentedControl class]]) {
        [[FTGlobalRumManager sharedInstance] addClickActionWithName:view.ft_actionName];
    } else if ([event isKindOfClass:[UIEvent class]] && event.type == UIEventTypeTouches &&
               [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
        [[FTGlobalRumManager sharedInstance] addClickActionWithName:view.ft_actionName];
    }
    
}
@end
