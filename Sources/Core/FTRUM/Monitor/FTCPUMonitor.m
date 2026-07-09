//
//  FTCPUMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/1.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTCPUMonitor.h"
#import "FTAppLifeCycle.h"
#import <mach/mach.h>
#import <assert.h>
#import <stdint.h>

static const uint64_t FTCPUTicksCounterRange = (uint64_t)UINT32_MAX + 1;

@interface FTCPUMonitor()<FTAppLifeCycleDelegate>
@property (nonatomic, assign)  uint64_t totalInactiveTicks;
@property (nonatomic, assign)  uint64_t utilizedTicksWhenResigningActive;
@property (nonatomic, assign)  uint64_t utilizedTicksRolloverOffset;
@property (nonatomic, assign)  uint32_t lastRawUtilizedTicks;
@property (nonatomic, assign)  BOOL hasUtilizedTicksWhenResigningActive;
@property (nonatomic, assign)  BOOL hasLastRawUtilizedTicks;

@end
@implementation FTCPUMonitor
-(instancetype)init{
    self = [super init];
    if (self) {
        self.totalInactiveTicks = 0;
        self.utilizedTicksWhenResigningActive = 0;
        self.utilizedTicksRolloverOffset = 0;
        self.lastRawUtilizedTicks = 0;
        self.hasUtilizedTicksWhenResigningActive = NO;
        self.hasLastRawUtilizedTicks = NO;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
- (double)readCpuUsage{
    uint64_t ticks = 0;
    double usage = -1;
    if ([self readUtilizedTicks:&ticks] && ticks>0) {
        uint64_t inactiveStartTicks = self.hasUtilizedTicksWhenResigningActive ? self.utilizedTicksWhenResigningActive : ticks;
        if (ticks < inactiveStartTicks) {
            return usage;
        }
        uint64_t ongoingInactiveTicks = ticks - inactiveStartTicks;
        if (UINT64_MAX - self.totalInactiveTicks < ongoingInactiveTicks) {
            return usage;
        }
        uint64_t inactiveTicks = self.totalInactiveTicks + ongoingInactiveTicks;
        if (ticks >= inactiveTicks) {
            usage = (double)(ticks - inactiveTicks);
        }
    }
    return usage;
}
//Total CPU usage
- (BOOL)readUtilizedTicks:(uint64_t *)ticks {
    uint32_t rawTicks = 0;
    if (![self readRawUtilizedTicks:&rawTicks]) {
        return NO;
    }

    if (self.hasLastRawUtilizedTicks && rawTicks < self.lastRawUtilizedTicks) {
        if (UINT64_MAX - self.utilizedTicksRolloverOffset < FTCPUTicksCounterRange) {
            return NO;
        }
        self.utilizedTicksRolloverOffset += FTCPUTicksCounterRange;
    }

    self.lastRawUtilizedTicks = rawTicks;
    self.hasLastRawUtilizedTicks = YES;
    if (ticks != NULL) {
        *ticks = self.utilizedTicksRolloverOffset + rawTicks;
    }
    return YES;
}

- (BOOL)readRawUtilizedTicks:(uint32_t *)rawTicks {
    kern_return_t kr;
    mach_msg_type_number_t count;
    host_cpu_load_info_data_t info;
    count = HOST_CPU_LOAD_INFO_COUNT;
    
    kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count);
    if (kr == KERN_SUCCESS) {
        if (rawTicks != NULL) {
            *rawTicks = (uint32_t)info.cpu_ticks[CPU_STATE_USER];
        }
        return YES;
    }
    return NO;
}

- (void)applicationDidBecomeActive{
    uint64_t currentTicks = 0;
    if (self.hasUtilizedTicksWhenResigningActive && [self readUtilizedTicks:&currentTicks]) {
        if (currentTicks >= self.utilizedTicksWhenResigningActive) {
            uint64_t inactiveTicks = currentTicks - self.utilizedTicksWhenResigningActive;
            if (UINT64_MAX - self.totalInactiveTicks >= inactiveTicks) {
                self.totalInactiveTicks += inactiveTicks;
            }
        }
        self.utilizedTicksWhenResigningActive = 0;
        self.hasUtilizedTicksWhenResigningActive = NO;
    }
}

- (void)applicationWillResignActive{
    uint64_t ticks = 0;
    self.hasUtilizedTicksWhenResigningActive = NO;
    if ([self readUtilizedTicks:&ticks]) {
        self.utilizedTicksWhenResigningActive = ticks;
        self.hasUtilizedTicksWhenResigningActive = YES;
    }
}
@end
