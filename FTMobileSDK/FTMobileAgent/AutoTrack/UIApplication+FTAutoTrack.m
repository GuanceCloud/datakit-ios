//
//  UIApplication+AutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIApplication+FTAutoTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTMonitorManager.h"
@implementation UIApplication (FTAutoTrack)
-(BOOL)dataflux_sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event{
    [self ftTrack:action to:target from:sender forEvent:event];
    return [self dataflux_sendAction:action to:target from:sender forEvent:event];
}
- (void)ftTrack:(SEL)action to:(id)target from:(id )sender forEvent:(UIEvent *)event {
    if ([sender isKindOfClass:UITabBarItem.class] || [sender isKindOfClass:UIBarButtonItem.class]) {
        return;
    }
    if ([target isKindOfClass:UIViewController.class]) {
        if([target isBlackListContainsViewController]){
            return;
        }
    }
    
    if ([sender isKindOfClass:UISwitch.class] || [sender isKindOfClass:UIStepper.class] ||
        [sender isKindOfClass:UIPageControl.class]||[sender isKindOfClass:[UISegmentedControl class]]) {
        [[FTMonitorManager sharedInstance] trackClickWithView:sender];
    } else if ([event isKindOfClass:[UIEvent class]] && event.type == UIEventTypeTouches &&
               [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
        [[FTMonitorManager sharedInstance] trackClickWithView:sender];
    }
    
}
@end
