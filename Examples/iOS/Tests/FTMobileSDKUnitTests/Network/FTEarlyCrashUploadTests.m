//
//  FTEarlyCrashUploadTests.m
//  FTMobileSDK
//
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
#import "FTDataUploadWorker.h"
#import "FTEarlyCrash.h"
#import "FTCrashMonitor_AppState.h"
#import "FTRecordModel.h"
#import "FTTrackerEventDBTool.h"
#import "FTNetworkConnectivity.h"
#import "FTNetworkInfoManager.h"
#import "FTTrackDataManager.h"
#import "FTHTTPClient.h"
#import "FTConstants.h"
#import "FTSDKAgent.h"
#import "FTSDKConfig.h"
#import "FTCrash.h"
#import "FTCrashC.h"
#import "FTCrashMonitorContext.h"
#import "FTAppLifeCycle.h"
#import <objc/runtime.h>


static char FTEarlyProbeQueueKey;

@interface FTDataUploadWorker (EarlyCrashTests)
@property (nonatomic, readonly) dispatch_queue_t networkQueue;
- (void)_flushSyncData:(BOOL)withSleep;
- (BOOL)beginImmediateUpload;
- (BOOL)hasImmediateOrActiveUpload;
@property (nonatomic, copy) dispatch_block_t uploadWork;
- (BOOL)reserveFirstAutomaticUpload;
- (BOOL)previousEarlyCrashEligible;
- (void)rememberPreviousEarlyCrash:(BOOL)early;
- (NSTimeInterval)automaticUploadNow;
- (void)scheduleUploadWork:(dispatch_block_t)work afterDelay:(NSTimeInterval)delay;
- (BOOL)privateUpload;
- (void)waitBeforeRetry:(NSTimeInterval)delay;
@property (nonatomic, readonly) BOOL isUploading;
@property (nonatomic, readonly) BOOL hasPendingUpload;
- (void)performSynchronouslyOnNetworkQueue:(dispatch_block_t)block;
@end

@interface FTEarlyUploadProbe : FTDataUploadWorker
@property BOOL firstWaitUsed;
@property BOOL eligible;
@property BOOL performRealUpload;
@property (strong) NSMutableArray<NSNumber *> *retryDelays;
@property double now;
@property double deadline;
@property double reservedDelay;
@property NSUInteger uploadCalls;
@property (copy) dispatch_block_t debounce;
@property (copy) dispatch_block_t waiting;
@property (copy) dispatch_block_t willSynchronize;
@property BOOL admissionOnNetworkQueue;
@property NSUInteger immediateAdmissionCalls;
@property BOOL publicationOnNetworkQueue;
@property NSUInteger workPublications;
@property NSUInteger cancelPublication;
@property BOOL cancelPublicationSynchronously;
@property NSUInteger additionalPasses;
@property BOOL cancelDuringUpload;
@property (copy) dispatch_block_t afterBusySnapshot;
@end
@implementation FTEarlyUploadProbe
- (BOOL)hasImmediateOrActiveUpload {
    BOOL busy = [super hasImmediateOrActiveUpload];
    dispatch_block_t hook = self.afterBusySnapshot;
    if (hook) { self.afterBusySnapshot = nil; hook(); }
    return busy;
}
- (NSTimeInterval)automaticUploadNow { return self.now; }
- (BOOL)beginImmediateUpload {
    self.immediateAdmissionCalls++;
    self.admissionOnNetworkQueue = dispatch_get_specific(&FTEarlyProbeQueueKey) == (__bridge void *)self;
    return [super beginImmediateUpload];
}
- (void)setUploadWork:(dispatch_block_t)work {
    [super setUploadWork:work];
    if (work) {
        self.publicationOnNetworkQueue = dispatch_get_specific(&FTEarlyProbeQueueKey) == (__bridge void *)self;
        self.workPublications++;
        if (self.cancelPublication == self.workPublications) {
            self.cancelPublication = 0;
            if (self.cancelPublicationSynchronously) [self cancelSynchronously];
            else [self cancelAsynchronously];
        }
    }
}
- (void)performSynchronouslyOnNetworkQueue:(dispatch_block_t)block {
    if (self.willSynchronize) self.willSynchronize();
    [super performSynchronouslyOnNetworkQueue:block];
}
- (BOOL)reserveFirstAutomaticUpload { BOOL first = !self.firstWaitUsed; self.firstWaitUsed = YES; return first; }
- (BOOL)previousEarlyCrashEligible { return self.eligible; }
- (void)rememberPreviousEarlyCrash:(BOOL)early { if (early) self.eligible = YES; }
- (void)scheduleDelayedUploadTimer {
    self.deadline = self.now + 0.1;
    __weak typeof(self) weakSelf = self;
    self.debounce = ^{ [weakSelf _flushSyncData:YES]; };
}
- (void)cancelDelayedUploadTimer { self.debounce = nil; }
- (void)scheduleUploadWork:(dispatch_block_t)work afterDelay:(NSTimeInterval)delay {
    self.reservedDelay = delay;
    self.deadline = self.now + delay;
    self.waiting = work;
}
- (BOOL)privateUpload {
    self.uploadCalls++;
    if (self.cancelDuringUpload) {
        self.cancelDuringUpload = NO;
        [self cancelSynchronously];
        return YES; // more data must not revive work canceled by this pass
    }
    if (self.additionalPasses) { self.additionalPasses--; return YES; }
    return self.performRealUpload ? [super privateUpload] : NO;
}
- (void)waitBeforeRetry:(NSTimeInterval)delay { [self.retryDelays addObject:@(delay)]; }
- (void)close {
    [self invalidateAndCancelPendingUploads];
    dispatch_sync(self.networkQueue, ^{});
    self.debounce = nil; self.waiting = nil; self.willSynchronize = nil;
}
- (void)advanceTo:(double)time {
    dispatch_sync(self.networkQueue, ^{
        self.now = time;
        if (self.debounce && time >= self.deadline) {
            dispatch_block_t block = self.debounce; self.debounce = nil; block();
        } else if (self.waiting && time >= self.deadline) {
            dispatch_block_t block = self.waiting; self.waiting = nil; block();
        }
    });
}
@end

