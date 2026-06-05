//
//  FTTrackDataManagerTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/29.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTNetworkInfoManager.h"
#import "FTTrackDataManager.h"
#import "FTTrackerEventDBTool+Test.h"
#import "OHHTTPStubs.h"
#import "FTJSONUtil.h"
#import "FTModelHelper.h"
#import "FTTestUtils.h"
#import "FTConstants.h"
#import "FTDBDataCachePolicy.h"
#import "FTTrackDataManager+Test.h"
#import "FTBaseInfoHandler.h"
#import "FTInnerLog.h"
#import "FTRequest.h"
#import "FTTrackDataManager+Test.h"
#import "FTDataUploadWorker.h"
#import "FTAppLifeCycle.h"
@interface FTTrackDataManagerTest : XCTestCase

@end
@interface FTDataUploadWorker (FTTrackDataManagerTest)
@property (nonatomic, assign, readonly) BOOL isUploading;
@property (nonatomic, assign, readonly) BOOL hasPendingUpload;
@property (nonatomic, strong, readonly) dispatch_queue_t networkQueue;
@end

@implementation FTTrackDataManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [FTNetworkInfoManager sharedInstance].setCompressionIntakeRequests(NO);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testEnableDBLimitDiscardNew{
    [self enableDBLimitDiscard:YES limitCount:NO];
}
- (void)testEnableDBLimitDiscardOld{
    [self enableDBLimitDiscard:NO limitCount:NO];
}
- (void)testEnableDBLimitDiscardNew_limitCount{
    [self enableDBLimitDiscard:YES limitCount:YES];
}
- (void)testEnableDBLimitDiscardOld_limitCount{
    [self enableDBLimitDiscard:NO limitCount:YES];
}
- (void)enableDBLimitDiscard:(BOOL)isNew limitCount:(BOOL)limitCount{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:isNew];
    if(limitCount){
        [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:10 discardNew:isNew];
        [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:10 discardNew:isNew];
    }
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<500; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscard %d",i]] type:FTAddDataLogging];
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscard RUM %d",i]] type:FTAddDataRUM];
        }
    }];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSLog(@"interval:%f",interval);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    FTRecordModel *rumModel = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    if(isNew){
        XCTAssertTrue([rumModel.data containsString:@"TEST DBLimitDiscard RUM 0"]);
    }else{
        XCTAssertFalse([model.data containsString:@"TEST DBLimitDiscard 0"]);
        XCTAssertFalse([rumModel.data containsString:@"TEST DBLimitDiscard RUM 0"]);
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);

    XCTAssertTrue(count > 20 && count < 1000);

    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 105*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_log{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataLogging];
        }
    }];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];

    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_logCountLimit{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:100 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataLogging];
        }
    }];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 100);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_log{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:40*1204 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataLogging];
        }
    }];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 60*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_logCountLimit{
    [FTLog enableLog:YES];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:70*1204 discardNew:NO];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:299 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataLogging];
        }
    }];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 0 && count < 1000);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 75*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_rum{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];

    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_RUMCountLimit{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:50 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 50);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_RUM{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 60*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_RUMCountLimit{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:NO];
    [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:50 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 50);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 60*1204);
    [FTTrackDataManager shutDown];
}
- (void)testTrackDataManagerShutDown{
    [self mockHttp];
    [FTLog enableLog:YES];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRumModel] type:FTAddDataRUM];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    NSNumber *isUploading = [worker valueForKey:@"isUploading"];
    XCTAssertTrue([isUploading boolValue] == NO);
    [[FTTrackDataManager sharedInstance] flushSyncData];
    NSNumber *isUploadingN = [worker valueForKey:@"isUploading"];
    XCTAssertTrue([isUploadingN boolValue] == YES);
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        [FTTrackDataManager shutDown];
    }];
    XCTAssertTrue(interval<0.1);
}
- (void)testDelayedUploadReservesUploadSlotBeforeUploadStarts{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertFalse(worker.isUploading);
    XCTAssertTrue(worker.hasPendingUpload);

    [NSThread sleepForTimeInterval:0.2];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertTrue(worker.isUploading);
    XCTAssertFalse(worker.hasPendingUpload);

    [FTTrackDataManager shutDown];
}
- (void)testDelayedUploadIgnoresNewFlushDuringTenSecondWait{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    [NSThread sleepForTimeInterval:0.2];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertTrue(worker.isUploading);
    XCTAssertFalse(worker.hasPendingUpload);

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertTrue(worker.isUploading);
    XCTAssertFalse(worker.hasPendingUpload);

    [FTTrackDataManager shutDown];
}
- (void)testAsyncCancelDelayedUploadDuringTenSecondWaitReleasesUploadSlot{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    [NSThread sleepForTimeInterval:0.2];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertTrue(worker.isUploading);
    XCTAssertFalse(worker.hasPendingUpload);

    [worker cancelAsynchronously];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertFalse(worker.isUploading);
    XCTAssertFalse(worker.hasPendingUpload);

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertFalse(worker.isUploading);
    XCTAssertTrue(worker.hasPendingUpload);

    [FTTrackDataManager shutDown];
}
- (void)testManualUploadCancelsPendingDelayedUpload{
    [self mockHttp];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRumModel] type:FTAddDataRUM];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertFalse(worker.isUploading);
    XCTAssertTrue(worker.hasPendingUpload);

    [[FTTrackDataManager sharedInstance] flushSyncData];

    XCTAssertTrue(worker.isUploading);
    XCTAssertFalse(worker.hasPendingUpload);

    [FTTrackDataManager shutDown];
}
- (void)testManualUploadCalledFromNetworkQueueDoesNotDeadlock{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    XCTestExpectation *expectation = [self expectationWithDescription:@"manual upload returns on network queue"];

    dispatch_async(worker.networkQueue, ^{
        [worker flushWithSleep:NO];
        [expectation fulfill];
    });

    [self waitForExpectations:@[expectation] timeout:1];
    [FTTrackDataManager shutDown];
}
- (void)testInsertCacheToDBSchedulesDelayedUploadWhenAutoSyncEnabled{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTTrackDataManager *manager = [FTTrackDataManager sharedInstance];
    [manager setValue:@YES forKey:@"autoSync"];
    FTDataUploadWorker *worker = manager.dataUploadWorker;

    [manager addTrackData:[FTModelHelper createLogModel:@"testInsertCacheToDBSchedulesDelayedUploadWhenAutoSyncEnabled"] type:FTAddDataLogging];
    [manager insertCacheToDB];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertTrue(worker.hasPendingUpload);
    XCTAssertFalse(worker.isUploading);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 1);
    [FTTrackDataManager shutDown];
}
- (void)testLifecycleFlushesLogCacheWithoutSchedulingUpload{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTTrackDataManager *manager = [FTTrackDataManager sharedInstance];
    [manager setValue:@YES forKey:@"autoSync"];
    FTDataUploadWorker *worker = manager.dataUploadWorker;

    [manager addTrackData:[FTModelHelper createLogModel:@"testLifecycleFlushesLogCacheWithoutSchedulingUpload"] type:FTAddDataLogging];
    [(id<FTAppLifeCycleDelegate>)manager applicationWillResignActive];
    dispatch_sync(worker.networkQueue, ^{});

    XCTAssertFalse(worker.hasPendingUpload);
    XCTAssertFalse(worker.isUploading);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 1);
    [FTTrackDataManager shutDown];
}
- (void)testSynchronousCancelCalledFromNetworkQueueDoesNotDeadlock{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    XCTestExpectation *expectation = [self expectationWithDescription:@"synchronous cancel returns on network queue"];

    dispatch_async(worker.networkQueue, ^{
        [worker cancelSynchronously];
        [expectation fulfill];
    });

    [self waitForExpectations:@[expectation] timeout:1];
    [FTTrackDataManager shutDown];
}
- (void)testShutdownCancelsPendingDelayedUploadBeforeStart{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    __block NSInteger requestCount = 0;
    NSString *urlStr = @"http://www.test.com/some/url/shutdown/pending";
    NSString *marker = @"testShutdownCancelsPendingDelayedUploadBeforeStart";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if (![request.URL.absoluteString containsString:urlStr]) {
            return NO;
        }
        NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        return [body containsString:marker];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (self) {
            requestCount++;
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");
    XCTAssertEqualObjects(manager.datakitUrl, urlStr);

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:marker] type:FTAddDataRUM];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;

    [worker flushWithSleep:YES];
    dispatch_sync(worker.networkQueue, ^{});
    XCTAssertTrue(worker.hasPendingUpload);
    [FTTrackDataManager shutDown];

    XCTestExpectation *unexpectedUpload = [self expectationWithDescription:@"pending upload should not start after shutdown"];
    unexpectedUpload.inverted = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @synchronized (self) {
            if (requestCount > 0) {
                [unexpectedUpload fulfill];
            }
        }
    });
    [self waitForExpectations:@[unexpectedUpload] timeout:0.5];
    @synchronized (self) {
        XCTAssertEqual(requestCount, 0);
    }
    [OHHTTPStubs removeStub:stub];
}
- (void)testDBReachHalfLimit{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:NO];

    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNEW %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    BOOL reachHalfLimit = [[FTTrackDataManager sharedInstance].dataCachePolicy reachHalfLimit];
    XCTAssertTrue(reachHalfLimit);
    [FTTrackDataManager shutDown];
}
- (void)testRUMCountReachHalfLimit{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:50 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<26; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    BOOL reachHalfLimit = [[FTTrackDataManager sharedInstance].dataCachePolicy reachHalfLimit];
    XCTAssertTrue(reachHalfLimit);
    [FTTrackDataManager shutDown];
}
- (void)testLogCountReachHalfLimit{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:50 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<26; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataLogging];
        }
    }];
    NSLog(@"interval:%f",interval);
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    BOOL reachHalfLimit = [[FTTrackDataManager sharedInstance].dataCachePolicy reachHalfLimit];
    XCTAssertTrue(reachHalfLimit);
    [FTTrackDataManager shutDown];
}
- (void)addLogBacklog:(NSInteger)count prefix:(NSString *)prefix{
    for (NSInteger i = 0; i < count; i++) {
        NSString *message = [NSString stringWithFormat:@"%@-%ld",prefix,(long)i];
        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:message] type:FTAddDataLogging];
    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
}
- (NSString *)uploadTypeForRequest:(NSURLRequest *)request{
    if ([request.URL.path hasSuffix:@"/v1/write/rum"]) {
        return @"rum";
    }
    if ([request.URL.path hasSuffix:@"/v1/write/logging"]) {
        return @"logging";
    }
    return request.URL.path;
}
- (void)testRUMUploadTakesPriorityOverLogBacklog{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/log-backlog";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (requestPaths) {
            [requestPaths addObject:[self uploadTypeForRequest:request]];
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        [self addLogBacklog:6 prefix:@"testRUMUploadTakesPriorityOverLogBacklog"];
        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testRUMUploadTakesPriorityOverLogBacklog-rum"] type:FTAddDataRUM];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertTrue(requestPaths.count > 0);
            XCTAssertEqualObjects(requestPaths.firstObject, @"rum");
        }
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testRUMInsertedDuringLogDrainWaitsForNextPass{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    __block BOOL insertedRUM = NO;
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/log-drain";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (requestPaths) {
            [requestPaths addObject:[self uploadTypeForRequest:request]];
        }
        if ([request.URL.path hasSuffix:@"/v1/write/logging"] && !insertedRUM) {
            insertedRUM = YES;
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testRUMInsertedDuringLogDrain"] type:FTAddDataRUM];
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        [self addLogBacklog:3 prefix:@"testRUMInsertedDuringLogDrainWaitsForNextPass"];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertEqual(requestPaths.count, 1);
            XCTAssertEqualObjects(requestPaths[0], @"logging");
        }
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM], 1);
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 2);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testRUMBacklogDrainsBeforeLogBacklog{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/weighted";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (requestPaths) {
            [requestPaths addObject:[self uploadTypeForRequest:request]];
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        for (int i = 0; i < 5; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"testRUMBacklogDrainsBeforeLogBacklog-rum-%d",i]] type:FTAddDataRUM];
        }
        [self addLogBacklog:2 prefix:@"testRUMBacklogDrainsBeforeLogBacklog-log"];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertEqual(requestPaths.count, 4);
            for (NSInteger index = 0; index < 3; index++) {
                XCTAssertEqualObjects(requestPaths[index], @"rum");
            }
            XCTAssertEqualObjects(requestPaths[3], @"logging");
        }
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM], 2);
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 1);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testLogOnlyBacklogUploadsOneBatchPerPass{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/log-only-drain";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (requestPaths) {
            [requestPaths addObject:[self uploadTypeForRequest:request]];
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        [self addLogBacklog:5 prefix:@"testLogOnlyBacklogUploadsOneBatchPerPass-log"];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertEqual(requestPaths.count, 1);
            XCTAssertEqualObjects(requestPaths[0], @"logging");
        }
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 4);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testLargeLogBacklogUploadsOneBatchPerPass{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/log-only-tail-drain-limit";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (requestPaths) {
            [requestPaths addObject:[self uploadTypeForRequest:request]];
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        [self addLogBacklog:12 prefix:@"testLargeLogBacklogUploadsOneBatchPerPass-log"];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertEqual(requestPaths.count, 1);
            XCTAssertEqualObjects(requestPaths[0], @"logging");
        }
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 11);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testLogRetryDoesNotPollRUMUntilNextPass{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    __block NSInteger logRequestCount = 0;
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/log-retry-yield";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        @synchronized (requestPaths) {
            [requestPaths addObject:[self uploadTypeForRequest:request]];
        }
        if ([request.URL.path hasSuffix:@"/v1/write/logging"]) {
            logRequestCount++;
            if (logRequestCount == 1) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testLogRetryDoesNotPollRUMUntilNextPass-rum"] type:FTAddDataRUM];
                });
                NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"retry later",@"code":@501}];
                return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:501 headers:nil];
            }
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        [self addLogBacklog:1 prefix:@"testLogRetryDoesNotPollRUMUntilNextPass-log"];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertEqual(requestPaths.count, 2);
            XCTAssertEqualObjects(requestPaths[0], @"logging");
            XCTAssertEqualObjects(requestPaths[1], @"logging");
        }
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM], 1);
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 0);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testLargeBacklogRetryShutdownStopsNextPassAndKeepsPendingData{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSMutableArray<NSString *> *requestPaths = [NSMutableArray array];
    __block NSInteger rumRequestCount = 0;
    __block NSInteger logRequestCount = 0;
    __block BOOL logStartedFulfilled = NO;
    dispatch_semaphore_t allowLogResponse = dispatch_semaphore_create(0);
    XCTestExpectation *logRequestStarted = [self expectationWithDescription:@"log request started"];
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/large-backlog-retry-shutdown";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *uploadType = [self uploadTypeForRequest:request];
        BOOL shouldFulfillLogStarted = NO;
        @synchronized (requestPaths) {
            [requestPaths addObject:uploadType];
            if ([uploadType isEqualToString:@"rum"]) {
                rumRequestCount++;
            } else if ([uploadType isEqualToString:@"logging"]) {
                logRequestCount++;
                if (!logStartedFulfilled) {
                    logStartedFulfilled = YES;
                    shouldFulfillLogStarted = YES;
                }
            }
        }
        if (shouldFulfillLogStarted) {
            [logRequestStarted fulfill];
        }
        if ([uploadType isEqualToString:@"logging"]) {
            dispatch_semaphore_wait(allowLogResponse, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
            NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"retry later",@"code":@501}];
            return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:501 headers:nil];
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    @try {
        for (int i = 0; i < 9; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"testLargeBacklogRetryShutdownStopsNextPassAndKeepsPendingData-rum-%d",i]] type:FTAddDataRUM];
        }
        [self addLogBacklog:30 prefix:@"testLargeBacklogRetryShutdownStopsNextPassAndKeepsPendingData-log"];

        [[FTTrackDataManager sharedInstance] flushSyncData];
        [self waitForExpectations:@[logRequestStarted] timeout:2];

        [FTTrackDataManager shutDown];
        dispatch_semaphore_signal(allowLogResponse);
        dispatch_sync(worker.networkQueue, ^{});

        @synchronized (requestPaths) {
            XCTAssertEqual(requestPaths.count, 4);
            if (requestPaths.count == 4) {
                XCTAssertEqualObjects(requestPaths[0], @"rum");
                XCTAssertEqualObjects(requestPaths[1], @"rum");
                XCTAssertEqualObjects(requestPaths[2], @"rum");
                XCTAssertEqualObjects(requestPaths[3], @"logging");
            }
            XCTAssertEqual(rumRequestCount, 3);
            XCTAssertEqual(logRequestCount, 1);
        }
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM], 6);
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 30);
    } @finally {
        dispatch_semaphore_signal(allowLogResponse);
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testRUMFailureDoesNotBlockLogUploadAttempt{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    __block NSInteger logRequestCount = 0;
    __block NSInteger rumRequestCount = 0;
    NSString *urlStr = @"http://www.test.com/some/url/rum-priority/rum-failure";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        if ([request.URL.path hasSuffix:@"/v1/write/logging"]) {
            logRequestCount++;
        }else if ([request.URL.path hasSuffix:@"/v1/write/rum"]) {
            rumRequestCount++;
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"retry later",@"code":@501}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:501 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setCompressionIntakeRequests(NO)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    @try {
        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testRUMFailureDoesNotBlockLogUploadAttempt-rum"] type:FTAddDataRUM];
        [self addLogBacklog:2 prefix:@"testRUMFailureDoesNotBlockLogUploadAttempt-log"];
        FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        XCTAssertEqual(rumRequestCount, 6);
        XCTAssertEqual(logRequestCount, 6);
        XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 2);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testRUMInsertClearsOldLogsWhenDatabaseIsOverLimit{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    @try {
        [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:20 discardNew:NO];
        NSString *largeMessage = [@"" stringByPaddingToLength:4096 withString:@"L" startingAtIndex:0];
        for (int i = 0; i < 120; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"testRUMInsertClearsOldLogsWhenDatabaseIsOverLimit-%d-%@",i,largeMessage]] type:FTAddDataLogging];
        }
        [[FTTrackDataManager sharedInstance] insertCacheToDB];
        NSInteger logCountBefore = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        long long dbSizeBefore = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
        [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:MAX(1, dbSizeBefore - 4096) discardNew:YES];

        NSString *rumMarker = @"testRUMInsertClearsOldLogsWhenDatabaseIsOverLimit-rum";
        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:rumMarker] type:FTAddDataRUM];

        NSArray *rumRecords = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        NSInteger logCountAfter = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        XCTAssertTrue(logCountAfter < logCountBefore);
        XCTAssertEqual(rumRecords.count, 1);
        FTRecordModel *rumRecord = rumRecords.firstObject;
        XCTAssertTrue([rumRecord.data containsString:rumMarker]);
    } @finally {
        [FTTrackDataManager shutDown];
    }
}
- (void)testRUMInsertClearsOldLogsWithinLogLimitWhenDatabaseIsOverLimit{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    @try {
        NSString *largeMessage = [@"" stringByPaddingToLength:4096 withString:@"R" startingAtIndex:0];
        for (int i = 0; i < 40; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"testRUMInsertClearsOldLogsWithinLogLimitWhenDatabaseIsOverLimit-rum-%d-%@",i,largeMessage]] type:FTAddDataRUM];
        }
        [self addLogBacklog:5 prefix:@"testRUMInsertClearsOldLogsWithinLogLimitWhenDatabaseIsOverLimit-log"];
        NSInteger logCountBefore = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        NSInteger rumCountBefore = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
        long long dbSizeBefore = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
        [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:MAX(1, dbSizeBefore - 4096) discardNew:YES];

        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testRUMInsertClearsOldLogsWithinLogLimitWhenDatabaseIsOverLimit-new-rum"] type:FTAddDataRUM];

        NSInteger logCountAfter = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        NSInteger rumCountAfter = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
        XCTAssertTrue(logCountAfter < logCountBefore);
        XCTAssertEqual(rumCountAfter, rumCountBefore + 1);
    } @finally {
        [FTTrackDataManager shutDown];
    }
}
- (void)testRUMInsertDeletesLogsBeforeGlobalOldestDataWhenDatabaseIsOverLimit{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    @try {
        [self addLogBacklog:5 prefix:@"testRUMInsertDeletesLogsBeforeGlobalOldestDataWhenDatabaseIsOverLimit-log"];
        NSString *largeMessage = [@"" stringByPaddingToLength:4096 withString:@"R" startingAtIndex:0];
        for (int i = 0; i < 120; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"testRUMInsertDeletesLogsBeforeGlobalOldestDataWhenDatabaseIsOverLimit-rum-%d-%@",i,largeMessage]] type:FTAddDataRUM];
        }
        NSInteger logCountBefore = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        long long dbSizeBefore = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
        [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:MAX(1, dbSizeBefore - 100 * 1024) discardNew:NO];

        NSString *rumMarker = @"testRUMInsertDeletesLogsBeforeGlobalOldestDataWhenDatabaseIsOverLimit-new-rum";
        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:rumMarker] type:FTAddDataRUM];

        NSInteger logCountAfter = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        NSArray *rumRecords = [[FTTrackerEventDBTool sharedManager] getFirstRecords:200 withType:FT_DATA_TYPE_RUM];
        XCTAssertTrue(logCountAfter < logCountBefore);
        XCTAssertEqual(logCountAfter, 0);
        XCTAssertTrue(rumRecords.count > 0);
        BOOL hasNewRUM = NO;
        for (FTRecordModel *rumRecord in rumRecords) {
            if ([rumRecord.data containsString:rumMarker]) {
                hasNewRUM = YES;
                break;
            }
        }
        XCTAssertTrue(hasNewRUM);
    } @finally {
        [FTTrackDataManager shutDown];
    }
}
- (void)testLogInsertDoesNotDeleteRUMWhenDatabaseIsOverLimitWithoutOldLogs{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    @try {
        NSString *largeMessage = [@"" stringByPaddingToLength:4096 withString:@"R" startingAtIndex:0];
        for (int i = 0; i < 40; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"testLogInsertDoesNotDeleteRUMWhenDatabaseIsOverLimitWithoutOldLogs-rum-%d-%@",i,largeMessage]] type:FTAddDataRUM];
        }
        NSInteger rumCountBefore = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
        long long dbSizeBefore = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
        [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:MAX(1, dbSizeBefore - 4096) discardNew:NO];

        [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:@"testLogInsertDoesNotDeleteRUMWhenDatabaseIsOverLimitWithoutOldLogs-log"] type:FTAddDataLogging];
        [[FTTrackDataManager sharedInstance] insertCacheToDB];

        NSInteger logCountAfter = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        NSInteger rumCountAfter = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
        XCTAssertEqual(logCountAfter, 0);
        XCTAssertEqual(rumCountAfter, rumCountBefore);
    } @finally {
        [FTTrackDataManager shutDown];
    }
}
/**
 * packageId remains unchanged
 * sdk_id changes
 * Request count: normal sync + retry count (5) = 6
 */
