//
//  FTRUMMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/19.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import "FTSDKCompat.h"
#import "FTRUMMonitor.h"
#import "FTDisplayRateMonitor.h"
#import "FTMemoryMonitor.h"
#import "FTCPUMonitor.h"
@implementation FTRUMMonitor
- (instancetype)initWithMonitorType:(DeviceMetricsMonitorType)type frequency:(MonitorFrequency)frequency{
    self = [super init];
    if (self) {
        if (type & DeviceMetricsMonitorCpu) {
            self.cpuMonitor = [[FTCPUMonitor alloc]init];
        }
#if !FT_MAC
        if (type & DeviceMetricsMonitorFps) {
            self.displayMonitor = [[FTDisplayRateMonitor alloc]init];
        }
#endif
        if (type & DeviceMetricsMonitorMemory) {
            self.memoryMonitor = [[FTMemoryMonitor alloc] init];
        }
        _frequency = MonitorFrequencyMap[frequency];
    }
    return self;
}
@end
