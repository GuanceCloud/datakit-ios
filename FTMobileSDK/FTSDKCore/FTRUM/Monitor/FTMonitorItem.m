//
//  FTMonitorUnit.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/6.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import "FTMonitorItem.h"
#import "FTCPUMonitor.h"
#import "FTMemoryMonitor.h"
#import "FTDisplayRateMonitor.h"
#import "FTMonitorValue.h"
#import "FTThreadDispatchManager.h"
#import "FTSDKCompat.h"
static double NormalizedRefreshRate = 60.0;
@interface FTMonitorItem()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) FTReadWriteHelper<FTMonitorValue *> *displayHelper;
@property (nonatomic, assign) NSInteger maximumRefreshRate;
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
        __weak typeof(self) weakSelf = self;
        [self takeMonitorValue];
        if (cpuMonitor || memoryMonitor) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:frequency repeats:YES block:^(NSTimer * _Nonnull timer) {
                [weakSelf takeMonitorValue];
            }];
            [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
            _timer = timer;
        }
        _cpuHelper = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        _memoryHelper = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        _displayHelper = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        [_displayRateMonitor addMonitorItem:_displayHelper];
        _maximumRefreshRate = 60;
        if (@available(iOS 10.3, *)) {
#if FT_IOS
            _maximumRefreshRate = [UIScreen mainScreen].maximumFramesPerSecond;
#endif
        }
    }
    return self;
}
- (FTMonitorValue *)refreshDisplay{
    FTMonitorValue *value = self.displayHelper.currentValue;
    return [value scaledDown:_maximumRefreshRate/NormalizedRefreshRate];
}
- (void)takeMonitorValue{
    [self.cpuHelper concurrentWrite:^(FTMonitorValue * _Nonnull value) {
        [value addSample:[self.cpuMonitor readCpuUsage]];
    }];
    [self.memoryHelper concurrentWrite:^(FTMonitorValue * _Nonnull value) {
        [value addSample:[self.memoryMonitor memoryUsage]];
    }];
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
