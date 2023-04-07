//
//  FTDisplayRate.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTReadWriteHelper,FTMonitorValue;
NS_ASSUME_NONNULL_BEGIN

/// FPS 监控器
@interface FTDisplayRateMonitor : NSObject
/// 添加监控项 , RUM 中每个 ViewHandler 包含一个监控项，监控该 View 生命周期内的数据
/// - Parameter item: 监控项
- (void)addMonitorItem:(FTReadWriteHelper *)item;

/// 移除监控项
/// - Parameter item: 监控项
- (void)removeMonitorItem:(FTReadWriteHelper *)item;
@end

NS_ASSUME_NONNULL_END
