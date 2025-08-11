//
//  UIApplication+AutoTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIApplication+FTAutoTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "UIView+FTAutoTrack.h"
#import "FTConstants.h"
#import "FTAutoTrackHandler.h"
@implementation UIApplication (FTAutoTrack)
#if TARGET_OS_IOS
-(BOOL)ft_sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event{
    [self ftTrack:action to:target from:sender forEvent:event];
    return [self ft_sendAction:action to:target from:sender forEvent:event];
}
- (void)ftTrack:(SEL)action to:(id)target from:(id )sender forEvent:(UIEvent *)event {
   // Filter out redundant click events from the bottom and top navigation bars, only collect UITabBarButton and _UIButtonBarButton
    if ([sender isKindOfClass:UITabBarItem.class] || [sender isKindOfClass:UIBarButtonItem.class]) {
        return;
    }
    if ([target isKindOfClass:UIViewController.class]) {
        if([target isActionBlackListContainsViewController]){
            return;
        }
    }
    if(![sender isKindOfClass:UIView.class]){
        return;
    }
    UIView *view = (UIView *)sender;
    id<FTUIEventHandler> actionHandler = [FTAutoTrackHandler sharedInstance].actionHandler;
    if ([sender isKindOfClass:UISwitch.class] ||
        [sender isKindOfClass:UIStepper.class] ||
        [sender isKindOfClass:UIPageControl.class] ||
        [sender isKindOfClass:UISegmentedControl.class]) {
        if(actionHandler  && [actionHandler respondsToSelector:@selector(notify_sendAction:)]){
            [actionHandler notify_sendAction:view];
        }
    } else if ([event isKindOfClass:[UIEvent class]] && event.type == UIEventTypeTouches &&
               [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
        if(actionHandler  && [actionHandler respondsToSelector:@selector(notify_sendAction:)]){
            [actionHandler notify_sendAction:view];
        }
    }
    
}
#elif TARGET_OS_TV
- (void)ft_sendEvent:(UIEvent *)event{
    [self ftSendEvent:event];
    [self ft_sendEvent:event];
}
// Handle TVOS click events
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
    id<FTUIEventHandler> actionHandler = [FTAutoTrackHandler sharedInstance].actionHandler;
    if(actionHandler  && [actionHandler respondsToSelector:@selector(notify_sendActionWithPressType:view:)]){
        [actionHandler notify_sendActionWithPressType:press.type view:view];
    }
}
#endif
@end
