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
- (void)ft_sendEvent:(UIEvent *)event{
    [self ftTrackTouchEvent:event];
    [self ft_sendEvent:event];
}
- (void)ftTrackTouchEvent:(UIEvent *)event {
    UITouch *touch = [self ft_touchFromEvent:event];
    if (!touch || touch.phase != UITouchPhaseEnded) {
        return;
    }
    UIView *touchView = touch.view;
    if (!touchView || [self ft_isViewInKeyboard:touchView] || [self ft_isActionBlacklistedForView:touchView]) {
        return;
    }
    UIView *actionTargetView = [self ft_actionTargetViewForTouchView:touchView];
    if (!actionTargetView) {
        return;
    }
    id<FTUIEventHandler> actionHandler = [FTAutoTrackHandler sharedInstance].actionHandler;
    NSValue *locationInHeatmapTargetView = [self ft_locationValueFromTouch:touch inView:touchView];
    if(actionHandler  && [actionHandler respondsToSelector:@selector(notify_sendAction:heatmapTargetView:locationInHeatmapTargetView:)]){
        [actionHandler notify_sendAction:actionTargetView heatmapTargetView:touchView locationInHeatmapTargetView:locationInHeatmapTargetView];
    } else if(actionHandler  && [actionHandler respondsToSelector:@selector(notify_sendAction:locationInView:)]){
        [actionHandler notify_sendAction:actionTargetView locationInView:locationInHeatmapTargetView];
    } else if(actionHandler  && [actionHandler respondsToSelector:@selector(notify_sendAction:)]){
        [actionHandler notify_sendAction:actionTargetView];
    }
}
- (UITouch *)ft_touchFromEvent:(UIEvent *)event {
    if (![event isKindOfClass:[UIEvent class]] || event.type != UIEventTypeTouches) {
        return nil;
    }
    NSSet<UITouch *> *allTouches = [event allTouches];
    if (allTouches.count != 1) {
        return nil;
    }
    return [allTouches anyObject];
}
- (NSValue *)ft_locationValueFromTouch:(UITouch *)touch inView:(UIView *)view {
    if (!touch || !view) {
        return nil;
    }
    return [NSValue valueWithCGPoint:[touch locationInView:view]];
}
- (UIView *)ft_actionTargetViewForTouchView:(UIView *)view {
    if ([view isKindOfClass:UIControl.class] || [view isAlertClick]) {
        return view;
    }
    UIView *targetView = view.superview;
    while (targetView) {
        if ([targetView isKindOfClass:UIControl.class] ||
            [targetView isKindOfClass:UITableViewCell.class] ||
            [targetView isKindOfClass:UICollectionViewCell.class] ||
            [targetView isAlertClick]) {
            return targetView;
        }
        targetView = targetView.superview;
    }
    return nil;
}
- (BOOL)ft_isActionBlacklistedForView:(UIView *)view {
    UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:UIViewController.class]) {
            UIViewController *viewController = (UIViewController *)responder;
            return [viewController isActionBlackListContainsViewController];
        }
        responder = responder.nextResponder;
    }
    return NO;
}
- (BOOL)ft_isViewInKeyboard:(UIView *)view {
    UIView *targetView = view;
    while (targetView) {
        if ([NSStringFromClass(targetView.class) containsString:@"Keyboard"]) {
            return YES;
        }
        targetView = targetView.superview;
    }
    return [NSStringFromClass(view.window.class) containsString:@"Keyboard"];
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
