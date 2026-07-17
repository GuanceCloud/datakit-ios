//
//  FTMonitorValue.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/5.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTMonitorValue.h"
@interface FTMonitorValue()
/* Sample minimum value */
@property (nonatomic, assign ,readwrite) double minValue;
/* Sample maximum value */
@property (nonatomic, assign ,readwrite) double maxValue;
/* Sample average value */
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