@interface FTEarlyTestClient : FTHTTPClient
@property NSUInteger calls;
@property NSInteger responseStatus;
@property (strong) dispatch_semaphore_t requestEntered;
@property (strong) dispatch_semaphore_t releaseResponse;
@end
@implementation FTEarlyTestClient
- (void)sendRequest:(id<FTRequestProtocol>)request completion:(void (^)(NSHTTPURLResponse *, NSData *, NSError *))callback {
    self.calls++;
    if (self.requestEntered) {
        dispatch_semaphore_signal(self.requestEntered);
        dispatch_semaphore_t release = self.releaseResponse;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
            callback([[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil], nil, nil);
        });
        return;
    }
    callback([[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"] statusCode:self.responseStatus HTTPVersion:@"HTTP/1.1" headerFields:nil], nil, nil);
}
@end
@interface FTEarlyFlowObserver : NSObject <FTSessionOnErrorDataHandler>
@property NSUInteger calls;
@end
@implementation FTEarlyFlowObserver
- (void)checkRUMSessionOnErrorDatasExpired { self.calls++; }
- (long long)getErrorTimeLineFromFileCache { return 0; }
- (long long)getLastProcessFatalErrorTime { return 0; }
@end
@interface FTEarlyCrashUploadTests : XCTestCase
@property (copy) NSString *directory;
@property (copy) NSString *statePath;
@property (strong) FTEarlyUploadProbe *worker;
@end
@implementation FTEarlyCrashUploadTests
- (void)setUp {
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
    self.statePath = [self.directory stringByAppendingPathComponent:@"CrashState.json"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTNetworkConnectivity.sharedInstance stop];
    dispatch_sync([FTNetworkConnectivity.sharedInstance valueForKey:@"monitorQueue"], ^{});
    [FTNetworkConnectivity.sharedInstance setValue:@NO forKey:@"isConnected"];
    [FTNetworkInfoManager sharedInstance].setUploadURL(@"http://localhost", nil, nil);
}
- (void)tearDown {
    [self.worker close];
    self.worker = nil;
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [[NSFileManager defaultManager] removeItemAtPath:self.directory error:nil];
}
- (FTEarlyUploadProbe *)workerAfterCrashAt:(uint64_t)elapsed {
    NSDictionary *json = @{@"version":@1, @"previousEarlyCrash":(elapsed > 0 ? @YES : @NO), @"earlyCrashDurationNS":@(elapsed)};
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    XCTAssertTrue([data writeToFile:self.statePath atomically:YES]);
    __block FTCrash_AppState snapshot = {0};
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        XCTAssertTrue(ftcrashstate_readPersistedState(self.statePath.fileSystemRepresentation, &snapshot));
    });
    XCTAssertEqual(snapshot.previousEarlyCrash, elapsed > 0 && elapsed <= UINT64_C(5000000000));
    self.worker = [[FTEarlyUploadProbe alloc] initWithSyncPageSize:10 syncSleepTime:0];
    dispatch_queue_set_specific(self.worker.networkQueue, &FTEarlyProbeQueueKey, (__bridge void *)self.worker, NULL);
    self.worker.retryDelays = [NSMutableArray array];
    [self.worker updatePreviousEarlyCrash:snapshot.previousEarlyCrash];
    dispatch_sync(self.worker.networkQueue, ^{});
    return self.worker;
}
- (void)reserve:(FTEarlyUploadProbe *)worker {
    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    [worker advanceTo:worker.deadline];
}
- (void)assertNoUploadWork:(FTEarlyUploadProbe *)worker {
    // Production task access is queue-confined; tests observe on the same queue.
    [worker performSynchronouslyOnNetworkQueue:^{ XCTAssertNil(worker.uploadWork); }];
}
- (void)insertEvent {
    FTRecordModel *event = [[FTRecordModel alloc] initWithSource:@"logger" op:FT_DATA_TYPE_LOGGING tags:@{} fields:@{@"message": @"early crash regression"} tm:1000000000];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManager] insertItem:event]);
}

