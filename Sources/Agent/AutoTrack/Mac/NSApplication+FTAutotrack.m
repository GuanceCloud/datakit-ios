//
//  NSApplication+FTAutotrack.m
//  Pods
//
//  Created by hulilei on 2021/9/10.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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
#if TARGET_OS_OSX
#import "NSApplication+FTAutotrack.h"
#import "FTGlobalRumManager.h"
#import "NSView+FTAutoTrack.h"
#import "FTAutoTrack.h"
#import "NSMenuItem+FTAutoTrack.h"
@implementation NSApplication (FTAutotrack)
- (BOOL)datakit_sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender{
    [self datakitTrack:action to:target from:sender];
    return [self datakit_sendAction:action to:target from:sender];
}
- (void)datakitTrack:(SEL)action to:(id)target from:(id )sender{

    if (![sender isKindOfClass:[NSView class]] && ![sender isKindOfClass:[NSMenuItem class]] && ![sender isKindOfClass:[NSGestureRecognizer class]]) {
        return;
    }
    //Don't collect drag events
    if (self.currentEvent.type != NSEventTypeLeftMouseUp &&  self.currentEvent.type != NSEventTypeLeftMouseDown ) {
        return;
    }
    //Handle gesture events
    if ([sender isKindOfClass:NSGestureRecognizer.class]) {
        NSGestureRecognizer *ges = (NSGestureRecognizer *)sender;
        if (ges.state != NSGestureRecognizerStateEnded) {
            return;
        }
        NSView *view = ges.view;
        if([view isKindOfClass:[NSImageView class]]||[view isKindOfClass:[NSTextField class]]){
            [[FTAutoTrack sharedInstance] trackActionWithName:view.datakit_actionName];
        }
        return;
    }
    //NSMenu doesn't inherit from NSView
    if ([sender isKindOfClass:NSMenuItem.class]) {
        // Exclude NSPopUpButton popped NSMenuItem clicks to avoid duplication
        if(target != NULL && [target isKindOfClass:[NSPopUpButtonCell class]]){
            return;
        }
        NSMenuItem *menu = (NSMenuItem *)sender;
        [[FTAutoTrack sharedInstance] trackActionWithName:menu.datakit_actionName];
        return;
    }
    //Don't collect click events on scrollbars
    if ([sender isKindOfClass:NSScroller.class]){
        return;
    }
    //Filter NSTableView doubleAction
    if([sender isKindOfClass:NSTableView.class]){
        NSTableView *tableView = (NSTableView *)sender;
        if(action && tableView.doubleAction != tableView.action && tableView.doubleAction == action){
            return;
        }
    }
    NSView *view = sender;
    //Don't collect click events if view has no window
    if(!view.window){
        return;
    }
    NSString *actionName = view.datakit_actionName;
    // NSDatePicker
    if([sender isKindOfClass:NSDatePicker.class]){
        // Filter out NSEventTypeLeftMouseDown without action
        if( self.currentEvent.type == NSEventTypeLeftMouseDown && !action){
            return;
        }
        NSDatePicker *datePicker = (NSDatePicker *)view;
        if (action && datePicker.datePickerStyle == NSDatePickerStyleClockAndCalendar){
            actionName = [NSString stringWithFormat:@"[%@]%@",NSStringFromClass([sender class]),NSStringFromSelector(action)];
        }
    }
    //Filter NSComboBox dropdown selection box click events to avoid duplication
    if ([sender isKindOfClass:NSClassFromString(@"NSComboTableView")]){
        return;
    }
    //Filter NSSearchField cancel button multiple sendAction on single click, and distinguish between search button and cancel button
    if ([sender isKindOfClass:NSSearchField.class]) {
        if(!action){
            return;
        }
        actionName = [NSString stringWithFormat:@"[%@]%@",NSStringFromClass([sender class]),NSStringFromSelector(action)];
    }
    if([sender isKindOfClass:NSDatePicker.class] && action){
        actionName = [NSString stringWithFormat:@"[%@]%@",NSStringFromClass([sender class]),NSStringFromSelector(action)];
    }
    
    [[FTAutoTrack sharedInstance] trackActionWithName:actionName];
    
}
@end
#endif
