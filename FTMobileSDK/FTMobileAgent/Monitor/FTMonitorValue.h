//
//  FTMonitorValue.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/5.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTMonitorValue : NSObject
/* 样本值 */
@property (nonatomic, assign) double sampleValue;
/* 样本数量 */
@property (nonatomic, assign) int sampleValueCount;
/* 样本最小值 */
@property (nonatomic, assign) double minValue;
/* 样本最大值 */
@property (nonatomic, assign) double maxValue;
/* 样本平均值 */
@property (nonatomic, assign) double meanValue;

/* 添加样本值*/
- (void)addSample:(double)sample;
@end

NS_ASSUME_NONNULL_END
