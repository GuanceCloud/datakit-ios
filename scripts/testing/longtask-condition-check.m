// Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>
#import <errno.h>
#import <stdatomic.h>
#import <objc/runtime.h>
#import "FTLongTaskTiming.h"
#import "FTDateUtil.h"
#import "NSDate+FTUtil.h"
#import "FTLog.h"

static const uint64_t ms = NSEC_PER_MSEC;
static uint64_t fakeNow;
static BOOL fakeClock;
static int (^waitHook)(pthread_cond_t *, pthread_mutex_t *, const struct timespec *);

@implementation FTDateUtil
+ (uint64_t)continuousTime { return fakeClock ? fakeNow : clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW); }
@end
@implementation FTLog
+ (BOOL)isLoggerEnabled { return NO; }
@end
@implementation NSDate (FTUtil)
+ (long long)ft_currentNanosecondTimeStamp { return fakeClock ? (long long)fakeNow : (long long)(NSDate.date.timeIntervalSince1970 * NSEC_PER_SEC); }
@end

// Only the detector's call is redirected here; unscripted waits use the real pthread implementation.
int FTTestConditionWait(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
    if (waitHook) return waitHook(condition, mutex, timeout);
    return pthread_cond_timedwait_relative_np(condition, mutex, timeout);
}

int FTTestUnexpectedUntimedWait(pthread_cond_t *condition, pthread_mutex_t *mutex) {
    fprintf(stderr, "FAIL: detector must use timed condition waits\n");
    exit(1);
}

@interface FTLongTaskDetector (ConditionTests)
- (void)setRunloopRunning:(BOOL)running activity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (void)recordRunLoopBeginActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (void)recordRunLoopEndActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (BOOL)readRunLoopSnapshot:(FTLongTaskRunLoopSnapshot *)snapshot;
- (int)waitForRunLoopChangeSinceSequence:(uint64_t)sequence timeoutNanoseconds:(uint64_t)timeoutNs;
- (void)registerObserver;
- (void)beginPreparingForSuspend;
- (void)endPreparingForSuspend;
+ (BOOL)installSuspendHookForClass:(Class)cls;
@end

@interface TimingProbe : NSObject <FTLongTaskTimingDelegate>
@property (nonatomic) NSUInteger observations;
@property (nonatomic, copy) uint64_t (^observe)(FTLongTaskDetector *, FTLongTaskTiming);
@end
@implementation TimingProbe
- (uint64_t)longTaskDetector:(FTLongTaskDetector *)detector didObserveTiming:(FTLongTaskTiming)timing {
    self.observations += 1;
    return self.observe ? self.observe(detector, timing) : UINT64_MAX;
}
@end

static NSUInteger releasedTemporaries;
@interface AutoreleaseToken : NSObject @end
@implementation AutoreleaseToken
- (void)dealloc { releasedTemporaries += 1; }
@end

// Explicitly enqueue ten owned tokens, without ARC return-value optimizations.
extern void *FTTestAutorelease(void *) __asm__("_objc_autorelease");
static void EnqueueTemporaries(void) {
    for (NSUInteger index = 0; index < 10; index++) {
        FTTestAutorelease((__bridge_retained void *)[AutoreleaseToken new]);
    }
}

// Exercise the real worker without unrelated main RunLoop callbacks.
@interface ControlledDetector : FTLongTaskDetector
@property (nonatomic) NSUInteger observerRegistrations;
@end
@implementation ControlledDetector
- (void)registerObserver { self.observerRegistrations += 1; }
@end

static void Check(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
static uint64_t Sequence(FTLongTaskDetector *detector) {
    FTLongTaskRunLoopSnapshot snapshot;
    Check([detector readRunLoopSnapshot:&snapshot], "coherent RunLoop snapshot");
    return snapshot.sequence;
}
static void *IvarAddress(FTLongTaskDetector *detector, const char *name) {
    Ivar ivar = class_getInstanceVariable(FTLongTaskDetector.class, name);
    Check(ivar != NULL, "test synchronization seam exists");
    return (uint8_t *)(__bridge void *)detector + ivar_getOffset(ivar);
}
// Isolate the wait helper: mark collection active without launching a worker.
static FTLongTaskDetector *WaitingDetector(TimingProbe *probe) {
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:probe];
    atomic_store((atomic_bool *)IvarAddress(detector, "_monitoring"), true);
    return detector;
}
static void Await(dispatch_semaphore_t gate) {
    Check(dispatch_semaphore_wait(gate, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0, "synchronization gate completed");
}
static uint64_t TimeoutNs(const struct timespec *timeout) { return timeout->tv_sec * NSEC_PER_SEC + timeout->tv_nsec; }
static void ResetClock(void) { waitHook = nil; fakeClock = NO; fakeNow = 0; }

static void DrainDetector(FTLongTaskDetector *detector) {
    dispatch_sync([detector valueForKey:@"longTaskQueue"], ^{});
}

static void TestIdleWorkerUsesBoundedWait(void) {
    for (NSNumber *state in @[@(kCFRunLoopBeforeWaiting), @(kCFRunLoopExit), @0]) {
        TimingProbe *probe = [TimingProbe new];
        ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
        fakeClock = YES;
        fakeNow = 1000 * ms;
        if (state.unsignedLongValue != 0) {
            [detector recordRunLoopEndActivity:state.unsignedLongValue atTimeNs:fakeNow];
        }
        __block NSUInteger waits = 0;
        waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
            Check(TimeoutNs(timeout) == NSEC_PER_SEC, "idle wait has a one-second recheck deadline");
            fakeNow += 600 * NSEC_PER_SEC;
            waits += 1;
            if (waits == 3) [detector stopDetecting];
            return ETIMEDOUT;
        };
        [detector startDetecting];
        DrainDetector(detector);
        Check(waits == 3 && probe.observations == 0,
              "idle timeout rechecks never become stall callbacks");
        ResetClock();
    }
}

