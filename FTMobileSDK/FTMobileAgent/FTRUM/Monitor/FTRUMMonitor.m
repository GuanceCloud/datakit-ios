//
//  FTRUMMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/19.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTRUMMonitor.h"
#import "FTDisplayRateMonitor.h"
#import "FTMemoryMonitor.h"
#import "FTCPUMonitor.h"
#import "FTEnumConstant.h"
@implementation FTRUMMonitor
- (instancetype)initWithMonitorType:(FTDeviceMetricsMonitorType)type frequency:(FTMonitorFrequency)frequency{
    self = [super init];
    if (self) {
        if (type & FTDeviceMetricsMonitorCpu) {
            self.cpuMonitor = [[FTCPUMonitor alloc]init];
        }
        if (type & FTDeviceMetricsMonitorFps) {
            self.displayMonitor = [[FTDisplayRateMonitor alloc]init];
        }
        if (type & FTDeviceMetricsMonitorMemory) {
            self.memoryMonitor = [[FTMemoryMonitor alloc] init];
        }
        _frequency = MonitorFrequencyMap[frequency];
    }
    return self;
}
@end
