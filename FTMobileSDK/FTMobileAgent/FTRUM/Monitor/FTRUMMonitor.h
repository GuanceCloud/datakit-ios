//
//  FTRUMMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/19.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
@class FTDisplayRateMonitor,FTMemoryMonitor,FTCPUMonitor;

NS_ASSUME_NONNULL_BEGIN
@interface FTRUMMonitor : NSObject
@property (nonatomic, strong) FTDisplayRateMonitor * _Nullable displayMonitor;
@property (nonatomic, strong) FTMemoryMonitor *_Nullable memoryMonitor;
@property (nonatomic, strong) FTCPUMonitor *_Nullable cpuMonitor;
@property (nonatomic, assign) NSTimeInterval frequency;
- (instancetype)initWithMonitorType:(FTDeviceMetricsMonitorType)type frequency:(FTMonitorFrequency)frequency;
@end

NS_ASSUME_NONNULL_END