static void TestBurstIsOneStateChange(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    for (NSUInteger i = 0; i < 10000; i++) {
        [detector recordRunLoopBeginActivity:kCFRunLoopBeforeSources atTimeNs:(long long)(1000 + i) * ms];
    }
    Check([detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:0] == 0, "observe latest state published before wait");
    uint64_t consumed = Sequence(detector);
    Check([detector waitForRunLoopChangeSinceSequence:consumed timeoutNanoseconds:0] == ETIMEDOUT,
          "10000 callbacks must not leave counted wakeups after latest state is consumed");
    Check(probe.observations == 0, "notifications alone do not report a stall");
}

static void TestSpuriousWakeupsKeepDeadline(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    fakeClock = YES; fakeNow = 1000 * ms;
    __block NSUInteger calls = 0;
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
        uint64_t expected[] = {250 * ms, 200 * ms, 125 * ms};
        Check(calls < 3, "spurious wakeups cannot extend deadline");
        Check(TimeoutNs(timeout) == expected[calls], "exact remaining timeout after spurious wakeup");
        fakeNow += (calls == 0 ? 50 : calls == 1 ? 75 : 125) * ms;
        return ++calls == 3 ? ETIMEDOUT : 0;
    };
    Check([detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:250 * ms] == ETIMEDOUT,
          "spurious notifications do not count as RunLoop progress");
    Check(calls == 3 && fakeNow == 1250 * ms, "fixed 250ms timeout budget");
    ResetClock();
}

static void TestPublishBetweenPredicateAndSleep(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    fakeClock = YES; fakeNow = 1000 * ms;
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
        // Producer runs after the predicate check but before the actual wait.
        // The retained state must win over a concurrent ETIMEDOUT result.
        [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:1100 * ms];
        fakeNow = 1250 * ms;
        return ETIMEDOUT;
    };
    Check([detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:250 * ms] == 0,
          "state published in pre-sleep gap is observed, not classified as a timeout");
    Check(Sequence(detector) == 2, "one callback observed across timeout race");
    ResetClock();
}

static void TestRunLoopNeverWaitsForWaitMutex(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    pthread_mutex_t *mutex = IvarAddress(detector, "_waitMutex");
    pthread_mutex_lock(mutex);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [detector recordRunLoopBeginActivity:kCFRunLoopBeforeSources atTimeNs:1000 * ms];
        dispatch_semaphore_signal(done);
    });
    long result = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
    pthread_mutex_unlock(mutex);
    Check(result == 0, "RunLoop publisher does not block behind descheduled waiter owning mutex");
    Check(Sequence(detector) == 2, "publisher retained its exact snapshot");
}

static void TestStopWakesRealWaiter(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), done = dispatch_semaphore_create(0);
    __block int result = 0;
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
        dispatch_semaphore_signal(entered);
        return pthread_cond_timedwait_relative_np(condition, mutex, timeout);
    };
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        result = [detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:10 * NSEC_PER_SEC];
        dispatch_semaphore_signal(done);
    });
    Await(entered);
    // Acquiring this lock proves pthread has atomically released it to wait.
    pthread_mutex_t *mutex = IvarAddress(detector, "_waitMutex");
    pthread_mutex_lock(mutex);
    [detector stopDetecting];
    pthread_mutex_unlock(mutex);
    Await(done);
    Check(result == ECANCELED, "stop wakes waiter without waiting for 10-second timeout");
    ResetClock();
}

static void TestStopInPreSleepGap(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    fakeClock = YES; fakeNow = 1000 * ms;
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
        [detector stopDetecting];
        fakeNow += TimeoutNs(timeout);
        return ETIMEDOUT;
    };
    Check([detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:250 * ms] == ECANCELED,
          "stop in pre-sleep race cancels instead of reporting a stall");
    ResetClock();
}

static void TestStatePublicationWakesRealWaiter(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), done = dispatch_semaphore_create(0);
    __block int result = ETIMEDOUT;
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
        dispatch_semaphore_signal(entered);
        return pthread_cond_timedwait_relative_np(condition, mutex, timeout);
    };
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        result = [detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:10 * NSEC_PER_SEC];
        dispatch_semaphore_signal(done);
    });
    Await(entered);
    pthread_mutex_t *mutex = IvarAddress(detector, "_waitMutex");
    pthread_mutex_lock(mutex);
    [detector recordRunLoopBeginActivity:kCFRunLoopBeforeSources atTimeNs:1234 * ms];
    pthread_mutex_unlock(mutex);
    Await(done);
    Check(result == 0, "RunLoop publication wakes an actual sleeping pthread waiter");
    FTLongTaskRunLoopSnapshot snapshot;
    Check([detector readRunLoopSnapshot:&snapshot] &&
          snapshot.activity == kCFRunLoopBeforeSources && snapshot.startTimeNs == 1234 * ms && snapshot.sequence == 2,
          "woken reader sees the exact published state and event timestamp");
    ResetClock();
}

