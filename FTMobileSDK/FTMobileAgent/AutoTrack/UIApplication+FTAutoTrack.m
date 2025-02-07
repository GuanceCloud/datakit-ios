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
#import "FTConstants.h"
#import "FTTrack.h"
@implementation UIApplication (FTAutoTrack)
#if TARGET_OS_IOS
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
        if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]){
            [[FTTrack sharedInstance].addRumDatasDelegate startAction:view.ft_actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:nil];
        }
    } else if ([event isKindOfClass:[UIEvent class]] && event.type == UIEventTypeTouches &&
               [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
        if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]){
            [[FTTrack sharedInstance].addRumDatasDelegate startAction:view.ft_actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:nil];

        }
    }
    
}
#elif TARGET_OS_TV
- (void)ft_sendEvent:(UIEvent *)event{
    [self ftSendEvent:event];
    [self ft_sendEvent:event];
}
// 处理 TVOS 点击事件
- (void)ftSendEvent:(UIEvent *)event{
    if (![event isKindOfClass:UIPressesEvent.class]) {
        return;
    }
    UIPressesEvent *pressEvent = (UIPressesEvent *)event;
    NSSet <UIPress *> *allPresses = pressEvent.allPresses;
    if(allPresses == nil||allPresses.count!=1){
        return;
    }
    UIPress *press = allPresses.anyObject;
    if(press.phase != UIPressPhaseEnded){
        return;
    }
    if(![press.responder isKindOfClass:UIView.class]){
        return;
    }
    UIView *view = (UIView *)press.responder;
    UIWindow *window = view.window;
    if (window == nil) {
        return;
    }
    if(![press.responder isKindOfClass:UIView.class]){
        return;
    }
    if([NSStringFromClass(view.class) containsString:@"Keyboard"]){
        return;
    }
    NSString *actionName = nil;
    switch (press.type) {
        case UIPressTypeSelect:
            actionName = view.ft_actionName;
            break;
        case UIPressTypeMenu:
            actionName = @"[menu]";
            break;
        case UIPressTypePlayPause:
            actionName = @"[play-pause]";
            break;
        default:
            return;
    }
    if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]){
        [[FTTrack sharedInstance].addRumDatasDelegate startAction:actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:nil];
    }
}
#endif
@end
