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
@interface FTMonitorItem()
@property (nonatomic, strong) NSTimer *timer;


@end
@implementation FTMonitorItem
- (instancetype)initWithCpuMonitor:(FTCPUMonitor *)cpuMonitor memoryMonitor:(FTMemoryMonitor *)memoryMonitor displayRateMonitor:(FTDisplayRateMonitor *)displayRateMonitor{
    self = [super init];
    if (self) {
        _cpuMonitor = cpuMonitor;
        _displayRateMonitor = displayRateMonitor;
        _memoryMonitor = memoryMonitor;
        NSTimer *timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(takeMonitorValue) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        _timer = timer;
        _cpu = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        _memory = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        _display = [[FTReadWriteHelper alloc]initWithValue:[FTMonitorValue new]];
        [_displayRateMonitor addMonitorItem:_display];
    }
    return self;
}

- (void)takeMonitorValue{
//        [self.cpu.value addSample:[self.cpuMonitor appCpuUsage]];
//        [self.memory.value addSample:[self.memoryMonitor memoryUsage]];
}

-(void)dealloc{
    [self.displayRateMonitor removeMonitorItem:self.display];
    if (self.timer) {
        [self.timer invalidate];
    }
}
@end