static void TestWaitErrorsAreNotTimeouts(void) {
    TimingProbe *probe = [TimingProbe new]; FTLongTaskDetector *detector = WaitingDetector(probe);
    fakeClock = YES; fakeNow = 1000 * ms;
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) { return EINVAL; };
    Check([detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:250 * ms] == EINVAL,
          "invalid wait is not converted into a busy timeout");
    ResetClock();
}

static void TestMissedSignalIsObservedAtDeadline(void) {
    for (NSNumber *cancel in @[@NO, @YES]) {
        TimingProbe *probe = [TimingProbe new];
        FTLongTaskDetector *detector = WaitingDetector(probe);
        fakeClock = YES;
        fakeNow = 1000 * ms;
        __block NSUInteger waits = 0;
        waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
            Check(TimeoutNs(timeout) == NSEC_PER_SEC, "pre-sleep race retains a finite deadline");
            waits += 1;
            // Signal before sleeping has no waiter. Timeout must still observe
            // the retained state or cancellation rather than report a stall.
            if (cancel.boolValue) [detector stopDetecting];
            else [detector setRunloopRunning:YES activity:kCFRunLoopAfterWaiting atTimeNs:1100 * ms];
            fakeNow += NSEC_PER_SEC;
            return ETIMEDOUT;
        };
        int result = [detector waitForRunLoopChangeSinceSequence:0 timeoutNanoseconds:NSEC_PER_SEC];
        Check(result == (cancel.boolValue ? ECANCELED : 0) && waits == 1,
              "timeout recovers a missed signal without converting state changes into stalls");
        ResetClock();
    }
}

