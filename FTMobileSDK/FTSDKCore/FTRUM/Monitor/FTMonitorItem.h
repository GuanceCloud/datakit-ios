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
/// 监控项 , RUM 中每个 ViewHandler 包含一个监控项，监控该 View 生命周期内的数据（memory、CPU、fps）
@interface FTMonitorItem : NSObject
/// fps 监控器
@property (nonatomic, strong) FTDisplayRateMonitor *displayRateMonitor;
/// cpu 监控器
@property (nonatomic, strong) FTCPUMonitor *cpuMonitor;
/// memory 监控器
@property (nonatomic, strong) FTMemoryMonitor *memoryMonitor;

/// 监控项初始化方法
/// - Parameters:
///   - cpuMonitor: cpu 监控器
///   - memoryMonitor: memory 监控器
///   - displayRateMonitor: fps 监控器
///   - frequency: 采样频率
- (instancetype)initWithCpuMonitor:(FTCPUMonitor *)cpuMonitor memoryMonitor:(FTMemoryMonitor *)memoryMonitor displayRateMonitor:(FTDisplayRateMonitor *)displayRateMonitor frequency:(NSTimeInterval)frequency;
/// 获取 fps 数据
- (FTMonitorValue *)refreshDisplay;
/// 获取 cpu 数据
- (FTMonitorValue *)cpu;
/// 获取 memory 数据
- (FTMonitorValue *)memory;

@end

NS_ASSUME_NONNULL_END
