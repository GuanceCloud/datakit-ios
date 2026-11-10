//
//  FTLongTaskDetector.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/26.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTLongTaskTiming.h"
#import "FTInnerLog.h"
#import "FTDateUtil.h"
#import "NSDate+FTUtil.h"
#import <stdatomic.h>
#import <pthread.h>
#import <errno.h>
#import <objc/runtime.h>
#import <TargetConditionals.h>

static const uint64_t FTIdleWaitNs = NSEC_PER_SEC;
static const uint64_t FTIntervalEndWaitNs = NSEC_PER_SEC;
static const uint64_t FTCallbackOverlapLimitNs = NSEC_PER_SEC;

// Main-thread-owned weak registrations; the installed hook has process lifetime.
static NSHashTable<FTLongTaskDetector *> *FTSuspendDetectors;
static void (*FTOriginalPrepareForSuspend)(id, SEL);

@interface FTLongTaskDetector () {
    CFRunLoopObserverRef m_runLoopBeginObserver;
    CFRunLoopObserverRef m_runLoopEndObserver;
    pthread_cond_t _stateChanged;
    pthread_mutex_t _waitMutex;
    BOOL _waitPrimitivesInitialized;

    // SDK shutdown stops this instance; SDK reinitialization creates a new detector.
    atomic_bool _monitoring;

    // Main-thread publication version: odd = being written, even = ready to read.
    // Each callback adds 2, so sequence / 2 is the interval's delegate generation.
    atomic_ullong _runLoopSequence;
    _Atomic(CFRunLoopActivity) _activity;
    atomic_bool _runloopRunning;
    atomic_llong _runLoopStartTimestampNs;
    atomic_ullong _runLoopContinuousNs;

    // Worker arms one sequence. The main thread saves its FIRST closing boundary;
    // later callbacks must not overwrite it before the worker has processed End.
    atomic_ullong _watchedSequence;
    atomic_ullong _closedSequence;
    atomic_ullong _closedContinuousNs;
    atomic_llong _closedEpochNs;
}
@property (nonatomic, weak) id<FTLongTaskTimingDelegate> longTaskDelegate;
@property (nonatomic, strong) dispatch_queue_t longTaskQueue;

@end

static void FTPrepareForSuspend(id scene, SEL selector);

@implementation FTLongTaskDetector

#pragma mark - Lifecycle and worker queue

- (instancetype)initWithDelegate:(id<FTLongTaskTimingDelegate>)delegate {
    self = [super init];
    if (self) {
        _longTaskDelegate = delegate;
        if (pthread_mutex_init(&_waitMutex, NULL) != 0) {
            return nil;
        }
        if (pthread_cond_init(&_stateChanged, NULL) != 0) {
            pthread_mutex_destroy(&_waitMutex);
            return nil;
        }
        _waitPrimitivesInitialized = YES;
        atomic_init(&_monitoring, false);
        atomic_init(&_runLoopSequence, 0);
        atomic_init(&_activity, 0);
        atomic_init(&_runloopRunning, false);
        atomic_init(&_runLoopStartTimestampNs, 0);
        atomic_init(&_runLoopContinuousNs, 0);
        atomic_init(&_watchedSequence, 0);
        atomic_init(&_closedSequence, 0);
        atomic_init(&_closedContinuousNs, 0);
        atomic_init(&_closedEpochNs, 0);
        _longTaskQueue = dispatch_queue_create("com.ft.longtask", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)startDetecting {
    if (atomic_exchange(&_monitoring, true)) {
        return;
    }

    [self registerObserver];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.longTaskQueue, ^{
        [weakSelf runMonitor];
    });
}

- (void)stopDetecting {
    atomic_store(&_monitoring, false);
    [self signalStateChange];

    if (m_runLoopBeginObserver) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopBeginObserver, kCFRunLoopCommonModes);
    }
    if (m_runLoopEndObserver) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopEndObserver, kCFRunLoopCommonModes);
    }
    dispatch_block_t removeRegistration = ^{
        [FTSuspendDetectors removeObject:self];
    };
    if (NSThread.isMainThread) {
        removeRegistration();
    } else {
        dispatch_async(dispatch_get_main_queue(), removeRegistration);
    }
}

- (void)performAsynchronousBlock:(dispatch_block_t)block {
    dispatch_async(self.longTaskQueue, block);
}

- (BOOL)isMonitoringGeneration:(uint64_t)generation {
    return atomic_load(&_monitoring) && atomic_load(&_runLoopSequence) == generation * 2;
}

