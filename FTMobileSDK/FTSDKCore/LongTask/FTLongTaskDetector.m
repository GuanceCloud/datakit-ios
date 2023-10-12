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
}

@property (nonatomic, weak) id<FTANRDetectorDelegate> delegate;

@end
@implementation FTLongTaskDetector
-(instancetype)initWithDelegate:(id<FTANRDetectorDelegate>)delegate{
    self = [super init];
    if(self){
        _delegate = delegate;
    }
    return self;
}
- (void)startDetecting {
    [self registerObserver];
}
// 注册一个Observer来监测Loop的状态,回调函数是runLoopObserverCallBack
- (void)registerObserver
{
    // 创建Runloop observer对象
    CFRunLoopObserverRef beginObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                                            kCFRunLoopEntry|kCFRunLoopBeforeTimers|kCFRunLoopBeforeSources|kCFRunLoopAfterWaiting,
                                                                            YES,
                                                                            LONG_MIN,
                                                                            ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
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
    __weak __typeof(self) weakSelf = self;
    CFRunLoopObserverRef endObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopExit|kCFRunLoopBeforeWaiting, YES, LONG_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopBeforeWaiting:
                if (g_bRun) {
                    __strong __typeof(weakSelf) strongSelf = weakSelf;
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
    unsigned long long duration = [self diffTime:&g_tvRun endTime:&tvCur];
    if ((duration > MXRMonitorRunloopStandstillMillisecond) && (duration < MXRMonitorRunloopMaxtillMillisecond)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *backtrace = [FTCallStack ft_backtraceOfMainThread];
            id<FTANRDetectorDelegate> del = self.delegate;
            if (del != nil && [del respondsToSelector:@selector(onMainThreadSlowStackDetected:duration:)]) {
                [del onMainThreadSlowStackDetected:backtrace duration:duration];
            }
        });
    }
}
- (unsigned long long)diffTime:(struct timeval *)tvStart endTime:(struct timeval *)tvEnd {
    return 1000000000 * (tvEnd->tv_sec - tvStart->tv_sec) + tvEnd->tv_usec - tvStart->tv_usec;
}
- (void)stopDetecting{
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopEndObserver, kCFRunLoopCommonModes);
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopBeginObserver, kCFRunLoopCommonModes);
}
-(void)dealloc{
    CFRelease(m_runLoopEndObserver);
    CFRelease(m_runLoopBeginObserver);

}

@end
