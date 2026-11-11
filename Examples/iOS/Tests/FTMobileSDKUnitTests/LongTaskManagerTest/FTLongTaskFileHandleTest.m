//
//  FTLongTaskFileHandleTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/8.
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

#import <XCTest/XCTest.h>
#import "FTLongTaskManager+Test.h"
#import "FTRUMDependencies.h"
#import "FTFatalErrorContext.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTCrash.h"
#import "FTCrashReportWrapper.h"
#import "FTCrashThread.h"
#import "FTErrorMonitorInfo.h"
#import "FTRUMContext.h"
#import "NSDate+FTUtil.h"
#import "FTLongTaskDetector.h"
#import "FTLongTaskTiming.h"
#import "FTLongTaskEvent.h"
#import "FTRUMViewHandler.h"
#import "FTRUMAppStateHistory.h"
#import "FTJSONUtil.h"
#import "FTRUMManager.h"
#import <objc/runtime.h>
#import <os/lock.h>
#import "FTSDKCompat.h"
#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

@interface FTLongTaskDetector (FTWaitTest)
- (void)recordRunLoopBeginActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (void)recordRunLoopEndActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (BOOL)readRunLoopSnapshot:(FTLongTaskRunLoopSnapshot *)snapshot;
@end

@interface FTRUMViewHandler (FTLongTaskEndpointTest)
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context;
@end

@interface FTLongTaskDetectorDelegateMock : NSObject <FTLongTaskTimingDelegate>
@end

@implementation FTLongTaskDetectorDelegateMock
- (uint64_t)longTaskDetector:(FTLongTaskDetector *)detector didObserveTiming:(FTLongTaskTiming)timing {
    return UINT64_MAX;
}
@end

@implementation FTManualTimingDetector
- (instancetype)initWithDelegate:(id<FTLongTaskTimingDelegate>)delegate {
    if ((self = [super initWithDelegate:delegate])) _testAppState = FTAppStateUnknown;
    return self;
}
- (BOOL)isMonitoringGeneration:(uint64_t)generation { return !self.intervalEnded; }
- (FTAppState)currentAppState { return self.testAppState; }
@end

typedef void (^FTLongTaskCallBack)(NSString *slowStack, long long duration);
typedef void (^FTWriteCallBack)(NSDictionary *fields, NSDictionary *tags);

@interface FTLongTaskBacktraceMock : NSObject<FTBacktraceReporting>
@property (nonatomic, copy) NSString *mainThreadBacktrace;
@property (nonatomic, copy) NSString *allThreadsBacktrace;
@property (nonatomic, assign) NSInteger mainThreadCallCount;
@property (nonatomic, assign) NSInteger allThreadsCallCount;
@property (nonatomic, assign) NSInteger nilAllThreadsResponseCount;
@property (nonatomic, copy) dispatch_block_t duringMainCapture;
@property (nonatomic, copy) dispatch_block_t duringAllThreadsCapture;
@property (nonatomic, copy) dispatch_block_t onMainThread;
@property (nonatomic, copy) dispatch_block_t onAllThreads;
@end

@implementation FTLongTaskBacktraceMock
- (NSString *)generateMainThreadBacktrace {
    return [self generateMainThreadBacktraceWithCaptureValidation:^BOOL{ return YES; }];
}
- (NSString *)generateAllThreadsBacktrace {
    return [self generateAllThreadsBacktraceWithCaptureValidation:^BOOL{ return YES; }];
}
- (NSString *)generateMainThreadBacktraceWithCaptureValidation:(FTBacktraceCaptureValidation)validation {
    if (!validation()) return nil;
    self.mainThreadCallCount += 1;
    if (self.duringMainCapture) self.duringMainCapture();
    if (!validation()) return nil;
    if (self.onMainThread) self.onMainThread(); // Formatting after valid raw capture.
    return self.mainThreadBacktrace;
}
- (NSString *)generateAllThreadsBacktraceWithCaptureValidation:(FTBacktraceCaptureValidation)validation {
    if (!validation()) return nil;
    self.allThreadsCallCount += 1;
    if (self.duringAllThreadsCapture) self.duringAllThreadsCapture();
    if (!validation()) return nil;
    if (self.onAllThreads) self.onAllThreads(); // Formatting after valid raw capture.
    if (self.nilAllThreadsResponseCount > 0) {
        self.nilAllThreadsResponseCount -= 1;
        return nil;
    }
    return self.allThreadsBacktrace;
}
@end

@interface FTCrashReportWrapper (FTCaptureFormatTest)
- (void)appendCommonTailToMutableString:(NSMutableString *)string imagesDict:(NSMutableDictionary *)images;
@end
@interface FTCaptureFormatProbe : FTCrashReportWrapper
@property (nonatomic, copy) dispatch_block_t onFormatting;
@property (nonatomic) NSUInteger formattingCount;
@end
@implementation FTCaptureFormatProbe
- (void)appendCommonTailToMutableString:(NSMutableString *)string imagesDict:(NSMutableDictionary *)images {
    self.formattingCount++;
    if (self.onFormatting) self.onFormatting();
    [super appendCommonTailToMutableString:string imagesDict:images];
}
@end

@interface FTCountingEnvironment : NSObject <FTErrorMonitorInfoProvider, FTErrorMonitorInfoWrapper>
@property (nonatomic) NSUInteger sampleCount;
@end
@implementation FTCountingEnvironment
- (NSDictionary *)errorMonitorInfo { return @{@"sample": @(++_sampleCount)}; }
- (void)onErrorMonitorInfoChange:(ErrorMonitorInfoChangeBlock)onChange {}
- (BOOL)enableMonitorMemory { return YES; }
- (BOOL)enableMonitorCpu { return YES; }
@end

@interface FTStateCaptureRUMManager : FTRUMManager
@property (nonatomic, strong) FTRUMDataModel *capturedError;
@end
@implementation FTStateCaptureRUMManager
- (BOOL)process:(FTRUMDataModel *)model context:(NSDictionary *)context {
    if (model.type == FTRUMDataError) self.capturedError = model;
    return YES;
}
@end

@interface FTLongTaskFileHandleTest : XCTestCase<FTRunloopDetectorDelegate,FTRUMDataWriteProtocol>
@property (nonatomic, copy) FTLongTaskCallBack  callBack;
@property (nonatomic, copy) FTWriteCallBack  writeCallBack;
@property (nonatomic, strong) FTLongTaskBacktraceMock *backtraceMock;
@property (nonatomic, assign) long long lastFatalErrorDate;
@property (nonatomic, strong) FTFatalErrorContext *fatalErrorContext;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *reportedANRTimes;
@property (nonatomic) long long observedEndTimeNs;
@property (nonatomic) NSUInteger assembledErrors;
@property (nonatomic, copy) NSDictionary *recoveredErrorTags;
@property (nonatomic, copy) NSDictionary *recoveredErrorFields;
@property (nonatomic, strong) FTLongTaskEvent *observedLongTask;
@property (nonatomic, copy) NSString *observedANRSituation;
@property (nonatomic, copy) NSString *observedANRIntervalState;
@property (nonatomic) BOOL ignoreBackgroundForTests;
@property (nonatomic) NSUInteger totalRUMWrites;

@end


@implementation FTLongTaskFileHandleTest

#if FT_HAS_UIKIT
- (void)testDetectorBootstrapsStartSituationAndIntervalIndependently {
    NSArray *scenarios = @[
        @[@(UIApplicationStateActive), @(FTAppStateRun), @(FTRUMAppStateForegroundOnly)],
        @[@(UIApplicationStateInactive), @(FTAppStateStartUp), @(FTRUMAppStateForegroundOnly)],
        @[@(UIApplicationStateBackground), @(FTAppStateBackground), @(FTRUMAppStateBackgroundOnly)]
    ];
    Method method = class_getInstanceMethod(UIApplication.class, @selector(applicationState));
    for (NSArray *scenario in scenarios) {
        UIApplicationState state = [scenario[0] integerValue];
        IMP replacement = imp_implementationWithBlock(^UIApplicationState(id application) { return state; });
        IMP original = method_setImplementation(method, replacement);
        FTLongTaskDetectorDelegateMock *probe = [FTLongTaskDetectorDelegateMock new];
        FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:probe];
        @try {
            [detector startDetecting];
            [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:NSEC_PER_SEC];
            FTLongTaskRunLoopSnapshot snapshot;
            XCTAssertTrue([detector readRunLoopSnapshot:&snapshot]);
            XCTAssertEqual(snapshot.startAppState, [scenario[1] unsignedIntegerValue]);
            XCTAssertEqual(snapshot.startIntervalState, [scenario[2] unsignedIntegerValue]);
        } @finally {
            [detector stopDetecting];
            FTTestDrainDetector(detector);
            method_setImplementation(method, original);
            imp_removeBlock(replacement);
        }
    }
}

