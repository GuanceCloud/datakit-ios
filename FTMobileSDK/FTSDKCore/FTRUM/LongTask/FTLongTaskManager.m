//
//  FTLongTaskManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTLongTaskManager.h"
#import "FTLongTaskDetector.h"
#import "FTLongTaskANRData.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTFatalErrorContext.h"
#import "FTErrorMonitorInfo.h"
#import "FTInnerLog.h"
#import "FTRUMContext.h"

@interface FTLongTaskActiveEvent : NSObject
@property (nonatomic, assign) long long startTimeNs;
@property (nonatomic, assign) long long lastObservedTimeNs;
@property (nonatomic, assign) long long lastANRDataUpdateTimeNs;
@property (nonatomic, assign) long long freezeThresholdNs;
@property (nonatomic, copy) NSString *mainThreadBacktrace;
@property (nonatomic, copy) NSString *allThreadsBacktrace;
@property (nonatomic, strong) FTFatalErrorContextModel *errorContextModel;
@property (nonatomic, assign) BOOL hasPersistedANRData;
@property (nonatomic, assign, readonly) long long durationNs;
@property (nonatomic, assign, readonly) BOOL isANR;
@property (nonatomic, assign, readonly) BOOL isLongTask;
@property (nonatomic, assign, readonly) BOOL needsAllThreadsBacktrace;

- (void)observeTimeNs:(long long)timeNs;
- (BOOL)shouldPrepareANRDataAtTimeNs:(long long)timeNs;
- (BOOL)updateAllThreadsBacktrace:(NSString *)allThreadsBacktrace;
- (BOOL)shouldAppendANRDataUpdateAtTimeNs:(long long)timeNs;
- (void)markANRDataPersistedAtTimeNs:(long long)timeNs;
- (void)markANRDataUpdatedAtTimeNs:(long long)timeNs;
- (FTLongTaskANRData *)anrData;
@end

@implementation FTLongTaskActiveEvent

- (instancetype)initWithStartTimeNs:(long long)startTimeNs freezeDurationMs:(long)freezeDurationMs {
    self = [super init];
    if (self) {
        _startTimeNs = startTimeNs;
        _lastObservedTimeNs = startTimeNs;
        _lastANRDataUpdateTimeNs = startTimeNs;
        _freezeThresholdNs = (long long)freezeDurationMs * NSEC_PER_MSEC;
    }
    return self;
}

- (long long)durationNs {
    return self.lastObservedTimeNs > self.startTimeNs ? self.lastObservedTimeNs - self.startTimeNs : 0;
}

- (BOOL)isANR {
    return self.durationNs > FT_ANR_THRESHOLD_NS;
}

- (BOOL)isLongTask {
    return self.durationNs > self.freezeThresholdNs;
}

- (BOOL)needsAllThreadsBacktrace {
    return self.allThreadsBacktrace.length == 0;
}

- (void)observeTimeNs:(long long)timeNs {
    self.lastObservedTimeNs = timeNs;
}

- (BOOL)shouldPrepareANRDataAtTimeNs:(long long)timeNs {
    return timeNs - self.startTimeNs > FTLongTaskANRDataThresholdNs;
}

- (BOOL)updateAllThreadsBacktrace:(NSString *)allThreadsBacktrace {
    if (!self.needsAllThreadsBacktrace) {
        return NO;
    }
    if (allThreadsBacktrace.length == 0) {
        self.allThreadsBacktrace = nil;
        return NO;
    }
    self.allThreadsBacktrace = allThreadsBacktrace;
    return YES;
}

- (BOOL)shouldAppendANRDataUpdateAtTimeNs:(long long)timeNs {
    return timeNs - self.lastANRDataUpdateTimeNs > FTLongTaskANRDataUpdateIntervalNs;
}

- (void)markANRDataPersistedAtTimeNs:(long long)timeNs {
    self.hasPersistedANRData = YES;
    self.lastANRDataUpdateTimeNs = timeNs;
}

- (void)markANRDataUpdatedAtTimeNs:(long long)timeNs {
    self.lastANRDataUpdateTimeNs = timeNs;
}

