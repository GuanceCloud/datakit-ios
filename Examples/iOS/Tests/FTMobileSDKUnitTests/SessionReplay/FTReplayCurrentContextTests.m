//
//  FTReplayCurrentContextTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/9/14.
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

#import <XCTest/XCTest.h>
#import "FTRUMManager.h"
#import "FTRUMDependencies.h"
#import "FTRUMSessionHandler.h"
#import "FTRUMContext.h"
#import "FTModuleManager.h"
#import "FTGlobalRumManager+Private.h"
#import "FTSessionReplayFeature.h"
#import "FTRecordingCoordinator.h"
#import "FTSessionReplayConfig.h"
#import "FTScheduler.h"
#import "FTRecorder.h"
#import "FTViewAttributes.h"
#import "FTConstants.h"

@interface FTModuleManager (ReplayTestDrain)
- (void)syncProcess;
@end
@interface FTRUMManager (ReplayTestLifecycle)
- (void)shutDown;
@end

// No timer or run-loop sleeps: tests explicitly drain each domain and trigger capture.
@interface FTReplayTestQueue : NSObject <FTQueue>
@property (nonatomic, strong) NSMutableArray *blocks;
- (void)drain;
@end
@implementation FTReplayTestQueue
- (instancetype)init { if ((self = [super init])) _blocks = [NSMutableArray new]; return self; }
- (void)run:(dispatch_block_t)block { @synchronized (self) { [self.blocks addObject:[block copy]]; } }
- (void)drain {
    while (YES) {
        dispatch_block_t block;
        @synchronized (self) {
            if (!self.blocks.count) break;
            block = self.blocks.firstObject;
            [self.blocks removeObjectAtIndex:0];
        }
        block();
    }
}
@end
@interface FTReplayTestScheduler : NSObject <FTScheduler>
@property (nonatomic, strong) FTReplayTestQueue *queue;
@property (nonatomic, copy) dispatch_block_t capture;
@property (nonatomic, assign) BOOL running;
@end
@implementation FTReplayTestScheduler
- (instancetype)init { if ((self = [super init])) _queue = [FTReplayTestQueue new]; return self; }
- (void)scheduleWithOperation:(dispatch_block_t)operation {
    __weak typeof(self) weakSelf = self;
    self.capture = ^{ if (weakSelf.running) operation(); };
}
- (void)start { self.running = YES; }
- (void)stop { self.running = NO; }
@end
@interface FTReplayContextRecorder : FTRecorder
@property (nonatomic, strong) NSMutableArray<FTSRContext *> *captures;
@end
@implementation FTReplayContextRecorder
- (instancetype)init { if ((self = [super init])) _captures = [NSMutableArray new]; return self; }
- (void)taskSnapShot:(FTSRContext *)context touchSnapshot:(FTTouchSnapshot *)touchSnapshot { [self.captures addObject:context]; }
- (void)forceFullSnapshot {}
@end

