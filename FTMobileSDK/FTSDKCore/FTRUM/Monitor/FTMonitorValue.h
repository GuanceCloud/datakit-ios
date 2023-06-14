//
//  FTMonitorValue.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/5.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 监控器数值
@interface FTMonitorValue : NSObject
/// 样本数量
@property (nonatomic, assign) int sampleValueCount;
/// 样本最小值
@property (nonatomic, assign ,readonly) double minValue;
/// 样本最大值
@property (nonatomic, assign ,readonly) double maxValue;
/// 样本平均值
@property (nonatomic, assign ,readonly) double meanValue;

/// 添加样本值
/// - Parameter sample: 样本值
- (void)addSample:(double)sample;
/// 样本最大最小差值
- (double)greatestDiff;
/// 按比例缩小
/// - Parameter scale: 缩小比例
- (FTMonitorValue *)scaledDown:(double)scale;
@end

NS_ASSUME_NONNULL_END
