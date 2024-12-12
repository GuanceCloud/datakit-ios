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
#import "FTLog+Private.h"
#import "FTCallStack.h"
#import "FTConstants.h"
#import <sys/time.h>
#import "NSDate+FTUtil.h"

static NSDate *g_startDate;

@interface FTLongTaskDetector (){
    CFRunLoopObserverRef m_runLoopBeginObserver;  // 观察者
    CFRunLoopObserverRef m_runLoopEndObserver;    // 观察者
    dispatch_semaphore_t _semaphore;
    CFRunLoopActivity _activity;     // 状态
}

@property (nonatomic, weak) id<FTLongTaskProtocol> longTaskDelegate;
@property (nonatomic, assign) BOOL isCancel;
@property (nonatomic, assign) NSInteger countTime; // 耗时次数
@property (nonatomic, strong) dispatch_queue_t longTaskQueue;
@property (nonatomic, assign) long limitMillisecond;
@end
@implementation FTLongTaskDetector
-(instancetype)initWithDelegate:(id<FTLongTaskProtocol>)delegate{
    self = [super init];
    if(self){
        _longTaskDelegate = delegate;
        _semaphore = dispatch_semaphore_create(0);
        _limitFreezeMillisecond = FT_DEFAULT_BLOCK_DURATIONS_MS;
        _limitMillisecond = MIN(_limitFreezeMillisecond, FT_ANR_THRESHOLD_MS);
        _longTaskQueue = dispatch_queue_create("com.guance.longtask", 0);
    }
    return self;
}
- (void)startDetecting {
    [self registerObserver];
    self.isCancel = NO;
    __weak __typeof(self) weakSelf = self;
    dispatch_async(_longTaskQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        while (!strongSelf.isCancel) {
            @autoreleasepool {
                long st = dispatch_semaphore_wait(self->_semaphore, dispatch_time(DISPATCH_TIME_NOW, strongSelf.limitMillisecond*NSEC_PER_MSEC));
                if(st!=0){
                    if (self->_activity == kCFRunLoopBeforeSources || self->_activity == kCFRunLoopAfterWaiting) {
                        strongSelf.countTime++;
                        if(strongSelf.countTime == 1){
                            NSString *backtrace = [FTCallStack ft_backtraceOfMainThread];
                            if (strongSelf.longTaskDelegate != nil && [strongSelf.longTaskDelegate  respondsToSelector:@selector(startLongTask:backtrace:)]) {
                                [strongSelf.longTaskDelegate startLongTask:g_startDate backtrace:backtrace];
                            }
                        }else{
                            if (strongSelf.longTaskDelegate != nil && [strongSelf.longTaskDelegate  respondsToSelector:@selector(updateLongTaskDate:)]) {
                                [strongSelf.longTaskDelegate updateLongTaskDate:[NSDate date]];
                            }
                        }
                        continue;
                    }
                }
                // end semaphore wait
                if(strongSelf.countTime>0){
                    if (strongSelf.longTaskDelegate != nil && [strongSelf.longTaskDelegate  respondsToSelector:@selector(endLongTask)]) {
                        [strongSelf.longTaskDelegate endLongTask];
                    }
                }
                strongSelf.countTime = 0;
            }
        }
    });
}
// 注册一个Observer来监测Loop的状态,回调函数是runLoopObserverCallBack
- (void)registerObserver{
    __weak __typeof(self) weakSelf = self;
    // 创建Runloop observer对象
    CFRunLoopObserverRef beginObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                                            kCFRunLoopEntry|kCFRunLoopBeforeSources|kCFRunLoopAfterWaiting,
                                                                            YES,
                                                                            LONG_MIN,
                                                                            ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        strongSelf->_activity = activity;
        g_startDate = [NSDate date];
        dispatch_semaphore_signal(strongSelf->_semaphore);
    });
    CFRetain(beginObserver);
    m_runLoopBeginObserver = beginObserver;
    CFRelease(beginObserver);
    CFRunLoopObserverRef endObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopExit|kCFRunLoopBeforeWaiting, YES, LONG_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        strongSelf->_activity = activity;
        g_startDate = [NSDate date];
        dispatch_semaphore_signal(strongSelf->_semaphore);
    });
    CFRetain(endObserver);
    m_runLoopEndObserver = endObserver;
    CFRelease(endObserver);
    // 将新建的observer加入到当前thread的runloop
    CFRunLoopAddObserver(CFRunLoopGetMain(), beginObserver, kCFRunLoopCommonModes);
    CFRunLoopAddObserver(CFRunLoopGetMain(), endObserver, kCFRunLoopCommonModes);
}
- (void)stopDetecting{
    self.isCancel = YES;
    if(!m_runLoopEndObserver) return;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopEndObserver, kCFRunLoopCommonModes);
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopBeginObserver, kCFRunLoopCommonModes);
}
-(void)dealloc{
    CFRelease(m_runLoopEndObserver);
    CFRelease(m_runLoopBeginObserver);
}

@end