@interface FTReplayCurrentContextTests : XCTestCase
@property (nonatomic, strong) FTRUMManager *rum;
@property (nonatomic, strong) FTSessionReplayFeature *feature;
@property (nonatomic, strong) FTRecordingCoordinator *coordinator;
@property (nonatomic, strong) FTReplayTestScheduler *scheduler;
@property (nonatomic, strong) FTReplayContextRecorder *recorder;
@end
@implementation FTReplayCurrentContextTests
- (void)setUp {
    [super setUp];
    self.rum = [self newRUM:@"app-A"];
    [self drainRUM];
}
- (FTRUMManager *)newRUM:(NSString *)appID {
    FTRUMDependencies *dependencies = [FTRUMDependencies new];
    dependencies.appId = appID;
    dependencies.sampleRate = 100;
    return [[FTRUMManager alloc] initWithRumDependencies:dependencies];
}
- (void)tearDown {
    [self.feature shutDown];
    [self.scheduler.queue drain];
    if ([self.rum respondsToSelector:@selector(shutDown)]) [self.rum shutDown];
    self.feature = nil;
    self.coordinator = nil;
    self.rum = nil;
    [[FTModuleManager sharedInstance] syncProcess];
    [super tearDown];
}
- (void)drainRUM {
    // Requests enter rumQueue from the bus; their replies return to the bus.
    [[FTModuleManager sharedInstance] syncProcess];
    [self.rum syncProcess];
    [[FTModuleManager sharedInstance] syncProcess];
}
- (void)makeReplay {
    [self makeReplayWithConfig:[FTSessionReplayConfig new]];
}
- (void)makeReplayWithConfig:(FTSessionReplayConfig *)config {
    config.enableLinkRUMKeys = @[@"team"];
    self.feature = [[FTSessionReplayFeature alloc] initWithConfig:config];
    self.coordinator = [self.feature valueForKey:@"recordingCoordinator"];
    self.scheduler = [FTReplayTestScheduler new];
    self.coordinator.scheduler = self.scheduler;
    self.recorder = [FTReplayContextRecorder new];
    self.coordinator.recorder = self.recorder;
}
- (NSDictionary *)linkedContext {
    __block NSDictionary *context;
    [self.rum getLinkRUMDataWithCompletion:^(NSDictionary *value) { context = [value copy]; }];
    [self.rum syncProcess];
    return context;
}
- (NSDictionary *)contextFromModule:(FTModuleManager *)modules {
    __block NSDictionary *context;
    [modules rumContextWithCompletion:^(NSDictionary *value) { context = value; }];
    [modules syncProcess];
    return context;
}
- (NSDictionary *)coreContext {
    return [self contextFromModule:[FTModuleManager sharedInstance]];
}
- (void)testDelayedReplayCapturesExistingViewWithoutAnotherRUMEvent {
    [self.rum startViewWithName:@"existing" property:@{@"team":@"ios"}];
    [self drainRUM]; // No receiver exists when the original View notification is delivered.
    NSDictionary *expected = [self linkedContext];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    FTSRContext *capture = self.recorder.captures.firstObject;
    XCTAssertEqualObjects(capture.applicationID, @"app-A");
    XCTAssertEqualObjects(capture.sessionID, expected[FT_RUM_KEY_SESSION_ID]);
    XCTAssertEqualObjects(capture.viewID, expected[FT_KEY_VIEW_ID]);
    XCTAssertEqualObjects(capture.viewPath, @"existing");
    XCTAssertEqualObjects(capture.bindInfo[@"team"], @"ios");
}
- (void)testStoppedViewWithPendingResourceCannotBeRecordedAndNewViewResumes {
    [self.rum startViewWithName:@"old"];
    [self.rum startResourceWithKey:@"pending"];
    [self.rum stopView];
    [self drainRUM];
    FTRUMSessionHandler *session = [self.rum valueForKey:@"sessionHandler"];
    NSArray *retainedViews = [session valueForKey:@"viewHandlers"];
    XCTAssertEqual(retainedViews.count, 1); // Pending Resource keeps the stopped handler alive.
    XCTAssertFalse([[retainedViews.lastObject valueForKey:@"isActiveView"] boolValue]);
    XCTAssertEqualObjects([self linkedContext], [session.context getGlobalSessionTags]);
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 0);
    XCTAssertNil(self.coordinator.currentRUMContext[FT_KEY_VIEW_ID]);
    [self.rum startViewWithName:@"new"];
    [self drainRUM];
    NSDictionary *expected = [self linkedContext];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    XCTAssertEqualObjects(self.recorder.captures.firstObject.viewID, expected[FT_KEY_VIEW_ID]);
}