- (void)testNetworkFail_NetworkRetry{
    [FTTrackDataManager shutDown];
    [FTLog enableLog:YES];
    NSMutableArray<NSInputStream *> *datas = [NSMutableArray new];
    NSMutableSet *set = [[NSMutableSet alloc]init];
    NSString *urlStr = @"http://www.test.com/some/url/retry";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if ([request.URL.absoluteString containsString:urlStr]) {
            NSString *str = [request.allHTTPHeaderFields valueForKey:@"X-Pkg-Id"];
            if(str){
                [set addObject:[request.allHTTPHeaderFields valueForKey:@"X-Pkg-Id"]];
                [datas addObject:request.HTTPBodyStream];
            }
            return YES;
        }
        return NO;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@501}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:501 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setSdkVersion(@"RequestTest");

    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];

    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testNetworkFail_NetworkRetry"] type:FTAddDataRUM];

    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    @try {
        CFTimeInterval startTime = CACurrentMediaTime();
        NSString *packageId = [FTRumRequest.serialGenerator getCurrentSerialNumber];
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});
        CFTimeInterval endTime = CACurrentMediaTime();
        CFTimeInterval duration = endTime-startTime;
        NSLog(@"endTime-startTime:%f",duration);
        XCTAssertTrue(duration>7 && duration<9);
        NSString *endPackageId = [FTRumRequest.serialGenerator getCurrentSerialNumber];
        XCTAssertTrue([endPackageId isEqualToString:packageId]);
        XCTAssertTrue(set.count == 6);


        NSString *first = [[NSString alloc]initWithData:[FTTestUtils transStreamToData:datas.firstObject] encoding:NSUTF8StringEncoding];
        NSString *last = [[NSString alloc]initWithData:[FTTestUtils transStreamToData:datas.lastObject] encoding:NSUTF8StringEncoding];

        [self compareSdkID:first second:last increase:0];
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)testNetworkFail_403RetryAndKeepData{
    [self verifyUploadRetryAndKeepDataWithStatusCode:403];
}
- (void)testNetworkFail_429RetryAndKeepData{
    [self verifyUploadRetryAndKeepDataWithStatusCode:429];
}
- (void)testShutdownStopsRetryForInFlightFailedUpload{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    __block NSInteger requestCount = 0;
    __block BOOL startedFulfilled = NO;
    dispatch_semaphore_t allowResponse = dispatch_semaphore_create(0);
    XCTestExpectation *requestStarted = [self expectationWithDescription:@"first failed request started"];
    NSString *urlStr = @"http://www.test.com/some/url/shutdown/fail";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        BOOL shouldWait = NO;
        @synchronized (self) {
            requestCount++;
            shouldWait = requestCount == 1;
            if (!startedFulfilled) {
                startedFulfilled = YES;
                [requestStarted fulfill];
            }
        }
        if (shouldWait) {
            dispatch_semaphore_wait(allowResponse, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@403}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:403 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testShutdownStopsRetryForInFlightFailedUpload"] type:FTAddDataRUM];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    [[FTTrackDataManager sharedInstance] flushSyncData];
    [self waitForExpectations:@[requestStarted] timeout:2];

    [FTTrackDataManager shutDown];
    dispatch_semaphore_signal(allowResponse);
    dispatch_sync(worker.networkQueue, ^{});

    @synchronized (self) {
        XCTAssertEqual(requestCount, 1);
    }
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getUploadDatasCount], 1);
    [OHHTTPStubs removeStub:stub];
}
- (void)testShutdownCommitsSuccessfulInFlightUploadAndStopsNextBatch{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    __block NSInteger requestCount = 0;
    __block BOOL startedFulfilled = NO;
    dispatch_semaphore_t allowResponse = dispatch_semaphore_create(0);
    XCTestExpectation *requestStarted = [self expectationWithDescription:@"first successful request started"];
    NSString *urlStr = @"http://www.test.com/some/url/shutdown/success";
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        BOOL shouldWait = NO;
        @synchronized (self) {
            requestCount++;
            shouldWait = requestCount == 1;
            if (!startedFulfilled) {
                startedFulfilled = YES;
                [requestStarted fulfill];
            }
        }
        if (shouldWait) {
            dispatch_semaphore_wait(allowResponse, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
        }
        NSString *data = [FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        return [OHHTTPStubsResponse responseWithData:[data dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setSdkVersion(@"RequestTest");

    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testShutdownCommitsSuccessfulInFlightUploadAndStopsNextBatch-1"] type:FTAddDataRUM];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testShutdownCommitsSuccessfulInFlightUploadAndStopsNextBatch-2"] type:FTAddDataRUM];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    [[FTTrackDataManager sharedInstance] flushSyncData];
    [self waitForExpectations:@[requestStarted] timeout:2];

    [FTTrackDataManager shutDown];
    dispatch_semaphore_signal(allowResponse);
    dispatch_sync(worker.networkQueue, ^{});

    @synchronized (self) {
        XCTAssertEqual(requestCount, 1);
    }
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getUploadDatasCount], 1);
    [OHHTTPStubs removeStub:stub];
}
- (void)testRequestCreationFailureStopsUploadWithoutRetry{
    [FTTrackDataManager shutDown];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [[FTNetworkInfoManager sharedInstance] clearUploadInfo];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:1 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testRequestCreationFailureStopsUploadWithoutRetry"] type:FTAddDataRUM];
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;

    CFTimeInterval startTime = CACurrentMediaTime();
    [[FTTrackDataManager sharedInstance] flushSyncData];
    dispatch_sync(worker.networkQueue, ^{});
    CFTimeInterval duration = CACurrentMediaTime() - startTime;

    XCTAssertTrue(duration < 1);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getUploadDatasCount], 1);
    [FTTrackDataManager shutDown];
}
- (void)verifyUploadRetryAndKeepDataWithStatusCode:(NSInteger)statusCode{
    [FTTrackDataManager shutDown];
    [FTLog enableLog:YES];
    __block NSInteger requestCount = 0;
    NSString *urlStr = [NSString stringWithFormat:@"http://www.test.com/some/url/retry/%ld",(long)statusCode];
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        requestCount++;
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@(statusCode)}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:(int)statusCode headers:nil];
    }];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setSdkVersion(@"RequestTest");

    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];

    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"testNetworkFail_%ldRetryAndKeepData",(long)statusCode]] type:FTAddDataRUM];

    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    @try {
        [[FTTrackDataManager sharedInstance] flushSyncData];
        dispatch_sync(worker.networkQueue, ^{});

        XCTAssertTrue(requestCount == 6);
        XCTAssertTrue([[FTTrackerEventDBTool sharedManager] getUploadDatasCount] == 1);
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}

