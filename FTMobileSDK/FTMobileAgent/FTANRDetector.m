//
//  FTANRMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTANRDetector.h"
#import "FTLog.h"
#import "FTCallStack.h"

#include <signal.h>
#include <pthread.h>

#include <libkern/OSAtomic.h>
#include <execinfo.h>

// minimum
static const NSInteger MXRMonitorRunloopMinOneStandstillMillisecond = 20;
static const NSInteger MXRMonitorRunloopMinStandstillCount = 1;

// default
// 超过多少毫秒为一次卡顿
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond = 50;
// 多少次卡顿纪录为一次有效卡顿
static const NSInteger MXRMonitorRunloopStandstillCount = 5;

@interface FTANRDetector (){
    CFRunLoopObserverRef _observer;  // 观察者
    dispatch_semaphore_t _semaphore; // 信号量
    CFRunLoopActivity _activity;     // 状态
}

@property (nonatomic, assign) BOOL isCancel;
@property (nonatomic, assign) NSInteger countTime; // 耗时次数
@property (nonatomic, strong) NSMutableArray *backtrace;
@end
@implementation FTANRDetector
+ (instancetype)sharedInstance
{
    static FTANRDetector* instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [FTANRDetector new];
        instance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond;
        instance.standstillCount  = MXRMonitorRunloopStandstillCount;
    });
    
    return instance;
}
- (void)setLimitMillisecond:(int)limitMillisecond
{
    [self willChangeValueForKey:@"limitMillisecond"];
    _limitMillisecond = limitMillisecond >= MXRMonitorRunloopMinOneStandstillMillisecond ? limitMillisecond : MXRMonitorRunloopMinOneStandstillMillisecond;
    [self didChangeValueForKey:@"limitMillisecond"];
}

- (void)setStandstillCount:(int)standstillCount
{
    [self willChangeValueForKey:@"standstillCount"];
    _standstillCount = standstillCount >= MXRMonitorRunloopMinStandstillCount ? standstillCount : MXRMonitorRunloopMinStandstillCount;
    [self didChangeValueForKey:@"standstillCount"];
}
- (void)startDetecting {
    self.isCancel = NO;
    [self registerObserver];
}
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    FTANRDetector *instance = [FTANRDetector sharedInstance];
    // 记录状态值
    instance->_activity = activity;
    // 发送信号
    dispatch_semaphore_t semaphore = instance->_semaphore;
    dispatch_semaphore_signal(semaphore);
}
// 注册一个Observer来监测Loop的状态,回调函数是runLoopObserverCallBack
- (void)registerObserver
{
    // 设置Runloop observer的运行环境
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    // 创建Runloop observer对象
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                        kCFRunLoopAllActivities,
                                        YES,
                                        0,
                                        &runLoopObserverCallBack,
                                        &context);
    // 将新建的observer加入到当前thread的runloop
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    // 创建信号
    _semaphore = dispatch_semaphore_create(0);
    
    __weak __typeof(self) weakSelf = self;
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        while (YES) {
            if (strongSelf.isCancel) {
                return;
            }
            // N次卡顿超过阈值T记录为一次卡顿
            long dsw = dispatch_semaphore_wait(self->_semaphore, dispatch_time(DISPATCH_TIME_NOW, strongSelf.limitMillisecond * NSEC_PER_MSEC));
            if (dsw != 0) {
                if (self->_activity == kCFRunLoopBeforeSources || self->_activity == kCFRunLoopAfterWaiting) {
                    if (++strongSelf.countTime < strongSelf.standstillCount){
                        ZYDebug(@"%ld",(long)strongSelf.countTime);
                        continue;
                    }
                    NSString *backtrace = [FTCallStack ft_backtraceOfMainThread];
                    ZYDebug(@"++++%@",backtrace);
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
            }
            strongSelf.countTime = 0;
        }
    });
}

- (void)stopDetecting{
    self.isCancel = YES;
    if(!_observer) return;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    CFRelease(_observer);
    _observer = NULL;
}

@end
