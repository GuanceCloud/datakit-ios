//
//  FTRUMAppStateHistory.m
//  FTMobileSDK
//
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

#import "FTRUMAppStateHistory.h"
#import "FTAppLifeCycle.h"
#import "NSDate+FTUtil.h"
#import <limits.h>

@interface FTRUMAppStateHistory () <FTAppLifeCycleDelegate>
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *transitions;
@property (nonatomic, assign) BOOL epochComparable;
@property (nonatomic, assign) FTRUMAppState lifecycleState;
@property (nonatomic, assign) BOOL monitoring;
@end

@implementation FTRUMAppStateHistory

- (instancetype)initWithState:(NSString *)state timeNs:(long long)timeNs {
    self = [super init];
    if (self) {
        _transitions = [NSMutableArray array];
        _epochComparable = YES;
        _lifecycleState = FTRUMAppStateFromString(state);
        [self recordState:state timeNs:timeNs];
    }
    return self;
}

- (void)startMonitoring {
    @synchronized (self) {
        if (self.monitoring) return;
        self.monitoring = YES;
        [[FTAppLifeCycle sharedInstance] insertAppLifecycleDelegate:self];
    }
}

- (void)stopMonitoring {
    @synchronized (self) {
        self.monitoring = NO;
        [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    }
}

- (NSDate *)lifecycleDate {
    return [NSDate date];
}

- (BOOL)isTimeComparable {
    @synchronized (self) {
        return self.epochComparable;
    }
}

- (void)recordLifecycleState:(FTRUMAppState)state time:(NSDate *)time {
    @synchronized (self) {
        if (!self.monitoring) return;
        if (![self recordState:FTStringFromRUMAppState(state) timeNs:[time ft_nanosecondTimeStamp]]) return;
        self.lifecycleState = state;
    }
    [self.delegate appStateHistory:self didChangeState:state time:time];
}

- (void)applicationDidBecomeActive {
    NSDate *time = [self lifecycleDate];
    @synchronized (self) {
        if (self.lifecycleState == FTRUMAppStateForegroundOnly) return;
    }
    [self recordLifecycleState:FTRUMAppStateForegroundOnly time:time];
}

#if FT_HAS_UIKIT
- (void)applicationWillEnterForeground {
    NSDate *time = [self lifecycleDate];
    [self recordLifecycleState:FTRUMAppStateForegroundOnly time:time];
}

- (void)applicationDidEnterBackground {
    NSDate *time = [self lifecycleDate];
    [self recordLifecycleState:FTRUMAppStateBackgroundOnly time:time];
}
#endif

- (void)applicationWillResignActive {
#if FT_HOST_MAC
    NSDate *time = [self lifecycleDate];
    [self recordLifecycleState:FTRUMAppStateUnknown time:time];
#endif
}

- (void)dealloc {
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}

- (BOOL)recordState:(NSString *)state timeNs:(long long)timeNs {
    @synchronized (self) {
        if (timeNs <= 0) return NO;
        NSDictionary *last = self.transitions.lastObject;
        if (last && timeNs < [last[@"time"] longLongValue]) {
            self.epochComparable = NO;
            return YES;
        }
        NSString *normalized = ([state isEqualToString:@"foreground"] || [state isEqualToString:@"background"])
            ? state : @"unknown";
        if (last && timeNs == [last[@"time"] longLongValue]) {
            self.transitions[self.transitions.count - 1] = @{@"state": normalized, @"time": @(timeNs)};
        } else {
            [self.transitions addObject:@{@"state": normalized, @"time": @(timeNs)}];
        }
        if (self.transitions.count > 128) {
            [self.transitions removeObjectAtIndex:0];
        }
        return YES;
    }
}

- (NSString *)stateAt:(long long)timeNs {
    if (timeNs <= 0) return @"unknown";
    @synchronized (self) {
        if (!self.epochComparable) return @"unknown";
        if (self.transitions.count == 0 || timeNs < [self.transitions.firstObject[@"time"] longLongValue]) return @"unknown";
        NSString *state = @"unknown";
        for (NSDictionary *transition in self.transitions) {
            if ([transition[@"time"] longLongValue] > timeNs) break;
            state = transition[@"state"];
        }
        return state;
    }
}

- (NSString *)stateFrom:(long long)startNs duration:(long long)durationNs {
    if (durationNs <= 0 || startNs <= 0 || startNs > LLONG_MAX - durationNs) return @"unknown";
    return [self stateFrom:startNs to:startNs + durationNs];
}

- (NSString *)stateFrom:(long long)startNs to:(long long)endNs {
    if (startNs <= 0 || endNs <= startNs) {
        return @"unknown";
    }
    @synchronized (self) {
        if (!self.epochComparable) return @"unknown";
        if (self.transitions.count == 0 || startNs < [self.transitions.firstObject[@"time"] longLongValue]) {
            return @"unknown";
        }
        NSString *current = @"unknown";
        BOOL foreground = NO;
        BOOL background = NO;
        for (NSDictionary *transition in self.transitions) {
            long long time = [transition[@"time"] longLongValue];
            if (time >= endNs) {
                break;
            }
            if (time <= startNs) {
                current = transition[@"state"];
                continue;
            }
            foreground |= [current isEqualToString:@"foreground"];
            background |= [current isEqualToString:@"background"];
            current = transition[@"state"];
        }
        foreground |= [current isEqualToString:@"foreground"];
        background |= [current isEqualToString:@"background"];
        if (foreground && background) {
            return @"foreground_and_background";
        }
        if (foreground) return @"foreground";
        return background ? @"background" : @"unknown";
    }
}
@end