// Freeze the real HTTP completion after the caller has observed "not busy".
// The timeout is only a failure escape hatch; no upload/timer delay is simulated.
- (void)testMainThreadManualFlushReturnsBeforeAutomaticHTTPCompletes {
    XCTAssertTrue(NSThread.isMainThread);
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.performRealUpload = YES;
    FTEarlyTestClient *client = [[FTEarlyTestClient alloc] initWithTimeoutIntervalForRequest:30];
    client.requestEntered = dispatch_semaphore_create(0);
    client.releaseResponse = dispatch_semaphore_create(0);
    worker.httpClient = client;
    [self insertEvent];
    [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    [self reserve:worker];
    dispatch_block_t automaticWork = worker.waiting;
    worker.waiting = nil;
    worker.afterBusySnapshot = ^{
        dispatch_async(worker.networkQueue, automaticWork);
        XCTAssertEqual(dispatch_semaphore_wait(client.requestEntered,
            dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0L);
    };
    dispatch_semaphore_t returned = dispatch_semaphore_create(0);
    dispatch_semaphore_t checked = dispatch_semaphore_create(0);
    __block BOOL returnedBeforeHTTPCompletion = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        returnedBeforeHTTPCompletion = dispatch_semaphore_wait(returned,
            dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0;
        dispatch_semaphore_signal(client.releaseResponse);
        dispatch_semaphore_signal(checked);
    });
    FTTrackDataManager *manager = [[FTTrackDataManager alloc] init];
    [manager setValue:worker forKey:@"dataUploadWorker"];
    [manager flushSyncData];
    dispatch_semaphore_signal(returned);
    dispatch_semaphore_wait(checked, DISPATCH_TIME_FOREVER);
    dispatch_sync(worker.networkQueue, ^{});
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertTrue(returnedBeforeHTTPCompletion, @"Manual flush must return while automatic HTTP is still frozen");
    XCTAssertEqual(client.calls, 1u);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCount], 0);
}

