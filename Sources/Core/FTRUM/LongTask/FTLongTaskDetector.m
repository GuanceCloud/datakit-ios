//
//  FTANRMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/28.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTLongTaskDetector.h"
#import "FTInnerLog.h"
#import "FTConstants.h"
#import "FTDateUtil.h"
#import <stdatomic.h>
#import <sys/time.h>
#import "NSDate+FTUtil.h"
#import "FTErrorDataProtocol.h"

_Static_assert(ATOMIC_LONG_LOCK_FREE == 2 && ATOMIC_LLONG_LOCK_FREE == 2,
               "RunLoop snapshot atomics must be lock-free on supported targets");

typedef struct {
    CFRunLoopActivity activity;
    long long startTimestampNs;
    uint64_t generation;
} FTRunLoopSnapshot;

typedef NS_ENUM(NSUInteger, FTLongTaskDetectionState) {
    FTLongTaskDetectionStateIdle,
    FTLongTaskDetectionStateWaitingForNormalTimeout,
    FTLongTaskDetectionStateStartDispatched,
};

@interface FTLongTaskDetector (){
    CFRunLoopObserverRef m_runLoopBeginObserver;  // Observer
    CFRunLoopObserverRef m_runLoopEndObserver;    // Observer
    dispatch_semaphore_t _semaphore;
    atomic_ullong _runLoopSequence;
    _Atomic(CFRunLoopActivity) _activity; // Status
    atomic_llong _runLoopStartTimestampNs;
    long long _resumeBaselineNs;
    uint64_t _resumeGeneration;
    FTLongTaskDetectionState _detectionState;
}

@property (nonatomic, weak, nullable) id<FTLongTaskProtocol> longTaskDelegate;
@property (nonatomic, assign) BOOL isCancel;
@property (nonatomic, strong) dispatch_queue_t longTaskQueue;
@property (nonatomic, assign) long limitMillisecond;
@end
@implementation FTLongTaskDetector
-(instancetype)initWithDelegate:(id<FTLongTaskProtocol>)delegate{
    self = [super init];
    if(self){
        _longTaskDelegate = delegate;
        _semaphore = dispatch_semaphore_create(0);
        atomic_init(&_runLoopSequence, 0);
        atomic_init(&_activity, 0);
        atomic_init(&_runLoopStartTimestampNs, 0);
        _detectionState = FTLongTaskDetectionStateIdle;
        self.limitFreezeMillisecond = FT_DEFAULT_BLOCK_DURATIONS_MS;
        _longTaskQueue = dispatch_queue_create("com.ft.longtask", 0);
    }
    return self;
}
- (void)setLimitFreezeMillisecond:(long)limitFreezeMillisecond {
    _limitFreezeMillisecond = limitFreezeMillisecond;
    _limitMillisecond = MIN(limitFreezeMillisecond, FT_ANR_THRESHOLD_MS);
}
- (BOOL)runLoopSnapshot:(FTRunLoopSnapshot *)snapshot {
    // The main RunLoop is the only writer. An even sequence brackets one complete callback.
    // A stalled reader never holds up the main thread; discard a snapshot being updated.
    for (NSUInteger attempt = 0; attempt < 3; attempt++) {
        unsigned long long before = atomic_load_explicit(&_runLoopSequence, memory_order_seq_cst);
        if (before & 1) {
            continue;
        }
        CFRunLoopActivity activity = atomic_load_explicit(&_activity, memory_order_seq_cst);
        long long startTimestampNs = atomic_load_explicit(&_runLoopStartTimestampNs, memory_order_seq_cst);
        unsigned long long after = atomic_load_explicit(&_runLoopSequence, memory_order_seq_cst);
        if (before == after) {
            *snapshot = (FTRunLoopSnapshot){activity, startTimestampNs, after / 2};
            return YES;
        }
    }
    return NO;
}

- (void)recordRunLoopActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs {
    unsigned long long nextSequence = atomic_load_explicit(&_runLoopSequence, memory_order_relaxed) + 2;
    atomic_store_explicit(&_runLoopSequence, nextSequence - 1, memory_order_seq_cst);
    atomic_store_explicit(&_activity, activity, memory_order_seq_cst);
    atomic_store_explicit(&_runLoopStartTimestampNs, timeNs, memory_order_seq_cst);
    atomic_store_explicit(&_runLoopSequence, nextSequence, memory_order_seq_cst);
    dispatch_semaphore_signal(_semaphore);
}

