//
//  FTAutoTrack.m
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
#import "FTAutoTrack.h"
#import "FTInnerLog.h"
#import "FTSwizzle.h"
#import "NSWindow+FTAutoTrack.h"
#import "NSApplication+FTAutotrack.h"
#import "NSCollectionView+FTAutoTrack.h"
#import "NSTabView+FTAutoTrack.h"
#import "FTConstants.h"
@implementation FTAutoTrack

+ (instancetype)sharedInstance {
    static FTAutoTrack *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
- (void)startHookView:(BOOL)enableView action:(BOOL)enableAction{
    if(enableView){
        [self logWindowLifeCycle];
    }
    if(enableAction){
        [self logTargetAction];
    }
}
- (void)logWindowLifeCycle{
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error = NULL;
            [NSWindow ft_swizzleMethod:@selector(initWithCoder:) withMethod:@selector(datakit_initWithCoder:) error:&error];
            [NSWindow ft_swizzleMethod:@selector(initWithContentRect:styleMask:backing:defer:) withMethod:@selector(datakit_initWithContentRect:styleMask:backing:defer:) error:&error];
            [NSWindow ft_swizzleMethod:@selector(init) withMethod:@selector(datakit_init) error:&error];
            [NSWindow ft_swizzleMethod:@selector(resignKeyWindow) withMethod:@selector(datakit_resignKeyWindow) error:&error];
            [NSWindow ft_swizzleMethod:@selector(becomeKeyWindow) withMethod:@selector(datakit_becomeKeyWindow) error:&error];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }
}
- (void)logTargetAction{
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error = NULL;
            [NSApplication ft_swizzleMethod:@selector(sendAction:to:from:) withMethod:@selector(datakit_sendAction:to:from:) error:&error];
            [NSCollectionView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(datakit_setDelegate:) error:&error];
            [NSTabView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(datakit_setDelegate:) error:&error];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }
}
- (void)trackActionWithName:(NSString *)actionName {
    if (actionName.length == 0) {
        return;
    }
    if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]) {
        [self.addRumDatasDelegate startAction:actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:nil];
    }
}
@end
#endif