- (void)testDetectorReceivesRealLifecycleNotificationsAndUnsubscribes {
    FTLongTaskDetectorDelegateMock *probe = [FTLongTaskDetectorDelegateMock new];
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:probe];
    [detector startDetecting];
    NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
    [notifications postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [detector recordRunLoopBeginActivity:kCFRunLoopEntry atTimeNs:NSEC_PER_SEC];
    FTLongTaskRunLoopSnapshot background, foreground, stopped;
    XCTAssertTrue([detector readRunLoopSnapshot:&background]);
    XCTAssertEqual(background.startAppState, FTAppStateBackground);
    XCTAssertEqual(background.startIntervalState, FTRUMAppStateBackgroundOnly);
    [notifications postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [notifications postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [detector recordRunLoopBeginActivity:kCFRunLoopAfterWaiting atTimeNs:2LL*NSEC_PER_SEC];
    XCTAssertTrue([detector readRunLoopSnapshot:&foreground]);
    XCTAssertEqual(foreground.startAppState, FTAppStateRun);
    XCTAssertEqual(foreground.startIntervalState, FTRUMAppStateForegroundOnly);
    [detector stopDetecting];
    FTTestDrainDetector(detector);
    [notifications postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [detector recordRunLoopBeginActivity:kCFRunLoopAfterWaiting atTimeNs:3LL*NSEC_PER_SEC];
    XCTAssertTrue([detector readRunLoopSnapshot:&stopped]);
    XCTAssertEqual(stopped.startAppState, FTAppStateRun);
    XCTAssertEqual(stopped.foregroundRevision, foreground.foregroundRevision);
    XCTAssertEqual(stopped.backgroundRevision, foreground.backgroundRevision);
}
#endif

- (void)testDetectorStateSurvivesMissingHistoryAndDelayedEnd {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    [self.fatalErrorContext setAppState:@"background"];
    FTTestObserveLongTaskState(manager, FTLongTaskPhaseBegin, NSEC_PER_SEC, 0, NSEC_PER_SEC,
                              FTAppStateRun, FTRUMAppStateForegroundOnly);
    FTTestObserveLongTaskState(manager, FTLongTaskPhaseCheckpoint, NSEC_PER_SEC, 3001*NSEC_PER_MSEC,
                              4LL*NSEC_PER_SEC+NSEC_PER_MSEC, FTAppStateRun, FTRUMAppStateForegroundOnly);
    XCTAssertEqualObjects([FTTestANRStore(manager) readANRData].errorContextModel.appState, @"run");
    // Producer End was 7s; background was observed before the worker processed it.
    FTTestObserveLongTaskState(manager, FTLongTaskPhaseEnd, NSEC_PER_SEC, 6LL*NSEC_PER_SEC,
                              7LL*NSEC_PER_SEC, FTAppStateRun, FTRUMAppStateBackgroundAndForeground);
    XCTAssertEqualObjects(self.observedANRSituation, @"run");
    XCTAssertEqualObjects(self.observedANRIntervalState, @"foreground_and_background");
    XCTAssertEqualObjects(self.observedLongTask.appState, @"foreground_and_background");
    XCTAssertEqual(self.observedLongTask.endTimeNs, 7LL*NSEC_PER_SEC);
    XCTAssertEqual(self.observedLongTask.durationNs, 6LL*NSEC_PER_SEC);
    [manager shutDown];
}

- (void)testHistoryCannotReplaceUnavailableProducerStartState {
    for (NSNumber *mode in @[@0, @1, @2, @3]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
        if (mode.integerValue != 0) {
            dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"foreground"
                timeNs:(mode.integerValue == 1 ? 2LL : 1LL)*NSEC_PER_SEC];
            if (mode.integerValue == 2) {
                for (NSUInteger index = 2; index <= 130; index++)
                    [dependencies.appStateHistory recordState:@"background" timeNs:index*NSEC_PER_SEC];
            } else if (mode.integerValue == 3) {
                [dependencies.appStateHistory recordState:@"background" timeNs:NSEC_PER_SEC-1];
            }
        }
        [self.fatalErrorContext setAppState:@"run"];
        [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:140LL*NSEC_PER_SEC to:manager];
        FTLongTaskANRData *saved = [FTTestANRStore(manager) readANRData];
        XCTAssertEqualObjects(saved.errorContextModel.appState, @"unknown");
        [manager shutDown];
    }
}

- (void)testContextRefreshCannotReplaceDetectorRecordedSituation {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    self.backtraceMock.onAllThreads = ^{
        [self.fatalErrorContext setAppState:@"background"];
    };
    FTTestObserveLongTaskState(manager, FTLongTaskPhaseBegin, NSEC_PER_SEC, 0, NSEC_PER_SEC,
                              FTAppStateRun, FTRUMAppStateForegroundOnly);
    FTTestObserveLongTaskState(manager, FTLongTaskPhaseCheckpoint, NSEC_PER_SEC, 3001*NSEC_PER_MSEC,
                              4LL*NSEC_PER_SEC+NSEC_PER_MSEC, FTAppStateRun, FTRUMAppStateUnknown);
    XCTAssertEqualObjects([FTTestANRStore(manager) readANRData].errorContextModel.appState, @"run");
    FTTestObserveLongTaskState(manager, FTLongTaskPhaseEnd, NSEC_PER_SEC, 6LL*NSEC_PER_SEC,
                              7LL*NSEC_PER_SEC, FTAppStateRun, FTRUMAppStateBackgroundAndForeground);
    XCTAssertEqualObjects(self.observedANRSituation, @"run");
    XCTAssertEqualObjects(self.observedANRIntervalState, @"foreground_and_background");
    self.backtraceMock.onAllThreads = nil;
    [manager shutDown];
}

- (void)testLongTaskAndANRShareOneFrozenIntervalClassification {
    NSArray *scenarios = @[
        @[@(FTAppStateStartUp), @(FTRUMAppStateForegroundOnly), @"foreground", @"startup"],
        @[@(FTAppStateRun), @(FTRUMAppStateForegroundOnly), @"foreground", @"run"],
        @[@(FTAppStateBackground), @(FTRUMAppStateBackgroundOnly), @"background", @"background"],
        @[@(FTAppStateRun), @(FTRUMAppStateBackgroundAndForeground), @"foreground_and_background", @"run"],
        @[@(FTAppStateBackground), @(FTRUMAppStateBackgroundAndForeground), @"foreground_and_background", @"background"],
        @[@(FTAppStateUnknown), @(FTRUMAppStateUnknown), @"unknown", @"unknown"]
    ];
    for (NSArray *scenario in scenarios) {
        self.observedLongTask = nil;
        self.observedANRSituation = nil;
        self.observedANRIntervalState = nil;
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTAppState startState = [scenario[0] unsignedIntegerValue];
        FTRUMAppState appState = [scenario[1] unsignedIntegerValue];
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseBegin, NSEC_PER_SEC, 0, NSEC_PER_SEC,
                                  startState, FTRUMAppStateUnknown);
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseCheckpoint, NSEC_PER_SEC, 3001*NSEC_PER_MSEC,
                                  4LL*NSEC_PER_SEC+NSEC_PER_MSEC, startState, FTRUMAppStateUnknown);
        self.callBack = ^(NSString *stack, long long duration) {
            // The first delegate can change lifecycle context; ANR must retain the
            // detector's stop-time classification and immutable start situation.
            [self.fatalErrorContext setAppState:@"background"];
        };
        NSUInteger previousANRCount = self.reportedANRTimes.count;
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseEnd, NSEC_PER_SEC, 6LL*NSEC_PER_SEC,
                                  7LL*NSEC_PER_SEC, startState, appState);
        XCTAssertEqual(self.reportedANRTimes.count, previousANRCount + 1);
        XCTAssertNotNil(self.observedLongTask);
        XCTAssertEqualObjects(self.observedLongTask.appState, scenario[2]);
        XCTAssertEqualObjects(self.observedANRIntervalState, scenario[2]);
        XCTAssertEqualObjects(self.observedANRSituation, scenario[3]);
        XCTAssertEqual(self.observedLongTask.endTimeNs, 7LL*NSEC_PER_SEC);
        NSUInteger count = self.reportedANRTimes.count;
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseEnd, NSEC_PER_SEC, 9LL*NSEC_PER_SEC,
                                  10LL*NSEC_PER_SEC, FTAppStateBackground, FTRUMAppStateBackgroundOnly);
        XCTAssertEqual(self.reportedANRTimes.count, count);
        self.callBack = nil;
        [manager shutDown];
    }
}

- (void)testV3RecoveryPreservesOnlyValidRecordedSituationsAndReservesIntervalField {
    for (id value in @[@"startup", @"run", @"background", @"unknown", @"foreground", @42, NSNull.null]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        [self.fatalErrorContext setAppState:[value isKindOfClass:NSString.class] ? value : nil];
        FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
        __block FTIssueInfo *received;
        dependencies.issueDataProvider = ^NSDictionary *(FTIssueInfo *issue) {
            received = issue;
            return @{@"app_state": @"foreground", @"error_situation": @"background", @"custom": @"kept"};
        };
        FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC
            durationNs:6LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all"
            errorContextModel:self.fatalErrorContext.currentContextModel];
        data.usesEffectiveDuration = YES;
        data.endTimeNs = 7LL*NSEC_PER_SEC;
        NSMutableDictionary *raw = [[data convertToDictionary] mutableCopy];
        NSMutableDictionary *rawContext = [raw[@"errorContextModel"] mutableCopy];
        rawContext[@"appState"] = value;
        rawContext[@"dynamicContext"] = @{FT_KEY_ERROR_SITUATION: @"custom-override"};
        raw[@"errorContextModel"] = rawContext;
        data = [[FTLongTaskANRData alloc] initWithDictionary:raw];
        [FTTestANRStore(manager) writeANRData:data];
        [FTTestANRProcessor(manager) reportPreviousANRIfFound];
        dispatch_sync(FTTestANRStore(manager).queue, ^{});
        NSString *expected = [@[@"startup", @"run", @"background", @"unknown"] containsObject:value] ? value : @"unknown";
        XCTAssertEqualObjects(self.recoveredErrorTags[FT_KEY_ERROR_SITUATION], expected);
        XCTAssertEqualObjects(self.recoveredErrorFields[@"app_state"], @"unknown");
        XCTAssertEqualObjects(self.recoveredErrorFields[@"custom"], @"kept");
        XCTAssertEqualObjects(received.appState, expected);
        XCTAssertTrue(received.isHistorical);
        XCTAssertEqual(received.occurredAtNanoseconds, NSEC_PER_SEC);
        dependencies.issueDataProvider = nil;
        [manager shutDown];
    }
}

- (void)testAutomaticLongTaskKeepsFrozenIntervalAfterRUMDelay {
    FTRUMDependencies *dependencies = [FTRUMDependencies new];
    dependencies.writer = self;
    // State history has been trimmed past this completed producer interval.
    dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"background" timeNs:100LL*NSEC_PER_SEC];
    FTRUMViewModel *view = [[FTRUMViewModel alloc] initWithViewID:@"delayed" viewName:@"delayed" viewReferrer:@""];
    view.tm = NSEC_PER_SEC;
    FTRUMContext *context = [[FTRUMContext alloc] initWithSampleRate:100 sessionOnErrorSampleRate:0 appId:@"app"];
    FTRUMViewHandler *handler = [[FTRUMViewHandler alloc] initWithModel:view context:context rumDependencies:dependencies needsMonitoring:NO];
    FTRUMDataModel *model = [FTRUMDataModel new];
    model.type = FTRUMDataLongTask;
    model.tm = NSEC_PER_SEC;
    model.tags = @{};
    model.fields = @{FT_DURATION: @(3LL*NSEC_PER_SEC)};
    model.longTaskEvent = [[FTLongTaskEvent alloc] initWithStack:@"main" startTimeNs:NSEC_PER_SEC
        endTimeNs:61LL*NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC appState:@"foreground_and_background"];
    __block NSDictionary *written;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) { written = fields; };
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"], @"foreground_and_background");
    XCTAssertEqual([written[FT_DURATION] longLongValue], 3LL*NSEC_PER_SEC);
    model.longTaskEvent = nil; // Manual collection retains its original history query.
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) { written = fields; };
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"], @"unknown");
    self.writeCallBack = nil;
}

- (void)testDelayedRUMAndIssueProviderCannotChangeANRStates {
    FTRUMDependencies *dependencies = [FTRUMDependencies new];
    dependencies.fatalErrorContext = [[FTFatalErrorContext alloc] initWithErrorInfoProvider:nil];
    FTStateCaptureRUMManager *rum = [[FTStateCaptureRUMManager alloc] initWithRumDependencies:dependencies];
    [rum syncProcess];
    [dependencies.appStateHistory stopMonitoring];
    dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"foreground" timeNs:NSEC_PER_SEC];
    [dependencies.appStateHistory recordState:@"background" timeNs:3LL*NSEC_PER_SEC];
    NSString *interval = [dependencies.appStateHistory stateFrom:NSEC_PER_SEC to:7LL*NSEC_PER_SEC];
    __block NSUInteger calls = 0;
    __block FTIssueInfo *received;
    dependencies.issueDataProvider = ^NSDictionary *(FTIssueInfo *issue) {
        calls += 1; received = issue;
        return issue.category == FTIssueCategoryANR
            ? @{@"app_state": @"background", @"error_situation": @"background", @"custom": @"kept"} : @{};
    };
    dispatch_queue_t queue = [rum valueForKey:@"rumQueue"];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0), done = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{ dispatch_semaphore_signal(entered); dispatch_semaphore_wait(release, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)); });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)), 0L);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [rum addAutomaticIssueWithCategory:FTIssueCategoryANR errorType:@"anr_error" appState:@"run"
            message:@"ios_anr" stack:@"all" threadName:@"main" time:NSEC_PER_SEC historical:NO intervalAppState:interval];
        dispatch_semaphore_signal(done);
    });
    for (NSUInteger index = 10; index < 140; index++)
        [dependencies.appStateHistory recordState:@"background" timeNs:index*NSEC_PER_SEC];
    dispatch_semaphore_signal(release);
    XCTAssertEqual(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)), 0L);
    [rum syncProcess];
    XCTAssertEqualObjects(rum.capturedError.fields[@"app_state"], @"foreground_and_background");
    XCTAssertEqualObjects(rum.capturedError.tags[FT_KEY_ERROR_SITUATION], @"run");
    XCTAssertEqualObjects(rum.capturedError.fields[@"custom"], @"kept");
    XCTAssertEqualObjects(received.appState, @"run");
    XCTAssertEqual(received.occurredAtNanoseconds, NSEC_PER_SEC);
    XCTAssertFalse(received.isHistorical);
    XCTAssertEqual(rum.capturedError.tm, NSEC_PER_SEC);
    [rum addErrorWithType:@"anr_error" state:FTAppStateBackground message:@"manual" stack:@"main" property:nil];
    XCTAssertNil(rum.capturedError.fields[@"app_state"]);
    XCTAssertEqual(calls, 1U);
    [rum addAutomaticIssueWithCategory:FTIssueCategoryCrash errorType:@"ios_crash" appState:@"background"
        message:@"crash" stack:@"main" threadName:@"main" time:9LL*NSEC_PER_SEC historical:YES];
    XCTAssertNil(rum.capturedError.fields[@"app_state"]);
    XCTAssertEqualObjects(rum.capturedError.tags[FT_KEY_ERROR_SITUATION], @"background");
    XCTAssertEqual(calls, 2U);
    dependencies.issueDataProvider = nil;
}

- (void)testRecordedSituationSurvivesContextRefreshAndPersistence {
    NSArray *states = @[@"startup", @"run", @"background"];
    NSArray *values = @[@(FTAppStateStartUp), @(FTAppStateRun), @(FTAppStateBackground)];
    for (NSUInteger index = 0; index < states.count; index++) {
        NSString *startState = states[index];
        FTAppState start = [values[index] unsignedIntegerValue];
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
        // Delayed creation and persistence must not read a later context or history.
        dependencies.appStateHistory = nil;
        [self.fatalErrorContext setAppState:@"background"];
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseBegin, NSEC_PER_SEC, 0, NSEC_PER_SEC,
                                  start, FTRUMAppStateUnknown);
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseCheckpoint, NSEC_PER_SEC, 251*NSEC_PER_MSEC,
                                  3LL*NSEC_PER_SEC, start, FTRUMAppStateUnknown);
        FTLongTaskActiveEvent *event = [manager valueForKey:@"longTaskEvent"];
        XCTAssertEqualObjects(event.errorContextModel.appState, startState);
        [self.fatalErrorContext setAppState:@"run"];
        FTTestObserveLongTaskState(manager, FTLongTaskPhaseCheckpoint, NSEC_PER_SEC, 3001*NSEC_PER_MSEC,
                                  5LL*NSEC_PER_SEC, start, FTRUMAppStateUnknown);
        XCTAssertEqualObjects(event.errorContextModel.appState, startState);
        FTLongTaskANRData *saved = [FTTestANRStore(manager) readANRData];
        XCTAssertEqualObjects(saved.errorContextModel.appState, startState);
        [manager shutDown];
    }
}