- (void)processWaitResult:(long)waitResult elapsedNanoseconds:(uint64_t)elapsedNanoseconds currentEpochNs:(long long)currentEpochNs {
    FTRunLoopSnapshot snapshot;
    if (![self runLoopSnapshot:&snapshot]) {
        return;
    }
    if (_detectionState == FTLongTaskDetectionStateWaitingForNormalTimeout && snapshot.generation != _resumeGeneration) {
        // A real RunLoop callback supplied a new start; queued semaphore signals do not.
        _resumeBaselineNs = 0;
        _detectionState = FTLongTaskDetectionStateIdle;
    }

    BOOL busyTimeout = waitResult != 0 &&
        (snapshot.activity == kCFRunLoopBeforeSources || snapshot.activity == kCFRunLoopAfterWaiting);
    if (busyTimeout) {
        if (_detectionState != FTLongTaskDetectionStateStartDispatched && self.limitMillisecond > 0 && currentEpochNs > 0 &&
            elapsedNanoseconds > (uint64_t)self.limitMillisecond * 2 * NSEC_PER_MSEC) {
            // The detector was not scheduled promptly. The earlier RunLoop time is no longer a
            // trustworthy start for a new sample; require another normal timeout first.
            _resumeBaselineNs = currentEpochNs;
            _resumeGeneration = snapshot.generation;
            _detectionState = FTLongTaskDetectionStateWaitingForNormalTimeout;
            return;
        }
        if (_detectionState == FTLongTaskDetectionStateStartDispatched) {
            if (self.longTaskDelegate && [self.longTaskDelegate respondsToSelector:@selector(updateLongTaskDate:)]) {
                [self.longTaskDelegate updateLongTaskDate:currentEpochNs];
            }
        } else {
            long long effectiveStartNs = snapshot.startTimestampNs;
            if (_detectionState == FTLongTaskDetectionStateWaitingForNormalTimeout && _resumeBaselineNs > effectiveStartNs) {
                effectiveStartNs = _resumeBaselineNs;
            }
            _resumeBaselineNs = 0;
            _detectionState = FTLongTaskDetectionStateStartDispatched;
            if (self.longTaskDelegate && [self.longTaskDelegate respondsToSelector:@selector(startLongTask:)]) {
                [self.longTaskDelegate startLongTask:effectiveStartNs];
            }
        }
        return;
    }
    if (_detectionState == FTLongTaskDetectionStateStartDispatched) {
        if (self.longTaskDelegate && [self.longTaskDelegate respondsToSelector:@selector(endLongTask)]) {
            [self.longTaskDelegate endLongTask];
        }
        _detectionState = FTLongTaskDetectionStateIdle;
    }
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
                uint64_t waitStart = [FTDateUtil continuousTime];
                long waitResult = dispatch_semaphore_wait(self->_semaphore, dispatch_time(DISPATCH_TIME_NOW, strongSelf.limitMillisecond*NSEC_PER_MSEC));
                uint64_t waitEnd = [FTDateUtil continuousTime];
                uint64_t elapsed = waitEnd >= waitStart ? waitEnd - waitStart : 0;
                [strongSelf processWaitResult:waitResult elapsedNanoseconds:elapsed currentEpochNs:[NSDate ft_currentNanosecondTimeStamp]];
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
        [strongSelf recordRunLoopActivity:activity atTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
    });
    CFRetain(beginObserver);
    m_runLoopBeginObserver = beginObserver;
    CFRelease(beginObserver);
    CFRunLoopObserverRef endObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopExit|kCFRunLoopBeforeWaiting, YES, LONG_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf recordRunLoopActivity:activity atTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
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
    if (m_runLoopEndObserver) {
        CFRelease(m_runLoopEndObserver);
    }
    if (m_runLoopBeginObserver) {
        CFRelease(m_runLoopBeginObserver);
    }
}

@end