static void Run(FTLongTaskDetector *detector) {
    [detector startDetecting];
    DrainDetector(detector);
}
static void TestUnavailableDelegateUsesBoundedEndWait(void) {
    for (NSNumber *throws in @[@NO, @YES]) {
        fakeClock = YES;
        fakeNow = 1000 * ms;
        TimingProbe *probe = [TimingProbe new];
        ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
        if (throws.boolValue) {
            probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
                [NSException raise:@"delegate" format:@"test callback failure"];
                return 0;
            };
        } else {
            probe = nil; // The detector's weak delegate has disappeared.
        }
        [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
        __block NSUInteger waits = 0;
        waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
            Check(TimeoutNs(timeout) == NSEC_PER_SEC,
                  "absent or throwing delegate uses bounded end wait, not an invented checkpoint cadence");
            waits += 1;
            [detector stopDetecting];
            return ETIMEDOUT;
        };
        Run(detector);
        Check(waits == 1, "delegate failure does not terminate or spin the monitor");
        if (probe) Check(probe.observations == 1, "throwing callback was attempted exactly once");
        ResetClock();
    }
}
static void TestBoundedGapAndDelayedEnd(void) {
    fakeClock = YES; fakeNow = 1000 * ms;
    TimingProbe *probe = [TimingProbe new]; ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    __block NSUInteger waits=0, checkpoints=0, ends=0;
    waitHook = ^int(pthread_cond_t *c,pthread_mutex_t *m,const struct timespec *timeout) {
        Check(TimeoutNs(timeout)==250*ms,"next checkpoint supplies exact remaining budget");
        waits++;
        if (waits==1) { fakeNow+=250*ms; return ETIMEDOUT; }
        if (waits==2) { fakeNow+=60*NSEC_PER_SEC; return ETIMEDOUT; }
        fakeNow+=100*ms;
        [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
        fakeNow+=10*NSEC_PER_SEC; // terminal processing delayed by ten seconds
        return 0;
    };
    probe.observe=^uint64_t(FTLongTaskDetector *d,FTLongTaskTiming t) {
        if(t.phase==FTLongTaskPhaseBegin) return 250*ms;
        if(t.phase==FTLongTaskPhaseCheckpoint) {
            checkpoints++;
            Check(t.durationNs==checkpoints*250*ms,"confirmed interval credits only 250ms per timeout, including a later 60s gap");
            return t.durationNs+250*ms;
        }
        ends++; Check(t.durationNs==600*ms && t.observationTimeNs==61350*ms,"end preserves exact 600ms effective duration and actual 61.35s boundary");
        [d stopDetecting]; return UINT64_MAX;
    };
    Run(detector);
    Check(waits==3 && checkpoints==2 && ends==1,"confirmed interval survives later scheduling delay and ends once");
    probe.observe=nil;ResetClock();
}

static void TestFirstCheckpointRequiresNormallyScheduledWait(void) {
    for (NSNumber *budgetValue in @[@(251 * ms), @(3001 * ms)]) {
        uint64_t budget = budgetValue.unsignedLongLongValue;
        for (NSNumber *delayValue in @[@(2 * budget), @(2 * budget + 1), @(60 * NSEC_PER_SEC)]) {
            uint64_t delay = delayValue.unsignedLongLongValue;
            BOOL rejectFirst = delay > 2 * budget;
            fakeClock = YES; fakeNow = NSEC_PER_SEC;
            TimingProbe *probe = [TimingProbe new];
            ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
            [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
            __block NSUInteger waits = 0, checkpoints = 0, ends = 0;
            waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
                Check(TimeoutNs(timeout) == budget, "discarded first wait preserves the original checkpoint budget");
                waits += 1;
                if (waits == 1) { fakeNow += delay; return ETIMEDOUT; }
                if (rejectFirst && waits == 2) {
                    Check(checkpoints == 0, "more than twice the budget must not confirm the first checkpoint");
                    fakeNow += budget;
                    return ETIMEDOUT;
                }
                fakeNow += 100 * ms;
                [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
                return 0;
            };
            probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
                Check(timing.startTimeNs == NSEC_PER_SEC, "discarding wait credit does not fabricate a producer start");
                if (timing.phase == FTLongTaskPhaseBegin) return budget;
                if (timing.phase == FTLongTaskPhaseCheckpoint) {
                    checkpoints += 1;
                    Check(waits == (rejectFirst ? 2 : 1), "first checkpoint waits for a normal timeout after excessive delay");
                    Check(timing.durationNs == budget, "discarded waits contribute exactly zero effective duration");
                    return 2 * budget;
                }
                ends += 1;
                Check(timing.durationNs == budget + 100 * ms &&
                      timing.observationTimeNs == NSEC_PER_SEC + delay + (rejectFirst ? budget : 0) + 100 * ms,
                      "End retains exact effective duration and independent producer endpoint");
                [d stopDetecting]; return UINT64_MAX;
            };
            Run(detector);
            Check(waits == (rejectFirst ? 3 : 2) && checkpoints == 1 && ends == 1,
                  "strictly greater than 2x rejects; exactly 2x remains eligible");
            probe.observe = nil; ResetClock();
        }
    }
}

static void TestRepeatedFirstWaitDelayAndEndBeforeConfirmation(void) {
    fakeClock = YES; fakeNow = NSEC_PER_SEC;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    __block NSUInteger waits = 0, checkpoints = 0, ends = 0;
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        Check(TimeoutNs(timeout) == 251 * ms, "repeated excessive waits retain the first budget");
        waits += 1;
        if (waits <= 2) { fakeNow += 60 * NSEC_PER_SEC; return ETIMEDOUT; }
        fakeNow += 100 * ms;
        [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
        return 0;
    };
    probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
        if (timing.phase == FTLongTaskPhaseBegin) return 251 * ms;
        if (timing.phase == FTLongTaskPhaseCheckpoint) { checkpoints += 1; return 502 * ms; }
        ends += 1;
        Check(timing.durationNs == 100 * ms && timing.observationTimeNs == 121100 * ms,
              "two discarded waits contribute zero before the unconfirmed End");
        [d stopDetecting]; return UINT64_MAX;
    };
    Run(detector);
    Check(waits == 3 && checkpoints == 0 && ends == 1,
          "repeated scheduling delays never confirm an interval that subsequently ends");
    probe.observe = nil; ResetClock();
}

static void TestFirstWaitReturnsAfterProducerEnd(void) {
    for (NSNumber *waitResult in @[@0, @(ETIMEDOUT)]) {
        fakeClock = YES; fakeNow = 1000 * ms;
        TimingProbe *probe = [TimingProbe new];
        ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
        [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
        __block NSUInteger waits = 0, begins = 0, ends = 0, checkpoints = 0;
        waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
            Check(TimeoutNs(timeout) == 251 * ms, "first confirmation uses the exact 251ms budget");
            waits += 1;
            fakeNow = 1300 * ms;
            [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
            fakeNow = 1310 * ms;
            return waitResult.intValue;
        };
        probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
            if (timing.phase == FTLongTaskPhaseBegin) { begins += 1; return 251 * ms; }
            if (timing.phase == FTLongTaskPhaseCheckpoint) { checkpoints += 1; return UINT64_MAX; }
            ends += 1;
            Check(timing.durationNs == 251 * ms && timing.observationTimeNs == 1300 * ms,
                  "first End keeps bounded duration and the actual producer endpoint");
            [d stopDetecting];
            return UINT64_MAX;
        };
        Run(detector);
        Check(waits == 1 && begins == 1 && ends == 1 && checkpoints == 0,
              "already ended interval never emits first confirmation, whether signaled or timed out");
        probe.observe = nil; ResetClock();
    }
}