- (void)testLegacyV2RecoveryUsesSavedSituationAndUnknownInterval {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    [self.fatalErrorContext setAppState:@"run"];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC
        durationNs:6LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all"
        errorContextModel:self.fatalErrorContext.currentContextModel];
    data.lastUpdateTimeNs = 7LL*NSEC_PER_SEC;
    XCTAssertEqual([FTTestANRProcessor(manager) reportANRData:data], NSEC_PER_SEC);
    XCTAssertEqualObjects(self.recoveredErrorTags[FT_KEY_ERROR_SITUATION], @"run");
    XCTAssertEqualObjects(self.recoveredErrorFields[@"app_state"], @"unknown");
    [manager shutDown];
}

- (void)testEffectiveDurationSurvivesHistoricalRecovery {
    FTLongTaskManager *manager = [self mockLongTaskManager];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithDictionary:@{
        @"startDate": @(1000000000LL), @"duration": @(3000000000LL),
        @"effectiveDuration": @(3000000000LL), @"endDate": @(61000000000LL),
        @"mainThreadBacktrace": @"main"
    }];
    data.lastUpdateTimeNs = 61000000000LL;
    __block long long writtenDuration = 0;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) {
        if (fields[FT_DURATION]) writtenDuration = [fields[FT_DURATION] longLongValue];
    };
    XCTAssertEqual([FTTestANRProcessor(manager) reportANRData:data], 0LL);
    XCTAssertEqual(writtenDuration, 3000000000LL);
    self.writeCallBack = nil;
    [manager shutDown];
}


- (FTLongTaskManager *)timingManagerANR:(BOOL)anr freeze:(BOOL)freeze threshold:(long)threshold {
    self.backtraceMock = [FTLongTaskBacktraceMock new];
    self.backtraceMock.mainThreadBacktrace = @"main";
    self.backtraceMock.allThreadsBacktrace = @"all";
    FTLongTaskManager *manager = [self mockLongTaskManagerWithBacktraceReporting:self.backtraceMock enableANR:anr enableFreeze:freeze freezeDurationMs:threshold];
    return manager;
}
- (uint64_t)sendPhase:(FTLongTaskPhase)phase duration:(uint64_t)duration end:(long long)end to:(FTLongTaskManager *)manager {
    return FTTestObserveLongTask(manager, phase, NSEC_PER_SEC, duration, end);
}
// Producer End is delivered before capture returns, while coordinator End is
// processed afterward on the serial detector queue, matching the real call order.
- (void)testInternalBackgroundPolicyRejectsBackgroundCheckpoint {
    self.ignoreBackgroundForTests=YES;
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    FTTestObserveLongTaskState(manager,FTLongTaskPhaseBegin,NSEC_PER_SEC,0,NSEC_PER_SEC,
                              FTAppStateBackground,FTRUMAppStateBackgroundOnly);
    FTTestObserveLongTaskState(manager,FTLongTaskPhaseCheckpoint,NSEC_PER_SEC,5001*NSEC_PER_MSEC,7LL*NSEC_PER_SEC,
                              FTAppStateBackground,FTRUMAppStateBackgroundOnly);
    FTTestObserveLongTaskState(manager,FTLongTaskPhaseEnd,NSEC_PER_SEC,5100*NSEC_PER_MSEC,8LL*NSEC_PER_SEC,
                              FTAppStateBackground,FTRUMAppStateBackgroundOnly);
    XCTAssertNil(self.observedLongTask);
    XCTAssertEqual(self.reportedANRTimes.count,0U);
    XCTAssertEqual(self.backtraceMock.mainThreadCallCount,0);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount,0);
    [manager shutDown];
}

- (void)testCaptureRefreshPersistsLastRecordedSituation {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
    detector.testAppState=FTAppStateRun;
    FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateRun,.recordedAppState=FTAppStateRun};
    [manager longTaskDetector:detector didObserveTiming:timing];
    self.backtraceMock.onAllThreads=^{ detector.testAppState=FTAppStateBackground; };
    timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=3001*NSEC_PER_MSEC;timing.observationTimeNs=4LL*NSEC_PER_SEC+NSEC_PER_MSEC;
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertEqualObjects([FTTestANRStore(manager)readANRData].errorContextModel.appState,@"background");
    [manager shutDown];
}

- (void)testInternalBackgroundPolicyDefaultsAndCopies {
    FTRUMDependencies *dependencies=[FTRUMDependencies new];
    XCTAssertFalse(dependencies.ignoreBackgroundLongTaskAndANR);
    dependencies.ignoreBackgroundLongTaskAndANR=YES;
    FTRUMDependencies *copy=[dependencies copy];
    XCTAssertTrue(copy.ignoreBackgroundLongTaskAndANR);
}

- (void)testBackgroundAdmissionSnapshotCannotBeOverriddenByCurrentForeground {
    self.ignoreBackgroundForTests=YES;
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
    detector.testAppState=FTAppStateRun;
    FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateBackground,.recordedAppState=FTAppStateRun};
    XCTAssertEqual([manager longTaskDetector:detector didObserveTiming:timing],UINT64_MAX);
    timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=5001*NSEC_PER_MSEC;
    [manager longTaskDetector:detector didObserveTiming:timing];
    timing.phase=FTLongTaskPhaseEnd;
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertNil(self.observedLongTask);
    XCTAssertEqual(self.reportedANRTimes.count,0U);
    XCTAssertEqual(self.backtraceMock.mainThreadCallCount,0);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount,0);
    [manager shutDown];
}

- (void)testBackgroundAtEveryCheckpointCancelsAndCannotReviveTheInterval {
    for (NSUInteger stage=0;stage<7;stage++) {
        self.ignoreBackgroundForTests=YES;
        self.observedLongTask=nil;
        [self.reportedANRTimes removeAllObjects];
        FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
        FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
        detector.testAppState=FTAppStateRun;
        FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
            .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateRun,.recordedAppState=FTAppStateRun};
        [manager longTaskDetector:detector didObserveTiming:timing];
        dispatch_block_t background=^{detector.testAppState=FTAppStateBackground;};
        if(stage==0) background(); // State changed after the timing snapshot, before callback work.
        if(stage==1) self.backtraceMock.duringMainCapture=background;
        if(stage==2) self.backtraceMock.onMainThread=background;
        if(stage==3) self.backtraceMock.duringAllThreadsCapture=background;
        if(stage==4) self.backtraceMock.onAllThreads=background;
        timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=5001*NSEC_PER_MSEC;
        timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
        [manager longTaskDetector:detector didObserveTiming:timing];
        if(stage>=5) {
            XCTAssertNotNil([FTTestANRStore(manager)readANRData]);
            background();
            timing.recordedAppState=FTAppStateBackground;
            timing.phase=stage==5?FTLongTaskPhaseCheckpoint:FTLongTaskPhaseEnd;
            timing.durationNs=5100*NSEC_PER_MSEC;
            [manager longTaskDetector:detector didObserveTiming:timing];
        }
        XCTAssertNil([FTTestANRStore(manager)readANRData]);
        NSUInteger mainCalls=self.backtraceMock.mainThreadCallCount,allCalls=self.backtraceMock.allThreadsCallCount;
        XCTAssertEqual(mainCalls,stage==0?0U:1U);
        XCTAssertEqual(allCalls,stage<3?0U:1U);
        detector.testAppState=FTAppStateRun;timing.recordedAppState=FTAppStateRun;
        timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=6001*NSEC_PER_MSEC;
        [manager longTaskDetector:detector didObserveTiming:timing];
        timing.phase=FTLongTaskPhaseEnd;
        [manager longTaskDetector:detector didObserveTiming:timing];
        XCTAssertNil(self.observedLongTask);
        XCTAssertEqual(self.reportedANRTimes.count,0U);
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount,mainCalls);
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount,allCalls);
        self.backtraceMock.duringMainCapture=nil;self.backtraceMock.onMainThread=nil;
        self.backtraceMock.duringAllThreadsCapture=nil;self.backtraceMock.onAllThreads=nil;
        // A fresh foreground interval is independent. A late background End from
        // the cancelled generation must not discard the newly confirmed event.
        timing.generation=43;timing.startTimeNs=10LL*NSEC_PER_SEC;
        timing.phase=FTLongTaskPhaseBegin;timing.durationNs=0;
        [manager longTaskDetector:detector didObserveTiming:timing];
        timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=5001*NSEC_PER_MSEC;
        timing.observationTimeNs=timing.startTimeNs+timing.durationNs;
        [manager longTaskDetector:detector didObserveTiming:timing];
        FTLongTaskTiming late=timing;late.generation=42;late.phase=FTLongTaskPhaseEnd;late.recordedAppState=FTAppStateBackground;
        [manager longTaskDetector:detector didObserveTiming:late];
        XCTAssertNotNil([FTTestANRStore(manager)readANRData]);
        timing.phase=FTLongTaskPhaseEnd;timing.durationNs=5100*NSEC_PER_MSEC;
        timing.observationTimeNs=timing.startTimeNs+timing.durationNs;timing.appState=FTRUMAppStateForegroundOnly;
        [manager longTaskDetector:detector didObserveTiming:timing];
        XCTAssertEqual(self.observedLongTask.durationNs,5100*NSEC_PER_MSEC);
        XCTAssertEqualObjects(self.reportedANRTimes,(@[@(10LL*NSEC_PER_SEC)]));
        [manager shutDown];
    }
}

- (void)testDisabledBackgroundCollectionAndUnknownAdmissionRemainEligible {
    for(NSNumber *enabled in @[@NO,@YES]) {
        self.ignoreBackgroundForTests=enabled.boolValue;
        [self.reportedANRTimes removeAllObjects];
        FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
        FTAppState state=enabled.boolValue?FTAppStateUnknown:FTAppStateBackground;
        FTRUMAppState interval=enabled.boolValue?FTRUMAppStateUnknown:FTRUMAppStateBackgroundOnly;
        FTTestObserveLongTaskState(manager,FTLongTaskPhaseBegin,NSEC_PER_SEC,0,NSEC_PER_SEC,state,interval);
        FTTestObserveLongTaskState(manager,FTLongTaskPhaseCheckpoint,NSEC_PER_SEC,5001*NSEC_PER_MSEC,7LL*NSEC_PER_SEC,state,interval);
        FTTestObserveLongTaskState(manager,FTLongTaskPhaseEnd,NSEC_PER_SEC,5100*NSEC_PER_MSEC,8LL*NSEC_PER_SEC,state,interval);
        XCTAssertEqualObjects(self.observedANRSituation,enabled.boolValue?@"unknown":@"background");
        XCTAssertEqualObjects(self.observedLongTask.appState,enabled.boolValue?@"unknown":@"background");
        XCTAssertEqual(self.reportedANRTimes.count,1U);
        [manager shutDown];
    }
}

- (void)testFreezeOnlyRetainsBoundedBackgroundChecksWithoutRecapturing {
    self.ignoreBackgroundForTests=YES;
    FTLongTaskManager *manager=[self timingManagerANR:NO freeze:YES threshold:250];
    FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
    detector.testAppState=FTAppStateRun;
    FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateRun,.recordedAppState=FTAppStateRun};
    XCTAssertEqual([manager longTaskDetector:detector didObserveTiming:timing],251*NSEC_PER_MSEC);
    timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=251*NSEC_PER_MSEC;
    XCTAssertEqual([manager longTaskDetector:detector didObserveTiming:timing],1251*NSEC_PER_MSEC);
    timing.durationNs=1251*NSEC_PER_MSEC;
    XCTAssertEqual([manager longTaskDetector:detector didObserveTiming:timing],2251*NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.mainThreadCallCount,1);
    detector.testAppState=FTAppStateBackground;timing.recordedAppState=FTAppStateBackground;
    XCTAssertEqual([manager longTaskDetector:detector didObserveTiming:timing],UINT64_MAX);
    timing.phase=FTLongTaskPhaseEnd;
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertNil(self.observedLongTask);
    [manager shutDown];
}

