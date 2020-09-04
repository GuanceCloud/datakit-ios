//
//  FTLogTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTRecordModel.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTBaseInfoHander.h>
#import "UITestVC.h"
#import "FTTrackerEventDBTool+Test.h"

@interface FTLogTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTLogTest

- (void)setUp {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    config.eventFlowLog = YES;
    config.traceConsoleLog = YES;
    config.enableTrackAppCrash = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppLaunch | FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppViewScreen;
    config.source = @"iOSTest";
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[UITestVC alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/**
 * 测试控制台日志抓取
 * 日志类型数据 由于缓存策略 累计20条 使用事务写入数据库
 * 验证：new - old = 20 并且 最近添加数据库的数据类型 为 logging 且 抓取__content 包含"testTrackConsoleLog19"
*/
- (void)testTrackConsoleLog{
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSInteger old =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    for (int i = 0; i<21; i++) {
        NSLog(@"testTrackConsoleLog%d",i);
    }
    [NSThread sleepForTimeInterval:2];
    NSInteger new =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    FTRecordModel *model = [data lastObject];
    XCTAssertTrue(new-old == 20);
    XCTAssertTrue([model.op isEqualToString:@"logging"]);
    XCTAssertTrue([model.data containsString:@"testTrackConsoleLog"]);
}
- (void)testTraceEventEnter{
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"__content"];
    NSDictionary *contentDict =[FTBaseInfoHander ft_dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"enter"]);
}
- (void)testTraceEventLevae{
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    [self.testVC viewDidDisappear:NO];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"__content"];
    NSDictionary *contentDict =[FTBaseInfoHander ft_dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"leave"]);
}
- (void)testTraceEventClick{
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"__content"];
    NSDictionary *contentDict =[FTBaseInfoHander ft_dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"click"]);
}
- (void)testTraceEventLaunch{
    //模拟launch
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"__content"];
    NSDictionary *contentDict =[FTBaseInfoHander ft_dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"launch"]);
}
- (NSDictionary * _Nonnull)extracted:(NSString *)content {
    return [FTBaseInfoHander ft_dictionaryWithJsonString:content];
}

- (void)testTraceUploadingMethod{
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"__content"];
    NSDictionary *contentDict =[FTBaseInfoHander ft_dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"click"]);
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
    }];
}


@end