- (FTLongTaskANRData *)anrData {
    return [[FTLongTaskANRData alloc] initWithStartTimeNs:self.startTimeNs
                                                durationNs:self.durationNs
                                        mainThreadBacktrace:self.mainThreadBacktrace
                                        allThreadsBacktrace:self.allThreadsBacktrace
                                          errorContextModel:self.errorContextModel];
}

@end

@interface FTLongTaskManager()<FTLongTaskProtocol>
@property (nonatomic, weak, nullable) id<FTRunloopDetectorDelegate> delegate;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTLongTaskDetector *longTaskDetector;
@property (nonatomic, strong) FTLongTaskANRDataStore *anrDataStore;
@property (nonatomic, strong) FTLongTaskActiveEvent *longTaskEvent;
@property (nonatomic, assign) BOOL enableANR;
@property (nonatomic, assign) BOOL enableFreeze;
@property (nonatomic, assign) long freezeDurationMs;
@property (nonatomic, weak, nullable) id<FTBacktraceReporting> backtraceReporting;
@end

@implementation FTLongTaskManager

- (instancetype)initWithDependencies:(FTRUMDependencies *)dependencies
                             delegate:(id<FTRunloopDetectorDelegate>)delegate
                   backtraceReporting:(id<FTBacktraceReporting>)backtraceReporting
                    enableTrackAppANR:(BOOL)enableANR
                 enableTrackAppFreeze:(BOOL)enableFreeze
                     freezeDurationMs:(long)freezeDurationMs {
    self = [super init];
    if (self) {
        _dependencies = dependencies;
        _delegate = delegate;
        _enableANR = enableANR;
        _enableFreeze = enableFreeze;
        _freezeDurationMs = freezeDurationMs;
        _anrDataStore = [[FTLongTaskANRDataStore alloc] init];
        _longTaskDetector = [[FTLongTaskDetector alloc] initWithDelegate:self];
        _backtraceReporting = backtraceReporting;
        _longTaskDetector.limitFreezeMillisecond = freezeDurationMs;
        [self reportPreviousANRIfFound];
        [_longTaskDetector startDetecting];
    }
    return self;
}