- (void)testLastEndSituationIsFrozenBeforeDelegateProcessing {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
    detector.testAppState=FTAppStateRun;
    FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateRun,.recordedAppState=FTAppStateRun};
    [manager longTaskDetector:detector didObserveTiming:timing];
    timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=5001*NSEC_PER_MSEC;
    timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
    [manager longTaskDetector:detector didObserveTiming:timing];
    detector.testAppState=FTAppStateBackground;
    timing.phase=FTLongTaskPhaseEnd;timing.durationNs=5100*NSEC_PER_MSEC;
    timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
    timing.recordedAppState=FTAppStateBackground;timing.appState=FTRUMAppStateBackgroundAndForeground;
    self.callBack=^(NSString *stack,long long duration){if(duration>0)detector.testAppState=FTAppStateRun;};
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertEqualObjects(self.observedANRSituation,@"background");
    XCTAssertEqualObjects(self.observedANRIntervalState,@"foreground_and_background");
    XCTAssertEqualObjects(self.observedLongTask.appState,@"foreground_and_background");
    XCTAssertEqual(self.observedLongTask.durationNs,5100*NSEC_PER_MSEC);
    self.callBack=nil;[manager shutDown];
}

- (void)testBackgroundBeforeRemainingDeliverySuppressesANR {
    self.ignoreBackgroundForTests=YES;
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
    detector.testAppState=FTAppStateRun;
    FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateRun,.recordedAppState=FTAppStateRun};
    [manager longTaskDetector:detector didObserveTiming:timing];
    timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=5001*NSEC_PER_MSEC;
    [manager longTaskDetector:detector didObserveTiming:timing];
    self.callBack=^(NSString *stack,long long duration){if(duration>0)detector.testAppState=FTAppStateBackground;};
    timing.phase=FTLongTaskPhaseEnd;timing.durationNs=5100*NSEC_PER_MSEC;
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertNotNil(self.observedLongTask);
    XCTAssertEqual(self.reportedANRTimes.count,0U);
    XCTAssertNil([FTTestANRStore(manager)readANRData]);
    self.callBack=nil;[manager shutDown];
}

- (void)testRecordedStateChangesReplaceBaseAndRecoveryUsesLatestValue {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    FTManualTimingDetector *detector=[[FTManualTimingDetector alloc]initWithDelegate:manager];
    detector.testAppState=FTAppStateRun;
    FTLongTaskTiming timing={.phase=FTLongTaskPhaseBegin,.generation=42,.startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC,.startAppState=FTAppStateRun,.recordedAppState=FTAppStateRun};
    [manager longTaskDetector:detector didObserveTiming:timing];
    uint64_t durations[]={3001,4001,4101,4201,6001};
    FTAppState states[]={FTAppStateRun,FTAppStateRun,FTAppStateBackground,FTAppStateRun,FTAppStateRun};
    for(NSUInteger i=0;i<5;i++) {
        detector.testAppState=states[i];timing.recordedAppState=states[i];
        timing.phase=FTLongTaskPhaseCheckpoint;timing.durationNs=durations[i]*NSEC_PER_MSEC;
        timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
        [manager longTaskDetector:detector didObserveTiming:timing];
        FTLongTaskANRData *saved=[FTTestANRStore(manager)readANRData];
        XCTAssertEqual(saved.durationNs,durations[i]*NSEC_PER_MSEC);
        XCTAssertEqualObjects(saved.errorContextModel.appState,i==2?@"background":@"run");
        NSString *file=[NSString stringWithContentsOfFile:FTTestANRStore(manager).dataStorePath encoding:NSUTF8StringEncoding error:nil];
        NSString *tail=[file componentsSeparatedByString:@"\n___boundary.info.date___\n"].lastObject;
        if(i==0||i==2||i==3) XCTAssertEqualObjects(tail,@"");
        else XCTAssertTrue([tail containsString:@"effectiveDuration"]);
    }
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount,1);
    FTLongTaskANRData *saved=[FTTestANRStore(manager)readANRData];
    [self.fatalErrorContext setAppState:@"background"]; // New/current context cannot reclassify the file.
    XCTAssertEqual([FTTestANRProcessor(manager)reportANRData:saved],NSEC_PER_SEC);
    XCTAssertEqualObjects(self.recoveredErrorTags[FT_KEY_ERROR_SITUATION],@"run");
    [manager shutDown];
}

- (void)testRecoveryBackgroundPolicyUsesSavedV2AndV3Situation {
    self.ignoreBackgroundForTests=YES;
    for(NSNumber *v3 in @[@NO,@YES]) for(id state in @[@"background",@"run",@"unknown",@"foreground",NSNull.null]) {
        FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
        FTFatalErrorContextModel *context=[[FTFatalErrorContextModel alloc]initWithAppState:state==NSNull.null?nil:state
            lastSessionState:self.fatalErrorContext.currentContextModel.lastSessionState lastViewContext:nil
            dynamicContext:nil globalAttributes:nil errorMonitorInfo:nil];
        FTLongTaskANRData *data=[[FTLongTaskANRData alloc]initWithStartTimeNs:NSEC_PER_SEC durationNs:6LL*NSEC_PER_SEC
            mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:context];
        data.usesEffectiveDuration=v3.boolValue;data.endTimeNs=7LL*NSEC_PER_SEC;
        FTLongTaskANRDataStore *store=FTTestANRStore(manager);
        if(v3.boolValue) [store writeANRData:data];
        else {
            NSString *json=[FTJSONUtil convertToJsonDataWithObject:data.convertToDictionary];
            NSString *file=[NSString stringWithFormat:@"2.0.0\n___boundary.info.date___\n%@\n___boundary.info.date___\n7000000000\n",json];
            [file writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        [self.fatalErrorContext setAppState:@"background"];
        NSUInteger writes=self.totalRUMWrites,errors=self.assembledErrors;
        [FTTestANRProcessor(manager)reportPreviousANRIfFound];dispatch_sync(store.queue,^{});
        BOOL ignored=[state isEqual:@"background"];
        XCTAssertEqual(self.totalRUMWrites-writes,ignored?0U:2U);
        XCTAssertEqual(self.assembledErrors-errors,ignored?0U:1U);
        XCTAssertEqual(self.lastFatalErrorDate,ignored?0:NSEC_PER_SEC);
        if(!ignored) {
            NSString *expected=[@[@"run",@"unknown"] containsObject:state]?state:@"unknown";
            XCTAssertEqualObjects(self.recoveredErrorTags[FT_KEY_ERROR_SITUATION],expected);
            XCTAssertEqualObjects(self.recoveredErrorFields[@"app_state"],@"unknown");
        }
        XCTAssertFalse([[NSFileManager defaultManager]fileExistsAtPath:store.dataStorePath]);
        [manager shutDown];
    }
}

- (void)testProducerEndDuringMainStackFormattingRetainsCapturedResult {
    for (NSNumber *anr in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:anr.boolValue freeze:YES threshold:250];
        FTManualTimingDetector *detector = [[FTManualTimingDetector alloc] initWithDelegate:manager];
        FTLongTaskTiming timing = {.phase=FTLongTaskPhaseBegin, .generation=42, .startTimeNs=NSEC_PER_SEC,
            .observationTimeNs=NSEC_PER_SEC};
        [manager longTaskDetector:detector didObserveTiming:timing];
        self.backtraceMock.onMainThread = ^{ detector.intervalEnded = YES; };
        timing.phase=FTLongTaskPhaseCheckpoint;
        timing.durationNs=(anr.boolValue ? 5001 : 251)*NSEC_PER_MSEC;
        timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
        [manager longTaskDetector:detector didObserveTiming:timing];
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 0, @"End prevents a later full capture");
        XCTAssertNil([FTTestANRStore(manager) readANRData]);
        timing.phase=FTLongTaskPhaseEnd;
        timing.durationNs=(anr.boolValue ? 5100 : 320)*NSEC_PER_MSEC;
        timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
        __block NSUInteger reports=0;
        self.callBack=^(NSString *stack,long long duration) { if (duration > 0) reports++; };
        [manager longTaskDetector:detector didObserveTiming:timing];
        [manager longTaskDetector:detector didObserveTiming:timing];
        XCTAssertEqualObjects(self.observedLongTask.stack, @"main");
        XCTAssertEqual(self.observedLongTask.durationNs, (anr.boolValue ? 5100 : 320)*NSEC_PER_MSEC);
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 1);
        XCTAssertEqual(reports, 1U);
        // The helper shares this test's report list across the two modes.
        XCTAssertEqual(self.reportedANRTimes.count, anr.boolValue ? 1U : 0U);
        [manager shutDown];
    }
}

- (void)testProducerEndDuringFullStackFormattingRetainsCapturedResult {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTManualTimingDetector *detector = [[FTManualTimingDetector alloc] initWithDelegate:manager];
    FTLongTaskTiming timing = {.phase=FTLongTaskPhaseBegin, .generation=42, .startTimeNs=NSEC_PER_SEC,
        .observationTimeNs=NSEC_PER_SEC};
    [manager longTaskDetector:detector didObserveTiming:timing];
    self.backtraceMock.onAllThreads = ^{ detector.intervalEnded = YES; };
    timing.phase=FTLongTaskPhaseCheckpoint; timing.durationNs=5001*NSEC_PER_MSEC;
    timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertNil([FTTestANRStore(manager) readANRData], @"ended intervals must not start persistence");
    timing.phase=FTLongTaskPhaseEnd; timing.durationNs=5100*NSEC_PER_MSEC;
    timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
    __block NSString *reportedANR;
    self.callBack=^(NSString *stack,long long duration) { if (duration == 0) reportedANR=stack; };
    [manager longTaskDetector:detector didObserveTiming:timing];
    [manager longTaskDetector:detector didObserveTiming:timing];
    XCTAssertEqualObjects(reportedANR, @"all");
    XCTAssertEqualObjects(self.observedLongTask.stack, @"main");
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    XCTAssertEqual(self.reportedANRTimes.count, 1U);
    [manager shutDown];
}

- (void)testGenerationChangeDuringRawCaptureRejectsFrames {
    for (NSNumber *fullStack in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:fullStack.boolValue freeze:YES threshold:250];
        FTManualTimingDetector *detector = [[FTManualTimingDetector alloc] initWithDelegate:manager];
        FTLongTaskTiming timing = {.phase=FTLongTaskPhaseBegin, .generation=42, .startTimeNs=NSEC_PER_SEC,
            .observationTimeNs=NSEC_PER_SEC};
        [manager longTaskDetector:detector didObserveTiming:timing];
        dispatch_block_t endDuringCapture=^{ detector.intervalEnded=YES; };
        if (fullStack.boolValue) self.backtraceMock.duringAllThreadsCapture=endDuringCapture;
        else self.backtraceMock.duringMainCapture=endDuringCapture;
        timing.phase=FTLongTaskPhaseCheckpoint; timing.durationNs=5001*NSEC_PER_MSEC;
        timing.observationTimeNs=NSEC_PER_SEC+timing.durationNs;
        [manager longTaskDetector:detector didObserveTiming:timing];
        XCTAssertNil([FTTestANRStore(manager) readANRData]);
        __block NSString *reportedANR;
        self.callBack=^(NSString *stack,long long duration) { if (duration == 0) reportedANR=stack; };
        timing.phase=FTLongTaskPhaseEnd;
        [manager longTaskDetector:detector didObserveTiming:timing];
        XCTAssertEqualObjects(self.observedLongTask.stack, fullStack.boolValue ? @"main" : @"");
        if (fullStack.boolValue) XCTAssertEqualObjects(reportedANR, @"main");
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 1);
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount, fullStack.boolValue ? 1 : 0);
        [manager shutDown];
    }
}

