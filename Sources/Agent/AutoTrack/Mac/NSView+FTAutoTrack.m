//
//  NSView+FTAutoTrack.m
//  Pods
//
//  Created by hulilei on 2021/9/15.
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
#import "NSView+FTAutoTrack.h"

@implementation NSView (FTAutoTrack)
//-(NSString *)datakit_viewPath{
//    NSMutableString *str = [NSMutableString new];
//    [str appendString:NSStringFromClass([self class])];
//    NSView *currentView = self;
//    NSView *parentView = [currentView superview];
//    __block NSInteger index = 0;
//    [parentView.subviews enumerateObjectsUsingBlock:^(__kindof NSView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        if([obj isEqual:currentView]){
//        index = idx;
//        *stop = YES;
//        }
//    }];
//    [str appendFormat:@"[%ld]",(long)index];
//
//    while (![currentView isKindOfClass:[NSView class]]) {
//        currentView = [currentView superview];
//        if (!currentView) {
//            break;
//        }
//        [str insertString:[NSString stringWithFormat:@"%@/",NSStringFromClass([currentView class])] atIndex:0];
//    }
//
//    NSWindow *window = self.window;
//    window?[str insertString:[NSString stringWithFormat:@"%@/",NSStringFromClass(window.class)] atIndex:0]:nil;
//    return str;
//}
-(NSString *)datakit_actionName{
    // When NSToolBar is clicked, sender is private view NSToolbarItemViewer, can be distinguished by toolTip
    return self.toolTip?[NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.toolTip]:[NSString stringWithFormat:@"[%@]",NSStringFromClass(self.class)];
}

//-(id)datakit_controller{
//    NSResponder *nextResponder = self.nextResponder;
//    while (nextResponder != nil) {
//        // When getting view's viewcontroller, don't consider NSCollectionViewItem
//       if ([nextResponder isKindOfClass:NSViewController.class]&&![nextResponder isKindOfClass:NSCollectionViewItem.class]) {
//            break;
//        }else if([nextResponder isKindOfClass:NSPanel.class]){
//            nextResponder = [NSApplication sharedApplication].keyWindow.contentViewController?:[NSApplication sharedApplication].keyWindow;
//            break;
//        }else if([nextResponder isKindOfClass:NSWindow.class]){
//            break;
//        }else{
//            nextResponder = nextResponder.nextResponder;
//        }
//    }
//    return nextResponder;
//}
@end

@implementation NSPopUpButton (FTAutoTrack)
-(NSString *)datakit_actionName{
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.selectedItem.title];
}
@end
@implementation NSButton (FTAutoTrack)
-(NSString *)datakit_actionName{
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.title];
}
@end

@implementation NSSegmentedControl (FTAutoTrack)

-(NSString *)datakit_actionName{
    NSString *title = [self labelForSegment:self.selectedSegment];
    if(!title||title.length==0){
        NSMenu *menu = [self menuForSegment:self.selectedSegment];
        if(menu && menu.title){
            title = menu.title;
        }else{
            title = [NSString stringWithFormat:@"%ld",(long)self.selectedSegment];
        }
    }
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),title];
}
@end

@implementation NSStepper (FTAutoTrack)

-(NSString *)datakit_actionName{
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.stringValue];
}
@end
@implementation NSSlider (FTAutoTrack)

-(NSString *)datakit_actionName{
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.stringValue];
}
@end

@implementation NSComboBox (FTAutoTrack)

-(NSString *)datakit_actionName{
    return self.stringValue?[NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.stringValue]:super.datakit_actionName;
}

@end

@implementation NSSwitch (FTAutoTrack)

-(NSString *)datakit_actionName{
    NSString *title = self.state == NSControlStateValueOff ?@"Off":@"On";
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),title];
}

@end

@implementation NSTextField (FTAutoTrack)

-(NSString *)datakit_actionName{
    if([self isKindOfClass:[NSSecureTextField class]]){
        return [NSString stringWithFormat:@"[%@]",NSStringFromClass(self.class)];
    }
    return self.stringValue?[NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.stringValue]:super.datakit_actionName;
}

@end
@implementation NSDatePicker (FTAutoTrack)

-(NSString *)datakit_actionName{
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.dateValue];
}

@end

#endif
