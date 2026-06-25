//
//  UIApplication+AutoTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIApplication+FTAutoTrack.h"
#import "FTAutoTrackHandler.h"
#import "FTAutoTrackEventResolver.h"
@implementation UIApplication (FTAutoTrack)
#if TARGET_OS_IOS
- (void)ft_sendEvent:(UIEvent *)event{
    [self ftTrackTouchEvent:event];
    [self ft_sendEvent:event];
}
- (void)ftTrackTouchEvent:(UIEvent *)event {
    FTAutoTrackActionEvent *actionEvent = [FTAutoTrackEventResolver actionEventFromTouchEvent:event];
    if (!actionEvent) {
        return;
    }
    id<FTUIEventHandler> actionHandler = [FTAutoTrackHandler sharedInstance].actionHandler;
    if(actionHandler){
        [actionHandler notify_sendAction:actionEvent.actionTargetView heatmapTargetView:actionEvent.heatmapTargetView locationResolver:actionEvent.locationResolver];
    }
}
#elif TARGET_OS_TV
- (void)ft_sendEvent:(UIEvent *)event{
    [self ftSendEvent:event];
    [self ft_sendEvent:event];
}
// Handle TVOS click events
- (void)ftSendEvent:(UIEvent *)event{
    FTAutoTrackPressEvent *pressEvent = [FTAutoTrackEventResolver pressEventFromEvent:event];
    if (!pressEvent) {
        return;
    }
    id<FTUIEventHandler> actionHandler = [FTAutoTrackHandler sharedInstance].actionHandler;
    if(actionHandler){
        [actionHandler notify_sendActionWithPressType:pressEvent.pressType view:pressEvent.targetView];
    }
}
#endif
@end