- (void)testShutdownDuringFormattingRejectsResultAndPersistence {
    for (NSNumber *fullStack in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        dispatch_block_t shutdown=^{ [manager shutDown]; };
        if (fullStack.boolValue) self.backtraceMock.onAllThreads=shutdown;
        else self.backtraceMock.onMainThread=shutdown;
        [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
        XCTAssertNil(self.observedLongTask);
        XCTAssertEqual(self.reportedANRTimes.count, 0U);
        XCTAssertNil([FTTestANRStore(manager) readANRData]);
        XCTAssertTrue(FTTestANRStore(manager).isClosed);
        self.backtraceMock.onAllThreads=nil; self.backtraceMock.onMainThread=nil;
    }
}

- (void)testNativeRawCaptureValidationPrecedesFormatting {
    FTCaptureFormatProbe *wrapper=[FTCaptureFormatProbe new];
    __block BOOL active=YES;
    __block NSUInteger validations=0;
    wrapper.onFormatting=^{ active=NO; };
    NSString *stack=[wrapper generateBacktrace:(thread_t)ftcrashthread_self() captureValidation:^BOOL{
        validations++; return active;
    }];
    XCTAssertEqual(validations, 2U);
    XCTAssertEqual(wrapper.formattingCount, 1U);
    XCTAssertTrue([stack containsString:@"Thread 0:"], @"native frames survive End during formatting");
    XCTAssertFalse(active);
    wrapper.formattingCount=0;
    XCTAssertNil([wrapper generateBacktrace:(thread_t)ftcrashthread_self() captureValidation:^BOOL{ return NO; }]);
    XCTAssertEqual(wrapper.formattingCount, 0U);
    validations=0;
    XCTAssertNil([wrapper generateBacktrace:(thread_t)ftcrashthread_self() captureValidation:^BOOL{
        return ++validations == 1; // Producer changes during raw unwind.
    }]);
    XCTAssertEqual(validations, 2U);
    XCTAssertEqual(wrapper.formattingCount, 0U);
    XCTAssertNil([wrapper generateAllThreadsBacktraceWithCaptureValidation:^BOOL{ return NO; }]);
    XCTAssertEqual(wrapper.formattingCount, 0U);
}

- (void)testShortFreezeReportsWithoutWaitingForANRFileQueue {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:251*NSEC_PER_MSEC end:NSEC_PER_SEC+251*NSEC_PER_MSEC to:manager];
    FTLongTaskActiveEvent *event=[manager valueForKey:@"longTaskEvent"];
    XCTAssertFalse(event.hasPersistedANRData);
    FTLongTaskANRDataStore *store=FTTestANRStore(manager);
    dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
    dispatch_semaphore_t reported=dispatch_semaphore_create(0),finished=dispatch_semaphore_create(0);
    dispatch_async(store.queue, ^{ dispatch_semaphore_signal(entered); dispatch_semaphore_wait(release,DISPATCH_TIME_FOREVER); });
    XCTAssertEqual(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC)),0);
    __block NSUInteger reports=0;
    self.callBack=^(NSString *stack,long long duration) { reports++; dispatch_semaphore_signal(reported); };
    FTLongTaskDetector *detector=[manager valueForKey:@"longTaskDetector"];
    [detector performAsynchronousBlock:^{
        [self sendPhase:FTLongTaskPhaseEnd duration:320*NSEC_PER_MSEC end:NSEC_PER_SEC+320*NSEC_PER_MSEC to:manager];
        dispatch_semaphore_signal(finished);
    }];
    // Always release before asserting, so the pre-fix failure cannot strand queues.
    long reportResult=dispatch_semaphore_wait(reported,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC));
    dispatch_semaphore_signal(release);
    XCTAssertEqual(dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC)),0);
    XCTAssertEqual(reportResult,0,@"an unpersisted Freeze reports before the file queue is released");
    XCTAssertEqual(reports,1U);
    XCTAssertEqual(self.observedLongTask.durationNs,320*NSEC_PER_MSEC);
    XCTAssertEqualObjects(self.observedLongTask.stack,@"main");
    [manager shutDown];
}

- (void)testSubmittedPersistenceIsClearedAtEndEvenWhenPendingOrFailed {
    for (NSNumber *failWrite in @[@NO,@YES]) {
        FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
        FTLongTaskANRDataStore *store=FTTestANRStore(manager);
        NSURL *directory=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        if (failWrite.boolValue) store.dataStorePath=[[directory URLByAppendingPathComponent:@"longtask.log"] path];
        dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
        dispatch_semaphore_t endEntered=dispatch_semaphore_create(0),finished=dispatch_semaphore_create(0);
        dispatch_async(store.queue, ^{ dispatch_semaphore_signal(entered); dispatch_semaphore_wait(release,DISPATCH_TIME_FOREVER); });
        XCTAssertEqual(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC)),0);
        [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:4LL*NSEC_PER_SEC+NSEC_PER_MSEC to:manager];
        FTLongTaskActiveEvent *event=[manager valueForKey:@"longTaskEvent"];
        XCTAssertTrue(event.hasPersistedANRData,@"the marker means submission, before the file queue can write");
        FTLongTaskDetector *detector=[manager valueForKey:@"longTaskDetector"];
        [detector performAsynchronousBlock:^{
            dispatch_semaphore_signal(endEntered);
            [self sendPhase:FTLongTaskPhaseEnd duration:3100*NSEC_PER_MSEC end:4LL*NSEC_PER_SEC+100*NSEC_PER_MSEC to:manager];
            dispatch_semaphore_signal(finished);
        }];
        XCTAssertEqual(dispatch_semaphore_wait(endEntered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC)),0);
        dispatch_semaphore_signal(release);
        XCTAssertEqual(dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC)),0);
        XCTAssertEqual(self.observedLongTask.durationNs,3100*NSEC_PER_MSEC);
        XCTAssertEqual(self.reportedANRTimes.count,0U,@"cleanup also applies below the five-second ANR threshold");
        XCTAssertNil([store readANRData]);
        // A failed base remains retryable in memory unless End cleared it. Make
        // the path writable, then prove a late timing append cannot revive it.
        if (failWrite.boolValue) [[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
        [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4001*NSEC_PER_MSEC endTimeNs:5LL*NSEC_PER_SEC+NSEC_PER_MSEC];
        XCTAssertNil([store readANRData]);
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
        [manager shutDown];
        dispatch_sync(store.queue,^{});
        if (failWrite.boolValue) [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
    }
}

- (void)testFirstANRPersistenceReusesRefreshedEnvironmentSample {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:NO threshold:250];
    FTRUMDependencies *dependencies=[manager valueForKey:@"dependencies"];
    FTCountingEnvironment *provider=[FTCountingEnvironment new];
    FTFatalErrorContext *context=[[FTFatalErrorContext alloc] initWithErrorInfoProvider:provider];
    [context setLastSessionState:self.fatalErrorContext.currentContextModel.lastSessionState];
    dependencies.fatalErrorContext=context;
    dependencies.errorMonitorInfoWrapper=provider;
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:4LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRData *saved=[FTTestANRStore(manager) readANRData];
    XCTAssertEqual(provider.sampleCount, 2U, @"one creation sample and one persistence refresh");
    XCTAssertEqualObjects(saved.errorContextModel.errorMonitorInfo[@"sample"], @2);
    [manager shutDown];
}