static void TestTemporariesDrainDuringOngoingInterval(void) {
    fakeClock = YES; fakeNow = 1000 * ms; releasedTemporaries = 0;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    __block NSUInteger waits = 0, checkpoints = 0;
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        Check(releasedTemporaries == waits * 10,
              "checkpoint temporaries drain before the next wait in the same interval");
        waits += 1;
        if (waits == 3) [detector stopDetecting];
        fakeNow += TimeoutNs(timeout);
        return ETIMEDOUT;
    };
    probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
        if (timing.phase == FTLongTaskPhaseBegin) return 250 * ms;
        Check(timing.phase == FTLongTaskPhaseCheckpoint && timing.durationNs == (++checkpoints) * 250 * ms,
              "pool draining preserves exact checkpoint duration without an End");
        EnqueueTemporaries();
        return timing.durationNs + 250 * ms;
    };
    Run(detector);
    Check(waits == 3 && checkpoints == 2 && releasedTemporaries == 20,
          "all twenty checkpoint temporaries drain before shutdown");
    probe.observe = nil; ResetClock();
}

static void TestTemporariesDrainBetweenIntervals(void) {
    fakeClock = YES; fakeNow = 1000 * ms; releasedTemporaries = 0;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    __block NSUInteger begins = 0, ends = 0;
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        fakeNow = 1100 * ms;
        [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
        fakeNow = 1200 * ms;
        [detector recordRunLoopBeginActivity:kCFRunLoopAfterWaiting atTimeNs:fakeNow];
        return 0;
    };
    probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
        if (timing.phase == FTLongTaskPhaseBegin) {
            if (++begins == 1) EnqueueTemporaries();
            else {
                Check(releasedTemporaries == 10, "Begin temporaries drain before the next interval");
                [d stopDetecting];
            }
            return 250 * ms;
        }
        ends += 1;
        Check(timing.phase == FTLongTaskPhaseEnd && timing.durationNs == 100 * ms &&
              timing.observationTimeNs == 1100 * ms, "pool draining preserves the producer End boundary");
        return UINT64_MAX;
    };
    Run(detector);
    Check(begins == 2 && ends == 1 && releasedTemporaries == 10,
          "completed interval drains exactly ten Begin temporaries");
    probe.observe = nil; ResetClock();
}

static void TestTemporariesDrainBetweenIdleWaits(void) {
    fakeClock = YES; fakeNow = 1000 * ms; releasedTemporaries = 0;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    __block NSUInteger waits = 0;
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        Check(TimeoutNs(timeout) == NSEC_PER_SEC, "idle pool preserves the one-second recheck");
        if (++waits == 1) EnqueueTemporaries();
        else {
            Check(releasedTemporaries == 10, "idle temporaries drain on continue before the next wait");
            EnqueueTemporaries();
            [detector stopDetecting];
        }
        fakeNow += TimeoutNs(timeout);
        return ETIMEDOUT;
    };
    Run(detector);
    Check(waits == 2 && probe.observations == 0 && releasedTemporaries == 20,
          "idle and shutdown exits drain exactly twenty temporaries without reporting");
    ResetClock();
}

