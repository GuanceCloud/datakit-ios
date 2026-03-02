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
@interface FTRUMMonitor()
@property (nonatomic, assign) DeviceMetricsMonitorType type;
@end
@implementation FTRUMMonitor
- (instancetype)initWithMonitorType:(DeviceMetricsMonitorType)type frequency:(MonitorFrequency)frequency{
    self = [super init];
    if (self) {
        if (type & DeviceMetricsMonitorCpu) {
            self.cpuMonitor = [[FTCPUMonitor alloc]init];
        }
        if (type & DeviceMetricsMonitorMemory) {
            self.memoryMonitor = [[FTMemoryMonitor alloc] init];
        }
        _type = type;
        _frequency = MonitorFrequencyMap[frequency];
    }
    return self;
}
-(void)setDisplayMonitor:(FTDisplayRateMonitor *)displayMonitor{
    if (self.type & DeviceMetricsMonitorFps) {
        _displayMonitor = displayMonitor;
        [displayMonitor start];
    }
}
@end
