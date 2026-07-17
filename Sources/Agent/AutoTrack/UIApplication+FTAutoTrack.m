//
//  UIApplication+AutoTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/21.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
#endif
