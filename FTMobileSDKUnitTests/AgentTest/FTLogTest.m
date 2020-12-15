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
#import <FTJSONUtil.h>
@interface FTLogTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTLogTest

- (void)setUp {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.source = @"iOSTest";
    config.eventFlowLog = YES;
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
- (void)testTraceEventEnter{
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];

    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array firstObject];
    NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"__content"];
    NSDictionary *contentDict =[FTJSONUtil ft_dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"enter"]);
}
//- (void)testTraceEventLaunch{
//    [self.testVC view];
//    [self.testVC viewWillAppear:NO];
//    [self.testVC viewDidAppear:NO];
    //模拟launch
//    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
//
//
//    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
//    FTRecordModel *model = [array lastObject];
//    NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
//    NSDictionary *op = dict[@"opdata"];
//    NSDictionary *field = op[@"field"];
//    NSString *content = field[@"__content"];
//    NSDictionary *contentDict =[FTJSONUtil ft_dictionaryWithJsonString:content];
//    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"launch"]);
//}
//- (void)testTraceUploadingMethod{
//    [self.testVC view];
//    [self.testVC viewWillAppear:NO];
//    [self.testVC viewDidAppear:NO];
//    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
//    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
//
//    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
//    FTRecordModel *model = [array lastObject];
//    NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
//    NSDictionary *op = dict[@"opdata"];
//    NSDictionary *field = op[@"field"];
//    NSString *content = field[@"__content"];
//    NSDictionary *contentDict =[FTJSONUtil ft_dictionaryWithJsonString:content];
//    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"click"]);
//    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
//    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable respox/nse) {
//        XCTAssertTrue(statusCode == 200);
//        [expectation fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
//        XCTAssertNil(error);
//    }];
//}


@end
