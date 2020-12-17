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
#import "FTUploadTool+Test.h"
@interface FTMobileAgentTests : XCTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end


@implementation FTMobileAgentTests

- (void)setUp {
    /**
     * 设置 ft-sdk-iosTestUnitTests 的 Environment Variables
     * 额外 添加 isUnitTests = 1 防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.appid = self.appid;
    config.enableSDKDebugLog = YES;
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
#pragma mark ========== 用户数据绑定 ==========
/**
 * 测试 绑定用户
 * 验证：获取 RUM ES 数据 判断 userid 是否与设置一致
 */
- (void)testBindUser{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser"];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [data lastObject];
    NSDictionary *esData = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = esData[@"opdata"];
    NSDictionary *tags =opdata[@"tags"];
    NSString *userid = tags[@"userid"];
    NSString *is_signin= tags[@"is_signin"];

    XCTAssertTrue([userid isEqualToString:@"testBindUser"] && [is_signin isEqualToString:@"T"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * 测试 切换用户
 * 验证： 判断切换用户前后 获取上传信息里用户信息是否正确
 */
-(void)testChangeUser{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testChangeUser1"];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testChangeUser2"];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [data firstObject];
    NSDictionary *esData = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = esData[@"opdata"];
    NSDictionary *tags =opdata[@"tags"];
    NSString *userid = tags[@"userid"];
    NSString *is_signin= tags[@"is_signin"];
    XCTAssertTrue([userid isEqualToString:@"testChangeUser1"] && [is_signin isEqualToString:@"T"]);
    FTRecordModel *model2 = [data lastObject];
    NSDictionary *esData2 = [FTJSONUtil ft_dictionaryWithJsonString:model2.data];
    NSDictionary *opdata2 = esData2[@"opdata"];
    NSDictionary *tags2 =opdata2[@"tags"];
    NSString *userid2 = tags2[@"userid"];
    NSString *is_signin2= tags2[@"is_signin"];
    XCTAssertTrue([userid2 isEqualToString:@"testChangeUser2"] && [is_signin2 isEqualToString:@"T"]);

    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * 用户解绑
 * 验证：登出后 userid 改变 is_signin 为 F
 */
-(void)testUserlogout{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testUserlogout"];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] logout];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [data firstObject];
    NSDictionary *esData = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = esData[@"opdata"];
    NSDictionary *tags =opdata[@"tags"];
    NSString *userid = tags[@"userid"];
    NSString *is_signin= tags[@"is_signin"];
    XCTAssertTrue([userid isEqualToString:@"testUserlogout"] && [is_signin isEqualToString:@"T"]);
    FTRecordModel *model2 = [data lastObject];
    NSDictionary *esData2 = [FTJSONUtil ft_dictionaryWithJsonString:model2.data];
    NSDictionary *opdata2 = esData2[@"opdata"];
    NSDictionary *tags2 =opdata2[@"tags"];
    NSString *userid2 = tags2[@"userid"];
    NSString *is_signin2= tags2[@"is_signin"];
    XCTAssertTrue(![userid2 isEqualToString:@"testChangeUser2"] && [is_signin2 isEqualToString:@"F"]);

    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)addESData{
    NSString *name = @"TestBindUser";
    NSString *view_id = [name ft_md5HashToUpper32Bit];
    NSString *parent = FT_NULL_VALUE;
    NSDictionary *tags = @{@"view_id":view_id,
                           @"view_name":name,
                           @"view_parent":parent,
                                  @"app_apdex_level":@0,
    };
    NSDictionary *fields = @{
        @"view_load":@100,
    }.mutableCopy;
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_VIEW terminal:FT_TERMINAL_APP tags:tags fields:fields];
}
//#pragma mark ========== SDK 生命周期 ==========
//
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
