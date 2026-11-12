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

#import "FTANRProcessor.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTRUMContext.h"
#import "FTIssueFieldEnricher.h"

@implementation FTLongTaskActiveEvent

- (instancetype)initWithStartTimeNs:(long long)startTimeNs freezeDurationMs:(long)freezeDurationMs appState:(NSString *)appState {
    self = [super init];
    if (self) {
        _startTimeNs = startTimeNs;
        _lastObservedTimeNs = startTimeNs;
        _freezeThresholdNs = (long long)freezeDurationMs * NSEC_PER_MSEC;
        _startAppState = [appState copy];
    }
    return self;
}

- (void)updateErrorContext:(FTFatalErrorContextModel *)context {
    _errorContextModel = [[FTFatalErrorContextModel alloc] initWithAppState:self.startAppState
        lastSessionState:context.lastSessionState lastViewContext:context.lastViewContext
        dynamicPropertySnapshot:context.dynamicPropertySnapshot globalPropertySnapshot:context.globalPropertySnapshot
        errorMonitorInfo:context.errorMonitorInfo];
}

- (long long)durationNs {
    return (long long)self.effectiveDurationNs;
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

- (FTLongTaskANRData *)anrData {
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:self.startTimeNs
                                                durationNs:self.durationNs
                                        mainThreadBacktrace:self.mainThreadBacktrace
                                        allThreadsBacktrace:self.allThreadsBacktrace
                                          errorContextModel:self.errorContextModel];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = self.lastObservedTimeNs;
    return data;
}

@end