- (void)testNetworkSuccessIncreasePackageID{
    NSMutableArray<NSInputStream *> *datas = [NSMutableArray new];
    __block id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        NSString *packageId = [request.allHTTPHeaderFields valueForKey:@"X-Pkg-Id"];
        XCTAssertTrue(packageId);
        XCTAssertTrue([packageId hasPrefix:@"rumm-"]);
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [datas addObject:request.HTTPBodyStream];
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];

    NSString *urlStr = @"http://www.test.com/some/url/string";
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setSdkVersion(@"RequestTest");

    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    @try {
        NSString *logStartNum = [FTLoggingRequest.serialGenerator getCurrentSerialNumber];
        for (int i = 0; i<2; i++) {
            FTRecordModel *model = [FTModelHelper createRumModel];
            [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];

            [[FTTrackDataManager sharedInstance] flushSyncData];
            dispatch_sync(worker.networkQueue, ^{});
        }
        NSString *logEndtNum = [FTLoggingRequest.serialGenerator getCurrentSerialNumber];
        XCTAssertTrue([logEndtNum isEqualToString:logStartNum]);
        XCTAssertTrue(datas.count == 2);

        NSString *bodyStr = [[NSString alloc]initWithData:[FTTestUtils transStreamToData:datas.firstObject] encoding:NSUTF8StringEncoding];
        NSString *bodyStr2 = [[NSString alloc]initWithData:[FTTestUtils transStreamToData:datas.lastObject] encoding:NSUTF8StringEncoding];
        [self compareSdkID:bodyStr second:bodyStr2 increase:1];
    } @finally {
        [FTTrackDataManager shutDown];
        [OHHTTPStubs removeStub:stub];
    }
}
- (void)compareSdkID:(NSString *)first second:(NSString*)second increase:(int)increase{
    XCTAssertFalse([first isEqualToString:second]);
    NSArray *array1 = [first componentsSeparatedByString:@","];
    NSArray *array2 = [second componentsSeparatedByString:@","];
    __block NSString *sdk_data_id1;
    __block NSString *sdk_data_id2;
    [array1 enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj containsString:@"sdk_data_id"]) {
            sdk_data_id1 = obj;
            *stop = YES;
        }
    }];
    [array2 enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj containsString:@"sdk_data_id"]) {
            sdk_data_id2 = obj;
            *stop = YES;
        }
    }];
    array1 = [[sdk_data_id1 substringFromIndex:12] componentsSeparatedByString:@"."];
    array2 = [[sdk_data_id2 substringFromIndex:12] componentsSeparatedByString:@"."];
    // packageId +1
    XCTAssertTrue([FTTestUtils base36ToDecimal:array2[0]] - [FTTestUtils base36ToDecimal:array1[0]] == increase);
    // Process id is consistent
    XCTAssertTrue([array1[1] isEqualToString:array2[1]]);
    // Data count
    XCTAssertTrue([array2[2] intValue] == [array1[2] intValue] == 1);
    // packageId end random number
    NSString *random12 = array2[3];
    XCTAssertTrue(random12.length == 12);

    XCTAssertFalse([array2[3] isEqualToString:array1[3]]);
    // Data id is inconsistent
    XCTAssertFalse([[array1 lastObject] isEqualToString:[array2 lastObject]]);
}
- (void)mockHttp{
    __block id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        sleep(1);
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        [OHHTTPStubs removeStub:stub];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
    NSString *urlStr = @"http://www.test.com/some/url/string";
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setUploadURL(urlStr,nil,nil)
        .setSdkVersion(@"RequestTest");
}
- (void)testShutdown{
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[@"success" dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    NSInteger count = 0;
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [[FTTrackDataManager sharedInstance] updateAutoSync:NO syncPageSize:100 syncSleepTime:100];
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRumModel] type:FTAddDataRUM];
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel] type:FTAddDataLogging];
            [[FTTrackDataManager sharedInstance] flushSyncData];
            dispatch_group_leave(group);
        });
        dispatch_group_enter(group);
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [FTTrackDataManager shutDown];
            dispatch_async(dispatch_get_main_queue(), ^{
                [FTTrackDataManager startWithAutoSync:YES syncPageSize:10 syncSleepTime:0];
                [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:NO size:50 discardNew:YES];
                [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:500000 discardNew:YES];
                [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:500000 discardNew:YES];
                dispatch_group_leave(group);
            });
        });
        count ++;
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    XCTAssertTrue(count == 1000);
    [FTTrackDataManager shutDown];
    [OHHTTPStubs removeStub:stubs];
}
@end
