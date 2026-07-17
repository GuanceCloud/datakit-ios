//
//  FTTestHelper.m
//  MacOSAppTests
//
//  Created by hulilei on 2023/5/9.
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

#import "FTTestHelper.h"
#include <Carbon/Carbon.h>
#import "LoginWindow.h"
#import "SplitViewVC.h"
#import "SplitViewItemVC2.h"
#import "TabViewController.h"
#import "MainWindow.h"
/**
 * View Tags:
 * Login Page NSSearchField: 50
 * Login Page LoginBtn: 100
 * TableView Item:
 *  AutoTrack   : 200
 *  RUM Data Collection  : 201
 *  Log Output     : 202
 *  Network Link Tracing  : 203
 *  Bind User     : 204
 *  Unbind User     : 205
 *  Console Log Collection: 206
 *  TabViewItem: 300
 *  CollectionViewItem:305-310
 *  NSPopUpButton: 320
 *  NSComboBox:    321
 *  NSButton-Check: 322
 */
void PostMouseEvent(CGMouseButton button, CGEventType type, const CGPoint point, int64_t clickCount)
{
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    CGEventRef theEvent = CGEventCreateMouseEvent(source, type, point, button);
    CGEventSetIntegerValueField(theEvent, kCGMouseEventPressure, clickCount);
    CGEventSetType(theEvent, type);
    CGEventPost(kCGHIDEventTap, theEvent);
    CFRelease(theEvent);
    CFRelease(source);
}
void dPostKeyboardEvent(CGKeyCode virtualKey, bool keyDown, CGEventFlags flags)
{
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    CGEventRef push = CGEventCreateKeyboardEvent(source, virtualKey, keyDown);
    CGEventSetFlags(push, flags);
    CGEventPost(kCGHIDEventTap, push);
    CFRelease(push);
    CFRelease(source);
}
@interface FTTestHelper()<NSComboBoxDelegate>
@property (nonatomic, strong) XCTestExpectation *popBtnExpectation;
@end
@implementation FTTestHelper
- (void)clickView:(TestClickView)view{
    NSView *clickView;
    NSWindow *keyWindow = [NSApplication sharedApplication].keyWindow;
    if(!keyWindow){
        return;
    }
    CGPoint offset = CGPointZero;
    switch (view) {
        case ClickTabViewItem_First:
            clickView = [keyWindow.contentView viewWithTag:ClickTabViewItem_First];
            offset = CGPointMake(-60, 45);
            break;
        case ClickTabViewItem_Second:
            clickView = [keyWindow.contentView viewWithTag:ClickTabViewItem_First];
            offset = CGPointMake(0, 45);
            break;
        case ClickTabViewItem_Third:
            clickView = [keyWindow.contentView viewWithTag:ClickTabViewItem_First];
            offset = CGPointMake(60, 45);
            break;
        case ClickPopUpButton:
            clickView = [keyWindow.contentView viewWithTag:view];
            break;
        case ClickComboBox:
            clickView = [keyWindow.contentView viewWithTag:view];
            offset = CGPointMake(clickView.frame.size.width/2-10, 0);
            break;
        default:
            clickView = [keyWindow.contentView viewWithTag:view];
            break;
    }
    if(clickView){
        if(view == ClickPopUpButton){
            NSPopUpButton *button = (NSPopUpButton *)clickView;
            CGPoint point =  [self getViewPointInWindow:clickView offset:offset];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSelectPopBtn:) name:NSPopUpButtonWillPopUpNotification object:button];
            [self clickAtPoint:point];
            self.popBtnExpectation = [self expectationWithDescription:@"Asynchronous operation timeout"];
            [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
                XCTAssertNil(error);
            }];
        }else if(view == ClickComboBox){
            NSComboBox *box = (NSComboBox *)clickView;
            box.delegate = self;
            CGPoint point =  [self getViewPointInWindow:clickView offset:offset];
            self.popBtnExpectation = [self expectationWithDescription:@"Asynchronous operation timeout"];
            [self clickAtPoint:point];
            [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
                XCTAssertNil(error);
            }];
        }else{
            [self clickAtView:clickView offset:offset];
        }
    }
    
}
- (void)comboBoxWillPopUp:(NSNotification *)notification{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        CGPoint point =  [self getViewPointInWindow:notification.object offset:CGPointMake(0, 20)];
        [self clickAtPoint:point];
        [self.popBtnExpectation fulfill];
    });
}
- (void)handleSelectPopBtn:(NSNotification *)notification{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGPoint point =  [self getViewPointInWindow:notification.object offset:CGPointMake(0, 20)];
        [self clickAtPoint:point];
        [self.popBtnExpectation fulfill];
        self.popBtnExpectation = nil;
    });

}
- (CGPoint)getViewPointInWindow:(NSView *)view offset:(CGPoint)offset{
    NSRect rect = [NSScreen mainScreen].frame;
    NSWindow *window = view.window;
    NSRect viewRect = [view convertRect:view.bounds toView:window.contentViewController.view];
    CGFloat y =  rect.size.height - window.frame.origin.y - window.frame.size.height;
    if (![window.contentView isFlipped]){
        viewRect.origin.y = window.frame.size.height - viewRect.origin.y - viewRect.size.height;
    }
    CGPoint clickPoint = CGPointMake(window.frame.origin.x + viewRect.origin.x +viewRect.size.width/2+offset.x, y+viewRect.origin.y+viewRect.size.height/2+offset.y);
    return clickPoint;
}
- (void)clickAtView:(NSView *)view{
    [self clickAtView:view offset:CGPointZero];
}
- (void)clickAtView:(NSView *)view offset:(CGPoint)offset{
    CGPoint clickPoint = [self getViewPointInWindow:view offset:offset];
    [self sleep:0.5];
    [self clickAtPoint:clickPoint];
}
- (void)clickAtPoint:(CGPoint)clickPoint{
    PostMouseEvent(kCGMouseButtonLeft, kCGEventLeftMouseDown, clickPoint, 1);
    PostMouseEvent(kCGMouseButtonLeft, kCGEventLeftMouseUp, clickPoint, 1);
}
- (void)sleep:(NSInteger)time{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Asynchronous operation timeout"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:time+1 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)jumpToMainTestWindow{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    NSArray *array = [NSApplication sharedApplication].windows;
    for (NSWindow *window in array) {
        if([window isKindOfClass:LoginWindow.class]){
            [window becomeKeyWindow];
            NSSearchField *search = [window.contentView viewWithTag:50];
            search.stringValue = @"asd";
            NSView *view = [window.contentView viewWithTag:100];
            [self clickAtView:view];
            [self sleep:1];
            break;
        }else if ([window.contentViewController isKindOfClass:[SplitViewVC class]]){
            [window becomeKeyWindow];
            break;
        }
    }
}
@end