- (void)testNoViewHasSessionOnlyAndBeginsOnFirstRealView {
    NSDictionary *session = [self linkedContext];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_APP_ID], @"app-A");
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_RUM_KEY_SESSION_ID], session[FT_RUM_KEY_SESSION_ID]);
    XCTAssertNil(self.coordinator.currentRUMContext[FT_KEY_VIEW_ID]);
    XCTAssertEqual(self.recorder.captures.count, 0);
    [self.rum startViewWithName:@"first"];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    XCTAssertEqualObjects(self.recorder.captures.firstObject.viewPath, @"first");
}
- (void)testRepeatedStartRefreshesContextWithoutResamplingSession {
    [self.rum startViewWithName:@"existing"];
    [self drainRUM];
    NSDictionary *expected = [self linkedContext];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    // Deliberately change the decision: a repeated sampling calculation at 100% would replace it.
    [self.coordinator setSampleState:FTRecordingSampleStateError];
    [self.coordinator setValue:@{@"team":@"stale"} forKey:@"bindInfo"];
    NSMutableDictionary *stale = [self.coordinator.currentRUMContext mutableCopy];
    stale[FT_KEY_VIEW_NAME] = @"missed-update";
    [self.coordinator setValue:[stale copy] forKey:@"currentRUMContext"];
    [self.feature startRecording];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    XCTAssertEqual(self.coordinator.sampleState, FTRecordingSampleStateError);
    XCTAssertNil([self.coordinator valueForKey:@"bindInfo"][@"team"]);
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_KEY_VIEW_ID], expected[FT_KEY_VIEW_ID]);
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
}
- (void)testMissingBindingsAndStoppedViewClearPreviouslyLinkedFields {
    [self.rum startViewWithName:@"first" property:@{@"team":@"ios"}];
    [self drainRUM];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqualObjects(self.recorder.captures.lastObject.bindInfo[@"team"], @"ios");
    [self.rum startViewWithName:@"second"];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertNil(self.recorder.captures.lastObject.bindInfo[@"team"]);
    [self.rum startResourceWithKey:@"keep-second-alive"];
    [self.rum stopView];
    [self drainRUM];
    [self.scheduler.queue drain];
    XCTAssertNil(self.coordinator.currentRUMContext[FT_KEY_VIEW_ID]);
    XCTAssertNil(self.coordinator.currentRUMContext[FT_KEY_VIEW_NAME]);
    XCTAssertNil(self.coordinator.currentRUMContext[FT_KEY_ACTION_ID]);
    XCTAssertNil(self.coordinator.currentRUMContext[FT_LINK_RUM_KEYS]);
    XCTAssertNil([self.coordinator valueForKey:@"bindInfo"]);
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 2);
}
- (void)testDelayedRequestAndSchedulerPreserveNewerViewOrdering {
    [self.rum startViewWithName:@"A"];
    [self drainRUM];
    [self makeReplay];
    dispatch_queue_t rumQueue = [self.rum valueForKey:@"rumQueue"];
    dispatch_suspend(rumQueue);
    [self.feature startRecording];
    [[FTModuleManager sharedInstance] syncProcess]; // Core read sees A before the queued View B is processed.
    [self.rum startViewWithName:@"B"];
    dispatch_resume(rumQueue);
    [self drainRUM];
    NSDictionary *expected = [self linkedContext];
    // Both A's cached context and B's live update are pending on the scheduler.
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    XCTAssertEqualObjects(self.recorder.captures.firstObject.viewPath, @"B");
    XCTAssertEqualObjects(self.recorder.captures.firstObject.viewID, expected[FT_KEY_VIEW_ID]);
}
- (void)testShutdownBeforeDelayedCoreReadCannotReviveReplay {
    [self.rum startViewWithName:@"old"];
    [self drainRUM];
    [self makeReplay];
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    [[FTModuleManager sharedInstance] postMessageWithKey:@"test-only" messageBlock:^NSDictionary *{
        dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
        return nil;
    }];
    [self.feature startRecording];
    [self.feature shutDown];
    dispatch_semaphore_signal(gate);
    [[FTModuleManager sharedInstance] syncProcess];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertTrue(self.coordinator.invalidated);
    XCTAssertNil(self.coordinator.currentRUMContext);
    XCTAssertEqual(self.recorder.captures.count, 0);
}
- (void)testShutdownBeforeDelayedSchedulerDeliveryCannotReviveReplay {
    [self.rum startViewWithName:@"old"];
    [self drainRUM];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM]; // Context already handed to scheduler, shutdown must still reject it.
    [self.feature shutDown];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertNil(self.coordinator.currentRUMContext);
    XCTAssertEqual(self.recorder.captures.count, 0);
}
- (void)testMissingSourceClearsContextOnRepeatedStart {
    [self.rum startViewWithName:@"old"];
    [self drainRUM];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    XCTAssertNotNil(self.coordinator.currentRUMContext[FT_KEY_VIEW_ID]);
    [self.rum shutDown];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqualObjects(self.coordinator.currentRUMContext, @{});
    XCTAssertEqual(self.coordinator.sampleState, FTRecordingSampleStateNone);
    XCTAssertEqual(self.recorder.captures.count, 0);
}
- (void)testRebuildWithRetainedOldRUMAndDelayedCallbacksUsesNewApplicationAndSession {
    [self.rum startViewWithName:@"old"];
    [self drainRUM];
    FTRUMManager *oldRUM = self.rum;
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM]; // Old context is pending in old scheduler.
    FTRecordingCoordinator *oldCoordinator = self.coordinator;
    FTReplayTestScheduler *oldScheduler = self.scheduler;
    [self.feature shutDown];
    [oldRUM shutDown];
    self.rum = [self newRUM:@"app-B"];
    [self drainRUM];
    NSDictionary *newSession = [self linkedContext];
    [self makeReplay];
    [self.feature startRecording];
    // A stale caller still retaining old RUM must not publish after replacement.
    [oldRUM startViewWithName:@"late-old"];
    [oldRUM syncProcess];
    [oldRUM shutDown]; // Must not unregister the new instance.
    [self drainRUM];
    [oldScheduler.queue drain];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertNil(oldCoordinator.currentRUMContext);
    XCTAssertEqual(self.recorder.captures.count, 0);
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_APP_ID], @"app-B");
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_RUM_KEY_SESSION_ID], newSession[FT_RUM_KEY_SESSION_ID]);
    [self.rum startViewWithName:@"fresh"];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    XCTAssertEqualObjects(self.recorder.captures.firstObject.applicationID, @"app-B");
    XCTAssertEqualObjects(self.recorder.captures.firstObject.sessionID, newSession[FT_RUM_KEY_SESSION_ID]);
    XCTAssertEqualObjects(self.recorder.captures.firstObject.viewPath, @"fresh");
}
- (void)testReplacedSourceDropsSnapshotAlreadyQueuedOnMessageBus {
    [self.rum startViewWithName:@"old"];
    [self drainRUM];
    FTRUMManager *oldRUM = self.rum;
    self.rum = [self newRUM:@"app-B"];
    [self drainRUM];
    NSDictionary *expected = [self coreContext];
    [self makeReplay];
    FTModuleManager *modules = [FTModuleManager sharedInstance];
    [modules syncProcess];
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    [modules postMessageWithKey:@"test-only" messageBlock:^NSDictionary *{
        dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
        return nil;
    }];
    [oldRUM startViewWithName:@"late-old"];
    [oldRUM syncProcess]; // A stale source publication is now queued behind the gate.
    dispatch_semaphore_signal(gate);
    [modules syncProcess];
    [self.scheduler.queue drain];
    XCTAssertNil(self.coordinator.currentRUMContext);
    [oldRUM shutDown];
    XCTAssertEqualObjects([self coreContext], expected);
    XCTAssertEqualObjects(expected[FT_APP_ID], @"app-B");
}
- (void)testGlobalRUMShutdownClearsCoreContextEvenWithRetainedManager {
    [self.rum startViewWithName:@"old"];
    [self drainRUM];
    XCTAssertEqualObjects([self coreContext][FT_KEY_VIEW_NAME], @"old");
    FTGlobalRumManager *global = [FTGlobalRumManager sharedInstance];
    global.rumManager = self.rum;
    [global shutDown];
    XCTAssertEqualObjects([self coreContext], @{});
}
- (void)testSamplingAndExternalOwnershipStillGateCaptures {
    [self.rum startViewWithName:@"existing"];
    [self drainRUM];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    [self.coordinator setSampleState:FTRecordingSampleStateNone];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 0);
    [self.coordinator setSampleState:FTRecordingSampleStateNormal];
    [self.coordinator setExternalRecorderActive:YES forOwner:@"test-engine"];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 0);
    [self.coordinator setExternalRecorderActive:NO forOwner:@"test-engine"];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
}

