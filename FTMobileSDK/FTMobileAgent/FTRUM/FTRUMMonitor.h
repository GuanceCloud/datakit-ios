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
/// RUM 监控器
@interface FTRUMMonitor : NSObject
/// fps 监控器
@property (nonatomic, strong) FTDisplayRateMonitor * _Nullable displayMonitor;
/// memory 监控器
@property (nonatomic, strong) FTMemoryMonitor *_Nullable memoryMonitor;
/// CPU 监控器
@property (nonatomic, strong) FTCPUMonitor *_Nullable cpuMonitor;
/// 监控频率
@property (nonatomic, assign) NSTimeInterval frequency;
/// 初始化方法
///
/// 根据 MonitorType 初始化对应监控器，各个监控项中的监控器从该类获取。
/// - Parameters:
///   - type: 支持的设备监控类型
///   - frequency: 监控频率
- (instancetype)initWithMonitorType:(DeviceMetricsMonitorType)type frequency:(MonitorFrequency)frequency;
@end

NS_ASSUME_NONNULL_END
