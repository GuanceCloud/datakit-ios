//
//  ft_sdk_iosTestUnitTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/19.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import <FTLocationManager.h>
#import "AppDelegate.h"
#import <FTUploadTool.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/Network/NSURLRequest+FTMonitor.h>
#import <objc/runtime.h>
#import "FTMonitorManager+Test.h"


#define WAIT                                                                \
do {                                                                        \
[self expectationForNotification:@"LCUnitTest" object:nil handler:nil]; \
[self waitForExpectationsWithTimeout:10 handler:nil];                   \
} while(0);
#define NOTIFY                                                                            \
do {                                                                                      \
[[NSNotificationCenter defaultCenter] postNotificationName:@"LCUnitTest" object:nil]; \
} while(0);
@interface FTMobileAgentTests : XCTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *akId;
@property (nonatomic, copy) NSString *akSecret;
@property (nonatomic, copy) NSString *token;

@end


@implementation FTMobileAgentTests

- (void)setUp {
    /**
     * 设置 ft-sdk-iosTestUnitTests 的 Environment Variables
     * 额外 添加 isUnitTests = 1 防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.akId =[processInfo environment][@"ACCESS_KEY_ID"];
    self.akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    self.token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.traceConsoleLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
/**
 * 测试是否能够获取地理位置
 */
- (void)testLocation{
    FTLocationManager *location = [[FTLocationManager alloc]init];
    location.updateLocationBlock = ^(FTLocationInfo * _Nonnull locInfo, NSError * _Nullable error) {
        XCTAssertTrue(locInfo.province.length>0||locInfo.city.length>0);
    };
}
#pragma mark ========== property ==========
- (void)testSetEmptyUUID{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTRecordModel new];
    model.op = FTNetworkingTypeMetrics;
    
    NSDictionary *data =@{FT_AGENT_OP:FT_TRACK_OP_CUSTOM,
                          FT_AGENT_OPDATA:@{
                                  FT_AGENT_MEASUREMENT:@"TestUnitTests",
                                  FT_AGENT_FIELD:@{@"test":@"testSetUUID"},
                          },
    };
    model.data = [FTBaseInfoHander ft_convertToJsonData:data];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *uuid = [request.allHTTPHeaderFields valueForKey:@"X-Datakit-UUID"];
    XCTAssertTrue(uuid.length>0);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetUUID{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.XDataKitUUID = @"testXDataKitUUID";
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] trackBackground:@"TestUnitTests" field:@{@"test":@"testSetUUID"}];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *uuid = [request.allHTTPHeaderFields valueForKey:@"X-Datakit-UUID"];
    XCTAssertTrue([uuid isEqualToString:@"testXDataKitUUID"]);
    [[FTMobileAgent sharedInstance] resetInstance];
    
}
-(void)testSetEmptyServiceName{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableTrackAppCrash = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] _loggingExceptionInsertWithContent:@"testSetEmptyServiceName" tm:[[NSDate date] ft_dateTimestamp]];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[@"tags"];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICENAME];
    XCTAssertTrue(serviceName.length>0);
    [[FTMobileAgent sharedInstance] resetInstance];
}

