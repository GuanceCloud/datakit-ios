//
//  FTTimerScheduler.m
//  SessionReplay
//
//  Created by hulilei on 2026/3/3.
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
#if TARGET_OS_IOS

#import "FTTimerScheduler.h"
#import "FTQueue.h"
#import <mach/mach_time.h>

static const NSTimeInterval kTimerTolerance = 0.1;

@implementation FTDispatchSourceTimerScheduler

+ (FTDispatchSourceTimerScheduler *)dispatchSource {
    static FTDispatchSourceTimerScheduler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithQueue:dispatch_get_main_queue()];
    });
    return instance;
}
+(instancetype)scheduler{
    return [[self alloc] initWithQueue:dispatch_get_main_queue()];
}
-(instancetype)initWithQueue:(dispatch_queue_t)queue{
    if (self = [super init]) {
        _queue = queue ?: dispatch_get_main_queue();
    }
    return self;
}
- (NSTimeInterval)now {
    return (NSTimeInterval)mach_absolute_time() / (NSTimeInterval)NSEC_PER_SEC;
}
-(id<FTScheduledTimer>)scheduleAfterInterval:(NSTimeInterval)interval action:(dispatch_block_t)action{
    if (interval < 0) interval = 0;
        if (!action) return nil;
        
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
        if (!timer) return nil;
        
        NSTimeInterval tolerance = interval * kTimerTolerance;
        dispatch_time_t leeway = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(tolerance * NSEC_PER_SEC));
        
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)),
                                  DISPATCH_TIME_FOREVER,
                                  leeway);
        
        dispatch_source_set_event_handler(timer, ^{
            action();
            dispatch_source_cancel(timer);
        });
        
        dispatch_resume(timer);
        
        return [[FTDispatchSourceScheduledTimer alloc] initWithDispatchSourceTimer:timer];
}
@end


@implementation FTDispatchSourceScheduledTimer{
    dispatch_source_t _timer;
}

- (instancetype)initWithDispatchSourceTimer:(dispatch_source_t)timer {
    if (self = [super init]) {
        _timer = timer;
    }
    return self;
}
- (void)cancel {
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}
- (void)dealloc {
    [self cancel];
    if (_timer) {
        _timer = nil;
    }
}

@end

#endif