static void TestFirstBoundarySurvivesLaterCallbacks(void) {
    fakeClock=YES;fakeNow=1000*ms;
    TimingProbe *probe=[TimingProbe new];ControlledDetector *detector=[[ControlledDetector alloc]initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    waitHook=^int(pthread_cond_t*c,pthread_mutex_t*m,const struct timespec*t){
        fakeNow=1100*ms;[detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
        fakeNow=5000*ms;[detector recordRunLoopBeginActivity:kCFRunLoopAfterWaiting atTimeNs:fakeNow];
        fakeNow=6000*ms;[detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
        fakeNow=19000*ms;return 0;
    };
    probe.observe=^uint64_t(FTLongTaskDetector*d,FTLongTaskTiming t){
        if(t.phase==FTLongTaskPhaseBegin)return 250*ms;
        Check(t.phase==FTLongTaskPhaseEnd && t.durationNs==100*ms && t.observationTimeNs==1100*ms,
              "first ending boundary cannot be overwritten by later cycles");
        [d stopDetecting];return UINT64_MAX;
    };
    Run(detector);probe.observe=nil;ResetClock();
}
static void TestShortCaptureOverlapUsesProducerEnd(void) {
    for (NSArray<NSNumber *> *scenario in @[@[@320, @350], @[@400, @350], @[@320, @60350]]) {
        uint64_t endOffset = scenario[0].unsignedLongLongValue * ms;
        uint64_t callbackFinishOffset = scenario[1].unsignedLongLongValue * ms;
        fakeClock = YES; fakeNow = 1000 * ms;
        TimingProbe *probe = [TimingProbe new];
        ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
        [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
        __block NSUInteger waits = 0, checkpoints = 0, ends = 0;
        waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
            waits += 1;
            if (waits == 1) { fakeNow = 1251 * ms; return ETIMEDOUT; }
            fakeNow = 1000 * ms + endOffset;
            [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
            fakeNow += 60 * NSEC_PER_SEC; // Terminal processing delay is not main-thread blocking.
            return 0;
        };
        probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
            if (timing.phase == FTLongTaskPhaseBegin) return 251 * ms;
            if (timing.phase == FTLongTaskPhaseCheckpoint) {
                checkpoints += 1;
                Check(timing.durationNs == 251 * ms, "first checkpoint retains its exact wait credit");
                if (endOffset < callbackFinishOffset) {
                    fakeNow = 1000 * ms + endOffset;
                    [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
                }
                fakeNow = 1000 * ms + callbackFinishOffset;
                return 502 * ms;
            }
            ends += 1;
            Check(timing.durationNs == endOffset, "End includes short capture overlap only until the producer recovery boundary");
            Check(timing.observationTimeNs == 1000 * ms + endOffset,
                  "End timestamp excludes callback completion and terminal processing delay");
            [d stopDetecting]; return UINT64_MAX;
        };
        Run(detector);
        Check(checkpoints == 1 && ends == 1 && waits == (endOffset < callbackFinishOffset ? 1 : 2),
              "End during or after capture settles the interval once");
        probe.observe = nil; ResetClock();
    }
}

static void TestCallbackOverlapHasStrictOneSecondLimit(void) {
    for (NSNumber *gapValue in @[@(NSEC_PER_SEC - 1), @(NSEC_PER_SEC), @(NSEC_PER_SEC + 1)]) {
        uint64_t gap = gapValue.unsignedLongLongValue;
        fakeClock = YES; fakeNow = 1000 * ms;
        TimingProbe *probe = [TimingProbe new];
        ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
        [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
        waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
            fakeNow += TimeoutNs(timeout); return ETIMEDOUT;
        };
        probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
            if (timing.phase == FTLongTaskPhaseBegin) return 251 * ms;
            if (timing.phase == FTLongTaskPhaseCheckpoint) {
                fakeNow += gap;
                [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
                fakeNow += 30 * ms;
                return 502 * ms;
            }
            uint64_t expected = 251 * ms + (gap < NSEC_PER_SEC ? gap : 0);
            Check(timing.durationNs == expected, "only a single callback overlap strictly below one second is credited");
            Check(timing.observationTimeNs == 1251 * ms + gap, "large-gap rejection does not alter the producer endpoint");
            [d stopDetecting]; return UINT64_MAX;
        };
        Run(detector); probe.observe = nil; ResetClock();
    }
}

static void TestRepeatedCallbackOverlapsAccumulateIndependently(void) {
    fakeClock = YES; fakeNow = 1000 * ms;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    __block NSUInteger checkpoints = 0, waits = 0;
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        // Each 20 ms callback already advances effective time toward the next checkpoint.
        Check(TimeoutNs(timeout) == (waits++ == 0 ? 251 : 230) * ms,
              "normal callback overlap reduces the following wait budget");
        fakeNow += TimeoutNs(timeout); return ETIMEDOUT;
    };
    probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
        if (timing.phase == FTLongTaskPhaseBegin) return 251 * ms;
        if (timing.phase == FTLongTaskPhaseCheckpoint) {
            checkpoints += 1;
            Check(timing.durationNs == (251 + (checkpoints - 1) * 250) * ms,
                  "every checkpoint includes previous normal callback overlaps");
            fakeNow += 20 * ms;
            if (checkpoints == 60) {
                [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
                fakeNow += 60 * NSEC_PER_SEC;
            }
            return timing.durationNs + 250 * ms;
        }
        // 60 waits: 251 + 59*230 = 13821 ms; 60 callbacks add 1200 ms.
        Check(timing.durationNs == 15021 * ms, "sixty normal overlaps totaling over one second are all retained");
        Check(timing.observationTimeNs == 16021 * ms, "post-End callback delay cannot extend the event");
        [d stopDetecting]; return UINT64_MAX;
    };
    Run(detector);
    Check(waits == 60 && checkpoints == 60, "only sixty planned checkpoints execute");
    probe.observe = nil; ResetClock();
}

static void TestAbnormalCallbackDoesNotDiscardNeighboringNormalOverlaps(void) {
    fakeClock = YES; fakeNow = 1000 * ms;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    __block NSUInteger checkpoints = 0;
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        fakeNow += TimeoutNs(timeout); return ETIMEDOUT;
    };
    probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
        if (timing.phase == FTLongTaskPhaseBegin) return 251 * ms;
        if (timing.phase == FTLongTaskPhaseCheckpoint) {
            checkpoints += 1;
            Check(timing.durationNs == (251 + (checkpoints - 1) * 250) * ms,
                  "an abnormal callback does not change absolute effective checkpoints");
            fakeNow += (checkpoints == 2 ? 60000 : 20) * ms;
            if (checkpoints == 3) [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
            return timing.durationNs + 250 * ms;
        }
        Check(timing.durationNs == 771 * ms, "only the sixty-second callback is discarded, normal neighbors remain");
        Check(timing.observationTimeNs == 61771 * ms, "discarding callback time preserves the actual producer End");
        [d stopDetecting]; return UINT64_MAX;
    };
    Run(detector);
    Check(checkpoints == 3, "normal observation continues after the abnormal callback");
    probe.observe = nil; ResetClock();
}

static void TestCallbackOverlapPreservesWaitExclusions(void) {
    for (NSNumber *discardFirst in @[@YES, @NO]) {
        fakeClock = YES; fakeNow = 1000 * ms;
        TimingProbe *probe = [TimingProbe new];
        ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
        [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
        __block NSUInteger waits = 0, checkpoints = 0;
        waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
            waits += 1;
            BOOL longWait = waits == (discardFirst.boolValue ? 1 : 2);
            fakeNow += longWait ? 60 * NSEC_PER_SEC : TimeoutNs(timeout);
            return ETIMEDOUT;
        };
        probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
            if (timing.phase == FTLongTaskPhaseBegin) return 251 * ms;
            if (timing.phase == FTLongTaskPhaseCheckpoint) {
                checkpoints += 1;
                Check(timing.durationNs == checkpoints * 251 * ms, "checkpoints retain bounded credit after delayed waits");
                if (waits == 2) {
                    fakeNow += 69 * ms;
                    [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
                    fakeNow += 30 * ms;
                }
                return timing.durationNs + 251 * ms;
            }
            uint64_t expected = discardFirst.boolValue ? 320 * ms : 571 * ms;
            Check(timing.durationNs == expected, "callback overlap never restores discarded first waits or confirmed timeout overshoot");
            Check(timing.observationTimeNs == 61320 * ms, "effective correction leaves the real ending coordinate unchanged");
            [d stopDetecting]; return UINT64_MAX;
        };
        Run(detector);
        Check(waits == 2 && checkpoints == (discardFirst.boolValue ? 1 : 2), "correction preserves first-checkpoint confirmation policy");
        probe.observe = nil; ResetClock();
    }
}

static void TestLargeUnobservedDelegateGapIsNotCredited(void) {
    fakeClock=YES;fakeNow=1000*ms;
    TimingProbe *probe=[TimingProbe new];ControlledDetector *detector=[[ControlledDetector alloc]initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    waitHook=^int(pthread_cond_t*c,pthread_mutex_t*m,const struct timespec*t){fakeNow+=TimeoutNs(t);return ETIMEDOUT;};
    probe.observe=^uint64_t(FTLongTaskDetector*d,FTLongTaskTiming t){
        if(t.phase==FTLongTaskPhaseBegin){fakeNow+=60*NSEC_PER_SEC;return 250*ms;}
        if(t.phase==FTLongTaskPhaseCheckpoint){
            Check(t.durationNs==250*ms,"delayed Begin processing cannot count as blocking");
            fakeNow+=10*NSEC_PER_SEC;
            [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:fakeNow];
            return 500*ms;
        }
        Check(t.durationNs==250*ms,"a ten-second unobserved capture gap is not credited");
        [d stopDetecting];return UINT64_MAX;
    };
    Run(detector);probe.observe=nil;ResetClock();
}
static void TestSuspendBoundaryAndRunLoopCallbacks(void) {
    fakeClock=YES;fakeNow=1000*ms;
    TimingProbe *probe=[TimingProbe new];ControlledDetector *detector=[[ControlledDetector alloc]initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:fakeNow];
    waitHook=^int(pthread_cond_t*c,pthread_mutex_t*m,const struct timespec*t){
        fakeNow=1100*ms;[detector beginPreparingForSuspend];
        [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:1200*ms];
        FTLongTaskRunLoopSnapshot snapshot;
        Check([detector readRunLoopSnapshot:&snapshot] &&
              snapshot.activity == kCFRunLoopBeforeWaiting && snapshot.startTimeNs == 1200*ms,
              "RunLoop callbacks are forwarded normally during suspend preparation");
        fakeNow=61000*ms;[detector endPreparingForSuspend];
        return 0;
    };
    probe.observe=^uint64_t(FTLongTaskDetector*d,FTLongTaskTiming t){
        if(t.phase==FTLongTaskPhaseBegin)return 250*ms;
        Check(t.phase==FTLongTaskPhaseEnd && t.durationNs==100*ms && t.observationTimeNs==1100*ms,
              "rapid false/true still ends old interval at hook entry");
        [d stopDetecting];return UINT64_MAX;
    };
    Run(detector);probe.observe=nil;ResetClock();
}
static void TestSuspendReturnCannotResumeStoppedDetector(void) {
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector endPreparingForSuspend];
    Check(Sequence(detector) == 0, "return without active collection does nothing");
    [detector startDetecting];
    [detector beginPreparingForSuspend];
    [detector stopDetecting];
    uint64_t stoppedSequence = Sequence(detector);
    [detector endPreparingForSuspend];
    Check(Sequence(detector) == stoppedSequence, "late hook return cannot resume stopped collection");
    DrainDetector(detector);

    // SDK reinitialization creates an independent detector, never restarts this one.
    ControlledDetector *newDetector = [[ControlledDetector alloc] initWithDelegate:probe];
    [newDetector startDetecting];
    [newDetector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:2000 * ms];
    uint64_t newSequence = Sequence(newDetector);
    [detector endPreparingForSuspend];
    Check(Sequence(detector) == stoppedSequence && Sequence(newDetector) == newSequence,
          "old hook return cannot change stopped collection or a new detector instance");
    Check(![detector isMonitoringGeneration:stoppedSequence / 2] &&
          [newDetector isMonitoringGeneration:newSequence / 2],
          "stopped collection rejects work while the new detector remains active");
    [newDetector stopDetecting];
    DrainDetector(newDetector);
}
static void TestBeforeSourcesDoesNotEnableDisabledRunloop(void) {
    fakeClock = YES;
    fakeNow = 1000 * ms;
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    [detector recordRunLoopBeginActivity:kCFRunLoopBeforeSources atTimeNs:1000 * ms];
    waitHook = ^int(pthread_cond_t *condition, pthread_mutex_t *mutex, const struct timespec *timeout) {
        Check(TimeoutNs(timeout) == NSEC_PER_SEC, "BeforeSources preserves the idle recheck interval");
        [detector stopDetecting];
        return ETIMEDOUT;
    };
    Run(detector);
    ResetClock();
}
static void TestShutdownBeforeWorkerStarts(void) {
    TimingProbe *probe = [TimingProbe new];
    ControlledDetector *detector = [[ControlledDetector alloc] initWithDelegate:probe];
    dispatch_queue_t queue = [detector valueForKey:@"longTaskQueue"];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0);
    dispatch_semaphore_t release = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{ dispatch_semaphore_signal(entered); Await(release); });
    Await(entered);

    [detector startDetecting];
    [detector startDetecting];
    Check(detector.observerRegistrations == 1, "duplicate start is idempotent before worker runs");
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:2000 * ms];
    [detector stopDetecting];
    __block NSUInteger observations = 0;
    __block NSUInteger waits = 0;
    probe.observe = ^uint64_t(FTLongTaskDetector *d, FTLongTaskTiming timing) {
        observations += 1;
        return UINT64_MAX;
    };
    waitHook = ^int(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *timeout) {
        waits += 1;
        return EINVAL;
    };
    dispatch_semaphore_signal(release);
    DrainDetector(detector);
    Check(observations == 0 && waits == 0, "queued worker cannot begin monitoring after SDK shutdown");
    probe.observe = nil;
    ResetClock();
}
@interface MissingSuspend : NSObject @end
@implementation MissingSuspend @end
@interface InvalidSuspend : NSObject
- (BOOL)_prepareForSuspend;
@end
@implementation InvalidSuspend
- (BOOL)_prepareForSuspend{return YES;}
@end
static NSUInteger originalCalls;
static BOOL shouldThrow;
@interface FakeSuspend : NSObject
- (void)_prepareForSuspend;
@end
@implementation FakeSuspend
- (void)_prepareForSuspend{originalCalls++;if(shouldThrow)[NSException raise:@"probe" format:@"original"] ;}
@end
static void TestHookCompatibilityAndOriginalCall(void) {
    Check(![FTLongTaskDetector installSuspendHookForClass:MissingSuspend.class],"missing selector fails open");
    Check(![FTLongTaskDetector installSuspendHookForClass:InvalidSuspend.class],"incompatible signature fails open");
    Check([FTLongTaskDetector installSuspendHookForClass:FakeSuspend.class],"compatible hook installed");
    Check([FTLongTaskDetector installSuspendHookForClass:FakeSuspend.class],"repeated installation idempotent");
    FakeSuspend *target=[FakeSuspend new];[target _prepareForSuspend];
    Check(originalCalls==1,"original called exactly once");
    shouldThrow=YES;BOOL caught=NO;
    @try{[target _prepareForSuspend];}@catch(NSException*e){caught=[e.name isEqual:@"probe"];}
    Check(caught && originalCalls==2,"original exception propagates without duplicate call");
}

