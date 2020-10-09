//
//  FTANRMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTANRDetector.h"
#import "FTLog.h"
#import "FTCallStack.h"
#define FTANRDetector_Watch_Interval     1.0f
#define FTANRDetector_Warning_Level     (16.0f/1000.0f)

#define Notification_FTANRDetector_Worker_Ping    @"Notification_FTANRDetector_Worker_Ping"
#define Notification_FTANRDetector_Main_Pong    @"Notification_FTANRDetector_Main_Pong"

#include <signal.h>
#include <pthread.h>

#define CALLSTACK_SIG SIGUSR1
static pthread_t mainThreadID;

#include <libkern/OSAtomic.h>
#include <execinfo.h>

dispatch_source_t createGCDTimer(uint64_t interval, uint64_t leeway, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, interval), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}


@interface FTANRDetector ()
@property (nonatomic, strong) dispatch_source_t  pingTimer;
@property (nonatomic, strong) dispatch_source_t  pongTimer;
@end
@implementation FTANRDetector
+ (instancetype)sharedInstance
{
    static FTANRDetector* instance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [FTANRDetector new];
    });

    return instance;
}

- (void)startDetecting {
    
    if ([NSThread isMainThread] == false) {
        ZYDebug(@"Error: startWatch must be called from main thread!");
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectPingFromWorkerThread) name:Notification_FTANRDetector_Worker_Ping object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectPongFromMainThread) name:Notification_FTANRDetector_Main_Pong object:nil];
        
    mainThreadID = pthread_self();
    
    //ping from worker thread
    uint64_t interval = FTANRDetector_Watch_Interval * NSEC_PER_SEC;
    self.pingTimer = createGCDTimer(interval, interval / 10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self pingMainThread];
    });
}
- (void)stopDetecting{
    if (![NSThread isMainThread]) {
        NSLog(@"error: %s must be executing in mainthread", __func__);
        return;
    }
    
    [self cancelPingTimer];
}
- (void)pingMainThread
{
    uint64_t interval = FTANRDetector_Warning_Level * NSEC_PER_SEC;
    self.pongTimer = createGCDTimer(interval, interval / 10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self onPongTimeout];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_FTANRDetector_Worker_Ping object:nil];
    });
}

- (void)detectPingFromWorkerThread
{
    [[NSNotificationCenter defaultCenter] postNotificationName:Notification_FTANRDetector_Main_Pong object:nil];
}

- (void)onPongTimeout
{
    [self cancelPongTimer];
    NSString *backtrace = [FTCallStack ft_backtraceOfMainThread];
    id<FTANRDetectorDelegate> del = [FTANRDetector sharedInstance].delegate;
       if (del != nil && [del respondsToSelector:@selector(onMainThreadSlowStackDetected:)]) {
           [del onMainThreadSlowStackDetected:backtrace];
       }
       else
       {
           ZYDebug(@"detect slow call stack on main thread! \n");
           ZYDebug(@"%@\n", backtrace);
       }
}

- (void)detectPongFromMainThread
{
    [self cancelPongTimer];
}
- (void)cancelPingTimer{
    if (self.pingTimer) {
           dispatch_source_cancel(_pingTimer);
           _pingTimer = nil;
       }
}
- (void)cancelPongTimer
{
    if (self.pongTimer) {
        dispatch_source_cancel(_pongTimer);
        _pongTimer = nil;
    }
}
@end
