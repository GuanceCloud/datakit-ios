//
//  ft_sdk_iosTestUnitTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/19.
//  Copyright © 2019 hll. All rights reserved.
//
#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTBaseInfoHandler.h"
#import "FTRecordModel.h"
#import "FTMobileAgent+Private.h"
#import "FTMobileAgent+Public.h"
#import "FTConstants.h"
#import "FTDateUtil.h"
#import <objc/runtime.h>
#import "NSString+FTAdd.h"
#import "FTJSONUtil.h"
#import "FTPresetProperty.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
@interface FTMobileAgentTests : KIFTestCase
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
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
#pragma mark ========== 用户数据绑定 ==========
///
- (void)testAdaptOldUserSet{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[NSUserDefaults standardUserDefaults] setValue:@"old_user" forKey:@"ft_userid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTMobileAgent sharedInstance] shutDown];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];
   
    NSDictionary *dict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
    NSString *userid = dict[FT_USER_ID];
    XCTAssertTrue([userid isEqualToString:@"old_user"]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ft_userid"];
    [[FTMobileAgent sharedInstance] shutDown];
}
/**
 * 测试 绑定用户
 * 验证：获取 RUM ES 数据 判断 userid 是否与设置一致
 */
- (void)testBindUser{
    [self setRightSDKConfig];
   
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser"];
    NSDictionary *dict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
    NSString *userid = dict[FT_USER_ID];
    XCTAssertTrue([userid isEqualToString:@"testBindUser"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testBindUserWithNameEmail{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser2" userName:@"name1" userEmail:@"111@qq.com"];
    NSDictionary *dict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
    NSString *userid = dict[FT_USER_ID];
    NSString *username = dict[FT_USER_NAME];
    NSString *useremail = dict[FT_USER_EMAIL];
    XCTAssertTrue([userid isEqualToString:@"testBindUser2"]);
    XCTAssertTrue([username isEqualToString:@"name1"]);
    XCTAssertTrue([useremail isEqualToString:@"111@qq.com"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testBindUserWithNameEmailAndExtra{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser3" userName:@"name2" userEmail:@"222@qq.com" extra:@{@"user_age":@1}];
    NSDictionary *dict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
    NSString *userid = dict[FT_USER_ID];
    NSString *username = dict[FT_USER_NAME];
    NSString *useremail = dict[FT_USER_EMAIL];
    NSNumber *userage = dict[@"user_age"];
    XCTAssertTrue([userid isEqualToString:@"testBindUser3"]);
    XCTAssertTrue([username isEqualToString:@"name2"]);
    XCTAssertTrue([useremail isEqualToString:@"222@qq.com"]);
    XCTAssertTrue([userage isEqual:@1]);
    [[FTMobileAgent sharedInstance] shutDown];

}
/**
 * 测试 切换用户
 * 验证： 判断切换用户前后 获取上传信息里用户信息是否正确
 */
-(void)testChangeUser{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testChangeUser1"];
     NSDictionary *dict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
     NSString *userid = dict[@"userid"];
    XCTAssertTrue([userid isEqualToString:@"testChangeUser1"]);

    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testChangeUser2"];
    NSDictionary *newDict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
    NSString *newUserid = newDict[@"userid"];
   XCTAssertTrue([newUserid isEqualToString:@"testChangeUser2"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
/**
 * 用户解绑
 * 验证：登出后 userid 改变 is_signin 为 F
 */
-(void)testUserlogout{
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"ft_sessionid"];
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testUserlogout" userName:@"name" userEmail:@"email" extra:@{@"ft_key":@"ft_value"}];
    
    [[FTMobileAgent sharedInstance] logout];
    NSDictionary *dict  = [[FTMobileAgent sharedInstance].presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];
    NSString *userid = dict[FT_USER_ID];
    NSString *userName = dict[FT_USER_NAME];
    NSString *userEmail = dict[FT_USER_EMAIL];
    NSString *ft_key = dict[@"ft_key"];
    XCTAssertFalse([userid isEqualToString:@"testUserlogout"]);
    XCTAssertFalse([userName isEqualToString:@"name"]);
    XCTAssertFalse([userEmail isEqualToString:@"email"]);
    XCTAssertFalse([ft_key isEqualToString:@"ft_value"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
-(void)testServiceName{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.service = @"testSetServiceName";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([serviceName isEqualToString:@"testSetServiceName"]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumserviceName = [rumtags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([rumserviceName isEqualToString:@"testSetServiceName"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.globalContext = @{@"testGlobalContext":@"testGlobalContext"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"testGlobalContext"] isEqualToString:@"testGlobalContext"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testShutDown{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    logger.enableConsoleLog = YES;
    logger.enableLinkRumData = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:self.appid];
    rum.enableTrackAppANR = YES;
    rum.enableTraceUserView = YES;
    rum.enableTrackAppCrash = YES;
    rum.enableTrackAppFreeze = YES;
    rum.enableTraceUserAction = YES;
    rum.enableTraceUserResource = YES;
    rum.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    FTTraceConfig *trace = [[FTTraceConfig alloc]init];
    trace.enableAutoTrace = YES;
    trace.enableLinkRumData = YES;
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:trace];
    
    [tester waitForTimeInterval:0.5];
    [[FTMobileAgent sharedInstance] shutDown];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertThrows([FTMobileAgent sharedInstance]);
    for (int i = 0; i<20; i++) {
        NSLog(@"testConsoleLog");
    }
    // 控制台日志不再采集
    [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManger] getDatasCount] == count);
    // RUM Anctio、View、Resource采集关闭
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
    [[tester waitForViewWithAccessibilityLabel:@"Network data collection"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"Network data collection"] tap];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    // Trace 功能关闭、Rum Resource采集关闭
    [self networkUploadHandler:^(NSURLResponse *response, NSDictionary *requestHeader, NSError *error) {
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[requestHeader[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    [tester waitForTimeInterval:1];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManger] getDatasCount] == count);
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSDictionary *requestHeader ,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
   
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,task.currentRequest.allHTTPHeaderFields,error):nil;
    }];

    [task resume];
}
@end