- (void)testEndBeforeFirstCheckpointDoesNotConfirmIncident {
    for (NSString *state in @[@"foreground", @"background"]) {
        for (NSNumber *mode in @[@0, @1, @2]) {
            BOOL anr = mode.integerValue != 0, freeze = mode.integerValue != 1;
            FTLongTaskManager *manager = [self timingManagerANR:anr freeze:freeze threshold:250];
            [self.fatalErrorContext setAppState:state];
            uint64_t firstCheckpoint = freeze ? 251 * NSEC_PER_MSEC : 3001 * NSEC_PER_MSEC;
            XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], firstCheckpoint);
            __block NSUInteger reports = 0;
            self.callBack = ^(NSString *stack, long long duration) { reports += 1; };
            // The worker sees the producer End before processing its first checkpoint.
            long long end = NSEC_PER_SEC + firstCheckpoint + 49 * NSEC_PER_MSEC;
            XCTAssertEqual([self sendPhase:FTLongTaskPhaseEnd duration:firstCheckpoint end:end to:manager], UINT64_MAX);
            [self sendPhase:FTLongTaskPhaseEnd duration:firstCheckpoint end:end + NSEC_PER_SEC to:manager];
            XCTAssertEqual(reports, 0U);
            XCTAssertEqual(self.reportedANRTimes.count, 0U);
            XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 0);
            XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 0);
            XCTAssertNil([manager valueForKey:@"longTaskEvent"]);
            XCTAssertNil([FTTestANRStore(manager) readANRData]);
            self.callBack = nil;
            [manager shutDown];
        }
    }
}
- (void)testConfirmedIncidentSettlesOnceAtEndWithoutRecapturing {
    for (NSString *state in @[@"foreground", @"background"]) {
        [self.reportedANRTimes removeAllObjects];
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        [self.fatalErrorContext setAppState:state];
        [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001 * NSEC_PER_MSEC end:4LL * NSEC_PER_SEC + NSEC_PER_MSEC to:manager];
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 1);
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
        NSMutableArray *durations = [NSMutableArray array];
        self.callBack = ^(NSString *stack, long long duration) { [durations addObject:@(duration)]; };
        [self sendPhase:FTLongTaskPhaseEnd duration:5100 * NSEC_PER_MSEC end:8LL * NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseEnd duration:5100 * NSEC_PER_MSEC end:9LL * NSEC_PER_SEC to:manager];
        XCTAssertEqualObjects(durations, (@[@(5100 * NSEC_PER_MSEC), @0]));
        XCTAssertEqualObjects(self.reportedANRTimes, (@[@(NSEC_PER_SEC)]));
        XCTAssertEqual(self.observedEndTimeNs, 8LL * NSEC_PER_SEC);
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 1);
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
        XCTAssertNil([FTTestANRStore(manager) readANRData]);
        self.callBack = nil;
        [manager shutDown];
    }
}
- (void)testTimingOnlyCheckpointKeepsBaseSnapshotUnchanged {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    self.backtraceMock.allThreadsBacktrace = [@"stack\n" stringByPaddingToLength:100000 withString:@"frame\n" startingAtIndex:0];
    FTLongTaskANRDataStore *store = FTTestANRStore(manager);
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:61LL*NSEC_PER_SEC to:manager];
    dispatch_sync(store.queue, ^{});
    NSString *before = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:4002*NSEC_PER_MSEC end:62LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRData *saved = [store readANRData];
    NSString *after = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    NSArray *beforeParts = [before componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    NSArray *afterParts = [after componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertEqualObjects(afterParts[1], beforeParts[1]);
    XCTAssertGreaterThan([afterParts[2] length], 0U);
    XCTAssertLessThan([after lengthOfBytesUsingEncoding:NSUTF8StringEncoding] - [before lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 256U);
    XCTAssertEqual(saved.durationNs, 4002*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 62LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, self.backtraceMock.allThreadsBacktrace);
    [manager shutDown];
}
- (void)testV3RecoveryUsesLastCompleteValidatedTimingPair {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSString *payload = @"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"effectiveDuration\":3100000000,\"endDate\":5000000000}\n___boundary.info.date___\n"
        @"{\"effectiveDuration\":4100000000,\"endDate\":61000000000}\n"
        @"{\"effectiveDuration\":18446744079709551616,\"endDate\":62000000000}\n"
        @"{\"effectiveDuration\":5001000000,\"endDate\":62000000000}\n"
        @"{\"effectiveDuration\":6000000000,\"endDate\":63000000000}";
    XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.startTimeNs, NSEC_PER_SEC);
    XCTAssertEqual(saved.durationNs, 5001*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 62LL*NSEC_PER_SEC);
    XCTAssertEqual(saved.lastUpdateTimeNs, 62LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testV3TimingTailRejectsInvalidPairsAndRegressions {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSString *base = @"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"effectiveDuration\":3100000000,\"endDate\":5000000000}\n___boundary.info.date___\n"
        @"{\"effectiveDuration\":4100000000,\"endDate\":61000000000}\n";
    for (NSString *key in @[@"effectiveDuration", @"endDate"]) {
        NSArray *invalidValues = @[@"", @"null", @"true", @"false", @"\"6000000000\"", @"{}", @"[]", @"-1", @"0", @"0.5", @"6000000000.5", @"9223372036854775808", @"18446744079709551616", @"1e100"];
        if ([key isEqualToString:@"effectiveDuration"]) invalidValues = [invalidValues arrayByAddingObject:@"4000000000"];
        for (NSString *value in invalidValues) {
            NSString *field = value.length ? [NSString stringWithFormat:@"\"%@\":%@,", key, value] : @"";
            NSString *other = [key isEqualToString:@"effectiveDuration"] ? @"\"endDate\":62000000000" : @"\"effectiveDuration\":6000000000";
            NSString *payload = [base stringByAppendingFormat:@"{%@%@}\n", field, other];
            XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil]);
            FTLongTaskANRData *saved = [store readANRData];
            XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC, @"%@=%@", key, value);
            XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
        }
    }
    [store deleteFile];
}
- (void)testTimingAppendPreservesExactLargeNanoseconds {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:1 durationNs:0 mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 1;
    [store writeANRData:data];
    for (NSNumber *duration in @[@1780000000123456789LL, @9223372036854775806LL]) {
        [store appendTimingWithStartTimeNs:1 durationNs:duration.longLongValue endTimeNs:duration.longLongValue + 1];
        FTLongTaskANRData *saved = [store readANRData];
        XCTAssertEqual(saved.startTimeNs, 1LL);
        XCTAssertEqual(saved.durationNs, duration.longLongValue);
        XCTAssertEqual(saved.endTimeNs, duration.longLongValue + 1);
    }
    [store deleteFile];
}
- (void)testTimingAppendPreservesBaseAndReplacementClearsTail {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
    data.durationNs = 5100*NSEC_PER_MSEC; data.endTimeNs = 62LL*NSEC_PER_SEC; data.allThreadsBacktrace = @"all";
    [store writeANRData:data];
    saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 5100*NSEC_PER_MSEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, @"all");
    NSString *content = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([content componentsSeparatedByString:@"\n___boundary.info.date___\n"][2], @"");
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:6100*NSEC_PER_MSEC endTimeNs:63LL*NSEC_PER_SEC];
    saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 6100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 63LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testTimingAppendIsolatesTornTailAndCapturesScalarsBeforeQueueDelay {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    dispatch_sync(store.queue, ^{
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:store.dataStorePath];
        [handle seekToEndOfFile];
        [handle writeData:[@"{\"effectiveDuration\":9999999999" dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    });
    XCTAssertEqual([store readANRData].durationNs, 3100*NSEC_PER_MSEC);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0);
    dispatch_async(store.queue, ^{ dispatch_semaphore_signal(entered); dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER); });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    [store appendTimingWithStartTimeNs:data.startTimeNs durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    data.startTimeNs = 99LL*NSEC_PER_SEC; data.durationNs = 99LL*NSEC_PER_SEC; data.endTimeNs = 199LL*NSEC_PER_SEC;
    dispatch_semaphore_signal(release);
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.startTimeNs, NSEC_PER_SEC);
    XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testTimingAppendRequiresMatchingBaseAndCannotRecreateDeletedFile {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    dispatch_sync(store.queue, ^{});
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    [store appendTimingWithStartTimeNs:2LL*NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    XCTAssertEqual([store readANRData].durationNs, 3100*NSEC_PER_MSEC);
    // External loss of an active file can rebuild its retained base; explicit store deletion cannot.
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:store.dataStorePath error:nil]);
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    XCTAssertEqual([store readANRData].durationNs, 4100*NSEC_PER_MSEC);
    [store deleteFile];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    dispatch_sync(store.queue, ^{});
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
}
- (void)testFailedBaseWriteCannotReceiveTimingAppend {
    FTLongTaskANRDataStore *store = [FTLongTaskANRDataStore new];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]);
    store.dataStorePath = directory; // Atomic data writes cannot replace a directory.
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    dispatch_sync(store.queue, ^{});
    XCTAssertEqual([[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil].count, 0U);
    XCTAssertNil([store readANRData]);
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
}
- (void)testTimingUpdateRetriesFailedBaseBeforeAppending {
    FTLongTaskANRDataStore *store = [FTLongTaskANRDataStore new];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]);
    store.dataStorePath = directory;
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    dispatch_sync(store.queue, ^{});
    store.dataStorePath = [directory stringByAppendingPathComponent:@"recovered.log"];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, @"all");
    NSString *content = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([content componentsSeparatedByString:@"\n___boundary.info.date___\n"][2], @"");
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:5100*NSEC_PER_MSEC endTimeNs:62LL*NSEC_PER_SEC];
    saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 5100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 62LL*NSEC_PER_SEC);
    content = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertGreaterThan([[content componentsSeparatedByString:@"\n___boundary.info.date___\n"][2] length], 0U);
    [store deleteFile];
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
}
- (void)testLateFullStackReplacementClearsTimingTail {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    self.backtraceMock.nilAllThreadsResponseCount = 3;
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3100*NSEC_PER_MSEC end:5LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3600*NSEC_PER_MSEC end:6LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:4200*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRDataStore *store = FTTestANRStore(manager);
    XCTAssertEqual([store readANRData].durationNs, 4200*NSEC_PER_MSEC);
    NSString *before = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertGreaterThan([[before componentsSeparatedByString:@"\n___boundary.info.date___\n"][2] length], 0U);
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:4500*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 4500*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 8LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, @"all");
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 4);
    NSString *after = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([after componentsSeparatedByString:@"\n___boundary.info.date___\n"][2], @"");
    [manager shutDown];
}
- (void)testRecoveredTimingTailUsesEffectiveDurationAndRejectsOverflow {
    for (NSNumber *corrupt in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTLongTaskANRDataStore *store = FTTestANRStore(manager);
        FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:[self.fatalErrorContext currentContextModel]];
        data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
        [store writeANRData:data];
        dispatch_sync(store.queue, ^{
            NSString *line = [NSString stringWithFormat:@"{\"effectiveDuration\":%@,\"endDate\":61000000000}\n", corrupt.boolValue ? @"18446744079709551616" : @"6000000000"];
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:store.dataStorePath];
            [handle seekToEndOfFile]; [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [handle closeFile];
        });
        __block long long recoveredDuration = -1;
        self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) { recoveredDuration = [fields[FT_DURATION] longLongValue]; };
        self.assembledErrors = 0; self.lastFatalErrorDate = -1;
        [FTTestANRProcessor(manager) reportPreviousANRIfFound];
        dispatch_sync(store.queue, ^{});
        XCTAssertEqual(recoveredDuration, corrupt.boolValue ? 3100*NSEC_PER_MSEC : 6LL*NSEC_PER_SEC);
        XCTAssertEqual(self.assembledErrors, corrupt.boolValue ? 0U : 1U);
        XCTAssertEqual(self.lastFatalErrorDate, corrupt.boolValue ? 0LL : NSEC_PER_SEC);
        self.writeCallBack = nil; [manager shutDown];
    }
}
- (void)testDynamicCheckpointsAndEffectiveDurationPersistence {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:10000];
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], 3001 * NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3001 * NSEC_PER_MSEC end:61LL*NSEC_PER_SEC to:manager], 4001 * NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    FTLongTaskANRData *data = [FTTestANRStore(manager) readANRData];
    XCTAssertTrue(data.usesEffectiveDuration);
    XCTAssertEqual(data.durationNs, 3001 * NSEC_PER_MSEC);
    XCTAssertEqual(data.endTimeNs, 61LL * NSEC_PER_SEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:4001 * NSEC_PER_MSEC end:62LL*NSEC_PER_SEC to:manager], 5001 * NSEC_PER_MSEC);
    data = [FTTestANRStore(manager) readANRData];
    XCTAssertEqual(data.durationNs, 4001 * NSEC_PER_MSEC, @"one-second updates must persist without an extra 1 ms wakeup");
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:5001 * NSEC_PER_MSEC end:63LL*NSEC_PER_SEC to:manager], 6001 * NSEC_PER_MSEC);
    data = [FTTestANRStore(manager) readANRData];
    XCTAssertEqual(data.durationNs, 5001 * NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:64LL*NSEC_PER_SEC to:manager];
    XCTAssertEqualObjects(self.reportedANRTimes, (@[@(NSEC_PER_SEC)]));
    [manager shutDown];
}
- (void)testSuccessfulFullStackUsesOneSecondChecksAndPreservesANRBoundary {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:NO threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3500*NSEC_PER_MSEC end:5LL*NSEC_PER_SEC to:manager], 4500*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:4500*NSEC_PER_MSEC end:6LL*NSEC_PER_SEC to:manager], 5001*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager], 6001*NSEC_PER_MSEC);
    FTLongTaskANRData *saved = [FTTestANRStore(manager) readANRData];
    XCTAssertEqual(saved.durationNs, 5001*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 7LL*NSEC_PER_SEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1, @"successful capture is not retried during timing updates");
    [manager shutDown];
}
- (void)testFreezeOnlyPreservesRealEndpointAndEffectiveDuration {
    FTLongTaskManager *manager = [self timingManagerANR:NO freeze:YES threshold:250];
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], 251 * NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:251*NSEC_PER_MSEC end:61LL*NSEC_PER_SEC to:manager], UINT64_MAX);
    __block long long duration = 0;
    self.callBack = ^(NSString *stack,long long d) { duration=d; };
    [self sendPhase:FTLongTaskPhaseEnd duration:300*NSEC_PER_MSEC end:62LL*NSEC_PER_SEC to:manager];
    XCTAssertEqual(duration, 300*NSEC_PER_MSEC);
    XCTAssertEqual(self.observedEndTimeNs, 62LL*NSEC_PER_SEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 0);
    XCTAssertNil([FTTestANRStore(manager) readANRData]);
    self.callBack=nil; [manager shutDown];
}
- (void)testANROnlyFixedRetryAndMissingMainStack {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:NO threshold:250];
    self.backtraceMock.mainThreadBacktrace=nil;
    self.backtraceMock.nilAllThreadsResponseCount=1;
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], 3001*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:4LL*NSEC_PER_SEC to:manager], 3251*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3101*NSEC_PER_MSEC end:5LL*NSEC_PER_SEC to:manager], 3251*NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3251*NSEC_PER_MSEC end:6LL*NSEC_PER_SEC to:manager], 4251*NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 2);
    FTLongTaskANRData *data=[FTTestANRStore(manager) readANRData];
    XCTAssertEqualObjects(data.allThreadsBacktrace,@"all");
    XCTAssertEqualObjects(data.mainThreadBacktrace,@"");
    [manager shutDown];
}
- (void)testAutomaticStateIsFrozenAndManualStateUsesDurationHistory {
    FTRUMDependencies *dependencies=[FTRUMDependencies new];dependencies.writer=self;
    dependencies.appStateHistory=[[FTRUMAppStateHistory alloc]initWithState:@"foreground" timeNs:NSEC_PER_SEC];
    [dependencies.appStateHistory recordState:@"background" timeNs:10LL*NSEC_PER_SEC];
    FTRUMViewModel *view=[[FTRUMViewModel alloc]initWithViewID:@"view" viewName:@"view" viewReferrer:@""];
    view.tm=NSEC_PER_SEC;
    FTRUMContext *context=[[FTRUMContext alloc]initWithSampleRate:100 sessionOnErrorSampleRate:0 appId:@"app"];
    FTRUMViewHandler *handler=[[FTRUMViewHandler alloc]initWithModel:view context:context rumDependencies:dependencies needsMonitoring:NO];
    FTRUMDataModel *model=[FTRUMDataModel new];model.type=FTRUMDataLongTask;model.tm=NSEC_PER_SEC;
    model.tags=@{};model.fields=@{FT_DURATION:@(3LL*NSEC_PER_SEC)};
    model.longTaskEvent=[[FTLongTaskEvent alloc]initWithStack:@"main" startTimeNs:NSEC_PER_SEC endTimeNs:61LL*NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC appState:@"foreground_and_background"];
    __block NSDictionary *written;
    self.writeCallBack=^(NSDictionary *fields,NSDictionary *tags){written=fields;};
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"],@"foreground_and_background");
    XCTAssertEqual([written[FT_DURATION]longLongValue],3LL*NSEC_PER_SEC);
    model.longTaskEvent=[[FTLongTaskEvent alloc]initWithStack:@"main" startTimeNs:NSEC_PER_SEC
        endTimeNs:61LL*NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC];
    self.writeCallBack=^(NSDictionary *fields,NSDictionary *tags){written=fields;};
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"],@"unknown");
    // Existing manually reported LongTasks still derive their interval from duration.
    model.longTaskEvent=nil;
    self.writeCallBack=^(NSDictionary *fields,NSDictionary *tags){written=fields;};
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"],@"foreground");
    self.writeCallBack=nil;
}
- (void)testDuplicateEndAndShutdownDuringRecoveredCallback {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
    __block NSUInteger freezes=0;
    self.callBack=^(NSString *stack,long long d){ freezes++; [manager shutDown]; };
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:9LL*NSEC_PER_SEC to:manager];
    XCTAssertEqual(freezes,1U);
    XCTAssertEqual(self.reportedANRTimes.count,0U);
    self.callBack=nil;
}
- (void)testNewPersistenceIgnoresLegacyTrailerAndRejectsMissingDuration {
    FTLongTaskANRDataStore *store=[self mockANRDataStore];
    FTLongTaskANRData *data=[[FTLongTaskANRData alloc]initWithStartTimeNs:NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration=YES;data.endTimeNs=61LL*NSEC_PER_SEC;
    [store writeANRData:data];
    dispatch_sync(store.queue, ^{
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:store.dataStorePath];
        [handle seekToEndOfFile];
        [handle writeData:[@"1000000000000\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    });
    data=[store readANRData];
    XCTAssertEqual(data.durationNs,3LL*NSEC_PER_SEC);
    XCTAssertEqual(data.lastUpdateTimeNs,61LL*NSEC_PER_SEC);
    [store deleteFile];
    [@"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"endDate\":61000000000}\n___boundary.info.date___\n61000000000\n" writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNil([store readANRData]);[store deleteFile];
}
- (void)testV3RejectsMissingOrInvalidStartTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSArray<NSString *> *invalidStarts = @[@"", @"null", @"true", @"false", @"\"1000000000\"",
        @"{}", @"[]", @"0", @"-1", @"0.5", @"1.5", @"9223372036854775808",
        @"18446744073709551617", @"1e100"];
    for (NSString *start in invalidStarts) {
        NSString *startField = start.length ? [NSString stringWithFormat:@"\"startDate\":%@,", start] : @"";
        NSString *payload = [NSString stringWithFormat:
            @"3.0.0\n___boundary.info.date___\n{%@\"effectiveDuration\":0,\"endDate\":9223372036854775807}\n___boundary.info.date___\n", startField];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
        XCTAssertNil([store readANRData], @"Invalid startDate must reject the complete v3 record: %@", start);
    }
    [store deleteFile];
}
- (void)testV3PreservesExactPositiveIntegerStartTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSNumber *start in @[@1LL, @1000000000LL, @1780000000123456789LL, @9223372036854775807LL]) {
        NSString *payload = [NSString stringWithFormat:
            @"3.0.0\n___boundary.info.date___\n{\"startDate\":%@,\"effectiveDuration\":0,\"endDate\":9223372036854775807}\n___boundary.info.date___\n", start];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
        FTLongTaskANRData *data = [store readANRData];
        XCTAssertNotNil(data);
        XCTAssertTrue(data.usesEffectiveDuration);
        XCTAssertEqual(data.startTimeNs, start.longLongValue);
        XCTAssertEqual(data.endTimeNs, 9223372036854775807LL);
        XCTAssertEqual(data.durationNs, 0LL);
    }
    [store deleteFile];
}
- (void)testV3RejectsInvalidEffectiveDurationAndEndTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSString *key in @[@"effectiveDuration", @"endDate"]) {
        NSMutableArray<NSString *> *invalidValues = [@[@"", @"null", @"true", @"false", @"\"6000000000\"",
            @"{}", @"[]", @"-1", @"-0.5", @"0.5", @"6000000000.5", @"9223372036854775808",
            @"18446744073709551617", @"18446744079709551616", @"1e100"] mutableCopy];
        if ([key isEqualToString:@"endDate"]) [invalidValues addObject:@"0"];
        for (NSString *value in invalidValues) {
            NSString *field = value.length ? [NSString stringWithFormat:@"\"%@\":%@,", key, value] : @"";
            NSString *other = [key isEqualToString:@"effectiveDuration"] ? @"\"endDate\":9223372036854775807" : @"\"effectiveDuration\":0";
            NSString *payload = [NSString stringWithFormat:
                @"3.0.0\n___boundary.info.date___\n{\"startDate\":1,%@%@}\n___boundary.info.date___\n", field, other];
            NSError *error = nil;
            XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
            XCTAssertNil([store readANRData], @"Invalid %@ must reject the v3 record: %@", key, value);
        }
    }
    [store deleteFile];
}
- (void)testV3PreservesExactEffectiveDurationAndEndTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSNumber *duration in @[@0LL, @1LL, @6000000000LL, @1780000000123456789LL, @9223372036854775806LL]) {
        long long end = duration.longLongValue + 1;
        NSString *payload = [NSString stringWithFormat:
            @"3.0.0\n___boundary.info.date___\n{\"startDate\":1,\"effectiveDuration\":%@,\"endDate\":%lld}\n___boundary.info.date___\n", duration, end];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
        FTLongTaskANRData *data = [store readANRData];
        XCTAssertNotNil(data);
        XCTAssertTrue(data.usesEffectiveDuration);
        XCTAssertEqual(data.startTimeNs, 1LL);
        XCTAssertEqual(data.durationNs, duration.longLongValue);
        XCTAssertEqual(data.endTimeNs, end);
        XCTAssertEqual(data.lastUpdateTimeNs, end);
    }
    [store deleteFile];
}
- (void)testOverflowingV3DurationCannotEmitHistoricalTelemetry {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTLongTaskANRDataStore *store = FTTestANRStore(manager);
    NSString *context = [FTJSONUtil convertToJsonDataWithObject:[[self.fatalErrorContext currentContextModel] toDictionary]];
    NSString *payload = [NSString stringWithFormat:
        @"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"effectiveDuration\":18446744079709551616,\"endDate\":61000000000,\"mainThreadBacktrace\":\"main\",\"errorContextModel\":%@}\n___boundary.info.date___\n", context];
    NSError *error = nil;
    XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
    __block NSUInteger writes = 0;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) { writes += 1; };
    self.lastFatalErrorDate = -1;
    [FTTestANRProcessor(manager) reportPreviousANRIfFound];
    dispatch_sync(store.queue, ^{});
    XCTAssertEqual(writes, 0U);
    XCTAssertEqual(self.assembledErrors, 0U);
    XCTAssertEqual(self.lastFatalErrorDate, 0LL);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
    self.writeCallBack = nil;
    [manager shutDown];
}
- (void)testPersistenceSnapshotsBeforeItsQueueIsDelayed {
    FTLongTaskANRDataStore *store=[self mockANRDataStore];
    dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
    dispatch_async(store.queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,DISPATCH_TIME_FOREVER);});
    XCTAssertEqual(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC)),0);
    FTLongTaskANRData *data=[[FTLongTaskANRData alloc]initWithStartTimeNs:NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration=YES;data.endTimeNs=61LL*NSEC_PER_SEC;
    [store writeANRData:data];
    data.durationNs=99LL*NSEC_PER_SEC;data.endTimeNs=100LL*NSEC_PER_SEC;data.usesEffectiveDuration=NO;
    dispatch_semaphore_signal(release);
    FTLongTaskANRData *saved=[store readANRData];
    XCTAssertTrue(saved.usesEffectiveDuration);
    XCTAssertEqual(saved.durationNs,3LL*NSEC_PER_SEC);
    XCTAssertEqual(saved.endTimeNs,61LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.reportedANRTimes = [NSMutableArray array];
}

- (void)tearDown {
    // File cleanup is asynchronous in production; tests explicitly drain its shared queue.
    FTLongTaskANRDataStore *store = [FTLongTaskANRDataStore new];
    dispatch_sync(store.queue, ^{});
}
- (FTLongTaskManager *)mockLongTaskManager{
    return [self mockLongTaskManagerWithBacktraceReporting:nil enableFreeze:YES];
}
- (FTLongTaskManager *)mockLongTaskManagerWithBacktraceReporting:(id<FTBacktraceReporting>)backtraceReporting enableFreeze:(BOOL)enableFreeze{
    return [self mockLongTaskManagerWithBacktraceReporting:backtraceReporting enableANR:YES enableFreeze:enableFreeze freezeDurationMs:250];
}
- (FTLongTaskManager *)mockLongTaskManagerWithBacktraceReporting:(id<FTBacktraceReporting>)backtraceReporting enableANR:(BOOL)enableANR enableFreeze:(BOOL)enableFreeze freezeDurationMs:(long)freezeDurationMs{
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.writer = self;
    dependencies.ignoreBackgroundLongTaskAndANR = self.ignoreBackgroundForTests;
    FTFatalErrorContext *errorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:nil];
    [errorContext setLastSessionState:[[FTRUMSessionState alloc] init]];
    self.fatalErrorContext = errorContext;
    dependencies.fatalErrorContext = errorContext;
    if (!backtraceReporting) {
        [FTCrash setupWithMonitoringType:FTCrashCMonitorTypeSystem writer:self enableMonitorMemory:YES enableMonitorCpu:YES];
        backtraceReporting = [FTCrash shared].backtraceReporting;
    }
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self backtraceReporting:backtraceReporting enableTrackAppANR:enableANR enableTrackAppFreeze:enableFreeze freezeDurationMs:freezeDurationMs];
    FTLongTaskDetector *detector = [longTaskManager valueForKey:@"longTaskDetector"];
    [detector stopDetecting];
    FTTestDrainDetector(detector);
    [FTTestANRStore(longTaskManager) deleteFile];
    return longTaskManager;
}
- (FTLongTaskANRDataStore *)mockANRDataStore{
    FTLongTaskANRDataStore *store = [[FTLongTaskANRDataStore alloc] init];
    [store deleteFile];
    return store;
}
- (void)testSnapshotAtomicallyReplacesPreviousRecord {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    data.durationNs = 5100*NSEC_PER_MSEC;
    data.endTimeNs = 8LL*NSEC_PER_SEC;
    [store writeANRData:data];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 5100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 8LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testLegacyV2RecoveryStillUsesLastTrailer {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    [@"2.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"duration\":3100000000}\n___boundary.info.date___\n4100000000\n6100000000\n" writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertFalse(saved.usesEffectiveDuration);
    XCTAssertEqual(saved.startTimeNs, NSEC_PER_SEC);
    XCTAssertEqual(saved.lastUpdateTimeNs, 6100*NSEC_PER_MSEC);
    [store deleteFile];
}
- (void)testDeleteFileFromAndOutsideStoreQueue {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSNumber *inside in @[@NO, @YES]) {
        [@"fixture" writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        if (inside.boolValue) dispatch_sync(store.queue, ^{ [store deleteFile]; });
        else [store deleteFile];
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
    }
}
- (void)testLongTask_start_update_end{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 251*NSEC_PER_MSEC, startTime + 251*NSEC_PER_MSEC);
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertTrue(slowStack != nil);
        XCTAssertEqual(duration, 1001*NSEC_PER_MSEC);
        hasCallBack = YES;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 1001*NSEC_PER_MSEC, startTime + 1001*NSEC_PER_MSEC);
    self.callBack = nil;
    XCTAssertTrue(hasCallBack);

    [longTaskManager shutDown];
}
- (void)testLongTask_updateRetriesAllThreadsBacktraceWhileBlocked{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    self.backtraceMock = backtraceMock;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3600000000LL, startTime + 3600000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    XCTAssertEqualObjects(reportedANRStack, backtraceMock.allThreadsBacktrace);
    self.callBack = nil;
    self.backtraceMock = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_firstANRDataWriteFallsBackToMainThreadBacktraceWhenAllThreadsMissing{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"mainThreadBacktrace"], backtraceMock.mainThreadBacktrace);
    XCTAssertFalse([dict.allKeys containsObject:@"allThreadsBacktrace"]);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    [longTaskManager shutDown];
}
- (void)testLongTask_firstANRDataWriteIncludesAllThreadsBacktraceWhenCaptured{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"allThreadsBacktrace"], backtraceMock.allThreadsBacktrace);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    [longTaskManager shutDown];
}
- (void)testLongTask_emptyAllThreadsBacktraceRetriesWhileBlocked{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3600000000LL, startTime + 3600000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(reportedANRStack, backtraceMock.mainThreadBacktrace);
    self.callBack = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_endAnrDoesNotGenerateRecoveredAllThreadsBacktrace{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"blockedAllThreadsBacktrace";
    self.backtraceMock = backtraceMock;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100*NSEC_PER_MSEC, startTime + 3100*NSEC_PER_MSEC);
    backtraceMock.allThreadsBacktrace = @"recoveredAllThreadsBacktrace";
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    XCTAssertEqualObjects(reportedANRStack, @"blockedAllThreadsBacktrace");
    self.callBack = nil;
    self.backtraceMock = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_completedANRIsNotReportedAgainWhenNextCycleCannotStart{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long completedANRTime = [NSDate ft_currentNanosecondTimeStamp] - 6LL * NSEC_PER_SEC;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, completedANRTime, 0, completedANRTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, completedANRTime, 5001*NSEC_PER_MSEC, completedANRTime + 5001*NSEC_PER_MSEC);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, completedANRTime, 6LL*NSEC_PER_SEC, completedANRTime + 6LL*NSEC_PER_SEC);

    [self.fatalErrorContext setLastSessionState:nil];
    long long nextStart = completedANRTime + 7LL*NSEC_PER_SEC;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, nextStart, 0, nextStart);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, nextStart, 251*NSEC_PER_MSEC, nextStart + 251*NSEC_PER_MSEC);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, nextStart, 300*NSEC_PER_MSEC, nextStart + 300*NSEC_PER_MSEC);

    XCTAssertEqualObjects(self.reportedANRTimes, (@[@(completedANRTime)]));
    [longTaskManager shutDown];
}
- (void)testLongTask_rewritesANRDataWhenAllThreadsBacktraceCapturedAfterInitialWrite{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3600000000LL, startTime + 3600000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"allThreadsBacktrace"], @"allThreadsBacktrace\nThread 1:");
    FTLongTaskANRData *anrData = [FTTestANRStore(longTaskManager) readANRData];
    XCTAssertEqual(anrData.lastUpdateTimeNs, startTime + 3600000000LL);
    [longTaskManager shutDown];
}
- (void)testLongTask_reportFatalANRDataIfFound{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
        FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 5100000000LL, startTime + 5100000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    __block BOOL hasCallBack = NO;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) {
        XCTAssertTrue(fields[FT_KEY_LONG_TASK_STACK]);
        hasCallBack = YES;
    };
    XCTAssertNoThrow([FTTestANRProcessor(longTaskManager) reportPreviousANRIfFound]);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    XCTAssertTrue(hasCallBack);
    [longTaskManager shutDown];
}
- (void)testLongTask_reportPreviousANRDeletesMalformedANRDataAndNotifiesNoFatal{
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    [@"broken ANR data" writeToFile:FTTestANRStore(longTaskManager).dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    self.lastFatalErrorDate = -1;
    [FTTestANRProcessor(longTaskManager) reportPreviousANRIfFound];
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    XCTAssertTrue(data.length == 0);
    XCTAssertEqual(self.lastFatalErrorDate, 0);
    [longTaskManager shutDown];
}
- (void)testLongTask_freezeOnlyDoesNotWriteANRDataButReportsFreeze{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableANR:NO enableFreeze:YES freezeDurationMs:250];
    NSString *dataStorePath = FTTestANRStore(longTaskManager).dataStorePath;
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - NSEC_PER_SEC;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 251*NSEC_PER_MSEC, startTime + 251*NSEC_PER_MSEC);
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertEqualObjects(slowStack, @"mainThreadBacktrace");
        XCTAssertTrue(duration > 250 * NSEC_PER_MSEC);
        hasCallBack = YES;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data.length == 0);
    XCTAssertTrue(hasCallBack);
    self.callBack = nil;
    [longTaskManager shutDown];
}
- (void)testShutdownDoesNotWaitForDetectorOrFileQueue {
    for (NSNumber *blockDetector in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTLongTaskDetector *detector = [manager valueForKey:@"longTaskDetector"];
        dispatch_queue_t queue = blockDetector.boolValue ? [detector valueForKey:@"longTaskQueue"] : FTTestANRStore(manager).queue;
        dispatch_semaphore_t entered = dispatch_semaphore_create(0);
        dispatch_semaphore_t release = dispatch_semaphore_create(0);
        dispatch_semaphore_t returned = dispatch_semaphore_create(0);
        dispatch_async(queue, ^{
            dispatch_semaphore_signal(entered);
            dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
        });
        XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [manager shutDown];
            dispatch_semaphore_signal(returned);
        });
        long result = dispatch_semaphore_wait(returned, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
        dispatch_semaphore_signal(release); // Always unblock cleanup, including on assertion failure.
        XCTAssertEqual(result, 0L, @"shutdown must return while the target queue is still blocked");
        FTTestDrainDetector(detector);
        dispatch_sync(FTTestANRStore(manager).queue, ^{});
        XCTAssertTrue(FTTestANRStore(manager).isClosed);
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:FTTestANRStore(manager).dataStorePath]);
    }
}
- (void)testShutdownFromHistoricalProviderReturnsAndSuppressesLateError {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
    __block NSUInteger calls = 0;
    dependencies.issueDataProvider = ^NSDictionary *(FTIssueInfo *issue) {
        calls += 1;
        [manager shutDown];
        return @{};
    };
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:6LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:self.fatalErrorContext.currentContextModel];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 7LL*NSEC_PER_SEC;
    [FTTestANRStore(manager) writeANRData:data];
    self.lastFatalErrorDate = -1;
    [FTTestANRProcessor(manager) reportPreviousANRIfFound];
    dispatch_sync(FTTestANRStore(manager).queue, ^{});
    XCTAssertEqual(calls, 1U);
    XCTAssertEqual(self.assembledErrors, 0U);
    XCTAssertEqual(self.lastFatalErrorDate, -1LL);
    XCTAssertTrue(FTTestANRStore(manager).isClosed);
    dependencies.issueDataProvider = nil;
}
- (void)testShutdownCancelsQueuedHistoricalProcessing {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
    __block NSUInteger calls = 0;
    dependencies.issueDataProvider = ^NSDictionary *(FTIssueInfo *issue) { calls += 1; return @{}; };
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:6LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:self.fatalErrorContext.currentContextModel];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 7LL*NSEC_PER_SEC;
    [FTTestANRStore(manager) writeANRData:data];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0);
    dispatch_async(FTTestANRStore(manager).queue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
    });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    [FTTestANRProcessor(manager) reportPreviousANRIfFound];
    [manager shutDown];
    dispatch_semaphore_signal(release);
    dispatch_sync(FTTestANRStore(manager).queue, ^{});
    XCTAssertEqual(calls, 0U);
    dependencies.issueDataProvider = nil;
}
- (void)testOldStoreCannotOverwriteOrDeleteNewStoreData {
    FTLongTaskANRDataStore *oldStore = [self mockANRDataStore];
    FTLongTaskANRDataStore *newStore = [FTLongTaskANRDataStore new];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0);
    dispatch_async(oldStore.queue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
    });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"old" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 5LL*NSEC_PER_SEC;
    [oldStore writeANRData:data];
    [oldStore shutDown];
    data.startTimeNs = 10LL*NSEC_PER_SEC;
    data.durationNs = 5100*NSEC_PER_MSEC;
    data.endTimeNs = 17LL*NSEC_PER_SEC;
    [newStore writeANRData:data];
    [newStore appendTimingWithStartTimeNs:10LL*NSEC_PER_SEC durationNs:6100*NSEC_PER_MSEC endTimeNs:19LL*NSEC_PER_SEC];
    [oldStore writeANRData:data]; // A late write and duplicate shutdown must have no effect.
    [oldStore appendTimingWithStartTimeNs:10LL*NSEC_PER_SEC durationNs:9100*NSEC_PER_MSEC endTimeNs:99LL*NSEC_PER_SEC];
    [oldStore deleteFile];
    [oldStore shutDown];
    dispatch_semaphore_signal(release);
    FTLongTaskANRData *saved = [newStore readANRData];
    XCTAssertEqual(saved.startTimeNs, 10LL*NSEC_PER_SEC);
    XCTAssertEqual(saved.durationNs, 6100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 19LL*NSEC_PER_SEC);
    [newStore deleteFile];
}
- (void)testShutdownDuringCaptureCannotPersistOrReport {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    __block NSUInteger freezes = 0;
    self.callBack = ^(NSString *stack, long long duration) { freezes += 1; };
    self.backtraceMock.onAllThreads = ^{ [manager shutDown]; };
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
    dispatch_sync(FTTestANRStore(manager).queue, ^{});
    XCTAssertEqual(freezes, 0U);
    XCTAssertEqual(self.reportedANRTimes.count, 0U);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:FTTestANRStore(manager).dataStorePath]);
    self.backtraceMock.onAllThreads = nil;
    self.callBack = nil;
}
- (void)testFreezeThresholdCheckpointsAreSelectedByManager {
    NSDictionary<NSNumber *, NSNumber *> *checkpoints = @{@250: @251, @300: @301, @6000: @6001};
    for (NSNumber *threshold in checkpoints) {
        FTLongTaskManager *manager = [self timingManagerANR:NO freeze:YES threshold:threshold.longValue];
        uint64_t checkpoint = [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        XCTAssertEqual(checkpoint, checkpoints[threshold].unsignedLongLongValue * NSEC_PER_MSEC);
        [manager shutDown];
    }
}
- (void)testLongTaskDetector_runLoopCallbackDoesNotWaitForStalledSnapshotReader {
    FTLongTaskDetectorDelegateMock *delegate = [[FTLongTaskDetectorDelegateMock alloc] init];
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:delegate];
    Ivar lockIvar = class_getInstanceVariable(FTLongTaskDetector.class, "_runLoopLock");
    os_unfair_lock *oldSnapshotLock = lockIvar ? (os_unfair_lock *)((uint8_t *)(__bridge void *)detector + ivar_getOffset(lockIvar)) : NULL;
    if (oldSnapshotLock) {
        // Simulate the detector being suspended while it owns the snapshot lock.
        os_unfair_lock_lock(oldSnapshotLock);
    }

    dispatch_semaphore_t callbackDone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [detector recordRunLoopBeginActivity:kCFRunLoopBeforeSources atTimeNs:1000LL * NSEC_PER_MSEC];
        dispatch_semaphore_signal(callbackDone);
    });
    long callbackResult = dispatch_semaphore_wait(callbackDone, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
    if (oldSnapshotLock) {
        os_unfair_lock_unlock(oldSnapshotLock);
    }
    if (callbackResult != 0) {
        dispatch_semaphore_wait(callbackDone, DISPATCH_TIME_FOREVER);
    }
    XCTAssertEqual(callbackResult, 0, @"RunLoop callback must not wait for a stalled detector thread");
}
- (void)testLongTaskDetector_runLoopReadKeepsCallbackFieldsTogether {
    FTLongTaskDetectorDelegateMock *delegate = [[FTLongTaskDetectorDelegateMock alloc] init];
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:delegate];
    dispatch_semaphore_t writerDone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (uint64_t generation = 1; generation <= 5000; generation++) {
            if (generation & 1)
                [detector recordRunLoopEndActivity:kCFRunLoopBeforeWaiting atTimeNs:(long long)generation * NSEC_PER_MSEC];
            else
                [detector recordRunLoopBeginActivity:kCFRunLoopAfterWaiting atTimeNs:(long long)generation * NSEC_PER_MSEC];
        }
        dispatch_semaphore_signal(writerDone);
    });

    BOOL consistent = YES;
    for (NSUInteger attempt = 0; attempt < 10000; attempt++) {
        FTLongTaskRunLoopSnapshot snapshot;
        if (![detector readRunLoopSnapshot:&snapshot] || snapshot.sequence == 0) {
            continue;
        }
        uint64_t generation = snapshot.sequence / 2;
        BOOL expectedRunning = !(generation & 1);
        if (snapshot.running != expectedRunning || snapshot.startTimeNs != (long long)generation * NSEC_PER_MSEC) {
            consistent = NO;
            break;
        }
    }
    XCTAssertEqual(dispatch_semaphore_wait(writerDone, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0);
    FTLongTaskRunLoopSnapshot finalSnapshot;
    BOOL finalReadValid = [detector readRunLoopSnapshot:&finalSnapshot];
    XCTAssertTrue(finalReadValid);
    if (finalReadValid) {
        XCTAssertEqual(finalSnapshot.sequence / 2, 5000);
        XCTAssertEqual(finalSnapshot.startTimeNs, 5000LL * NSEC_PER_MSEC);
        XCTAssertTrue(finalSnapshot.running);
    }
    XCTAssertTrue(consistent);
}
-(void)testLongTaskFilePath{
#if TARGET_OS_TV
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#elif TARGET_OS_IOS
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
#else
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
#endif
    pathString = [pathString stringByAppendingPathComponent:@"com.ft.sdk"];
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.fatalErrorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:nil];
    [dependencies.fatalErrorContext setLastSessionState:[[FTRUMSessionState alloc] init]];
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self backtraceReporting:[FTCrash shared].backtraceReporting enableTrackAppANR:NO enableTrackAppFreeze:NO freezeDurationMs:250];
    NSString *path = FTTestANRStore(longTaskManager).dataStorePath;
    
    XCTAssertTrue([pathString isEqualToString:[path stringByDeletingLastPathComponent]]);
    [longTaskManager shutDown];
}
- (void)recordStack:(NSString *)slowStack duration:(long long)duration {
    if(self.callBack){
        self.callBack(slowStack, duration);
    }
}
- (void)longTaskDetected:(FTLongTaskEvent *)event {
    self.observedLongTask = event;
    self.observedEndTimeNs=event.endTimeNs;
    [self recordStack:event.stack duration:event.durationNs];
}
-(void)anrStackDetected:(NSString *)slowStack time:(NSDate *)time{
    if(self.callBack){
        self.callBack(slowStack, 0);
    }
}
-(void)anrStackDetected:(NSString *)slowStack appState:(NSString *)appState intervalAppState:(NSString *)intervalAppState time:(long long)time{
    self.observedANRSituation = appState;
    self.observedANRIntervalState = intervalAppState;
    [self.reportedANRTimes addObject:@(time)];
    if(self.callBack){
        self.callBack(slowStack, 0);
    }
}
-(void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time{
    self.totalRUMWrites++;
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}
-(void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache{
    self.totalRUMWrites++;
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}
-(void)lastFatalErrorIfFound:(long long)errorDate{
    self.lastFatalErrorDate = errorDate;
}

- (void)rumWrite:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime {
    
}


- (void)rumWriteAssembledData:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields time:(long long)time {
    if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
        self.assembledErrors += 1;
        self.recoveredErrorTags = tags;
        self.recoveredErrorFields = fields;
    }
    self.totalRUMWrites++;
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}

@end