// longTask、 ANR、View
- (void)reportPreviousANRIfFound {
    __weak __typeof(self) weakSelf = self;
    dispatch_async(self.anrDataStore.queue, ^{
        long long errorDate = 0;
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        @try {
            FTLongTaskANRData *anrData = [strongSelf.anrDataStore readANRData];
            if (anrData) {
                errorDate = [strongSelf reportANRData:anrData];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
        [strongSelf.anrDataStore deleteFile];
        [strongSelf.dependencies.writer lastFatalErrorIfFound:errorDate];
    });
}

- (long long)reportANRData:(FTLongTaskANRData *)anrData {
    long long startTime = anrData.startTimeNs;
    long long duration = anrData.lastUpdateTimeNs - startTime > 0 ? anrData.lastUpdateTimeNs - startTime : anrData.durationNs;
    if (duration <= 0) {
        return 0;
    }
    long long longTaskEndTime = startTime + duration;
    BOOL isAnr = duration > FT_ANR_THRESHOLD_NS;
    FTFatalErrorContextModel *contextModel = anrData.errorContextModel;
    NSDictionary *tags = [contextModel.lastSessionState sessionTags];
    NSString *backtrace = anrData.mainThreadBacktrace.length > 0 ? anrData.mainThreadBacktrace : nil;

    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields setValue:@(duration) forKey:FT_DURATION];
    [fields setValue:backtrace forKey:FT_KEY_LONG_TASK_STACK];
    NSDictionary *lastViews = contextModel.lastViewContext;
    BOOL sessionOnError = contextModel.lastSessionState.sampled_for_error_session;
    if (sessionOnError && isAnr) {
        [fields setValue:@(startTime) forKey:FT_SESSION_ERROR_TIMESTAMP];
    }
    if (lastViews) {
        NSMutableDictionary *lastViewsFields = [NSMutableDictionary dictionaryWithDictionary:lastViews[@"fields"]];
        long long viewStartTime = [lastViews[@"time"] longLongValue];
        long long timeSpent = longTaskEndTime - viewStartTime;
        if (timeSpent <= 0) {
            timeSpent = 1;
        }
        long long oldTimeSpent = [lastViewsFields[FT_KEY_TIME_SPENT] longLongValue];
        double oldLongTaskRate = [lastViewsFields[FT_KEY_VIEW_LONG_TASK_RATE] doubleValue];
        long long oldLongTaskDuration = (oldTimeSpent > 0 && oldLongTaskRate > 0) ? (long long)(oldLongTaskRate * oldTimeSpent) : 0;
        long long newLongTaskDuration = oldLongTaskDuration + duration;
        double viewLongTaskRate = timeSpent > 0 ? (double)newLongTaskDuration / (double)timeSpent : 0;
        if (isAnr) {
            lastViewsFields[FT_KEY_VIEW_ERROR_COUNT] = @([lastViewsFields[FT_KEY_VIEW_ERROR_COUNT] intValue] + 1);
            BOOL sampledForErrorReplay = [lastViewsFields[FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY] boolValue];
            if ([lastViewsFields.allKeys containsObject:FT_SESSION_HAS_REPLAY] && sampledForErrorReplay) {
                lastViewsFields[FT_SESSION_HAS_REPLAY] = @(YES);
            }
        }
        lastViewsFields[FT_KEY_VIEW_LONG_TASK_COUNT] = @([lastViewsFields[FT_KEY_VIEW_LONG_TASK_COUNT] intValue] + 1);
        lastViewsFields[FT_KEY_TIME_SPENT] = @(timeSpent);
        lastViewsFields[FT_KEY_VIEW_LONG_TASK_RATE] = @(viewLongTaskRate);
        lastViewsFields[FT_KEY_VIEW_UPDATE_TIME] = @([lastViewsFields[FT_KEY_VIEW_UPDATE_TIME] intValue] + 1);
        lastViewsFields[FT_KEY_IS_ACTIVE] = @(NO);
        NSNumber *time = lastViews[@"time"];

        [self.dependencies.writer rumWrite:FT_RUM_SOURCE_VIEW tags:lastViews[@"tags"] fields:lastViewsFields dynamicContext:contextModel.globalAttributes time:[time longLongValue] updateTime:longTaskEndTime cache:sessionOnError];
    }
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_LONG_TASK tags:tags fields:fields dynamicContext:contextModel.globalAttributes time:startTime updateTime:0 cache:sessionOnError];

    if (isAnr) {
        NSString *allBacktrace = anrData.allThreadsBacktrace.length > 0 ? anrData.allThreadsBacktrace : nil;
        NSMutableDictionary *anrTags = [NSMutableDictionary dictionary];
        [anrTags setValue:@"anr_error" forKey:FT_KEY_ERROR_TYPE];
        [anrTags setValue:FT_LOGGER forKey:FT_KEY_ERROR_SOURCE];
        [anrTags setValue:contextModel.appState forKey:FT_KEY_ERROR_SITUATION];
        [anrTags addEntriesFromDictionary:contextModel.errorMonitorInfo];
        [anrTags addEntriesFromDictionary:contextModel.globalAttributes];
        [anrTags addEntriesFromDictionary:contextModel.dynamicContext];
        [anrTags addEntriesFromDictionary:[contextModel.lastSessionState sessionTags]];
        [anrTags addEntriesFromDictionary:tags];

        NSMutableDictionary *anrFields = [NSMutableDictionary dictionary];
        [anrFields addEntriesFromDictionary:[contextModel.lastSessionState sessionFields]];
        [anrFields setValue:@"ios_anr" forKey:FT_KEY_ERROR_MESSAGE];
        [anrFields setValue:allBacktrace ?: backtrace forKey:FT_KEY_ERROR_STACK];
        [self.dependencies.writer rumWriteAssembledData:FT_RUM_SOURCE_ERROR tags:anrTags fields:anrFields time:startTime];
        return startTime;
    }
    return 0;
}
- (FTFatalErrorContextModel *)currentANRDataContextModel {
    FTFatalErrorContextModel *currentContextModel = [self.dependencies.fatalErrorContext currentContextModel];
    return [[FTFatalErrorContextModel alloc] initWithAppState:currentContextModel.appState
                                             lastSessionState:currentContextModel.lastSessionState
                                             lastViewContext:currentContextModel.lastViewContext
                                              dynamicContext:currentContextModel.dynamicContext
                                            globalAttributes:currentContextModel.globalAttributes
                                             errorMonitorInfo:[self.dependencies.errorMonitorInfoWrapper errorMonitorInfo]];
}

