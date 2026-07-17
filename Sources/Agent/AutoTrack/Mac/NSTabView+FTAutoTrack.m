//
//  NSTabView+FTAutoTrack.m
//  FTSDK
//
//  Created by hulilei on 2021/9/26.
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
#import "NSTabView+FTAutoTrack.h"
#import "FTSwizzler.h"
#import "FTGlobalRumManager.h"
#import "NSView+FTAutoTrack.h"
#import "FTInnerLog.h"
#import "FTAutoTrack.h"
@implementation NSTabView (FTAutoTrack)
static void *FTMacTabViewDidSelectKey = &FTMacTabViewDidSelectKey;
-(NSString *)datakit_actionName{
    if(self.selectedTabViewItem.label.length>0){
        return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.selectedTabViewItem.label];
    }
    NSInteger index = [self indexOfTabViewItem:self.selectedTabViewItem];
    if(index != NSNotFound){
        return [NSString stringWithFormat:@"[%@]selectedIndex:%ld",NSStringFromClass(self.class),(long)index];
    }
    return [NSString stringWithFormat:@"[%@]",NSStringFromClass(self.class)];
}
-(void)datakit_setDelegate:(id<NSTabViewDelegate>)delegate{
    [self datakit_setDelegate:delegate];
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(tabView:didSelectTabViewItem:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        FTSwizzlerInstanceMethod(class,
                                 selector,
                                 FTSWReturnType(void),
                                 FTSWArguments(NSTabView *tabView, NSTabViewItem *tabViewItem),
                                 FTSWReplacement({
            FTSWCallOriginal(tabView, tabViewItem);
            if (tabView && tabViewItem) {
                [[FTAutoTrack sharedInstance] trackActionWithName:tabView.datakit_actionName];
            }
        }), FTSwizzlerModeOncePerClassAndSuperclasses, FTMacTabViewDidSelectKey);
    }
    
}

@end
#endif
