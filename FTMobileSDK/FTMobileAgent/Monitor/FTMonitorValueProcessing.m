//
//  FTMonitorValueProcessing.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/5.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMonitorValueProcessing.h"

@implementation FTMonitorValueProcessing

- (void)addSample:(double)sample{
    self.meanValue = (sample + self.meanValue*self.sampleValue) / (self.sampleValueCount+1.0);
    self.maxValue = MAX(self.maxValue, sample);
    self.minValue = MIN(self.minValue,sample);
    self.sampleValueCount += 1;
}
@end
