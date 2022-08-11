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
#import <FTBaseInfoHandler.h>
#import <FTRecordModel.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTConstants.h>
#import <FTDateUtil.h>
#import <NSURLRequest+FTMonitor.h>
#import <objc/runtime.h>
#import "NSString+FTAdd.h"
#import <FTJSONUtil.h>
#import "FTPresetProperty.h"
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

    [[FTMobileAgent sharedInstance] resetInstance];
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
    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"testGlobalContext"] isEqualToString:@"testGlobalContext"]);
}
@end
