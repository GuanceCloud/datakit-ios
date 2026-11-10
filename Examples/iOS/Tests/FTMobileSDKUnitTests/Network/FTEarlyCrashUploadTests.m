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


// Test callback advances a processing clock without sleeping. The marker must
// already contain the original occurrence, before this callback completes.
static uint64_t callbackProcessingTime;
static NSString *callbackMarkerPath;
static NSData *markerDuringCallback;
static void delayedWillWrite(FTCrash_ExceptionHandlingPlan *plan, const FTCrash_MonitorContext *context) {
    (void)plan; (void)context;
    callbackProcessingTime += UINT64_C(60000000000);
    markerDuringCallback = [NSData dataWithContentsOfFile:callbackMarkerPath];
}

@interface FTDataUploadWorker (EarlyCrashTests)
@property (nonatomic, readonly) dispatch_queue_t networkQueue;
- (void)_flushSyncData:(BOOL)withSleep;
- (NSTimeInterval)nextAutomaticUploadDelay;
- (NSTimeInterval)automaticUploadNow;
- (void)afterEarlyCrashPreparation:(dispatch_block_t)completion;
- (void)scheduleUploadWork:(dispatch_block_t)work afterDelay:(NSTimeInterval)delay;
- (BOOL)privateUpload;
- (void)waitBeforeRetry:(NSTimeInterval)delay;
@property (nonatomic, readonly) BOOL isUploading;
@end

@interface FTEarlyUploadProbe : FTDataUploadWorker
@property FTEarlyCrashState *launch;
@property BOOL performRealUpload;
@property (strong) NSMutableArray<NSNumber *> *retryDelays;
@property double now;
@property double deadline;
@property double reservedDelay;
@property NSUInteger uploadCalls;
@property (copy) dispatch_block_t debounce;
@property (copy) dispatch_block_t waiting;
@property BOOL deferPreparation;
@property (copy) dispatch_block_t preparation;
@end
@implementation FTEarlyUploadProbe
- (NSTimeInterval)automaticUploadNow { return self.now; }
- (void)afterEarlyCrashPreparation:(dispatch_block_t)completion {
    if (self.deferPreparation) self.preparation = completion;
    else completion();
}
- (void)scheduleDelayedUploadTimer {
    self.deadline = self.now + 0.1;
    __weak typeof(self) weakSelf = self;
    self.debounce = ^{ [weakSelf _flushSyncData:YES]; };
}
- (void)cancelDelayedUploadTimer { self.debounce = nil; }
- (NSTimeInterval)nextAutomaticUploadDelay {
    return ft_earlyCrashTakeDelayInState(self.launch);
}
- (void)scheduleUploadWork:(dispatch_block_t)work afterDelay:(NSTimeInterval)delay {
    self.reservedDelay = delay;
    self.deadline = self.now + delay;
    self.waiting = work;
}
- (BOOL)privateUpload { self.uploadCalls++; return self.performRealUpload ? [super privateUpload] : NO; }
- (void)waitBeforeRetry:(NSTimeInterval)delay { [self.retryDelays addObject:@(delay)]; }
- (void)close {
    [self invalidateAndCancelPendingUploads];
    dispatch_sync(self.networkQueue, ^{});
    self.debounce = nil; self.waiting = nil; self.preparation = nil;
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
@end
@implementation FTEarlyTestClient
- (void)sendRequest:(id<FTRequestProtocol>)request completion:(void (^)(NSHTTPURLResponse *, NSData *, NSError *))callback {
    self.calls++;
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
@property (copy) NSString *marker;
@property FTEarlyCrashState *launch;
@property (strong) FTEarlyUploadProbe *worker;
@end
@implementation FTEarlyCrashUploadTests
- (void)setUp {
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
    self.marker = [self.directory stringByAppendingPathComponent:@"EarlyCrash.marker"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTNetworkConnectivity.sharedInstance stop];
    dispatch_sync([FTNetworkConnectivity.sharedInstance valueForKey:@"monitorQueue"], ^{});
    [FTNetworkConnectivity.sharedInstance setValue:@NO forKey:@"isConnected"];
    [FTNetworkInfoManager sharedInstance].setUploadURL(@"http://localhost", nil, nil);
}
- (void)tearDown {
    [self.worker close];
    self.worker = nil;
    ft_earlyCrashDestroy(self.launch); self.launch = NULL;
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [[NSFileManager defaultManager] removeItemAtPath:self.directory error:nil];
}
- (FTEarlyUploadProbe *)workerAfterCrashAt:(uint64_t)elapsed {
    FTEarlyCrashState *previous = ft_earlyCrashCreate();
    ft_earlyCrashInitialize(previous, 100000000000, self.marker.fileSystemRepresentation);
    if (elapsed) ft_earlyCrashRecordInState(previous, 100000000000 + elapsed);
    ft_earlyCrashDestroy(previous);
    self.launch = ft_earlyCrashCreate();
    ft_earlyCrashInitialize(self.launch, 200000000000, self.marker.fileSystemRepresentation);
    self.worker = [[FTEarlyUploadProbe alloc] initWithSyncPageSize:10 syncSleepTime:0];
    self.worker.launch = self.launch;
    self.worker.retryDelays = [NSMutableArray array];
    return self.worker;
}
- (void)reserve:(FTEarlyUploadProbe *)worker {
    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    [worker advanceTo:worker.deadline];
}
- (void)insertEvent {
    FTRecordModel *event = [[FTRecordModel alloc] initWithSource:@"logger" op:FT_DATA_TYPE_LOGGING tags:@{} fields:@{@"message": @"early crash regression"} tm:1000000000];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManager] insertItem:event]);
}

