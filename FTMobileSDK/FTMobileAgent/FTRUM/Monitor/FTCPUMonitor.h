//
//  FTCPUMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/1.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// CPU 监控器
@interface FTCPUMonitor : NSObject
/// 读取 CPU 使用 ticks
- (double)readCpuUsage;
@end

NS_ASSUME_NONNULL_END
