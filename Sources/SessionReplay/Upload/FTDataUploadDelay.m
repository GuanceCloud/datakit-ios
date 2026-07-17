//
//  FTDataUploadDelay.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/28.
//
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

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

#endif
