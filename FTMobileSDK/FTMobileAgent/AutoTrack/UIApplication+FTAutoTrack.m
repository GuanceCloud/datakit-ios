//
//  UIApplication+AutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIApplication+FTAutoTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "UIView+FTAutoTrack.h"
#import "FTTrack.h"
@implementation UIApplication (FTAutoTrack)
-(BOOL)ft_sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event{
    [self ftTrack:action to:target from:sender forEvent:event];
    return [self ft_sendAction:action to:target from:sender forEvent:event];
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
        if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
            [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:view.ft_actionName];
        }
    } else if ([event isKindOfClass:[UIEvent class]] && event.type == UIEventTypeTouches &&
               [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
        if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
            [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:view.ft_actionName];
        }
    }
    
}
-(void)ft_sendEvent:(UIEvent *)event{
    [self ft_sendEvent:event];
}
@end
