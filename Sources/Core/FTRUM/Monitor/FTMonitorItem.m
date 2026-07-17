//
//  FTMonitorUnit.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/6.
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

#import "FTMonitorItem.h"
#import "FTCPUMonitor.h"
#import "FTMemoryMonitor.h"
#import "FTDisplayRateMonitor.h"
#import "FTMonitorValue.h"
#import "FTThreadDispatchManager.h"
#import "FTSDKCompat.h"
@interface FTMonitorItem()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) FTReadWriteHelper<FTMonitorValue *> *displayHelper;
@property (nonatomic, strong) FTReadWriteHelper<FTMonitorValue *> *cpuHelper;
@property (nonatomic, strong) FTReadWriteHelper<FTMonitorValue *> *memoryHelper;
@property (nonatomic, assign) NSTimeInterval frequency;
@end
@implementation FTMonitorItem
- (instancetype)initWithCpuMonitor:(FTCPUMonitor *)cpuMonitor memoryMonitor:(FTMemoryMonitor *)memoryMonitor displayRateMonitor:(FTDisplayRateMonitor *)displayRateMonitor frequency:(NSTimeInterval)frequency{
    self = [super init];
    if (self) {
        _cpuMonitor = cpuMonitor;
        _displayRateMonitor = displayRateMonitor;
        _memoryMonitor = memoryMonitor;
        _frequency = frequency;
        if (cpuMonitor || memoryMonitor) {
            __weak typeof(self) weakSelf = self;
            [[NSRunLoop mainRunLoop] performInModes:@[NSRunLoopCommonModes] block:^{
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf takeMonitorValue];
            }];
            NSTimer *timer = [NSTimer timerWithTimeInterval:frequency repeats:YES block:^(NSTimer * _Nonnull timer) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf takeMonitorValue];
            }];
            [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
            _timer = timer;
        }
        _cpuHelper = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        _memoryHelper = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        _displayHelper = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        [_displayRateMonitor addMonitorItem:_displayHelper];
    }
    return self;
}
- (void)takeMonitorValue{
    [self.cpuHelper concurrentWrite:^(FTMonitorValue * _Nonnull value) {
        [value addSample:[self.cpuMonitor readCpuUsage]];
    }];
    [self.memoryHelper concurrentWrite:^(FTMonitorValue * _Nonnull value) {
        [value addSample:[self.memoryMonitor memoryUsage]];
    }];
}
- (FTMonitorValue *)refreshDisplay{
    return self.displayHelper.currentValue;
}
-(FTMonitorValue *)cpu{
    return self.cpuHelper.currentValue;
}
-(FTMonitorValue *)memory{
    return self.memoryHelper.currentValue;
}
-(void)dealloc{
    [self.displayRateMonitor removeMonitorItem:self.displayHelper];
    if (self.timer) {
        [self.timer invalidate];
    }
}
@end
