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
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import <FTLocationManager.h>
#import "AppDelegate.h"
#import <FTUploadTool.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#define WAIT                                                                \
do {                                                                        \
[self expectationForNotification:@"LCUnitTest" object:nil handler:nil]; \
[self waitForExpectationsWithTimeout:60 handler:nil];                   \
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
    //设置 ft-sdk-iosTestUnitTests 的 Environment Variables
    //key 与 ft-sdk-iosTest 中设置的不同 用以 避免启动测试用例时 在 AppDelegate 中 启动SDK
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.akId =[processInfo environment][@"TACCESS_KEY_ID"];
    self.akSecret = [processInfo environment][@"TACCESS_KEY_SECRET"];
    self.token = [processInfo environment][@"TACCESS_DATAWAY_TOKEN"];
    self.url = [processInfo environment][@"TACCESS_SERVER_URL"];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
  
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableDescLog = YES;
    config.enableAutoTrack = YES;
    config.traceConsoleLog = YES;
    config.enabledPageVtpDesc = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
    config.enableTrackAppCrash = YES;
    self.config = config;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
#pragma mark ========== property ==========
/**
 * url 为 空字符串
 * 验证标准：url为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
 */
- (void)testSetEmptyUrl{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"" datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableTrackAppCrash = YES;
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
- (void)testIllegalUrl{
    
}
/**
 * akId 为 空字符串
 * 验证标准：akId为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
*/
- (void)testSetEmptyAkId{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:@"" akSecret:self.akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableTrackAppCrash = YES;
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
/**
 * akSecret 为 空字符串
 * 验证标准：akSecret 为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
*/
- (void)testSetEmptyAkSecret{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:@"" enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableTrackAppCrash = YES;
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
#pragma mark ========== 数据同步 ==========
/**
 * 测试主动埋点是否成功
 */
- (void)testTrackMethod {
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] trackBackground:@"testTrack" field:@{@"event":@"testTrack"}];
    [NSThread sleepForTimeInterval:2];//写入数据库方法是异步的
    NSArray *all  = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    FTRecordModel *model =  [all lastObject];
    NSDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = item[@"opdata"];
    NSDictionary *field = op[@"field"];
    XCTAssertTrue([op[@"measurement"] isEqualToString:@"testTrack"] && [[field valueForKey:@"event"] isEqualToString:@"testTrack"]);
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-count==1);

}
/**
 * 测试控制台日志抓取
 * 日志类型数据 犹豫缓存策略 累计20条 使用事务写入数据库
 * 验证：new - old = 20 并且 最近添加数据库的数据类型 为 logging 且 抓取__content 包含"testTrackConsoleLog19"
*/
- (void)testTrackConsoleLog{
    [self setRightSDKConfig];
    NSInteger old =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    for (int i = 0; i<21; i++) {
        NSLog(@"testTrackConsoleLog%d",i);
    }
    __block NSInteger new;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        new =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
        NSArray *data = [[FTTrackerEventDBTool sharedManger] getAllDatas];
        FTRecordModel *model = [data lastObject];
        XCTAssertTrue(new-old == 20);
        XCTAssertTrue([model.op isEqualToString:@"logging"]);
        XCTAssertTrue([model.data containsString:@"testTrackConsoleLog19"]);
        NOTIFY
    });
     WAIT
}
/**
 * 测试是否能够获取地理位置
*/
- (void)testLocation{
    [self setRightSDKConfig];
    FTLocationManager *location = [[FTLocationManager alloc]init];
    location.updateLocationBlock = ^(FTLocationInfo * _Nonnull locInfo, NSError * _Nullable error) {
        XCTAssertTrue(locInfo.province.length>0||locInfo.city.length>0);
    };
}
#pragma mark ========== 用户数据绑定 ==========
/**
 * 测试 绑定用户 是否成功
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

}
/**
 * 测试 切换用户 是否成功 判断切换用户前后 获取上传信息里用户信息是否正确
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

}
@end