- (void)startLongTask:(long long)startTime {
    @try {
        // If lastSessionContext is nil, the current session is not sampled.
        FTFatalErrorContextModel *currentContextModel = self.dependencies.fatalErrorContext.currentContextModel;
        if (!currentContextModel.lastSessionState) {
            return;
        }
        FTLongTaskActiveEvent *event = [[FTLongTaskActiveEvent alloc] initWithStartTimeNs:startTime freezeDurationMs:self.freezeDurationMs];
        event.errorContextModel = currentContextModel;
        event.mainThreadBacktrace = [self.backtraceReporting generateMainThreadBacktrace];
        self.longTaskEvent = event;
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@", exception);
    }
}

- (void)updateLongTaskDate:(long long)time {
    @try {
        if (!self.enableANR || !self.longTaskEvent || time <= 0) {
            return;
        }
        FTLongTaskActiveEvent *event = self.longTaskEvent;
        [event observeTimeNs:time];
        if ([event shouldPrepareANRDataAtTimeNs:time]) {
            BOOL didCaptureAllThreadsBacktrace = NO;
            if (event.needsAllThreadsBacktrace) {
                didCaptureAllThreadsBacktrace = [event updateAllThreadsBacktrace:[self.backtraceReporting generateAllThreadsBacktrace]];
            }
            if (!event.hasPersistedANRData) {
                event.errorContextModel = [self currentANRDataContextModel];
                [self.anrDataStore writeANRData:event.anrData updateTimeNs:time resetFile:NO];
                [event markANRDataPersistedAtTimeNs:time];
            } else if (didCaptureAllThreadsBacktrace) {
                [self.anrDataStore writeANRData:event.anrData updateTimeNs:time resetFile:YES];
                [event markANRDataPersistedAtTimeNs:time];
            } else if ([event shouldAppendANRDataUpdateAtTimeNs:time]) {
                [self.anrDataStore appendUpdateTimeNs:time];
                [event markANRDataUpdatedAtTimeNs:time];
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@", exception);
    }
}
- (void)endLongTask {
    @try {
        if (!self.longTaskEvent) {
            return;
        }
        FTLongTaskActiveEvent *event = self.longTaskEvent;
        [event observeTimeNs:[NSDate ft_currentNanosecondTimeStamp]];
        if (event.isLongTask && self.enableFreeze && self.delegate && [self.delegate respondsToSelector:@selector(longTaskStackDetected:duration:time:)]) {
            [self.delegate longTaskStackDetected:event.mainThreadBacktrace duration:event.durationNs time:event.startTimeNs];
        }
        if (self.enableANR) {
            [self.anrDataStore deleteFile];
            if (event.isANR && self.delegate && [self.delegate respondsToSelector:@selector(anrStackDetected:appState:time:)]) {
                NSString *backtrace = event.allThreadsBacktrace.length > 0 ? event.allThreadsBacktrace : (event.mainThreadBacktrace.length > 0 ? event.mainThreadBacktrace : nil);
                [self.delegate anrStackDetected:backtrace appState:event.errorContextModel.appState time:event.startTimeNs];
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@", exception);
    }
}

- (void)shutDown {
    [self.longTaskDetector stopDetecting];
    self.longTaskEvent = nil;
    [self.anrDataStore deleteFile];
}

- (void)dealloc {
    if (_longTaskDetector) {
        [_longTaskDetector stopDetecting];
    }
}

@end