- (void)dealloc {
    if (_waitPrimitivesInitialized) {
        pthread_cond_destroy(&_stateChanged);
        pthread_mutex_destroy(&_waitMutex);
    }
    if (m_runLoopBeginObserver) {
        CFRelease(m_runLoopBeginObserver);
    }
    if (m_runLoopEndObserver) {
        CFRelease(m_runLoopEndObserver);
    }
}

#pragma mark - Main-thread RunLoop boundaries

- (void)recordRunLoopBeginActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs {
    switch (activity) {
        case kCFRunLoopEntry:
        case kCFRunLoopAfterWaiting:
            [self setRunloopRunning:YES activity:activity atTimeNs:timeNs];
            break;
        case kCFRunLoopBeforeSources:
            // Advance the interval without enabling a disabled RunLoop.
            [self setRunloopRunning:atomic_load(&_runloopRunning) activity:activity atTimeNs:timeNs];
            break;
        default:
            break;
    }
}

- (void)recordRunLoopEndActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs {
    if (activity == kCFRunLoopBeforeWaiting || activity == kCFRunLoopExit) {
        [self setRunloopRunning:NO activity:activity atTimeNs:timeNs];
    }
}

- (void)setRunloopRunning:(BOOL)running activity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs {
    uint64_t continuousNs = [FTDateUtil continuousTime];
    uint64_t previousSequence = atomic_load(&_runLoopSequence);
    atomic_store(&_runLoopSequence, previousSequence + 1); // Mark snapshot as being written.

    if (previousSequence != 0 && atomic_load(&_watchedSequence) == previousSequence) {
        atomic_store(&_closedEpochNs, timeNs);
        atomic_store(&_closedContinuousNs, continuousNs);
        atomic_store(&_closedSequence, previousSequence); // Publish only after both timestamps.
    }
    atomic_store(&_activity, activity);
    atomic_store(&_runloopRunning, running);
    atomic_store(&_runLoopStartTimestampNs, timeNs);
    atomic_store(&_runLoopContinuousNs, continuousNs);
    atomic_store(&_runLoopSequence, previousSequence + 2); // Publish the complete snapshot.
    [self signalStateChange];
}

- (BOOL)readRunLoopSnapshot:(FTLongTaskRunLoopSnapshot *)snapshot {
    for (NSUInteger attempt = 0; attempt < 3; attempt++) {
        uint64_t sequence = atomic_load(&_runLoopSequence);
        if (sequence & 1) {
            continue;
        }
        FTLongTaskRunLoopSnapshot candidate = {
            .sequence = sequence,
            .activity = atomic_load(&_activity),
            .running = atomic_load(&_runloopRunning),
            .startTimeNs = atomic_load(&_runLoopStartTimestampNs),
            .startContinuousNs = atomic_load(&_runLoopContinuousNs)
        };
        // A concurrent callback invalidates the entire read, not individual fields.
        if (sequence == atomic_load(&_runLoopSequence)) {
            *snapshot = candidate;
            return YES;
        }
    }
    return NO;
}

- (void)registerObserver {
    if (m_runLoopBeginObserver) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopBeginObserver, kCFRunLoopCommonModes);
        CFRelease(m_runLoopBeginObserver);
    }
    if (m_runLoopEndObserver) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), m_runLoopEndObserver, kCFRunLoopCommonModes);
        CFRelease(m_runLoopEndObserver);
    }
    __weak typeof(self) weakSelf = self;
    m_runLoopBeginObserver = CFRunLoopObserverCreateWithHandler(NULL,
        kCFRunLoopEntry | kCFRunLoopBeforeSources | kCFRunLoopAfterWaiting, YES, LONG_MIN,
        ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            [weakSelf recordRunLoopBeginActivity:activity atTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
        });
    m_runLoopEndObserver = CFRunLoopObserverCreateWithHandler(NULL,
        kCFRunLoopBeforeWaiting | kCFRunLoopExit, YES, LONG_MAX,
        ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            [weakSelf recordRunLoopEndActivity:activity atTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
        });
    CFRunLoopAddObserver(CFRunLoopGetMain(), m_runLoopBeginObserver, kCFRunLoopCommonModes);
    CFRunLoopAddObserver(CFRunLoopGetMain(), m_runLoopEndObserver, kCFRunLoopCommonModes);
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    if (NSThread.isMainThread && [[self class] installSuspendHookForClass:NSClassFromString(@"UIWindowScene")]) {
        if (!FTSuspendDetectors) {
            FTSuspendDetectors = [NSHashTable weakObjectsHashTable];
        }
        [FTSuspendDetectors addObject:self];
    }
#endif
}

#pragma mark - Worker: select an interval, then observe it until it ends

