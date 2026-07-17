//
//  FTRUMMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/19.
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
#import "FTInternalConstants.h"
@class FTDisplayRateMonitor,FTMemoryMonitor,FTCPUMonitor;

NS_ASSUME_NONNULL_BEGIN
/// RUM monitor
@interface FTRUMMonitor : NSObject
/// FPS monitor
@property (nonatomic, strong) FTDisplayRateMonitor * _Nullable displayMonitor;
/// Memory monitor
@property (nonatomic, strong) FTMemoryMonitor *_Nullable memoryMonitor;
/// CPU monitor
@property (nonatomic, strong) FTCPUMonitor *_Nullable cpuMonitor;
/// Monitoring frequency
@property (nonatomic, assign) NSTimeInterval frequency;
/// Initialization method
///
/// Initialize corresponding monitors based on MonitorType. Monitors in each monitoring item are obtained from this class.
/// - Parameters:
///   - type: Supported device monitoring types
///   - frequency: Monitoring frequency
- (instancetype)initWithMonitorType:(DeviceMetricsMonitorType)type frequency:(MonitorFrequency)frequency;
@end

NS_ASSUME_NONNULL_END
