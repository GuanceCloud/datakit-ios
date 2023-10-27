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
#import "FTLongTaskDetector.h"
#import "FTInternalLog.h"
#import "FTCallStack.h"
#import "FTConstants.h"
#import <sys/time.h>
//250ms  （纳秒）
static const NSInteger MXRMonitorRunloopStandstillMillisecond = 250000000;
//60s    （纳秒）
static const NSInteger MXRMonitorRunloopMaxtillMillisecond = 60000000000;
static struct timeval g_tvRun;
static BOOL g_bRun;

@interface FTLongTaskDetector (){
    CFRunLoopObserverRef m_runLoopBeginObserver;  // 观察者
    CFRunLoopObserverRef m_runLoopEndObserver;    // 观察者
    dispatch_semaphore_t semaphore;
    CFRunLoopActivity runLoopActivity;
    int timeoutCount;
    BOOL detecting;
}

@property (nonatomic, weak) id<FTRunloopDetectorDelegate> delegate;
@property (nonatomic, assign) BOOL enableANR;
@property (nonatomic, assign) BOOL enableFreeze;
@end
@implementation FTLongTaskDetector
-(instancetype)initWithDelegate:(id<FTRunloopDetectorDelegate>)delegate enableTrackAppANR:(BOOL)enableANR enableTrackAppFreeze:(BOOL)enableFreeze{
    self = [super init];
    if(self){
        _delegate = delegate;
        _enableANR = enableANR;
        _enableFreeze = enableFreeze;
        semaphore = dispatch_semaphore_create(0);
    }
    return self;
}
- (void)startDetecting {
    [self registerObserver];
    if(self.enableANR){
        detecting = YES;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            while (self->detecting) {
                long st = dispatch_semaphore_wait(self->semaphore, dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC));
                if(st!=0){
                    if(!self->m_runLoopEndObserver&&!self->m_runLoopBeginObserver) {
                        self->timeoutCount = 0;
                        self->semaphore = 0;
                        self->runLoopActivity = 0;
                        return;
                    }
                    if (self->runLoopActivity == kCFRunLoopBeforeSources || self->runLoopActivity == kCFRunLoopAfterWaiting) {
                        //出现三次出结果
                        if (++self->timeoutCount < 3) {
                            continue;
                        }
                        NSString *backtrace = [FTCallStack ft_backtraceOfMainThread];
                        id<FTRunloopDetectorDelegate> del = self.delegate;
                        if (del != nil && [del respondsToSelector:@selector(longTaskStackDetected:duration:)]) {
                            [del anrStackDetected:backtrace];
                        }
                        
                    } //end activity
                }// end semaphore wait
                self->timeoutCount = 0;
                
            }
        });
    }
}
// 注册一个Observer来监测Loop的状态,回调函数是runLoopObserverCallBack
- (void)registerObserver{
    __weak __typeof(self) weakSelf = self;
    // 创建Runloop observer对象
    CFRunLoopObserverRef beginObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                                            kCFRunLoopEntry|kCFRunLoopBeforeTimers|kCFRunLoopBeforeSources|kCFRunLoopAfterWaiting,
                                                                            YES,
                                                                            LONG_MIN,
                                                                            ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if(strongSelf.enableANR){
            self->runLoopActivity = activity;
            dispatch_semaphore_signal(self->semaphore);
        }
        switch (activity) {
            case kCFRunLoopEntry:
                g_bRun = YES;
                break;

            case kCFRunLoopBeforeTimers:
                if (g_bRun == NO) {
                    gettimeofday(&g_tvRun, NULL);
                }
                g_bRun = YES;
                break;

            case kCFRunLoopBeforeSources:
                if (g_bRun == NO) {
                    gettimeofday(&g_tvRun, NULL);
                }
                g_bRun = YES;
                break;

            case kCFRunLoopAfterWaiting:
                if (g_bRun == NO) {
                    gettimeofday(&g_tvRun, NULL);
                }
                g_bRun = YES;
                break;
            default:
                break;
        }
    });
    CFRetain(beginObserver);
    m_runLoopBeginObserver = beginObserver;
    CFRunLoopObserverRef endObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopExit|kCFRunLoopBeforeWaiting, YES, LONG_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if(strongSelf.enableANR){
            self->runLoopActivity = activity;
            dispatch_semaphore_signal(self->semaphore);
        }
        switch (activity) {
            case kCFRunLoopBeforeWaiting:
                if (g_bRun) {
                    if (!strongSelf) {
                        break;
                    }
                    [strongSelf checkLoopDuration];
                }
                gettimeofday(&g_tvRun, NULL);
                g_bRun = NO;
                break;

            case kCFRunLoopExit:
                g_bRun = NO;
                break;
            default:
                break;
        }
    });
    CFRetain(endObserver);
    m_runLoopEndObserver = endObserver;
    // 将新建的observer加入到当前thread的runloop
    CFRunLoopAddObserver(CFRunLoopGetMain(), beginObserver, kCFRunLoopCommonModes);
    CFRunLoopAddObserver(CFRunLoopGetMain(), endObserver, kCFRunLoopCommonModes);
}
- (void)checkLoopDuration{
    struct timeval tvCur;
    gettimeofday(&tvCur, NULL);
    unsigned long long duration = [self diffTime:&g_tvRun endTime:&tvCur]*1000;
    // 设置 250 ms 与 Instrument -> Time Profiler -> Hangs 采集基本一致 250ms < Microhang <500ms < Hang
    if ((duration > MXRMonitorRunloopStandstillMillisecond) && (duration < MXRMonitorRunloopMaxtillMillisecond)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *backtrace = [FTCallStack ft_backtraceOfMainThread];
            id<FTRunloopDetectorDelegate> del = self.delegate;
            if (del != nil && [del respondsToSelector:@selector(longTaskStackDetected:duration:)]) {
                [del longTaskStackDetected:backtrace duration:duration];
            }
        });
    }
}
- (unsigned long long)diffTime:(struct timeval *)tvStart endTime:(struct timeval *)tvEnd {
    return 1000000 * (tvEnd->tv_sec - tvStart->tv_sec) + tvEnd->tv_usec - tvStart->tv_usec;
}
- (void)stopDetecting{
    detecting = NO;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopEndObserver, kCFRunLoopCommonModes);
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopBeginObserver, kCFRunLoopCommonModes);
}
-(void)dealloc{
    CFRelease(m_runLoopEndObserver);
    CFRelease(m_runLoopBeginObserver);

}

@end
