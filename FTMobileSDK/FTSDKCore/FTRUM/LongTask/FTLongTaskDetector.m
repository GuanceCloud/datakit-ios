//
//  FTANRMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTLongTaskDetector.h"
#import "FTLog+Private.h"
#import "FTConstants.h"
#import <sys/time.h>
#import "NSDate+FTUtil.h"

static NSDate *g_startDate;

@interface FTLongTaskDetector (){
    CFRunLoopObserverRef m_runLoopBeginObserver;  // Observer
    CFRunLoopObserverRef m_runLoopEndObserver;    // Observer
    dispatch_semaphore_t _semaphore;
    CFRunLoopActivity _activity;     // Status
}

@property (nonatomic, weak) id<FTLongTaskProtocol> longTaskDelegate;
@property (nonatomic, assign) BOOL isCancel;
@property (nonatomic, assign) NSInteger countTime; // Time-consuming count
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
        _longTaskQueue = dispatch_queue_create("com.ft.longtask", 0);
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
                            /// TODO: mainThread backtrace
                            NSString *backtrace = @"";
                            //[FTCallStack ft_backtraceOfMainThread];
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
// Register an Observer to monitor the state of the Loop, callback function is runLoopObserverCallBack
- (void)registerObserver{
    __weak __typeof(self) weakSelf = self;
    // Create Runloop observer object
    CFRunLoopObserverRef beginObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                                            kCFRunLoopEntry|kCFRunLoopBeforeSources|kCFRunLoopAfterWaiting,
                                                                            YES,
                                                                            LONG_MIN,
                                                                            ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
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
    // Add the newly created observer to the current thread's runloop
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
