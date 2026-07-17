//
//  NSWindow+FTAutoTrack.m
//  FTSDK
//
//  Created by hulilei on 2021/9/9.
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
#import "NSWindow+FTAutoTrack.h"
#import "FTAutoTrackProtocol.h"
#import "FTSwizzler.h"
#import "FTConstants.h"
#import <objc/runtime.h>
#import "FTGlobalRumManager.h"
#import "FTAutoTrack.h"
@implementation NSWindow (FTAutoTrack)
#pragma mark - Rum Data -
static char *viewLoadStartTimeKey = "viewLoadStartTimeKey";
static char *viewLoadDuration = "viewLoadDuration";
static char *viewControllerUUID = "viewControllerUUID";
-(void)setDatakit_viewLoadStartTime:(NSDate *)datakit_viewLoadStartTime{
    objc_setAssociatedObject(self, &viewLoadStartTimeKey, datakit_viewLoadStartTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSDate *)datakit_viewLoadStartTime{
    return objc_getAssociatedObject(self, &viewLoadStartTimeKey);
}
-(NSNumber *)datakit_loadDuration{
    return objc_getAssociatedObject(self, &viewLoadDuration);
}
-(void)setDatakit_loadDuration:(NSNumber *)datakit_loadDuration{
    objc_setAssociatedObject(self, &viewLoadDuration, datakit_loadDuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSString *)datakit_viewUUID{
    return objc_getAssociatedObject(self, &viewControllerUUID);
}
-(void)setDatakit_viewUUID:(NSString *)datakit_viewUUID{
    objc_setAssociatedObject(self, &viewControllerUUID, datakit_viewUUID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
-(NSString *)datakit_windowName{
    if(self.contentViewController){
        return NSStringFromClass(self.contentViewController.class);
    }
    if(self.windowController){
        return NSStringFromClass(self.windowController.class);
    }
    return NSStringFromClass(self.class);
}
#pragma mark - AutoTrack -

-(instancetype)datakit_init{
    NSWindow *win = [self datakit_init];
    self.datakit_viewLoadStartTime = [NSDate date];
    return win;
}
-(instancetype)datakit_initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag{
    NSWindow *win = [self datakit_initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag];
    self.datakit_viewLoadStartTime = [NSDate date];
    return win;
}
- (instancetype)datakit_initWithCoder:(NSCoder *)coder{
    NSWindow *win = [self datakit_initWithCoder:coder];
    self.datakit_viewLoadStartTime = [NSDate date];
    return win;
}
-(void)datakit_becomeKeyWindow{
    [self datakit_becomeKeyWindow];
    //window
    //Record the time difference between init - keyWindow as window display loading duration
    //Only record the first time becoming keyWindow
    if(self.datakit_viewLoadStartTime){
        self.datakit_loadDuration = @((long long)([[NSDate date] timeIntervalSinceDate:self.datakit_viewLoadStartTime] * 1000000000.0));
        self.datakit_viewLoadStartTime = nil;
        if([self isKindOfClass:NSPanel.class]){
            NSPanel *panel = (NSPanel *)self;
            if(panel.becomesKeyOnlyIfNeeded){
                self.datakit_loadDuration = @0;
            }
        }
    }
    self.datakit_viewUUID = [NSUUID UUID].UUIDString;
    if([FTAutoTrack sharedInstance].addRumDatasDelegate){
        if([self.datakit_loadDuration intValue]>0){
            if( [[FTAutoTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(onCreateView:loadTime:)]){
                [[FTAutoTrack sharedInstance].addRumDatasDelegate onCreateView:self.datakit_windowName loadTime:self.datakit_loadDuration];
            }
        }
        if( [[FTAutoTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(startViewWithName:)]){
            [[FTAutoTrack sharedInstance].addRumDatasDelegate startViewWithName:self.datakit_windowName];
        }
    }
}
-(void)datakit_resignKeyWindow{
    [self datakit_resignKeyWindow];
    if([self isKindOfClass:NSClassFromString(@"NSPopupMenuWindow")]){
        return;
    }
    if([FTAutoTrack sharedInstance].addRumDatasDelegate && [[FTAutoTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(stopView)]){
        [[FTAutoTrack sharedInstance].addRumDatasDelegate stopView];
    }
}
@end
#endif