- (void)testTenThousandImmediateRequestsSubmitOneAdmission {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    [self insertEvent];
    [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    FTTrackDataManager *manager = [[FTTrackDataManager alloc] init];
    [manager setValue:worker forKey:@"dataUploadWorker"];
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    for (NSUInteger i = 0; i < 10000; i++) [manager flushSyncData];
    // Submission coalescing must not move upload state off networkQueue.
    XCTAssertFalse(worker.isUploading);
    dispatch_semaphore_signal(resume);
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(worker.immediateAdmissionCalls, 1u);
    XCTAssertEqual(worker.workPublications, 1u);
    XCTAssertEqual(worker.uploadCalls, 1u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testConcurrentImmediateRequestsSubmitOneAdmission {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    dispatch_apply(16, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(size_t index) {
        for (NSUInteger i = 0; i < 100; i++) [worker flushWithSleep:NO];
    });
    XCTAssertFalse(worker.isUploading);
    dispatch_semaphore_signal(resume);
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(worker.immediateAdmissionCalls, 1u);
    XCTAssertEqual(worker.workPublications, 1u);
    XCTAssertFalse(worker.isUploading);
}
- (void)testCancelSeparatesPendingImmediateSubmissions {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    [worker flushWithSleep:NO];
    [worker cancelAsynchronously];
    [worker flushWithSleep:NO];
    dispatch_semaphore_signal(resume);
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 1u);
    XCTAssertFalse(worker.isUploading);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testSameQueueSyncCancellationRetiresOnlyOldSubmission {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    dispatch_sync(worker.networkQueue, ^{
        [worker flushWithSleep:NO];
        [worker cancelSynchronously];
        [worker flushWithSleep:NO];
    });
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(worker.immediateAdmissionCalls, 1u);
    XCTAssertEqual(worker.workPublications, 1u);
    XCTAssertEqual(observer.calls, 1u);
    XCTAssertFalse(worker.isUploading);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}

- (void)testCanceledPendingSubmissionAllowsLaterImmediateRequest {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    [worker flushWithSleep:NO]; [worker cancelAsynchronously];
    dispatch_semaphore_signal(resume);
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 0u);
    [worker flushWithSleep:NO];
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 1u);
    XCTAssertFalse(worker.isUploading);
}

- (void)testManualAdmissionAndPublicationRunOnNetworkQueue {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertTrue(worker.admissionOnNetworkQueue);
    XCTAssertTrue(worker.publicationOnNetworkQueue);
}
- (void)testAsyncCancelBetweenManualPublicationAndEnqueueReleasesSlot {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    worker.cancelPublication = 1;
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertFalse(worker.isUploading);
    [self assertNoUploadWork:worker];
    XCTAssertEqual(observer.calls, 0u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testSyncCancelBetweenManualPublicationAndEnqueueReleasesSlot {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.cancelPublication = 1; worker.cancelPublicationSynchronously = YES;
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertFalse(worker.isUploading); [self assertNoUploadWork:worker];
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testSameQueueCancelOfQueuedManualWorkDoesNotStickUploading {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    dispatch_sync(worker.networkQueue, ^{
        [worker flushWithSleep:NO];
        [worker cancelAsynchronously]; // queued behind asynchronous admission, before its body
    });
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertFalse(worker.isUploading); [self assertNoUploadWork:worker];
    [worker flushWithSleep:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNotNil(worker.debounce);
}
- (void)testCanceledBatchContinuationReleasesImmediateReservation {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self insertEvent]; [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    worker.additionalPasses = 1; worker.cancelPublication = 2;
    [worker flushWithSleep:NO];
    // Drain admission, pass one, then its queued cancel/continuation.
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(worker.workPublications, 2u);
    XCTAssertEqual(observer.calls, 1u);
    XCTAssertFalse(worker.isUploading); [self assertNoUploadWork:worker];
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testCancelDuringActivePassDoesNotReviveBatchContinuation {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self insertEvent]; [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    worker.cancelDuringUpload = YES;
    [worker flushWithSleep:NO];
    dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(worker.uploadCalls, 1u); XCTAssertEqual(observer.calls, 1u);
    XCTAssertFalse(worker.isUploading); [self assertNoUploadWork:worker];
}
- (void)testShutdownWithQueuedManualWorkKeepsTerminalState {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    dispatch_sync(worker.networkQueue, ^{
        [worker flushWithSleep:NO];
        [worker invalidateAndCancelPendingUploads];
    });
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertFalse(worker.isUploading); [self assertNoUploadWork:worker];
    [worker flushWithSleep:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNil(worker.debounce);
}

// The production queue and state transitions remain real. Only timer firing is
// virtual; semaphores fix the enqueue/cancel order without a sleep or wall clock.
- (dispatch_semaphore_t)holdNetworkQueue:(FTEarlyUploadProbe *)worker {
    dispatch_semaphore_t entered = dispatch_semaphore_create(0);
    dispatch_semaphore_t resume = dispatch_semaphore_create(0);
    dispatch_async(worker.networkQueue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(resume, DISPATCH_TIME_FOREVER);
    });
    dispatch_semaphore_wait(entered, DISPATCH_TIME_FOREVER);
    return resume;
}
- (void)testAsyncCancellationAfterQueuedAutoRequestAllowsReenable {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTTrackDataManager *manager = [[FTTrackDataManager alloc] init];
    [manager setValue:worker forKey:@"dataUploadWorker"];
    [manager setValue:@YES forKey:@"autoSync"];
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    [worker flushWithSleep:YES];
    [manager enableAutoSync:NO];
    dispatch_semaphore_signal(resume);
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertFalse(worker.hasPendingUpload);
    XCTAssertNil(worker.debounce);
    @try {
        [manager enableAutoSync:YES];
        [(id)manager connectivityChanged:YES typeDescription:@"wifi"];
        dispatch_sync(worker.networkQueue, ^{});
        XCTAssertTrue(worker.hasPendingUpload);
        XCTAssertNotNil(worker.debounce);
        [worker advanceTo:0.1];
        XCTAssertEqual(worker.reservedDelay, 2);
    } @finally {
        [manager enableAutoSync:NO];
        dispatch_sync(worker.networkQueue, ^{});
    }
}
- (void)testSynchronousCancellationAfterQueuedAutoRequestReturnsIdle {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    dispatch_semaphore_t submitted = dispatch_semaphore_create(0);
    dispatch_semaphore_t completed = dispatch_semaphore_create(0);
    worker.willSynchronize = ^{ dispatch_semaphore_signal(submitted); };
    [worker flushWithSleep:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [worker cancelSynchronously];
        dispatch_semaphore_signal(completed);
    });
    dispatch_semaphore_wait(submitted, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_signal(resume);
    dispatch_semaphore_wait(completed, DISPATCH_TIME_FOREVER);
    worker.willSynchronize = nil;
    XCTAssertFalse(worker.hasPendingUpload);
    XCTAssertNil(worker.debounce);
    [worker flushWithSleep:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNotNil(worker.debounce);
}
- (void)testSynchronousCancellationFromNetworkQueueDoesNotDeadlock {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [worker flushWithSleep:YES]; dispatch_sync(worker.networkQueue, ^{});
    dispatch_sync(worker.networkQueue, ^{
        XCTAssertTrue(worker.hasPendingUpload);
        [worker cancelSynchronously];
        XCTAssertFalse(worker.hasPendingUpload);
        XCTAssertNil(worker.debounce);
    });
    [worker flushWithSleep:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNotNil(worker.debounce);
}
- (void)testRequestQueuedAfterAsyncCancellationCanReserveANewTimer {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    dispatch_semaphore_t resume = [self holdNetworkQueue:worker];
    [worker flushWithSleep:YES];
    [worker cancelAsynchronously];
    [worker flushWithSleep:YES]; // rapid re-enable: this request must survive
    dispatch_semaphore_signal(resume);
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertTrue(worker.hasPendingUpload);
    XCTAssertNotNil(worker.debounce);
}
- (void)testOccurrenceClassificationUsesCapturedTime {
    uint64_t elapsed = UINT64_MAX;
    XCTAssertTrue(ft_earlyCrashElapsed(100000000000, 104999000000, &elapsed));
    XCTAssertEqual(elapsed, UINT64_C(4999000000));
    XCTAssertTrue(ft_earlyCrashElapsed(100000000000, 105000000000, &elapsed));
    XCTAssertEqual(elapsed, UINT64_C(5000000000));
    XCTAssertTrue(ft_earlyCrashElapsed(100000000000, 100000000000, &elapsed));
    XCTAssertEqual(elapsed, 0u);
    XCTAssertFalse(ft_earlyCrashElapsed(100000000000, 105001000000, &elapsed));
    XCTAssertFalse(ft_earlyCrashElapsed(100000000000, 99999999999, &elapsed));
    XCTAssertFalse(ft_earlyCrashElapsed(0, 104999000000, &elapsed));
    XCTAssertFalse(ft_earlyCrashElapsed(100000000000, 0, &elapsed));
    // Later processing time is deliberately not an input to classification.
    uint64_t processingTime = UINT64_C(160000000000);
    XCTAssertTrue(ft_earlyCrashElapsed(100000000000, processingTime - UINT64_C(55001000000), &elapsed));
    XCTAssertEqual(elapsed, UINT64_C(4999000000));
}
- (void)testJSONRequiresBothValidDurationAndFlag {
    for (NSString *json in @[@"{\"version\":1,\"previousEarlyCrash\":true}",
        @"{\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":4999000000}",
        @"{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":true}",
        @"{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":4.999}",
        @"{\"version\":1,\"earlyCrashDurationNS\":4999000000}",
        @"{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":-1}",
        @"{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":5001000000}"]) {
        XCTAssertTrue([[json dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self.statePath atomically:YES]);
        FTCrash_AppState snapshot = {0};
        XCTAssertTrue(ftcrashstate_readPersistedState(self.statePath.fileSystemRepresentation, &snapshot));
        XCTAssertFalse(snapshot.previousEarlyCrash);
    }
    XCTAssertTrue([[@"{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":0}" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self.statePath atomically:YES]);
    FTCrash_AppState snapshot = {0};
    XCTAssertTrue(ftcrashstate_readPersistedState(self.statePath.fileSystemRepresentation, &snapshot));
    XCTAssertTrue(snapshot.previousEarlyCrash);
}
- (void)testPreviousEarlyCrashChangesOnlyFirstReservation {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    [worker advanceTo:0.099];
    XCTAssertNil(worker.waiting);
    [worker advanceTo:0.1];
    XCTAssertEqual(worker.reservedDelay, 2);
    XCTAssertEqualWithAccuracy(worker.deadline, 2.1, 0.000001);
    [worker cancelSynchronously];
    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    [worker advanceTo:0.2];
    XCTAssertEqual(worker.reservedDelay, 10);
    [worker close];
}
- (void)testInclusiveFiveSecondBoundary {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:5000000000];
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testFivePointZeroZeroOneSecondsKeepsTen {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:5001000000];
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testNormalLaunchKeepsTen {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testDeadlineEntersOriginalFlowThenNextPeriodIsTen {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new];
    worker.errorSampledConsume = observer;
    [self insertEvent];
    [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    [self reserve:worker];
    [worker advanceTo:2.099]; XCTAssertEqual(observer.calls, 0u); XCTAssertEqual(worker.uploadCalls, 0u);
    [worker advanceTo:2.1]; XCTAssertEqual(observer.calls, 1u); XCTAssertEqual(worker.uploadCalls, 1u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
    [worker advanceTo:12.199]; XCTAssertEqual(observer.calls, 1u);
    [worker advanceTo:12.2]; XCTAssertEqual(observer.calls, 2u); XCTAssertEqual(worker.uploadCalls, 2u);
}
- (void)testNoNetworkKeepsCacheAndConsumesFirstReservation {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    [self insertEvent];
    [self reserve:worker]; [worker advanceTo:2.1];
    XCTAssertEqual(worker.uploadCalls, 0u);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCount], 1);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testFailureUsesExistingFiveRetriesAndPreservesCache {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.performRealUpload = YES;
    FTEarlyTestClient *client = [[FTEarlyTestClient alloc] initWithTimeoutIntervalForRequest:30];
    client.responseStatus = 500; worker.httpClient = client;
    [self insertEvent]; [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    [self reserve:worker]; [worker advanceTo:2.1];
    XCTAssertEqual(client.calls, 6u);
    XCTAssertEqualObjects(worker.retryDelays, (@[@0.5, @1.0, @1.5, @2.0, @2.5]));
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCount], 1);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testSuccessfulUploadUsesExistingCacheDeletion {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:5000000000];
    worker.performRealUpload = YES;
    FTEarlyTestClient *client = [[FTEarlyTestClient alloc] initWithTimeoutIntervalForRequest:30];
    client.responseStatus = 200; worker.httpClient = client;
    [self insertEvent]; [FTNetworkConnectivity.sharedInstance setValue:@YES forKey:@"isConnected"];
    [self reserve:worker]; [worker advanceTo:2.1];
    XCTAssertEqual(client.calls, 1u); XCTAssertEqual(worker.retryDelays.count, 0u);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCount], 0);
}
- (void)testManualUploadBeforeAutoDoesNotConsumeShortWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 1u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testManualUploadCancelsExistingShortWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self reserve:worker];
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 1u);
    [worker advanceTo:2.1]; XCTAssertEqual(observer.calls, 1u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testAutoSyncDisabledDoesNotReserveWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTTrackDataManager *manager = [[FTTrackDataManager alloc] init];
    [manager setValue:worker forKey:@"dataUploadWorker"];
    [manager setValue:@NO forKey:@"autoSync"];
    [(id)manager applicationDidBecomeActive];
    [(id)manager connectivityChanged:YES typeDescription:@"wifi"];
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNil(worker.debounce); XCTAssertNil(worker.waiting);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testShutdownInvalidatesDelayedBlock {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self reserve:worker];
    [worker invalidateAndCancelPendingUploads]; dispatch_sync(worker.networkQueue, ^{});
    [worker advanceTo:2.1]; XCTAssertEqual(observer.calls, 0u);
}
- (void)testCrashResultShortensAnAlreadyReservedWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self reserve:worker]; XCTAssertEqualWithAccuracy(worker.deadline, 10.1, 0.000001);
    [worker advanceTo:1.1];
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqualWithAccuracy(worker.reservedDelay, 1, 0.000001);
    XCTAssertEqualWithAccuracy(worker.deadline, 2.1, 0.000001);
    [worker advanceTo:2.099]; XCTAssertEqual(observer.calls, 0u);
    [worker advanceTo:2.1]; XCTAssertEqual(observer.calls, 1u);
}
- (void)testCrashResultAfterShortDeadlineSchedulesImmediately {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [self reserve:worker]; [worker advanceTo:4];
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(worker.reservedDelay, 0); XCTAssertEqual(worker.deadline, 4);
}
- (void)testCrashResultAfterFirstWaitDoesNotChangeLaterPeriods {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [self reserve:worker]; [worker advanceTo:10.1];
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNil(worker.waiting);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testRepeatedCrashResultsDoNotMoveDeadline {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [self reserve:worker]; [worker advanceTo:1];
    for (NSUInteger i = 0; i < 100; i++) [worker updatePreviousEarlyCrash:YES];
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqualWithAccuracy(worker.deadline, 2.1, 0.000001);
}
- (void)testStaleOriginalTimerCannotExecuteANewerReservation {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self reserve:worker]; dispatch_block_t oldTimer = worker.waiting;
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    [worker advanceTo:2.1]; XCTAssertEqual(observer.calls, 1u);
    [self reserve:worker]; XCTAssertEqualWithAccuracy(worker.deadline, 12.2, 0.000001);
    dispatch_sync(worker.networkQueue, oldTimer);
    XCTAssertEqual(observer.calls, 1u);
    [worker advanceTo:12.2]; XCTAssertEqual(observer.calls, 2u);
}
- (void)testResultAfterCancellationDoesNotReviveUpload {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [self reserve:worker]; [worker cancelSynchronously];
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testResultAfterManualUploadKeepsItsExistingSemantics {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self reserve:worker]; [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{}); dispatch_sync(worker.networkQueue, ^{});
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 1u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 10);
}
- (void)testResultAfterShutdownDoesNotScheduleUpload {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:0];
    [worker invalidateAndCancelPendingUploads]; dispatch_sync(worker.networkQueue, ^{});
    [worker updatePreviousEarlyCrash:YES]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertNil(worker.waiting); XCTAssertFalse(worker.eligible);
}
- (void)testCrashDisabledStartupLeavesJSONUntouched {
    NSString *path = [[[ft_crashInstallPath() stringByAppendingPathComponent:@"Data"]
                      stringByAppendingPathComponent:@"CrashState.json"] copy];
    NSFileManager *files = NSFileManager.defaultManager;
    NSData *original = [NSData dataWithContentsOfFile:path];
    [files createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *history = [@"{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":4999000000}" dataUsingEncoding:NSUTF8StringEncoding];
    [history writeToFile:path atomically:YES];
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:@"http://localhost"]; config.autoSync = NO;
    @try {
        [FTSDKAgent startWithConfigOptions:config];
        uint64_t origin = ft_earlyCrashStartTime();
        XCTAssertGreaterThan(origin, 0u);
        XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], history);
        [FTSDKAgent shutDown];
        [FTSDKAgent startWithConfigOptions:config];
        XCTAssertEqual(ft_earlyCrashStartTime(), origin);
        XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], history);
    } @finally {
        [FTSDKAgent shutDown];
        if (original) [original writeToFile:path atomically:YES]; else [files removeItemAtPath:path error:nil];
    }
}
- (void)testRepeatedFlushDoesNotMoveShortDeadline {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    [self reserve:worker];
    [worker advanceTo:1];
    for (NSUInteger i = 0; i < 100; i++) [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqualWithAccuracy(worker.deadline, 2.1, 0.000001);
    XCTAssertEqual(worker.reservedDelay, 2);
}

@end
