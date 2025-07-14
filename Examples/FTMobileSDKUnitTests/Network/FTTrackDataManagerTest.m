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
#import "FTLog+Private.h"
#import "FTRequest.h"
#import "FTTrackDataManager+Test.h"
#import "FTDataUploadWorker.h"
@interface FTTrackDataManagerTest : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;

@end

@implementation FTTrackDataManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
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
    NSLog(@"interval:%f",interval);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    FTRecordModel *rumModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    if(isNew){
        XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscard 0"]);
        XCTAssertTrue([rumModel.data containsString:@"TEST DBLimitDiscard RUM 0"]);
    }else{
        XCTAssertFalse([model.data containsString:@"TEST DBLimitDiscard 0"]);
        XCTAssertFalse([rumModel.data containsString:@"TEST DBLimitDiscard RUM 0"]);
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    
    XCTAssertTrue(count > 20 && count < 1000);
    
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 105*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_log{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataLogging];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_logCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:100 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataLogging];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 100);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_log{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:40*1204 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataLogging];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 60*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_logCountLimit{
    [FTLog enableLog:YES];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:70*1204 discardNew:NO];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:299 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataLogging];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 299);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 75*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_rum{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardNew_RUMCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:YES];
    [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:50 discardNew:YES];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardNew %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 50);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertTrue([model.data containsString:@"TEST DBLimitDiscardNew 0"]);
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_RUM{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count < 1000);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 60*1204);
    [FTTrackDataManager shutDown];
}
- (void)testEnableDBLimitDiscardOld_RUMCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:YES size:60*1204 discardNew:NO];
    [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:50 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<1000; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataRUM];
        }
    }];
    NSLog(@"interval:%f",interval);
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"count:%ld",(long)count);
    XCTAssertTrue(count > 50);
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"TEST DBLimitDiscardOld 0"]);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
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
- (void)testDBReachHalfLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:50 discardNew:NO];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        for (int i=0; i<26; i++) {
            [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createLogModel:[NSString stringWithFormat:@"TEST DBLimitDiscardOld %d",i]] type:FTAddDataLogging];
        }
    }];
    NSLog(@"interval:%f",interval);
    BOOL reachHalfLimit = [[FTTrackDataManager sharedInstance].dataCachePolicy reachHalfLimit];
    XCTAssertTrue(reachHalfLimit);
    [FTTrackDataManager shutDown];
}
/**
 * packageId 不变
 * sdk_id 变化
 * 请求次数：正常同步 + retry count (5) = 6
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
    manager.setDatakitUrl(urlStr)
        .setSdkVersion(@"RequestTest");
    
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
   
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRUMModel:@"testNetworkFail_NetworkRetry"] type:FTAddDataRUM];
  
    self.expectation = [self expectationWithDescription:@"isUploadingEqualNO"];
    [[FTTrackDataManager sharedInstance].dataUploadWorker addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    CFTimeInterval startTime = CACurrentMediaTime();
    NSString *packageId = [FTRumRequest.serialGenerator getCurrentSerialNumber];
    [[FTTrackDataManager sharedInstance] flushSyncData];
    [self waitForExpectations:@[self.expectation]];
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
    [FTTrackDataManager shutDown];
    [OHHTTPStubs removeStub:stub];
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    
    NSString *urlStr = @"http://www.test.com/some/url/string";
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setDatakitUrl(urlStr)
        .setSdkVersion(@"RequestTest");
    
    [[FTTrackDataManager sharedInstance].dataUploadWorker addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    NSString *logStartNum = [FTLoggingRequest.serialGenerator getCurrentSerialNumber];
    for (int i = 0; i<2; i++) {
        self.expectation = [self expectationWithDescription:@"isUploadingEqualNO"];
        FTRecordModel *model = [FTModelHelper createRumModel];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];

        [[FTTrackDataManager sharedInstance] flushSyncData];
        [self waitForExpectations:@[self.expectation]];
    }
    NSString *logEndtNum = [FTLoggingRequest.serialGenerator getCurrentSerialNumber];
    XCTAssertTrue([logEndtNum isEqualToString:logStartNum]);
    XCTAssertTrue(datas.count == 2);
    
    NSString *bodyStr = [[NSString alloc]initWithData:[FTTestUtils transStreamToData:datas.firstObject] encoding:NSUTF8StringEncoding];
    NSString *bodyStr2 = [[NSString alloc]initWithData:[FTTestUtils transStreamToData:datas.lastObject] encoding:NSUTF8StringEncoding];
    [self compareSdkID:bodyStr second:bodyStr2 increase:1];
 
    [FTTrackDataManager shutDown];
    [OHHTTPStubs removeStub:stub];
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
    // 进程 id 一致
    XCTAssertTrue([array1[1] isEqualToString:array2[1]]);
    // 数据个数
    XCTAssertTrue([array2[2] intValue] == [array1[2] intValue] == 1);
    // packageId 末尾12位随机数
    NSString *random12 = array2[3];
    XCTAssertTrue(random12.length == 12);
    
    XCTAssertFalse([array2[3] isEqualToString:array1[3]]);
    // 数据 id 不一致
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
    manager.setDatakitUrl(urlStr)
        .setSdkVersion(@"RequestTest");
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"isUploading"]){
        FTDataUploadWorker *worker = object;
        NSNumber *isUploading = [worker valueForKey:@"isUploading"];
        BOOL uploadingEqualNO = [self.expectation.description isEqualToString:@"isUploadingEqualNO"];
        if(isUploading.boolValue == !uploadingEqualNO){
            [self.expectation fulfill];
            self.expectation = nil;
        }
    }
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
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [FTTrackDataManager shutDown];
            dispatch_async(dispatch_get_main_queue(), ^{
                [FTTrackDataManager startWithAutoSync:YES syncPageSize:10 syncSleepTime:0];
                [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:NO size:50 discardNew:YES];
                [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:500000 discardNew:YES];
                [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:500000 discardNew:YES];
                
            });
        });
        count ++;
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    XCTAssertTrue(count == 1000);
    [OHHTTPStubs removeStub:stubs];
}
@end