- (void)testStartupIncludesErrorSamplingStateFromCurrentSession {
    [self.rum startViewWithName:@"error-session"];
    [self drainRUM];
    dispatch_sync([self.rum valueForKey:@"rumQueue"], ^{
        FTRUMSessionHandler *session = [self.rum valueForKey:@"sessionHandler"];
        session.context.sessionState.sampled_for_error_session = YES;
    });
    [self.rum startAction:@"context-update" actionType:@"custom" property:nil];
    [self drainRUM];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION], @YES);
    XCTAssertEqual(self.coordinator.sampleState, FTRecordingSampleStateError);
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
}

- (void)testStartupWithZeroSamplingCannotCaptureExistingView {
    [self.rum startViewWithName:@"existing"];
    [self drainRUM];
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.sessionReplaySamplingRate = 0;
    config.sessionReplayOnErrorSamplingRate = 0;
    [self makeReplayWithConfig:config];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    XCTAssertEqual(self.coordinator.sampleState, FTRecordingSampleStateNone);
    XCTAssertEqualObjects(self.coordinator.currentRUMContext[FT_KEY_VIEW_NAME], @"existing");
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 0);
}
- (void)testBindingsAreOwnedBeforeCrossingQueues {
    [self.rum startViewWithName:@"existing"];
    [self drainRUM];
    NSMutableArray *values = [NSMutableArray arrayWithObject:@"before"];
    NSMutableDictionary *binding = [@{@"team":values} mutableCopy];
    NSMutableDictionary *published = [[self coreContext] mutableCopy];
    published[FT_LINK_RUM_KEYS] = binding;
    [[FTModuleManager sharedInstance] postRUMContext:published source:self.rum];
    [[FTModuleManager sharedInstance] syncProcess];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [values addObject:@"after"];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    XCTAssertEqualObjects(self.recorder.captures.firstObject.bindInfo[@"team"], @[@"before"]);
}