// Policy tests use a fresh state object to model each SDK launch. Only the
// separate C integration tests require an actual process exit and exec.
- (void)beginPolicyLaunchAt:(uint64_t)start path:(NSString *)path {
    ft_earlyCrashDestroy(self.launch);
    self.launch = ft_earlyCrashCreate();
    XCTAssertNotEqual(self.launch, NULL);
    ft_earlyCrashInitialize(self.launch, start, path.fileSystemRepresentation);
}
- (void)beginPolicyLaunchAt:(uint64_t)start {
    [self beginPolicyLaunchAt:start path:self.marker];
}
- (void)assertInvalidMarkerUsesDefaultWait:(NSData *)data {
    NSError *error = nil;
    XCTAssertTrue([data writeToFile:self.marker options:0 error:&error], @"%@", error);
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertEqual([NSData dataWithContentsOfFile:self.marker].length, 0u);
}
- (void)testMissingCrashTimeKeepsDefaultWait {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    ft_earlyCrashRecordInState(self.launch, 0);
    XCTAssertEqual([NSData dataWithContentsOfFile:self.marker].length, 0u);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testCrashBeforeSDKStartKeepsDefaultWait {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(99999999999));
    XCTAssertEqual([NSData dataWithContentsOfFile:self.marker].length, 0u);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testMissingSDKStartKeepsDefaultWait {
    [self beginPolicyLaunchAt:0];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.marker]);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testMissingMarkerPathKeepsDefaultWait {
    [self beginPolicyLaunchAt:UINT64_C(100000000000) path:nil];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.marker]);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testMarkerConsumptionFailureKeepsDefaultWait {
    // A directory cannot be consumed as a marker file. No timing or permissions
    // race is needed to reproduce this I/O failure.
    [self beginPolicyLaunchAt:UINT64_C(100000000000) path:self.directory];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    BOOL isDirectory = NO;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.directory isDirectory:&isDirectory]);
    XCTAssertTrue(isDirectory);
}
- (void)testInvalidMarkerMagicKeepsDefaultWait {
    const uint64_t marker[] = {0, 1, ~UINT64_C(1)};
    [self assertInvalidMarkerUsesDefaultWait:[NSData dataWithBytes:marker length:sizeof(marker)]];
}
- (void)testUnknownMarkerVersionKeepsDefaultWait {
    const uint64_t magic = UINT64_C(0x4654454300000003);
    const uint64_t marker[] = {magic, 1, ~(magic ^ UINT64_C(1))};
    [self assertInvalidMarkerUsesDefaultWait:[NSData dataWithBytes:marker length:sizeof(marker)]];
}
- (void)testCorruptMarkerChecksumKeepsDefaultWait {
    const uint64_t marker[] = {UINT64_C(0x4654454300000002), 1, 0};
    [self assertInvalidMarkerUsesDefaultWait:[NSData dataWithBytes:marker length:sizeof(marker)]];
}
- (void)testInvalidMarkerFlagKeepsDefaultWait {
    const uint64_t magic = UINT64_C(0x4654454300000002);
    const uint64_t marker[] = {magic, 0, ~magic};
    [self assertInvalidMarkerUsesDefaultWait:[NSData dataWithBytes:marker length:sizeof(marker)]];
}
- (void)testTruncatedMarkerKeepsDefaultWait {
    [self assertInvalidMarkerUsesDefaultWait:[@"FTEC" dataUsingEncoding:NSUTF8StringEncoding]];
}
- (void)testEarlyCrashThenNormalLaunchRestoresDefaultWait {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)]; // A
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    [self beginPolicyLaunchAt:UINT64_C(200000000000)]; // B, normal
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertEqual([NSData dataWithContentsOfFile:self.marker].length, 0u);
    [self beginPolicyLaunchAt:UINT64_C(300000000000)]; // C
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testConsecutiveEarlyCrashesShortenEachNextLaunchOnly {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)]; // A
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(105000000000));
    [self beginPolicyLaunchAt:UINT64_C(200000000000)]; // B
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(204999000000));
    NSData *current = [NSData dataWithContentsOfFile:self.marker];
    XCTAssertEqual(current.length, 24u);
    // Consuming the old in-memory allowance must not remove B's new marker.
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.marker], current);
    [self beginPolicyLaunchAt:UINT64_C(300000000000)]; // C, normal
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
    [self beginPolicyLaunchAt:UINT64_C(400000000000)]; // D
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testDelayedProcessingAndRepeatedInitializationKeepCapturedEvent {
    const uint64_t start = UINT64_C(100000000000);
    const uint64_t capture = start + UINT64_C(4999000000);
    const uint64_t processing = start + UINT64_C(9000000000);
    [self beginPolicyLaunchAt:start];
    // A delayed attempt to initialize again must not replace the original start.
    ft_earlyCrashInitialize(self.launch, processing, self.marker.fileSystemRepresentation);
    ft_earlyCrashRecordInState(self.launch, capture);
    NSData *current = [NSData dataWithContentsOfFile:self.marker];
    XCTAssertEqual(current.length, 24u);
    ft_earlyCrashRecordInState(self.launch, processing); // late duplicate
    ft_earlyCrashInitialize(self.launch, processing, self.marker.fileSystemRepresentation);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.marker], current);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
}
- (void)testEligibleDuplicatesPersistIdenticalMarkerBytes {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    NSData *first = [NSData dataWithContentsOfFile:self.marker];
    XCTAssertEqual(first.length, 24u);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(105000000000));
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.marker], first);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
}

