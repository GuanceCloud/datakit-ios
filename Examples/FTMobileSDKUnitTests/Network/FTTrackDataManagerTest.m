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
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:isNew];
    if(limitCount){
        [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:100 discardNew:isNew];
        [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:50 discardNew:isNew];
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
    
    XCTAssertTrue(count > 150 && count < 1000);
    
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    NSLog(@"size:%ld",(long)size);
    XCTAssertTrue(size <= 65*1204);
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardNew_log{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:YES];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardNew_logCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:YES];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardOld_log{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:40*1204 discardNew:NO];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardOld_logCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:NO];
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
    XCTAssertTrue(size <= 60*1204);
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardNew_rum{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:YES];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardNew_RUMCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:YES];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardOld_RUM{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:NO];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testEnableDBLimitDiscardOld_RUMCountLimit{
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    [[FTTrackDataManager sharedInstance] setDBLimitWithSize:60*1204 discardNew:NO];
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
    [[FTTrackDataManager sharedInstance] shutDown];
}
- (void)testTrackDataManagerShutDown{
    [self mockHttp];
    [FTTrackDataManager sharedInstance];
    [FTModelHelper createRumModel];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRumModel] type:FTAddDataRUM];
    self.expectation = [self expectationWithDescription:@"异步操作timeout"];
    [[FTTrackDataManager sharedInstance] addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    [[FTTrackDataManager sharedInstance] uploadTrackData];
    [self waitForExpectations:@[self.expectation] timeout:2];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        [[FTTrackDataManager sharedInstance] shutDown];
    }];
    XCTAssertTrue(interval<0.1);
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
        FTTrackDataManager *manager = object;
        NSNumber *isUploading = [manager valueForKey:@"isUploading"];
        if(isUploading.boolValue){
            [self.expectation fulfill];
            self.expectation = nil;
        }
    }
}
@end