- (void)testBindingSnapshotPreservesNumericTypes {
    [self.rum startViewWithName:@"existing"];
    [self drainRUM];
    NSMutableDictionary *published = [[self coreContext] mutableCopy];
    published[FT_LINK_RUM_KEYS] = @{@"team":@1.25};
    [[FTModuleManager sharedInstance] postRUMContext:published source:self.rum];
    [[FTModuleManager sharedInstance] syncProcess];
    [self makeReplay];
    [self.feature startRecording];
    [self drainRUM];
    [self.scheduler.queue drain];
    self.scheduler.capture();
    XCTAssertEqual(self.recorder.captures.count, 1);
    id value = self.recorder.captures.firstObject.bindInfo[@"team"];
    XCTAssertTrue([value isKindOfClass:NSNumber.class]);
    XCTAssertEqualObjects(value, @1.25);
}

- (void)testStartRecordingReadsCoreMemoryWhileRUMQueueIsBlocked {
    [self.rum startViewWithName:@"already-published"];
    [self drainRUM];
    NSDictionary *expected = [self linkedContext];
    [self makeReplay];
    dispatch_queue_t rumQueue = [self.rum valueForKey:@"rumQueue"];
    dispatch_suspend(rumQueue);
    @try {
        [self.feature startRecording];
        [[FTModuleManager sharedInstance] syncProcess];
        [self.scheduler.queue drain];
        self.scheduler.capture();
        XCTAssertEqual(self.recorder.captures.count, 1);
        XCTAssertEqualObjects(self.recorder.captures.firstObject.applicationID, @"app-A");
        XCTAssertEqualObjects(self.recorder.captures.firstObject.sessionID, expected[FT_RUM_KEY_SESSION_ID]);
        XCTAssertEqualObjects(self.recorder.captures.firstObject.viewID, expected[FT_KEY_VIEW_ID]);
    } @finally {
        dispatch_resume(rumQueue);
    }
}