- (void)runMonitor {
    while (atomic_load(&_monitoring)) {
        @autoreleasepool {
            FTLongTaskRunLoopSnapshot snapshot;
            if (![self readRunLoopSnapshot:&snapshot]) {
                continue;
            }

            if (!snapshot.running) {
                // Idle time is never credited as blocking. A signal or timeout rechecks state.
                int result = [self waitForRunLoopChangeSinceSequence:snapshot.sequence
                                                timeoutNanoseconds:FTIdleWaitNs];
                if (result != 0 && result != ETIMEDOUT) {
                    break;
                }
                continue;
            }

            [self monitorRunLoopInterval:snapshot];
        }
    }

    atomic_store(&_monitoring, false);
}

- (void)monitorRunLoopInterval:(FTLongTaskRunLoopSnapshot)snapshot {
    // Arm before validating: any callback after this point must save our End boundary.
    atomic_store(&_watchedSequence, snapshot.sequence);
    if (atomic_load(&_runLoopSequence) != snapshot.sequence) {
        atomic_store(&_watchedSequence, 0);
        return;
    }

    FTLongTaskTiming timing = {
        .phase = FTLongTaskPhaseBegin,
        .generation = snapshot.sequence / 2,
        .startTimeNs = snapshot.startTimeNs,
        .observationTimeNs = snapshot.startTimeNs,
        .durationNs = 0
    };
    uint64_t nextCheckpointNs = [self notifyTiming:timing];

    while (atomic_load(&_monitoring)) {
        // Drain checkpoint/capture temporaries without waiting for this interval to end.
        @autoreleasepool {
            // Checkpoints are absolute effective durations, not wall-clock deadlines.
            uint64_t waitBudgetNs = FTIntervalEndWaitNs;
            if (nextCheckpointNs != UINT64_MAX) {
                waitBudgetNs = nextCheckpointNs > timing.durationNs
                    ? nextCheckpointNs - timing.durationNs : NSEC_PER_MSEC;
            }
            uint64_t waitBeginNs = [FTDateUtil continuousTime];
            int result = [self waitForRunLoopChangeSinceSequence:snapshot.sequence
                                            timeoutNanoseconds:waitBudgetNs];
            if (!atomic_load(&_monitoring)) {
                break;
            }
            if (result != 0 && result != ETIMEDOUT) {
                FTInnerLogError(@"[LongTask] condition wait failed: %d", result);
                [self stopDetecting];
                break;
            }

            // Wait credit and callback overlap are settled separately, once per round.
            BOOL intervalEnded = atomic_load(&_closedSequence) == snapshot.sequence;
            uint64_t waitEndNs = intervalEnded ? atomic_load(&_closedContinuousNs) : [FTDateUtil continuousTime];
            uint64_t elapsedNs = waitEndNs > waitBeginNs ? waitEndNs - waitBeginNs : 0;
            if (!intervalEnded && timing.phase == FTLongTaskPhaseBegin) {
                // Require a normally scheduled wait before the first Checkpoint.
                // More than twice the budget discards this wait and retries without credit.
                uint64_t excessWaitNs = elapsedNs > waitBudgetNs ? elapsedNs - waitBudgetNs : 0;
                if (excessWaitNs > waitBudgetNs) {
                    continue;
                }
            }
            uint64_t creditedNs = waitBudgetNs;
            if (intervalEnded || result != ETIMEDOUT) {
                creditedNs = MIN(elapsedNs, waitBudgetNs);
            }
            // A timeout credits only its budget, even if scheduling/suspension delayed our return.
            timing.durationNs += creditedNs;
            if (intervalEnded) {
                // A boundary racing the timeout cannot produce more than the complete interval.
                uint64_t intervalSpanNs = waitEndNs > snapshot.startContinuousNs
                    ? waitEndNs - snapshot.startContinuousNs : 0;
                timing.durationNs = MIN(timing.durationNs, intervalSpanNs);
                timing.observationTimeNs = atomic_load(&_closedEpochNs);
                timing.phase = FTLongTaskPhaseEnd;
            } else {
                timing.observationTimeNs = [NSDate ft_currentNanosecondTimeStamp];
                timing.phase = FTLongTaskPhaseCheckpoint;
            }

            if (intervalEnded || timing.durationNs >= nextCheckpointNs) {
                uint64_t callbackBeginNs = [FTDateUtil continuousTime];
                nextCheckpointNs = [self notifyTiming:timing];
                if (!intervalEnded) {
                    // Main-thread work can continue while the worker captures/symbolicates.
                    // Clip to the FIRST producer End, even if the callback returns much later.
                    uint64_t callbackEndNs = [FTDateUtil continuousTime];
                    if (atomic_load(&_closedSequence) == snapshot.sequence) {
                        callbackEndNs = MIN(callbackEndNs, atomic_load(&_closedContinuousNs));
                    }
                    uint64_t overlapNs = callbackEndNs > callbackBeginNs ? callbackEndNs - callbackBeginNs : 0;
                    // A long unobserved callback may include process suspension. Reject only
                    // this round's overlap; normal overlaps from other rounds remain credited.
                    if (overlapNs < FTCallbackOverlapLimitNs) {
                        timing.durationNs += overlapNs;
                    }
                }
            }
            if (intervalEnded) {
                break;
            }
        }
    }
    atomic_store(&_watchedSequence, 0);
}

