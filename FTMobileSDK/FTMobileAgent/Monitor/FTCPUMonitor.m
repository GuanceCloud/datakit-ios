//
//  FTCPUMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/1.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTCPUMonitor.h"
#import "FTAppLifeCycle.h"
#import <mach/mach.h>
#import <assert.h>
@interface FTCPUMonitor()<FTAppLifeCycleDelegate>
@property (nonatomic, assign)  natural_t totalInactiveTicks;
@property (nonatomic, assign)  natural_t utilizedTicksWhenResigningActive;

@end
@implementation FTCPUMonitor
-(instancetype)init{
    self = [super init];
    if (self) {
        self.totalInactiveTicks = 0;
        self.utilizedTicksWhenResigningActive = 0;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
- (double)readCpuUsage{
    natural_t ticks = [self readUtilizedTicks];
    if (ticks>0) {
        natural_t ongoingInactiveTicks = ticks - (self.utilizedTicksWhenResigningActive>0 ?: ticks);
        natural_t inactiveTicks = self.totalInactiveTicks + ongoingInactiveTicks;
        return ticks - inactiveTicks;
    }
    return -1;
}
//总的 cpu 占用率
- (natural_t)readUtilizedTicks {
    kern_return_t kr;
    mach_msg_type_number_t count;
    static host_cpu_load_info_data_t previous_info = {0, 0, 0, 0};
    host_cpu_load_info_data_t info;
    
    count = HOST_CPU_LOAD_INFO_COUNT;
    
    kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    natural_t user   = info.cpu_ticks[CPU_STATE_USER];

    previous_info    = info;

    return user;
}

- (void)applicationDidBecomeActive{
    natural_t currentTicks = [self readUtilizedTicks];
    if (currentTicks>0 && self.utilizedTicksWhenResigningActive>0) {
        self.totalInactiveTicks += currentTicks - self.utilizedTicksWhenResigningActive;
        self.utilizedTicksWhenResigningActive = 0;
    }
}

- (void)applicationWillResignActive{
    self.utilizedTicksWhenResigningActive = [self readUtilizedTicks];
}
@end
