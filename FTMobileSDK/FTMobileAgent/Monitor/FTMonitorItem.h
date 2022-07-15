//
//  FTMonitorItem.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/6.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTReadWriteHelper.h"
NS_ASSUME_NONNULL_BEGIN
@class FTDisplayRateMonitor,FTCPUMonitor,FTMemoryMonitor,FTMonitorValue;
@interface FTMonitorItem : NSObject
@property (nonatomic, strong) FTDisplayRateMonitor *displayRateMonitor;
@property (nonatomic, strong) FTCPUMonitor *cpuMonitor;
@property (nonatomic, strong) FTMemoryMonitor *memoryMonitor;

- (instancetype)initWithCpuMonitor:(FTCPUMonitor *)cpuMonitor memoryMonitor:(FTMemoryMonitor *)memoryMonitor displayRateMonitor:(FTDisplayRateMonitor *)displayRateMonitor;
- (FTMonitorValue *)refreshDisplay;
- (FTMonitorValue *)cpu;
- (FTMonitorValue *)memory;

@end

NS_ASSUME_NONNULL_END
