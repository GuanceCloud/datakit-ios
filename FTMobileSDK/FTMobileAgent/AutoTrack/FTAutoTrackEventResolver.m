//
//  FTAutoTrackEventResolver.m
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import "FTAutoTrackEventResolver.h"
#import "UIView+FTAutoTrack.h"

#if TARGET_OS_IOS
@implementation FTAutoTrackActionEvent

- (instancetype)initWithActionTargetView:(UIView *)actionTargetView
                       heatmapTargetView:(UIView *)heatmapTargetView
                        locationResolver:(FTHeatmapLocationResolver)locationResolver {
    self = [super init];
    if (self) {
        _actionTargetView = actionTargetView;
        _heatmapTargetView = heatmapTargetView;
        _locationResolver = [locationResolver copy];
    }
    return self;
}

@end
#endif

#if TARGET_OS_TV
@implementation FTAutoTrackPressEvent

- (instancetype)initWithPressType:(UIPressType)pressType targetView:(UIView *)targetView {
    self = [super init];
    if (self) {
        _pressType = pressType;
        _targetView = targetView;
    }
    return self;
}

@end
#endif

@implementation FTAutoTrackEventResolver

#if TARGET_OS_IOS
+ (nullable FTAutoTrackActionEvent *)actionEventFromTouchEvent:(UIEvent *)event {
    UITouch *touch = [self touchFromEvent:event];
    if (!touch || touch.phase != UITouchPhaseEnded) {
        return nil;
    }
    UIView *touchView = touch.view;
    if (!touchView || [self isViewInKeyboard:touchView]) {
        return nil;
    }
    UIView *actionTargetView = [self actionTargetViewForTouchView:touchView];
    if (!actionTargetView) {
        return nil;
    }
    FTHeatmapLocationResolver locationResolver = ^CGPoint(UIView *targetView) {
        return [touch locationInView:targetView];
    };
    return [[FTAutoTrackActionEvent alloc]initWithActionTargetView:actionTargetView heatmapTargetView:touchView locationResolver:locationResolver];
}

+ (nullable UITouch *)touchFromEvent:(UIEvent *)event {
    if (![event isKindOfClass:UIEvent.class] || event.type != UIEventTypeTouches) {
        return nil;
    }
    NSSet<UITouch *> *allTouches = [event allTouches];
    if (allTouches.count != 1) {
        return nil;
    }
    return [allTouches anyObject];
}

+ (nullable UIView *)actionTargetViewForTouchView:(UIView *)view {
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
#endif

#if TARGET_OS_TV
+ (nullable FTAutoTrackPressEvent *)pressEventFromEvent:(UIEvent *)event {
    if (![event isKindOfClass:UIPressesEvent.class]) {
        return nil;
    }
    UIPressesEvent *pressEvent = (UIPressesEvent *)event;
    NSSet<UIPress *> *allPresses = pressEvent.allPresses;
    if (allPresses == nil || allPresses.count != 1) {
        return nil;
    }
    UIPress *press = allPresses.anyObject;
    if (press.phase != UIPressPhaseEnded) {
        return nil;
    }
    if (![press.responder isKindOfClass:UIView.class]) {
        return nil;
    }
    UIView *view = (UIView *)press.responder;
    if (view.window == nil || [self isViewInKeyboard:view]) {
        return nil;
    }
    return [[FTAutoTrackPressEvent alloc]initWithPressType:press.type targetView:view];
}
#endif

+ (BOOL)isViewInKeyboard:(UIView *)view {
    return [NSStringFromClass(view.window.class) containsString:@"Keyboard"];
}

@end