#pragma mark - Timed condition wait

- (void)signalStateChange {
    // State is retained in atomics; signals do not count events. The main thread never
    // takes the wait mutex. A pre-sleep lost signal is observed at the timed deadline.
    pthread_cond_signal(&_stateChanged);
}

- (int)waitForRunLoopChangeSinceSequence:(uint64_t)sequence
                    timeoutNanoseconds:(uint64_t)timeoutNs {
    uint64_t waitBeginNs = [FTDateUtil continuousTime];
    int result = pthread_mutex_lock(&_waitMutex);
    if (result != 0) {
        return result;
    }

    while (YES) {
        if (!atomic_load(&_monitoring)) {
            result = ECANCELED;
            break;
        }
        if (result != 0 && result != ETIMEDOUT) {
            break;
        }

        uint64_t currentSequence = atomic_load(&_runLoopSequence);
        if (!(currentSequence & 1) && currentSequence != sequence) {
            // A complete state change takes precedence over a racing timeout.
            result = 0;
            break;
        }
        if (result == ETIMEDOUT) {
            break;
        }

        uint64_t nowNs = [FTDateUtil continuousTime];
        uint64_t elapsedNs = nowNs >= waitBeginNs ? nowNs - waitBeginNs : 0;
        if (elapsedNs >= timeoutNs) {
            result = ETIMEDOUT;
            break;
        }
        // Spurious wakes use the remaining budget, never a fresh full interval.
        uint64_t remainingNs = timeoutNs - elapsedNs;
        struct timespec remaining = {
            .tv_sec = (time_t)(remainingNs / NSEC_PER_SEC),
            .tv_nsec = (long)(remainingNs % NSEC_PER_SEC)
        };
        // Darwin's relative wait avoids CLOCK_REALTIME adjustments.
        result = pthread_cond_timedwait_relative_np(&_stateChanged, &_waitMutex, &remaining);
    }
    pthread_mutex_unlock(&_waitMutex);
    return result;
}

#pragma mark - Timing delegate

- (uint64_t)notifyTiming:(FTLongTaskTiming)timing {
    id<FTLongTaskTimingDelegate> delegate = self.longTaskDelegate;
    @try {
        return delegate ? [delegate longTaskDetector:self didObserveTiming:timing] : UINT64_MAX;
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] callback exception %@", exception);
        return UINT64_MAX;
    }
}

#pragma mark - Scene suspend-preparation boundary

- (void)beginPreparingForSuspend {
    if (!atomic_load(&_monitoring)) {
        return;
    }
    [self setRunloopRunning:NO activity:0 atTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
}

- (void)endPreparingForSuspend {
    if (!atomic_load(&_monitoring)) {
        return;
    }
    [self setRunloopRunning:YES activity:0 atTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
}

+ (BOOL)installSuspendHookForClass:(Class)cls {
    if (!NSThread.isMainThread || !cls) {
        return NO;
    }
    SEL selector = NSSelectorFromString(@"_prepareForSuspend");
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return NO;
    }
    if (method_getImplementation(method) == (IMP)FTPrepareForSuspend) {
        return YES;
    }
    if (FTOriginalPrepareForSuspend) {
        return NO;
    }
    char *returnType = method_copyReturnType(method);
    BOOL compatible = returnType && strcmp(returnType, "v") == 0 && method_getNumberOfArguments(method) == 2;
    free(returnType);
    if (!compatible) {
        return NO;
    }
    FTOriginalPrepareForSuspend = (void (*)(id, SEL))method_getImplementation(method);
    class_replaceMethod(cls, selector, (IMP)FTPrepareForSuspend, method_getTypeEncoding(method));
    return YES;
}
@end

static void FTPrepareForSuspend(id scene, SEL selector) {
    NSArray<FTLongTaskDetector *> *detectors = NSThread.isMainThread ? FTSuspendDetectors.allObjects : nil;
    for (FTLongTaskDetector *detector in detectors) {
        [detector beginPreparingForSuspend];
    }
    @try {
        FTOriginalPrepareForSuspend(scene, selector);
    } @finally {
        for (FTLongTaskDetector *detector in detectors) {
            [detector endPreparingForSuspend];
        }
    }
}
