//
//  FTDataUploadDelay.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/28.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDataUploadDelay.h"
#import "FTPerformancePreset.h"
@interface FTDataUploadDelay()
@property (nonatomic, assign) NSTimeInterval maxDelay;
@property (nonatomic, assign) NSTimeInterval minDelay;
@property (nonatomic, assign) double changeRate;
@end
@implementation FTDataUploadDelay
-(instancetype)initWithPerformance:(id<FTUploadPerformancePreset>)performance{
    self = [super init];
    if(self){
        _maxDelay = performance.maxUploadDelay;
        _minDelay = performance.minUploadDelay;
        _changeRate = performance.uploadDelayChangeRate;
        _current = performance.initialUploadDelay;
    }
    return self;
}
- (void)decrease{
    _current = MAX(_minDelay, _current * (1.0 - _changeRate));
}
- (void)increase{
    _current = MIN(_current * (1.0 + _changeRate), _maxDelay);
}
@end
