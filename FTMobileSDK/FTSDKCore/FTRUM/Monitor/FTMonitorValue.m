//
//  FTMonitorValue.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/5.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMonitorValue.h"
@interface FTMonitorValue()
/* 样本最小值 */
@property (nonatomic, assign ,readwrite) double minValue;
/* 样本最大值 */
@property (nonatomic, assign ,readwrite) double maxValue;
/* 样本平均值 */
@property (nonatomic, assign ,readwrite) double meanValue;
@end
@implementation FTMonitorValue
-(instancetype)init{
    self = [super init];
    if (self) {
        _minValue = -1;
        _maxValue = -1;
    }
    return self;
}
-(double)greatestDiff{
    if (self.maxValue>0 && self.minValue>0) {
        return self.maxValue-self.minValue;
    }
    return -1;
}
- (void)addSample:(double)sample{
    self.meanValue = (sample + self.meanValue*self.sampleValueCount) / (self.sampleValueCount+1.0);
    self.maxValue = _maxValue == -1 ? sample : MAX(self.maxValue, sample);
    self.minValue = _minValue == -1 ? sample : MIN(self.minValue, sample);
    self.sampleValueCount += 1;
}
- (FTMonitorValue *)scaledDown:(double)scale{
    if (scale == 1 || scale <=0) {
        return self;
    }
    FTMonitorValue *value = [FTMonitorValue new];
    value.meanValue = self.meanValue / scale;
    value.maxValue = self.maxValue / scale;
    value.minValue = self.minValue / scale;
    value.sampleValueCount = self.sampleValueCount;
    return value;
}
- (id)copyWithZone:(nullable NSZone *)zone{
    FTMonitorValue *value = [[[self class] allocWithZone:zone] init];
    value.minValue = self.minValue;
    value.maxValue = self.maxValue;
    value.sampleValueCount = self.sampleValueCount;
    value.meanValue = self.meanValue;
    return value;
}
@end
