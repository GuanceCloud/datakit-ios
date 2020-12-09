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
#import <Network/FTUploadTool.h>
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
@end


@implementation FTMobileAgentTests

- (void)setUp {
    /**
     * 设置 ft-sdk-iosTestUnitTests 的 Environment Variables
     * 额外 添加 isUnitTests = 1 防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.traceConsoleLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
//    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
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
//#pragma mark ========== 用户数据绑定 ==========
///**
// * 测试 绑定用户
// * 验证：从数据库取出新数据 验证数据绑定的用户信息 是否与绑定的一致
// */
//- (void)testBindUser{
//    [self setRightSDKConfig];
//    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
//    [[FTMobileAgent sharedInstance] bindUserWithUserID:@""];
//
//    [NSThread sleepForTimeInterval:2];
//    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
//    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FT_DATA_TYPE_INFLUXDB];
//    FTRecordModel *model = [data lastObject];
//    NSDictionary *userData = [FTJSONUtil ft_dictionaryWithJsonString:model.userdata];
//    XCTAssertTrue(newCount>count);
//    XCTAssertTrue([userData[@"name"] isEqualToString:@"bindUser"]);
//    XCTAssertTrue([userData[@"id"] isEqualToString:@"bindUserId"]);
//    [[FTMobileAgent sharedInstance] resetInstance];
//}
///**
// * 测试 切换用户
// * 验证： 判断切换用户前后 获取上传信息里用户信息是否正确
// */
//-(void)testChangeUser{
//    [self setRightSDKConfig];
//    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
//    [NSThread sleepForTimeInterval:2];
//    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
//    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
//    NSDictionary *lastUserData;
//    if (array.count>0) {
//        FTRecordModel *model = [array lastObject];
//        lastUserData = [FTJSONUtil ft_dictionaryWithJsonString:model.userdata];
//    }
//
//    [[FTMobileAgent sharedInstance] logout];
//    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindNewUser" Id:@"bindNewUserId" exts:nil];
//
//    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
//    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
//    [NSThread sleepForTimeInterval:2];
//    NSArray *newarray = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FT_DATA_TYPE_LOGGING];
//    NSDictionary *userData;
//    if (newarray.count>0) {
//        FTRecordModel *model = [newarray lastObject];
//        userData = [FTJSONUtil ft_dictionaryWithJsonString:model.userdata];
//
//    }
//    XCTAssertTrue(userData.allKeys.count>0 && lastUserData.allKeys.count>0 && [userData[@"name"] isEqualToString:@"bindNewUser"] && [lastUserData[@"name"] isEqualToString:@"bindUser"]);
//    [[FTMobileAgent sharedInstance] resetInstance];
//}
///**
// * 用户解绑
// */
//-(void)testUserlogout{
//    [self setRightSDKConfig];
//    [NSThread sleepForTimeInterval:2];
//    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
//    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
//    NSInteger oldCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
//    [[FTMobileAgent sharedInstance] logout];
//    [NSThread sleepForTimeInterval:2];
//    NSArray *logoutArray = [[FTTrackerEventDBTool sharedManger] getFirstBindUserRecords:10 withType:FTNetworkingTypeMetrics];
//    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
//
//    //用户登出后 获取
//    XCTAssertTrue(logoutArray.count == array.count && newCount > oldCount);
//    [[FTMobileAgent sharedInstance] resetInstance];
//}
#pragma mark ========== SDK 生命周期 ==========

//- (void)testSDKStart{
//    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
//    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
//    config.enableSDKDebugLog = YES;
//    config.traceConsoleLog = YES;
//    config.enableTrackAppCrash = YES;
//    config.networkTrace = YES;
//    config.monitorInfoType = FTMonitorInfoTypeAll;
//    [FTMobileAgent startWithConfigOptions:config];
//    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
//    //监控项启动
//    NSDictionary *dict = @{
//        FT_AGENT_MEASUREMENT:@"iOSTest",
//        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
//        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
//    };
//    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
//                          FT_AGENT_OPDATA:dict,
//    };
//    
//    FTRecordModel *model = [FTRecordModel new];
//    model.op =FTNetworkingTypeMetrics;
//    model.data =[FTJSONUtil ft_convertToJsonData:data];
//    //uploadTool启动
//    [[FTMobileAgent sharedInstance] trackUpload:@[model] callBack:^(NSInteger statusCode, NSData * _Nullable response) {
//        XCTAssertTrue(statusCode == 200);
//        [expect fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
//        XCTAssertNil(error);
//    }];
//    
//    NSInteger old = [[FTTrackerEventDBTool sharedManger] getDatasCount];
//    
//    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
//    [NSThread sleepForTimeInterval:1];
//    NSInteger new = [[FTTrackerEventDBTool sharedManger] getDatasCount];
//    XCTAssertLessThan(old, new);
//    [[FTMobileAgent sharedInstance] resetInstance];
//}
//- (void)testSDKEnd{
//    [self setRightSDKConfig];
//    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
//    config.enableSDKDebugLog = YES;
//    config.traceConsoleLog = YES;
//    config.enableTrackAppCrash = YES;
//    config.networkTrace = YES;
//    config.monitorInfoType = FTMonitorInfoTypeAll;
//    [FTMobileAgent startWithConfigOptions:config];
//    [[FTMobileAgent sharedInstance] resetInstance];
//}
//- (void)testSDKReset{
//    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
//    config.enableSDKDebugLog = YES;
//    config.traceConsoleLog = YES;
//    config.enableTrackAppCrash = YES;
//    config.networkTrace = YES;
//    config.monitorInfoType = FTMonitorInfoTypeAll;
//    [FTMobileAgent startWithConfigOptions:config];
//    NSInteger oldHash = [FTMobileAgent sharedInstance].hash;
//    config.monitorInfoType = FTMonitorInfoTypeCpu;
//    [FTMobileAgent startWithConfigOptions:config];
//    NSInteger newHash = [FTMobileAgent sharedInstance].hash;
//    NSDictionary *dict2 =[FTMonitorManager sharedInstance].monitorTagDict;
//    XCTAssertTrue(newHash == oldHash);
//    XCTAssertFalse([dict isEqualToDictionary:dict2]);
//    [[FTMobileAgent sharedInstance] resetInstance];
//}
@end