int main(void){@autoreleasepool{
    TestIdleWorkerUsesBoundedWait();
    TestBurstIsOneStateChange();
    TestSpuriousWakeupsKeepDeadline();
    TestPublishBetweenPredicateAndSleep();
    TestRunLoopNeverWaitsForWaitMutex();
    TestStopWakesRealWaiter();
    TestStopInPreSleepGap();
    TestStatePublicationWakesRealWaiter();
    TestWaitErrorsAreNotTimeouts();
    TestMissedSignalIsObservedAtDeadline();
    TestUnavailableDelegateUsesBoundedEndWait();
    TestBoundedGapAndDelayedEnd();
    TestFirstCheckpointRequiresNormallyScheduledWait();
    TestRepeatedFirstWaitDelayAndEndBeforeConfirmation();
    TestFirstWaitReturnsAfterProducerEnd();
    TestTemporariesDrainDuringOngoingInterval();
    TestTemporariesDrainBetweenIntervals();
    TestTemporariesDrainBetweenIdleWaits();
    TestFirstBoundarySurvivesLaterCallbacks();
    TestShortCaptureOverlapUsesProducerEnd();
    TestCallbackOverlapHasStrictOneSecondLimit();
    TestRepeatedCallbackOverlapsAccumulateIndependently();
    TestAbnormalCallbackDoesNotDiscardNeighboringNormalOverlaps();
    TestCallbackOverlapPreservesWaitExclusions();
    TestLargeUnobservedDelegateGapIsNotCredited();
    TestSuspendBoundaryAndRunLoopCallbacks();
    TestSuspendReturnCannotResumeStoppedDetector();
    TestBeforeSourcesDoesNotEnableDisabledRunloop();
    TestShutdownBeforeWorkerStarts();
    TestHookCompatibilityAndOriginalCall();
    puts("PASS: 30 LongTask timing, suspend, autorelease and condition regressions");
}return 0;}
