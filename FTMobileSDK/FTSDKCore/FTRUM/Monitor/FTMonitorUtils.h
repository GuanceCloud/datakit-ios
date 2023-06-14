//
//  FTMonitorUtils.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// 监控项相关数据获取工具
@interface FTMonitorUtils : NSObject
/// 获取当前设备CPU使用率
+ (long )cpuUsage;
/// 获取当前电池电量使用率
+ (double)batteryUse;
/// 获取设备总内存
+ (NSString *)totalMemorySize;
/// 获取当前内存使用率
+ (float)usedMemory;
@end

NS_ASSUME_NONNULL_END
