//
//  FTRUMMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/19.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
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
