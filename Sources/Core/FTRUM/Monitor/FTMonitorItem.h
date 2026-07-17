//
//  FTMonitorItem.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/6.
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

#import <Foundation/Foundation.h>
#import "FTReadWriteHelper.h"
NS_ASSUME_NONNULL_BEGIN
@class FTDisplayRateMonitor,FTCPUMonitor,FTMemoryMonitor,FTMonitorValue;
/// Monitoring item, each ViewHandler in RUM contains a monitoring item to monitor data during the View lifecycle (memory, CPU, fps)
@interface FTMonitorItem : NSObject
/// fps monitor
@property (nonatomic, strong) FTDisplayRateMonitor *displayRateMonitor;
/// cpu monitor
@property (nonatomic, strong) FTCPUMonitor *cpuMonitor;
/// memory monitor
@property (nonatomic, strong) FTMemoryMonitor *memoryMonitor;

/// Monitoring item initialization method
/// - Parameters:
///   - cpuMonitor: cpu monitor
///   - memoryMonitor: memory monitor
///   - displayRateMonitor: fps monitor
///   - frequency: sampling frequency
- (instancetype)initWithCpuMonitor:(FTCPUMonitor *)cpuMonitor memoryMonitor:(FTMemoryMonitor *)memoryMonitor displayRateMonitor:(FTDisplayRateMonitor *)displayRateMonitor frequency:(NSTimeInterval)frequency;
/// Get fps data
- (FTMonitorValue *)refreshDisplay;
/// Get cpu data
- (FTMonitorValue *)cpu;
/// Get memory data
- (FTMonitorValue *)memory;

@end

NS_ASSUME_NONNULL_END
