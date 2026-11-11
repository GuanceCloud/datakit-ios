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
#import "FTRUMManager.h"
#import <stdatomic.h>

@implementation FTLongTaskEvent
- (instancetype)initWithStack:(NSString *)stack startTimeNs:(long long)startTimeNs endTimeNs:(long long)endTimeNs durationNs:(long long)durationNs {
    return [self initWithStack:stack startTimeNs:startTimeNs endTimeNs:endTimeNs durationNs:durationNs appState:nil];
}
- (instancetype)initWithStack:(NSString *)stack startTimeNs:(long long)startTimeNs endTimeNs:(long long)endTimeNs durationNs:(long long)durationNs appState:(NSString *)appState {
    if ((self = [super init])) {
        _stack = [stack copy]; _startTimeNs = startTimeNs; _endTimeNs = endTimeNs; _durationNs = durationNs;
        _appState = [appState copy];
    }
    return self;
}
@end

@interface FTLongTaskManager () <FTLongTaskTimingDelegate> {
    atomic_bool _stopped;
    uint64_t _intervalGeneration; // Owns callback identity even before an event is confirmed.
    BOOL _discardCurrentInterval; // Detector-queue owned; reset only by the next Begin.
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
- (FTLongTaskActiveEvent *)eventForTiming:(FTLongTaskTiming)timing {
    FTFatalErrorContextModel *context = self.dependencies.fatalErrorContext.currentContextModel;
    if (!context.lastSessionState) return nil;
    NSString *situation = FTStringFromAppState(timing.recordedAppState);
    FTLongTaskActiveEvent *event = [[FTLongTaskActiveEvent alloc] initWithStartTimeNs:timing.startTimeNs freezeDurationMs:self.freezeDurationMs appState:situation];
    [event updateErrorContext:context];
    return event;
}
- (BOOL)shouldIgnoreBackgroundAtStart:(FTAppState)startState currentState:(FTAppState)currentState {
    return self.dependencies.ignoreBackgroundLongTaskAndANR &&
        (startState == FTAppStateBackground || currentState == FTAppStateBackground);
}
- (void)discardCurrentEvent {
    _discardCurrentInterval = YES;
    FTLongTaskActiveEvent *event = self.longTaskEvent;
    self.longTaskEvent = nil;
    if (event.hasPersistedANRData) [self.anrProcessor.dataStore deleteFile];
}
- (uint64_t)longTaskDetector:(FTLongTaskDetector *)detector didObserveTiming:(FTLongTaskTiming)timing {
    if (atomic_load(&_stopped)) return UINT64_MAX;
    if (timing.phase == FTLongTaskPhaseBegin) {
        self.longTaskEvent = nil;
        _discardCurrentInterval = NO;
        _intervalGeneration = timing.generation;
    } else if (timing.generation != _intervalGeneration) {
        return UINT64_MAX;
    }
    if (_discardCurrentInterval) return UINT64_MAX;
    if ([self shouldIgnoreBackgroundAtStart:timing.startAppState currentState:timing.recordedAppState]) {
        [self discardCurrentEvent];
        return UINT64_MAX;
    }
    if (timing.phase == FTLongTaskPhaseBegin) {
        uint64_t freeze = self.enableFreeze ? (uint64_t)MAX(1, self.freezeDurationMs) * NSEC_PER_MSEC + NSEC_PER_MSEC : UINT64_MAX;
        return self.enableANR ? MIN(freeze, FTLongTaskANRDataThresholdNs + NSEC_PER_MSEC) : freeze;
    }
    // End only settles an event already observed at Checkpoint; it never confirms a new one.
    if (!self.longTaskEvent && timing.phase == FTLongTaskPhaseCheckpoint) {
        self.longTaskEvent = [self eventForTiming:timing];
    }
    FTLongTaskActiveEvent *event = self.longTaskEvent;
    if (!event) return UINT64_MAX;
    event.effectiveDurationNs = timing.durationNs;
    event.lastObservedTimeNs = timing.observationTimeNs;
    event.appState = FTStringFromAppState(timing.recordedAppState);
    if (timing.phase == FTLongTaskPhaseEnd) {
        [self finishEvent:event appState:FTStringFromRUMAppState(timing.appState) detector:detector];
        return UINT64_MAX;
    }
    BOOL (^acceptsResult)(void) = ^BOOL{ return !atomic_load(&_stopped) && self.longTaskEvent == event; };
    __block BOOL backgroundMatched = NO;
    // Capture predicates update only memory. Cleanup waits until capture has returned.
    BOOL (^observeStateAndContinue)(void) = ^BOOL{
        if (!acceptsResult()) return NO;
        FTAppState currentState = detector.currentAppState;
        event.appState = FTStringFromAppState(currentState);
        if ([self shouldIgnoreBackgroundAtStart:timing.startAppState currentState:currentState]) backgroundMatched = YES;
        return !backgroundMatched && [detector isMonitoringGeneration:timing.generation];
    };
    BOOL mainDue = (self.enableFreeze && event.isLongTask) || (self.enableANR && event.durationNs > FTLongTaskANRDataThresholdNs);
    if (mainDue && !event.mainStackAttempted && observeStateAndContinue()) {
        NSString *stack = [self.backtraceReporting generateMainThreadBacktraceWithCaptureValidation:observeStateAndContinue];
        // A normal producer End retains valid frames; background exclusion cancels them.
        if (!acceptsResult()) return UINT64_MAX;
        (void)observeStateAndContinue();
        if (!backgroundMatched) {
            event.mainStackAttempted = YES;
            event.mainThreadBacktrace = stack ?: @"";
        }
    }
    if (self.enableANR && !backgroundMatched)
        [self.anrProcessor updateEvent:event intervalActive:observeStateAndContinue acceptsResult:acceptsResult];
    if (backgroundMatched) {
        [self discardCurrentEvent];
        return UINT64_MAX;
    }
    uint64_t next = self.enableANR ? [self.anrProcessor nextCheckpointForEvent:event] : UINT64_MAX;
    if (self.enableFreeze && !event.mainStackAttempted)
        next = MIN(next, (uint64_t)MAX(1, self.freezeDurationMs) * NSEC_PER_MSEC + NSEC_PER_MSEC);
    // Freeze-only normally has no more business checkpoints after its stack.
    // Keep bounded policy checks while exclusion is enabled, without recapturing.
    if (self.dependencies.ignoreBackgroundLongTaskAndANR)
        next = MIN(next, event.effectiveDurationNs + NSEC_PER_SEC);
    return next;
}
- (BOOL)canDeliverWithDetector:(FTLongTaskDetector *)detector {
    return !atomic_load(&_stopped) &&
        !(self.dependencies.ignoreBackgroundLongTaskAndANR && detector.currentAppState == FTAppStateBackground);
}
- (void)finishEvent:(FTLongTaskActiveEvent *)event appState:(NSString *)intervalState detector:(FTLongTaskDetector *)detector {
    self.longTaskEvent = nil;
    if (atomic_load(&_stopped)) return;
    if (self.enableANR && event.hasPersistedANRData) [self.anrProcessor.dataStore deleteFile];
    if (![self canDeliverWithDetector:detector]) return;
    if (event.isLongTask && self.enableFreeze) {
        FTLongTaskEvent *result = [[FTLongTaskEvent alloc] initWithStack:event.mainThreadBacktrace ?: @""
            startTimeNs:event.startTimeNs endTimeNs:event.lastObservedTimeNs durationNs:event.durationNs appState:intervalState];
        [self.delegate longTaskDetected:result];
    }
    if ([self canDeliverWithDetector:detector] && self.enableANR && event.isANR) {
        NSString *stack = event.allThreadsBacktrace.length ? event.allThreadsBacktrace : event.mainThreadBacktrace;
        [self.delegate anrStackDetected:stack ?: @"" appState:event.appState intervalAppState:intervalState time:event.startTimeNs];
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