-(void)testSetServiceName{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.traceServiceName = @"testSetServiceName";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[@"tags"];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICENAME];
    XCTAssertTrue([serviceName isEqualToString:@"testSetServiceName"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * source
 */
- (void)testSetEmptySource{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptySource" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *body = [request ft_getBodyData:YES];
    NSArray *bodyArray = [body componentsSeparatedByString:@","];
    XCTAssertTrue([[bodyArray firstObject] isEqualToString:@"ft_mobile_sdk_ios"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetSource{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.source = @"iOSTest";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] logging:@"testSetSource" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *body = [request ft_getBodyData:YES];
    NSArray *bodyArray = [body componentsSeparatedByString:@","];
    XCTAssertTrue([[bodyArray firstObject] isEqualToString:@"iOSTest"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetEmptyEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.source = @"iOSTest";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    for (int i=0; i<21; i++) {
        [[FTMobileAgent sharedInstance] logging:@"testSetEmptyEnv" status:FTStatusInfo];
    }
    [NSThread sleepForTimeInterval:2];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *body = [request ft_getBodyData:YES];
    NSString *env = @"__env=dev";
    XCTAssertTrue([body containsString:env]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.source = @"iOSTest";
    config.env = @"testSetEnv";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    for (int i=0; i<21; i++) {
        [[FTMobileAgent sharedInstance] logging:@"testSetEnv" status:FTStatusInfo];
    }
    [NSThread sleepForTimeInterval:2];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *body = [request ft_getBodyData:YES];
    NSString *env = @"__env=testSetEnv";
    XCTAssertTrue([body containsString:env]);
    [[FTMobileAgent sharedInstance] resetInstance];
}

- (void)testSetEmptyToken{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:nil akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTRecordModel new];
    model.op = FTNetworkingTypeMetrics;
    NSDictionary *data =@{FT_AGENT_OP:@"Test",
                          FT_AGENT_OPDATA:@{
                              FT_AGENT_MEASUREMENT:@"iOSTest",
                              FT_AGENT_FIELD:@{@"name":@"testSetEmptyToken"},
                          },
    };
    model.data = [FTBaseInfoHander ft_convertToJsonData:data];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        if (statusCode != 200) {
            NSError *errors;
            NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&errors];
            XCTAssertTrue([responseObject[@"errorCode"] isEqualToString:@"dataway.tokenRequiredOnOpenWay"]);
        }
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetIllegalToken{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:@"1111" akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] trackBackground:@"iOSTest" field:@{@"test":@"testSetIllegalToken"}];
    [[FTMobileAgent sharedInstance] trackBackground:@"iOSTest" field:@{@"test":@"testSetIllegalToken"}];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * url 为 空字符串
 * 验证标准：url为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
 */
- (void)testSetEmptyUrl{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"" datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
- (void)testIllegalUrl{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:[NSString stringWithFormat:@"%@11",self.url] datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] trackBackground:@"iOSTest" field:@{@"test":@"testIllegalUrl"}];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}

/**
 * akId 为 空字符串
 * 验证标准：akId为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
 */
- (void)testSetEmptyAkId{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:@"" akSecret:self.akSecret enableRequestSigning:YES];
    
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
- (void)testSetIllegalAkId{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:@"aaaaa" akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] trackBackground:@"iOSTest" field:@{@"test":@"testSetIllegalAkId"}];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
//        XCTAssertTrue(statusCode != 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}

/**
 * akSecret 为 空字符串
 * 验证标准：akSecret 为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
 */
- (void)testSetEmptyAkSecret{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:@"" enableRequestSigning:YES];
    
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
- (void)testSetIllegalAkSecret{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:@"aaaa" enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] trackBackground:@"iOSTest" field:@{@"test":@"testSetIllegalAkSecret"}];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
//        XCTAssertTrue(statusCode != 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * token\url\akid\aksecret 正确
 */
- (void)testConfigSetRight{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] trackBackground:@"Test" field:@{@"test":@"testConfigSetRight"}];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
#pragma mark ========== 数据同步 ==========
/**
 * 测试主动埋点是否成功
 */
- (void)testTrackBackgroundMethod {
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    [self setRightSDKConfig];
    NSString *uuid = [NSUUID UUID].UUIDString;
    [[FTMobileAgent sharedInstance] trackBackground:@"iOSTest" field:@{@"event":uuid}];
    [NSThread sleepForTimeInterval:2];//写入数据库方法是异步的
    NSArray *data = [[FTTrackerEventDBTool sharedManger]getFirstTenData:FTNetworkingTypeMetrics];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict =  [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSString *event = field[@"event"];
    XCTAssertEqualObjects(event, uuid);
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testTrackImmediateMethod{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] trackImmediate:@"iOSTest" tags:@{@"name":@"test"} field:@{@"test":@"testTrackImmediateMethod"} callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testTrackImmediateListMethod{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
       [self setRightSDKConfig];
    FTTrackBean *bean = [FTTrackBean new];
    bean.measurement = @"iOSTest";
    bean.field =@{@"test":@"testTrackImmediateListMethod"};
    bean.tags = @{@"name":@"1"};
    FTTrackBean *bean2 = [FTTrackBean new];
    bean2.measurement = @"iOSTest";
    bean2.field =@{@"test":@"testTrackImmediateListMethod"};
    bean2.tags = @{@"name":@"2"};
    [[FTMobileAgent sharedInstance] trackImmediateList:@[bean,bean2] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
          XCTAssertNil(error);
      }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testLoggingMethod {
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.source = @"iOSTest";
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSString *uuid = [NSUUID UUID].UUIDString;
    [[FTMobileAgent sharedInstance] logging:uuid status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger]getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict =  [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSString *content = field[@"__content"];
    XCTAssertTrue([content containsString:uuid]);
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * SDK内部使用 无公开方法
 */
- (void)testObjectMethod{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    [self setRightSDKConfig];
    NSString *uuid =[NSUUID UUID].UUIDString;
    NSDictionary *tag = @{FT_KEY_CLASS:@"iOSTest"};
    NSDictionary *dict = @{FT_KEY_NAME:uuid,
                           FT_KEY_TAGS:tag,
                           FT_AGENT_OP:FTNetworkingTypeObject
    };
    FTRecordModel *model = [FTRecordModel new];
    model.op = FTNetworkingTypeObject;
    model.data = [FTBaseInfoHander ft_convertToJsonData:dict];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
    
}
#pragma mark ========== 用户数据绑定 ==========
/**
 * 测试 绑定用户
 * 验证：从数据库取出新数据 验证数据绑定的用户信息 是否与绑定的一致
 */
- (void)testBindUser{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
    
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstTenBindUserData:FTNetworkingTypeMetrics];
    FTRecordModel *model = [data lastObject];
    NSDictionary *userData = [FTBaseInfoHander ft_dictionaryWithJsonString:model.userdata];
    XCTAssertTrue(newCount>count);
    XCTAssertTrue([userData[@"name"] isEqualToString:@"bindUser"]);
    XCTAssertTrue([userData[@"id"] isEqualToString:@"bindUserId"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * 测试 切换用户
 * 验证： 判断切换用户前后 获取上传信息里用户信息是否正确
 */
-(void)testChangeUser{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenBindUserData:FTNetworkingTypeMetrics];
    NSDictionary *lastUserData;
    if (array.count>0) {
        FTRecordModel *model = [array lastObject];
        lastUserData = [FTBaseInfoHander ft_dictionaryWithJsonString:model.userdata];
    }
    
    [[FTMobileAgent sharedInstance] logout];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindNewUser" Id:@"bindNewUserId" exts:nil];
    
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];
    NSArray *newarray = [[FTTrackerEventDBTool sharedManger] getFirstTenBindUserData:FTNetworkingTypeMetrics];
    NSDictionary *userData;
    if (newarray.count>0) {
        FTRecordModel *model = [newarray lastObject];
        userData = [FTBaseInfoHander ft_dictionaryWithJsonString:model.userdata];
        
    }
    XCTAssertTrue(userData.allKeys.count>0 && lastUserData.allKeys.count>0 && [userData[@"name"] isEqualToString:@"bindNewUser"] && [lastUserData[@"name"] isEqualToString:@"bindUser"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * 用户解绑
 */
-(void)testUserlogout{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenBindUserData:FTNetworkingTypeMetrics];
    NSInteger oldCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] logout];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];
    NSArray *logoutArray = [[FTTrackerEventDBTool sharedManger] getFirstTenBindUserData:FTNetworkingTypeMetrics];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    //用户登出后 获取
    XCTAssertTrue(logoutArray.count == array.count && newCount > oldCount);
    [[FTMobileAgent sharedInstance] resetInstance];
}
#pragma mark ========== SDK 生命周期 ==========

- (void)testSDKStart{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.traceConsoleLog = YES;
    config.enableTrackAppCrash = YES;
    config.networkTrace = YES;
    config.autoTrackEventType  = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch;
    config.monitorInfoType = FTMonitorInfoTypeAll;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    //监控项启动
    XCTAssertTrue([FTMonitorManager sharedInstance].monitorTagDict != nil);
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    //uploadTool启动
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSInteger old = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [NSThread sleepForTimeInterval:1];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSInteger new = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertLessThan(old, new);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSDKEnd{
    [self setRightSDKConfig];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.traceConsoleLog = YES;
    config.enableTrackAppCrash = YES;
    config.networkTrace = YES;
    config.monitorInfoType = FTMonitorInfoTypeAll;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] resetInstance];
    XCTAssertTrue([FTMonitorManager sharedInstance].monitorTagDict == nil);
    XCTAssertNil([FTMonitorManager sharedInstance].monitorTagDict);
    
}
- (void)testSDKReset{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.traceConsoleLog = YES;
    config.enableTrackAppCrash = YES;
    config.networkTrace = YES;
    config.monitorInfoType = FTMonitorInfoTypeAll;
    [FTMobileAgent startWithConfigOptions:config];
    NSInteger oldHash = [FTMobileAgent sharedInstance].hash;
    NSDictionary *dict =[FTMonitorManager sharedInstance].monitorTagDict;
    config.monitorInfoType = FTMonitorInfoTypeCpu;
    [FTMobileAgent startWithConfigOptions:config];
    NSInteger newHash = [FTMobileAgent sharedInstance].hash;
    NSDictionary *dict2 =[FTMonitorManager sharedInstance].monitorTagDict;
    XCTAssertTrue(newHash == oldHash);
    XCTAssertFalse([dict isEqualToDictionary:dict2]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
@end