- (void)testHistoryIsConsumedEvenWithoutAnAutomaticReservation {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    ft_earlyCrashDestroy(self.launch);
    self.launch = ft_earlyCrashCreate();
    ft_earlyCrashRestoreHistoryInState(self.launch, self.marker.fileSystemRepresentation);
    // B never requests a wait (auto-sync remains disabled). C must still forget A.
    [self beginPolicyLaunchAt:UINT64_C(300000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
}
- (void)testHistoryRestoreNeedsNeitherSDKClockNorCrashRecording {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    ft_earlyCrashDestroy(self.launch);
    self.launch = ft_earlyCrashCreate();
    // Upload-only recovery must work even without a current SDK capture clock.
    ft_earlyCrashRestoreHistoryInState(self.launch, self.marker.fileSystemRepresentation);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.marker]);
}
- (void)testUploadHistoryLookupDoesNotCreateMissingDirectories {
    ft_earlyCrashDestroy(self.launch);
    self.launch = ft_earlyCrashCreate();
    NSString *directory = [self.directory stringByAppendingPathComponent:@"not-created-by-upload"];
    NSString *path = [directory stringByAppendingPathComponent:@"EarlyCrash.marker"];
    ft_earlyCrashRestoreHistoryInState(self.launch, path.fileSystemRepresentation);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:directory]);
}
- (void)testRecordingBeforeUploadKeepsBothHistoryAndCurrentMarker {
    [self beginPolicyLaunchAt:UINT64_C(100000000000)];
    ft_earlyCrashRecordInState(self.launch, UINT64_C(105000000000));
    ft_earlyCrashDestroy(self.launch);
    self.launch = ft_earlyCrashCreate();
    ft_earlyCrashStartInState(self.launch, UINT64_C(200000000000));
    ft_earlyCrashPrepareRecordingInState(self.launch, self.marker.fileSystemRepresentation);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(204999000000));
    NSData *current = [NSData dataWithContentsOfFile:self.marker];
    XCTAssertEqual(current.length, 24u);
    // A late upload recovery must not mistake B's new marker for A's history.
    ft_earlyCrashRestoreHistoryInState(self.launch, self.marker.fileSystemRepresentation);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 10u);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.marker], current);
    [self beginPolicyLaunchAt:UINT64_C(300000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
}
- (void)testLateCrashConfigurationKeepsOriginalSDKClock {
    ft_earlyCrashDestroy(self.launch);
    self.launch = ft_earlyCrashCreate();
    ft_earlyCrashStartInState(self.launch, UINT64_C(100000000000));
    ft_earlyCrashStartInState(self.launch, UINT64_C(109000000000));
    ft_earlyCrashRestoreHistoryInState(self.launch, self.marker.fileSystemRepresentation);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.marker]);
    ft_earlyCrashPrepareRecordingInState(self.launch, self.marker.fileSystemRepresentation);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(105001000000));
    XCTAssertEqual([NSData dataWithContentsOfFile:self.marker].length, 0u);
    ft_earlyCrashRecordInState(self.launch, UINT64_C(104999000000));
    XCTAssertEqual([NSData dataWithContentsOfFile:self.marker].length, 24u);
    [self beginPolicyLaunchAt:UINT64_C(200000000000)];
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
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
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{});
    XCTAssertEqual(observer.calls, 1u);
    [self reserve:worker]; XCTAssertEqual(worker.reservedDelay, 2);
}
- (void)testManualUploadCancelsExistingShortWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    FTEarlyFlowObserver *observer = [FTEarlyFlowObserver new]; worker.errorSampledConsume = observer;
    [self reserve:worker];
    [worker flushWithSleep:NO]; dispatch_sync(worker.networkQueue, ^{});
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
- (void)testDelayedPreparationKeepsOriginalUploadDeadline {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.deferPreparation = YES;
    [self reserve:worker];
    XCTAssertNil(worker.waiting);
    dispatch_sync(worker.networkQueue, ^{
        worker.now = 1.1;
        worker.preparation(); worker.preparation = nil;
    });
    XCTAssertEqualWithAccuracy(worker.reservedDelay, 1, 0.000001);
    XCTAssertEqualWithAccuracy(worker.deadline, 2.1, 0.000001);
}
- (void)testPreparationFinishingAfterDeadlineSchedulesImmediately {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.deferPreparation = YES;
    [self reserve:worker];
    dispatch_sync(worker.networkQueue, ^{
        worker.now = 4;
        worker.preparation(); worker.preparation = nil;
    });
    XCTAssertEqual(worker.reservedDelay, 0);
    XCTAssertEqual(worker.deadline, 4);
}
- (void)testShutdownDuringPreparationDoesNotConsumeShortWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.deferPreparation = YES;
    [self reserve:worker];
    [worker invalidateAndCancelPendingUploads];
    dispatch_sync(worker.networkQueue, ^{
        worker.preparation(); worker.preparation = nil;
    });
    XCTAssertNil(worker.waiting);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
}
- (void)testManualUploadDuringPreparationDoesNotConsumeShortWait {
    FTEarlyUploadProbe *worker = [self workerAfterCrashAt:4999000000];
    worker.deferPreparation = YES;
    [self reserve:worker];
    [worker flushWithSleep:NO];
    dispatch_sync(worker.networkQueue, ^{
        worker.preparation(); worker.preparation = nil;
    });
    XCTAssertNil(worker.waiting);
    XCTAssertEqual(ft_earlyCrashTakeDelayInState(self.launch), 2u);
}
- (void)testUploadRestoresHistoryWithoutCrashAndRecordingStartsSeparately {
    XCTAssertTrue(NSThread.isMainThread);
    NSString *bundle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"Unknown";
    bundle = [bundle stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    NSString *directory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject
                           stringByAppendingPathComponent:@"FTCrash"] stringByAppendingPathComponent:bundle];
    directory = [directory stringByAppendingPathComponent:@"Data"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [directory stringByAppendingPathComponent:@"EarlyCrash.marker"];
    FTEarlyCrashState *previous = ft_earlyCrashCreate();
    ft_earlyCrashInitialize(previous, 100000000000, path.fileSystemRepresentation);
    ft_earlyCrashRecordInState(previous, 105000000000);
    ft_earlyCrashDestroy(previous);
    NSData *history = [NSData dataWithContentsOfFile:path];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0);
    dispatch_semaphore_t resume = dispatch_semaphore_create(0);
    dispatch_async(ft_earlyCrashPreparationQueue(), ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(resume, DISPATCH_TIME_FOREVER);
    });
    dispatch_semaphore_wait(entered, DISPATCH_TIME_FOREVER);
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:@"http://localhost"];
    config.autoSync = NO;
    @try {
        [FTSDKAgent startWithConfigOptions:config];
        // Block the I/O queue: SDK startup must return without touching history.
        XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], history);
    } @finally {
        dispatch_semaphore_signal(resume);
    }
    dispatch_sync(ft_earlyCrashPreparationQueue(), ^{});
    // The upload manager restores history even with autoSync and Crash off,
    // but must not create this launch's recording file.
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:path]);
    FTDataUploadWorker *production = [[FTTrackDataManager sharedInstance] valueForKey:@"dataUploadWorker"];
    XCTestExpectation *restored = [self expectationWithDescription:@"upload restores history without RUM/crash"];
    [production afterEarlyCrashPreparation:^{ [restored fulfill]; }];
    [self waitForExpectations:@[restored] timeout:5];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:path]);
    XCTAssertEqual([production nextAutomaticUploadDelay], 2);
    XCTAssertEqual([production nextAutomaticUploadDelay], 10);
    XCTAssertEqual([NSData dataWithContentsOfFile:path].length, 0u);

    // Crash setup prepares current-launch recording independently of upload.
    [FTCrash prepareEarlyCrashAtSDKStart:ft_earlyCrashNow()];
    dispatch_sync(ft_earlyCrashPreparationQueue(), ^{});
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path]);
    FTCrash_MonitorContext context = {0};
    const uint64_t capture = ft_earlyCrashStartTime() + UINT64_C(4999000000);
    // Exact occurrence time is independent of test-host/SDK startup duration.
    context.earlyCrashTime = capture;
    context.requirements.shouldWriteReport = true;
    ftcrash_prepareEventForRecording(&context); // nonfatal
    context.requirements.isFatal = true; context.currentSnapshotUserReported = true;
    ftcrash_prepareEventForRecording(&context); // manually reported
    context.currentSnapshotUserReported = false; context.requirements.shouldWriteReport = false;
    ftcrash_prepareEventForRecording(&context); // reporting disabled
    context.requirements.shouldWriteReport = true; context.earlyCrashTime = 0;
    ftcrash_prepareEventForRecording(&context); // missing time
    context.earlyCrashTime = capture + 6000000000;
    ftcrash_prepareEventForRecording(&context); // late event
    XCTAssertEqual([NSData dataWithContentsOfFile:path].length, 0u);
    context.earlyCrashTime = capture;
    callbackProcessingTime = capture;
    callbackMarkerPath = path;
    ftcrash_setWillWriteCrashNotifyCallback(delayedWillWrite);
    @try {
        XCTAssertTrue(ftcrash_prepareEventForRecording(&context));
        XCTAssertEqual(callbackProcessingTime, capture + UINT64_C(60000000000));
        XCTAssertEqual(markerDuringCallback.length, 24u);
    } @finally {
        ftcrash_setWillWriteCrashNotifyCallback(NULL);
        callbackMarkerPath = nil; markerDuringCallback = nil;
    }
    NSData *current = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(current.length, 24u);
    context.earlyCrashTime = capture + 1000000000;
    ftcrash_prepareEventForRecording(&context); // duplicate cannot overwrite original
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], current);
    [FTSDKAgent startWithConfigOptions:config];
    [FTSDKAgent shutDown];
    [FTSDKAgent startWithConfigOptions:config];
    production = [[FTTrackDataManager sharedInstance] valueForKey:@"dataUploadWorker"];
    XCTAssertEqual([production nextAutomaticUploadDelay], 10);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], current);
    [FTSDKAgent shutDown];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
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