- (void)testCoreContextCallbackIsAsynchronousWithoutRUMProvider {
    FTModuleManager *modules = [FTModuleManager new];
    [modules registerRUMContextSource:self]; // Plain identity object, not a RUM provider.
    NSDictionary *expected = @{FT_APP_ID:@"app-unit", FT_RUM_KEY_SESSION_ID:@"session-unit", FT_KEY_VIEW_ID:@"view-unit"};
    [modules postRUMContext:expected source:self];
    XCTestExpectation *read = [self expectationWithDescription:@"Core context callback"];
    [modules postMessageWithKey:@"test-only" messageBlock:^NSDictionary *{
        __block BOOL callerReturned = NO;
        [modules rumContextWithCompletion:^(NSDictionary *context) {
            XCTAssertTrue(callerReturned);
            XCTAssertEqualObjects(context, expected);
            [read fulfill];
        }];
        callerReturned = YES;
        return nil;
    }];
    [self waitForExpectations:@[read] timeout:2];
}
- (void)testCoreMemoryReadsAndUpdatesRemainFIFO {
    FTModuleManager *modules = [FTModuleManager new];
    [modules registerRUMContextSource:self];
    NSDictionary *first = @{FT_APP_ID:@"app-unit", FT_KEY_VIEW_ID:@"A"};
    NSDictionary *second = @{FT_APP_ID:@"app-unit", FT_KEY_VIEW_ID:@"B"};
    NSMutableArray *reads = [NSMutableArray new];
    [modules postRUMContext:first source:self];
    [modules rumContextWithCompletion:^(NSDictionary *context) { [reads addObject:context]; }];
    [modules postRUMContext:second source:self];
    [modules rumContextWithCompletion:^(NSDictionary *context) { [reads addObject:context]; }];
    [modules syncProcess];
    XCTAssertEqualObjects(reads, (@[first, second]));
}
- (void)testCoreSnapshotOwnsNestedValuesBeforeBusDelivery {
    FTModuleManager *modules = [FTModuleManager new];
    [modules registerRUMContextSource:self];
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    [modules postMessageWithKey:@"test-only" messageBlock:^NSDictionary *{
        dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
        return nil;
    }];
    NSMutableString *name = [@"before" mutableCopy];
    NSMutableArray *values = [NSMutableArray arrayWithArray:@[@1.25, @YES, NSNull.null]];
    NSMutableDictionary *bindings = [@{@"name":name, @"values":values} mutableCopy];
    NSMutableDictionary *context = [@{FT_APP_ID:@"app-unit", FT_LINK_RUM_KEYS:bindings} mutableCopy];
    [modules postRUMContext:context source:self];
    [name setString:@"after"];
    [values addObject:@"after"];
    context[FT_APP_ID] = @"changed";
    dispatch_semaphore_signal(gate);
    NSDictionary *expected = @{FT_APP_ID:@"app-unit", FT_LINK_RUM_KEYS:@{@"name":@"before", @"values":@[@1.25, @YES, NSNull.null]}};
    XCTAssertEqualObjects([self contextFromModule:modules], expected);
}
- (void)testNewCoreSourceStartsEmptyAndRejectsOldPublications {
    FTModuleManager *modules = [FTModuleManager new];
    NSObject *replacement = [NSObject new];
    NSDictionary *first = @{FT_APP_ID:@"app-A", FT_KEY_VIEW_ID:@"old-view"};
    NSDictionary *second = @{FT_APP_ID:@"app-B", FT_KEY_VIEW_ID:@"new-view"};
    [modules registerRUMContextSource:self];
    [modules postRUMContext:first source:self];
    XCTAssertEqualObjects([self contextFromModule:modules], first);
    [modules registerRUMContextSource:replacement];
    XCTAssertEqualObjects([self contextFromModule:modules], @{});
    [modules postRUMContext:first source:self];
    XCTAssertEqualObjects([self contextFromModule:modules], @{});
    [modules postRUMContext:second source:replacement];
    [modules unregisterRUMContextSource:self]; // Late old shutdown cannot clear the new source.
    XCTAssertEqualObjects([self contextFromModule:modules], second);
    [modules unregisterRUMContextSource:replacement];
    XCTAssertEqualObjects([self contextFromModule:modules], @{});
}
@end
