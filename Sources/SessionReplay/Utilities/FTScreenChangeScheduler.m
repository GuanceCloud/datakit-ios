//
//  FTScreenChangeScheduler.m
//  SessionReplay
//
//  Created by hulilei on 2026/3/2.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTScreenChangeScheduler.h"
#import "FTQueue.h"
#if TARGET_OS_IOS
#import "FTScreenChangeMonitor.h"
#endif
#if TARGET_OS_OSX
const NSTimeInterval FTSessionReplayMacOSCaptureInterval = 0.1;
#endif
@interface FTScreenChangeScheduler()
@property (nonatomic, strong) id<FTQueue> queue;
@property (nonatomic, assign) NSTimeInterval minimumInterval;
#if TARGET_OS_IOS
@property (nonatomic, strong) FTScreenChangeMonitor *monitor;
#elif TARGET_OS_OSX
@property (nonatomic, strong, nullable) NSTimer *captureTimer;
#endif
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *operations;

@end

@implementation FTScreenChangeScheduler
- (instancetype)initWithMinimumInterval:(NSTimeInterval)minimumInterval
                         timerScheduler:(id<FTTimerScheduler>)timerScheduler {
    if (self = [super init]) {
        _minimumInterval = minimumInterval;
        _timerScheduler = timerScheduler ?: FTDispatchSourceTimerScheduler.dispatchSource;
        _queue = [[FTMainQueue alloc] init];
        _operations = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithMinimumInterval:(NSTimeInterval)minimumInterval{
    return [self initWithMinimumInterval:minimumInterval
                         timerScheduler:FTDispatchSourceTimerScheduler.dispatchSource];
}

#pragma mark - Scheduler
- (void)scheduleWithOperation:(dispatch_block_t)operation {
    if (!operation) {
        return;
    }
    [self.queue run:^{
        [self.operations addObject:[operation copy]];
    }];
}

- (void)start {
    __weak typeof(self) weakSelf = self;
    [self.queue run:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        #if TARGET_OS_IOS
        if (strongSelf.monitor) {
            return;
        }
        
        FTScreenChangeMonitor *monitor = [[FTScreenChangeMonitor alloc] initWithMinimumDeliveryInterval:strongSelf.minimumInterval timerScheduler:strongSelf.timerScheduler handler:^(FTCALayerChangeSnapshot * _Nonnull snapshot) {
            [strongSelf screenDidChange:snapshot];
        }];
        
        if (monitor) {
            [monitor start];
            strongSelf.monitor = monitor;
        } else {
            //
        }
        #elif TARGET_OS_OSX
        if (strongSelf.captureTimer) {
            return;
        }
        NSTimer *timer =
            [NSTimer timerWithTimeInterval:strongSelf.minimumInterval
                                  repeats:YES
                                    block:^(NSTimer *timer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                [timer invalidate];
                return;
            }
            [strongSelf captureScreen];
        }];
        strongSelf.captureTimer = timer;
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
        #endif
    }];
}

- (void)stop {
    __weak typeof(self) weakSelf = self;
    
    [self.queue run:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        #if TARGET_OS_IOS
        if (!strongSelf.monitor) {
            return;
        }
        [strongSelf.monitor stop];
        strongSelf.monitor = nil;
        #elif TARGET_OS_OSX
        [strongSelf.captureTimer invalidate];
        strongSelf.captureTimer = nil;
        #endif
    }];
}

#if TARGET_OS_IOS
- (void)screenDidChange:(FTCALayerChangeSnapshot *)snapshot {
    
    [self.operations enumerateObjectsUsingBlock:^(dispatch_block_t  _Nonnull operation, NSUInteger idx, BOOL * _Nonnull stop) {
        operation();
    }];

}
#elif TARGET_OS_OSX
- (void)captureScreen {
    for (dispatch_block_t operation in [self.operations copy]) {
        operation();
    }
}
#endif


@end

#endif
