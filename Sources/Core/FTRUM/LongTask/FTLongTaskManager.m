//
//  FTLongTaskManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTLongTaskManager.h"
#import "FTLongTaskTiming.h"
#import "FTLongTaskEvent.h"
#import "FTANRProcessor.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import <stdatomic.h>

@implementation FTLongTaskEvent
- (instancetype)initWithStack:(NSString *)stack startTimeNs:(long long)startTimeNs endTimeNs:(long long)endTimeNs durationNs:(long long)durationNs {
    if ((self = [super init])) {
        _stack = [stack copy]; _startTimeNs = startTimeNs; _endTimeNs = endTimeNs; _durationNs = durationNs;
    }
    return self;
}
@end

@interface FTLongTaskManager () <FTLongTaskTimingDelegate> {
    atomic_bool _stopped;
}
@property (nonatomic, weak) id<FTRunloopDetectorDelegate> delegate;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTLongTaskDetector *longTaskDetector;
@property (nonatomic, strong) FTANRProcessor *anrProcessor;
@property (nonatomic, strong) FTLongTaskActiveEvent *longTaskEvent;
@property (nonatomic) BOOL enableANR, enableFreeze;
@property (nonatomic) long freezeDurationMs;
@property (nonatomic, weak) id<FTBacktraceReporting> backtraceReporting;
@end
@implementation FTLongTaskManager
- (instancetype)initWithDependencies:(FTRUMDependencies *)dependencies delegate:(id<FTRunloopDetectorDelegate>)delegate
                  backtraceReporting:(id<FTBacktraceReporting>)backtraceReporting enableTrackAppANR:(BOOL)enableANR
                 enableTrackAppFreeze:(BOOL)enableFreeze freezeDurationMs:(long)freezeDurationMs {
    if ((self = [super init])) {
        atomic_init(&_stopped, false);
        _dependencies = dependencies; _delegate = delegate; _backtraceReporting = backtraceReporting;
        _enableANR = enableANR; _enableFreeze = enableFreeze; _freezeDurationMs = freezeDurationMs;
        _anrProcessor = [[FTANRProcessor alloc] initWithDependencies:dependencies backtraceReporting:backtraceReporting];
        _longTaskDetector = [[FTLongTaskDetector alloc] initWithDelegate:self];
        [self.anrProcessor reportPreviousANRIfFound];
        [_longTaskDetector startDetecting];
    }
    return self;
}
- (FTLongTaskActiveEvent *)eventAtTime:(long long)time {
    FTFatalErrorContextModel *context = self.dependencies.fatalErrorContext.currentContextModel;
    if (!context.lastSessionState) return nil;
    FTLongTaskActiveEvent *event = [[FTLongTaskActiveEvent alloc] initWithStartTimeNs:time freezeDurationMs:self.freezeDurationMs];
    event.errorContextModel = context;
    return event;
}
- (uint64_t)longTaskDetector:(FTLongTaskDetector *)detector didObserveTiming:(FTLongTaskTiming)timing {
    if (atomic_load(&_stopped)) return UINT64_MAX;
    if (timing.phase == FTLongTaskPhaseBegin) {
        self.longTaskEvent = nil;
        uint64_t freeze = self.enableFreeze ? (uint64_t)MAX(1, self.freezeDurationMs) * NSEC_PER_MSEC + NSEC_PER_MSEC : UINT64_MAX;
        return self.enableANR ? MIN(freeze, FTLongTaskANRDataThresholdNs + NSEC_PER_MSEC) : freeze;
    }
    // End only settles an event already observed at Checkpoint; it never confirms a new one.
    if (!self.longTaskEvent && timing.phase == FTLongTaskPhaseCheckpoint) {
        self.longTaskEvent = [self eventAtTime:timing.startTimeNs];
        self.longTaskEvent.generation = timing.generation;
    }
    FTLongTaskActiveEvent *event = self.longTaskEvent;
    if (!event || event.generation != timing.generation) return UINT64_MAX;
    event.effectiveDurationNs = timing.durationNs;
    event.lastObservedTimeNs = timing.observationTimeNs;
    if (timing.phase == FTLongTaskPhaseEnd) {
        [self finishEvent:event]; return UINT64_MAX;
    }
    BOOL (^current)(void) = ^BOOL{ return !atomic_load(&_stopped) && self.longTaskEvent == event && [detector isMonitoringGeneration:timing.generation]; };
    BOOL mainDue = (self.enableFreeze && event.isLongTask) || (self.enableANR && event.durationNs > FTLongTaskANRDataThresholdNs);
    if (mainDue && !event.mainStackAttempted && current()) {
        NSString *stack = [self.backtraceReporting generateMainThreadBacktrace];
        if (!current()) return UINT64_MAX;
        event.mainStackAttempted = YES;
        event.mainThreadBacktrace = stack ?: @"";
    }
    if (self.enableANR) [self.anrProcessor updateEvent:event stillCurrent:current];
    uint64_t next = self.enableANR ? [self.anrProcessor nextCheckpointForEvent:event] : UINT64_MAX;
    if (self.enableFreeze && !event.mainStackAttempted)
        next = MIN(next, (uint64_t)MAX(1, self.freezeDurationMs) * NSEC_PER_MSEC + NSEC_PER_MSEC);
    return next;
}
- (void)finishEvent:(FTLongTaskActiveEvent *)event {
    self.longTaskEvent = nil;
    if (atomic_load(&_stopped)) return;
    if (self.enableANR) [self.anrProcessor.dataStore deleteFile];
    if (!atomic_load(&_stopped) && event.isLongTask && self.enableFreeze) {
        FTLongTaskEvent *result = [[FTLongTaskEvent alloc] initWithStack:event.mainThreadBacktrace ?: @""
            startTimeNs:event.startTimeNs endTimeNs:event.lastObservedTimeNs durationNs:event.durationNs];
        [self.delegate longTaskDetected:result];
    }
    if (!atomic_load(&_stopped) && self.enableANR && event.isANR) {
        NSString *stack = event.allThreadsBacktrace.length ? event.allThreadsBacktrace : event.mainThreadBacktrace;
        [self.delegate anrStackDetected:stack ?: @"" appState:event.errorContextModel.appState time:event.startTimeNs];
    }
}
- (void)shutDown {
    if (atomic_exchange(&_stopped, true)) return;
    [self.longTaskDetector stopDetecting];
    [self.anrProcessor.dataStore shutDown];
    [self.longTaskDetector performAsynchronousBlock:^{
        self.longTaskEvent = nil;
    }];
}
- (void)dealloc {
    [_longTaskDetector stopDetecting];
}
@end
