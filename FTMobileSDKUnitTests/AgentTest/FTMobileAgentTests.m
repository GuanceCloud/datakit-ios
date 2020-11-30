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
#import <FTUploadTool.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/Network/NSURLRequest+FTMonitor.h>
#import <objc/runtime.h>
#import "FTMonitorManager+Test.h"
#import "NSString+FTAdd.h"
#import <FTMobileAgent/FTJSONUtil.h>
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
    NSArray *data = [[FTTrackerEventDBTool sharedManger]getFirstRecords:10 withType:FTNetworkingTypeMetrics];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict =  [FTJSONUtil ft_dictionaryWithJsonString:model.data];
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
    NSArray *data = [[FTTrackerEventDBTool sharedManger]getFirstRecords:10 withType:FTNetworkingTypeLogging];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict =  [FTJSONUtil ft_dictionaryWithJsonString:model.data];
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
#pragma mark ========== 用户数据绑定 ==========
/**
 * 测试 绑定用户
 * 验证：从数据库取出新数据 验证数据绑定的用户信息 是否与绑定的一致
 */
- (void)testBindUser{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
    
    [NSThread sleepForTimeInterval:2];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
    FTRecordModel *model = [data lastObject];
    NSDictionary *userData = [FTJSONUtil ft_dictionaryWithJsonString:model.userdata];
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
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
    NSDictionary *lastUserData;
    if (array.count>0) {
        FTRecordModel *model = [array lastObject];
        lastUserData = [FTJSONUtil ft_dictionaryWithJsonString:model.userdata];
    }
    
    [[FTMobileAgent sharedInstance] logout];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindNewUser" Id:@"bindNewUserId" exts:nil];
    
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];
    NSArray *newarray = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
    NSDictionary *userData;
    if (newarray.count>0) {
        FTRecordModel *model = [newarray lastObject];
        userData = [FTJSONUtil ft_dictionaryWithJsonString:model.userdata];
        
    }
    XCTAssertTrue(userData.allKeys.count>0 && lastUserData.allKeys.count>0 && [userData[@"name"] isEqualToString:@"bindNewUser"] && [lastUserData[@"name"] isEqualToString:@"bindUser"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * 用户解绑
 */
-(void)testUserlogout{
    [self setRightSDKConfig];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
    NSInteger oldCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] logout];
    [NSThread sleepForTimeInterval:2];
    NSArray *logoutArray = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
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
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    //uploadTool启动
    [[FTMobileAgent sharedInstance] trackUpload:@[model] callBack:^(NSInteger statusCode, NSData * _Nullable response) {
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
- (void)testTrackClientTimeCostResignActive{
    [self setRightSDKConfig];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeMetrics];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [NSThread sleepForTimeInterval:2];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeMetrics];
        XCTAssertTrue(newCount>oldCount);
     NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FTNetworkingTypeMetrics];
      FTRecordModel *model = [datas lastObject];
        NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
        NSString *op = [dict valueForKey:@"op"];
        XCTAssertTrue([op isEqualToString:@"mobile_client_time_cost"]);
        NSDictionary *opdata = [dict valueForKey:@"opdata"];
        NSDictionary *field = [opdata valueForKey:@"field"];
        NSDictionary *tags = [opdata valueForKey:@"tags"];
        NSNumber *duration = [field valueForKey:@"duration"];
        XCTAssertTrue(duration.intValue > 2*1000*1000);
        XCTAssertTrue([[tags valueForKey:FT_AUTO_TRACK_EVENT_ID] isEqualToString:[FT_EVENT_ACTIVATED ft_md5HashToUpper32Bit]]);

        XCTAssertTrue([[field valueForKey:@"event"] isEqualToString:@"activated"]);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];

}
- (void)testTrackClientTimeCostTerminate{
    [self setRightSDKConfig];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeMetrics];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [NSThread sleepForTimeInterval:2];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeMetrics];
        XCTAssertTrue(newCount>oldCount);
     NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FTNetworkingTypeMetrics];
      FTRecordModel *model = [datas lastObject];
        NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
        NSString *op = [dict valueForKey:@"op"];
        XCTAssertTrue([op isEqualToString:@"mobile_client_time_cost"]);
        NSDictionary *opdata = [dict valueForKey:@"opdata"];
        NSDictionary *field = [opdata valueForKey:@"field"];
        NSDictionary *tags = [opdata valueForKey:@"tags"];
        NSNumber *duration = [field valueForKey:@"duration"];
        XCTAssertTrue(duration.intValue > 2*1000*1000);
        XCTAssertTrue([[tags valueForKey:FT_AUTO_TRACK_EVENT_ID] isEqualToString:[FT_EVENT_ACTIVATED ft_md5HashToUpper32Bit]]);

        XCTAssertTrue([[field valueForKey:@"event"] isEqualToString:@"activated"]);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];

}
@end