@interface FTANRProcessor () {
    BOOL _ignoreBackgroundLongTaskAndANR;
}
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTLongTaskANRDataStore *dataStore;
@property (nonatomic, weak) id<FTBacktraceReporting> backtraceReporting;
@end
@implementation FTANRProcessor
- (instancetype)initWithDependencies:(FTRUMDependencies *)dependencies backtraceReporting:(id<FTBacktraceReporting>)backtrace ignoreBackgroundLongTaskAndANR:(BOOL)ignoreBackground {
    if ((self = [super init])) {
        _dependencies = dependencies; _backtraceReporting = backtrace;
        _ignoreBackgroundLongTaskAndANR = ignoreBackground;
        _dataStore = [FTLongTaskANRDataStore new];
    }
    return self;
}
- (void)updateEvent:(FTLongTaskActiveEvent *)event intervalActive:(BOOL (^)(void))intervalActive acceptsResult:(BOOL (^)(void))acceptsResult {
    if (self.dataStore.isClosed || !intervalActive() || event.durationNs <= FTLongTaskANRDataThresholdNs) return;
    BOOL captured = NO;
    if (event.needsAllThreadsBacktrace && event.effectiveDurationNs >= event.nextFullStackAttemptNs) {
        NSString *stack = [self.backtraceReporting generateAllThreadsBacktraceWithCaptureValidation:intervalActive];
        if (!acceptsResult()) return;
        captured = stack.length > 0;
        if (captured) event.allThreadsBacktrace = stack;
        event.nextFullStackAttemptNs = event.effectiveDurationNs + 250 * NSEC_PER_MSEC;
    }
    // Retain an ended interval's stack for End, but do no further collection or I/O.
    if (!intervalActive()) return;
    if (!event.hasPersistedANRData) {
        [event updateErrorContext:self.dependencies.fatalErrorContext.currentContextModel];
    }
    // Recheck collection admission after context/capture work.
    if (!intervalActive()) return;
    BOOL crossedANR = event.durationNs > FT_ANR_THRESHOLD_NS && event.lastPersistedDurationNs <= FT_ANR_THRESHOLD_NS;
    BOOL due = !event.hasPersistedANRData || captured || crossedANR ||
        event.effectiveDurationNs >= event.lastPersistedDurationNs + FTLongTaskANRDataUpdateIntervalNs;
    if (!due) return;
    if (!event.hasPersistedANRData || captured) {
        [self.dataStore writeANRData:event.anrData];
    } else {
        [self.dataStore appendTimingWithStartTimeNs:event.startTimeNs durationNs:event.durationNs endTimeNs:event.lastObservedTimeNs];
    }
    event.hasPersistedANRData = YES;
    event.lastPersistedDurationNs = event.durationNs;
}
- (uint64_t)nextCheckpointForEvent:(FTLongTaskActiveEvent *)event {
    uint64_t d = event.durationNs;
    if (d <= FTLongTaskANRDataThresholdNs) return FTLongTaskANRDataThresholdNs + NSEC_PER_MSEC;
    // Successful full capture leaves timing updates at one-second intervals.
    // Qualification and missing-stack retries may request an earlier checkpoint.
    uint64_t next = event.lastPersistedDurationNs + FTLongTaskANRDataUpdateIntervalNs;
    if (d <= FT_ANR_THRESHOLD_NS) next = MIN(next, FT_ANR_THRESHOLD_NS + NSEC_PER_MSEC);
    if (event.needsAllThreadsBacktrace) next = MIN(next, event.nextFullStackAttemptNs);
    return MAX(next, d + NSEC_PER_MSEC);
}
// longTask, ANR, View
- (void)reportPreviousANRIfFound {
    __weak __typeof(self) weakSelf = self;
    dispatch_async(self.dataStore.queue, ^{
        long long errorDate = 0;
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.dataStore.isClosed) return;
        @try {
            FTLongTaskANRData *anrData = [strongSelf.dataStore readANRData];
            if (anrData) {
                errorDate = [strongSelf reportANRData:anrData];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
        if (strongSelf.dataStore.isClosed) return;
        [strongSelf.dataStore deleteFile];
        [strongSelf.dependencies.writer lastFatalErrorIfFound:errorDate];
    });
}

- (long long)reportANRData:(FTLongTaskANRData *)anrData {
    if (self.dataStore.isClosed) return 0;
    long long startTime = anrData.startTimeNs;
    long long duration = anrData.usesEffectiveDuration ? anrData.durationNs :
        (anrData.lastUpdateTimeNs > startTime ? anrData.lastUpdateTimeNs - startTime : anrData.durationNs);
    if (duration <= 0) {
        return 0;
    }
    long long longTaskEndTime = anrData.usesEffectiveDuration ? MAX(startTime, anrData.endTimeNs) : startTime + duration;
    BOOL isAnr = duration > FT_ANR_THRESHOLD_NS;
    FTFatalErrorContextModel *contextModel = anrData.errorContextModel;
    NSString *savedSituation = contextModel.appState;
    BOOL validSituation = [savedSituation isKindOfClass:NSString.class] &&
        [@[@"startup", @"run", @"background", @"unknown"] containsObject:savedSituation];
    // V2 saved a sampling-time point, so it cannot establish the producer start.
    NSString *errorSituation = anrData.usesEffectiveDuration && validSituation ? savedSituation : @"unknown";
    if (_ignoreBackgroundLongTaskAndANR && validSituation && [savedSituation isEqualToString:@"background"]) return 0;
    NSDictionary *tags = [contextModel.lastSessionState sessionTags];
    NSString *backtrace = anrData.mainThreadBacktrace.length > 0 ? anrData.mainThreadBacktrace : nil;

    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields addEntriesFromDictionary:[contextModel.lastSessionState sessionFields]];
    [fields setValue:@(duration) forKey:FT_DURATION];
    [fields setValue:backtrace forKey:FT_KEY_LONG_TASK_STACK];
    NSDictionary *lastViews = contextModel.lastViewContext;
    BOOL sessionOnError = contextModel.lastSessionState.sampled_for_error_session;
    if (sessionOnError && isAnr) {
        [fields setValue:@(startTime) forKey:FT_SESSION_ERROR_TIMESTAMP];
    }
    if (lastViews) {
        NSMutableDictionary *lastViewsFields = [NSMutableDictionary dictionaryWithDictionary:lastViews[@"fields"]];
        NSSet *viewCustomKeys = FTRUMDecodeCustomKeys(lastViews[@"customFieldKeys"] ?: lastViews[@"tags"][FT_RUM_CUSTOM_KEYS]);
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
        lastViewsFields[@"app_state"] = @"unknown";
        NSNumber *time = lastViews[@"time"];

        if (self.dataStore.isClosed) return 0;
        FTRUMPropertySnapshot *viewSnapshot = lastViews[@"propertyTags"]
            ? [[FTRUMPropertySnapshot alloc] initWithTags:lastViews[@"propertyTags"] customKeys:FTRUMDecodeCustomKeys(lastViews[@"propertyCustomKeys"])]
            : contextModel.globalPropertySnapshot;
        FTRUMWriteData *viewData = [[FTRUMWriteData alloc] initWithSource:FT_RUM_SOURCE_VIEW tags:lastViews[@"tags"] fields:lastViewsFields
            context:viewSnapshot customTagKeys:nil customFieldKeys:viewCustomKeys time:time.longLongValue];
        NSString *viewVisitor = lastViews[@"tags"][FT_VISITOR_ID];
        if ([viewVisitor isKindOfClass:NSString.class]) viewData.visitorIDSnapshot = viewVisitor;
        viewData.updateTime = longTaskEndTime;
        viewData.cache = @(sessionOnError);
        [self.dependencies.writer writeRUMData:viewData];
    }
    if (self.dataStore.isClosed) return 0;
    FTRUMWriteData *longTaskData = [[FTRUMWriteData alloc] initWithSource:FT_RUM_SOURCE_LONG_TASK tags:tags fields:fields
        context:contextModel.globalPropertySnapshot customTagKeys:[NSSet set] customFieldKeys:[NSSet set] time:startTime];
    longTaskData.cache = @(sessionOnError);
    [self.dependencies.writer writeRUMData:longTaskData];

    if (isAnr && !self.dataStore.isClosed) {
        NSString *allBacktrace = anrData.allThreadsBacktrace.length > 0 ? anrData.allThreadsBacktrace : nil;
        NSMutableDictionary *anrTags = [NSMutableDictionary dictionary];
        NSMutableSet *anrTagKeys = [NSMutableSet set];
        NSMutableSet *anrFieldKeys = [NSMutableSet set];
        [anrTags setValue:@"anr_error" forKey:FT_KEY_ERROR_TYPE];
        [anrTags setValue:FT_LOGGER forKey:FT_KEY_ERROR_SOURCE];
        [anrTags addEntriesFromDictionary:contextModel.errorMonitorInfo];
        FTRUMMergeProperties(anrTags, anrTagKeys, contextModel.globalAttributes, contextModel.globalPropertySnapshot.customKeys);
        FTRUMMergeProperties(anrTags, anrTagKeys, contextModel.dynamicContext, contextModel.dynamicPropertySnapshot.customKeys);
        FTRUMMergeProperties(anrTags, anrTagKeys, [contextModel.lastSessionState sessionTags], nil);
        FTRUMMergeProperties(anrTags, anrTagKeys, tags, nil);
        // Event facts remain authoritative over saved custom/global context.
        FTRUMSetSystemProperty(anrTags, anrTagKeys, FT_KEY_ERROR_SITUATION, errorSituation);

        NSMutableDictionary *anrFields = [NSMutableDictionary dictionary];
        [anrFields addEntriesFromDictionary:[contextModel.lastSessionState sessionFields]];
        [anrFields setValue:@"ios_anr" forKey:FT_KEY_ERROR_MESSAGE];
        [anrFields setValue:allBacktrace ?: backtrace forKey:FT_KEY_ERROR_STACK];
        if (self.dependencies.issueFieldEnricher) {
            FTIssueInfo *issue = [[FTIssueInfo alloc]
                initWithCategory:FTIssueCategoryANR
                errorType:@"anr_error"
                message:@"ios_anr"
                stack:allBacktrace ?: backtrace ?: @""
                occurredAtNanoseconds:startTime
                appState:errorSituation
                threadName:@"main"
                historical:YES];
            NSMutableSet<NSString *> *reservedKeys = [NSMutableSet setWithArray:anrTags.allKeys];
            [reservedKeys addObjectsFromArray:anrFields.allKeys];
            NSDictionary *customFields =
                [self.dependencies.issueFieldEnricher fieldsForIssue:issue
                                                         reservedKeys:reservedKeys];
            FTRUMMergeProperties(anrFields, anrFieldKeys, customFields, FTRUMDecodeCustomKeys(customFields.allKeys));
        }
        if (self.dataStore.isClosed) return 0;
        FTRUMWriteData *errorData = [[FTRUMWriteData alloc] initWithSource:FT_RUM_SOURCE_ERROR tags:anrTags fields:anrFields
            context:nil customTagKeys:anrTagKeys customFieldKeys:anrFieldKeys time:startTime];
        errorData.cache = @NO;
        [self.dependencies.writer writeRUMData:errorData];
        return startTime;
    }
    return 0;
}


@end
