//
//  FTAutoTrackTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIViewController+FT_RootVC.h>
#import <UIView+FT_CurrentController.h>
#import "UITestVC.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <objc/runtime.h>
#import <FTAutoTrack.h>
#import <FTAutoTrack/FTAutoTrack.h>
#import "TestAccount.h"
@interface FTAutoTrackTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTAutoTrackTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
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

    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  
}
/**
  测试当前控制器获取是否正确
*/
- (void)testControllerOfTheView{

      UIViewController *currentVC = [self.testVC.firstButton ft_getCurrentViewController];
      XCTAssertEqualObjects(self.testVC, currentVC);

}
/**
  测试根视图是否正确
*/
- (void)testRootViewControllerOfTheView{
    
      NSString *rootStr = [UIViewController ft_getRootViewController];
      XCTAssertTrue([rootStr isEqualToString:@"UITabBarController"]);

}
/**
  验证控制器白名单
*/
- (void)testWhiteVCList{
    TestAccount *test = [[TestAccount alloc]init];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:test.accessServerUrl akId:test.accessKeyID akSecret:test.accessKeySecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
    config.whiteVCList = @[@"UITestVC"];
    config.monitorInfoType = FTMonitorInfoTypeAll;
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self trackMethodWithConfig:config];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-lastCount==2);

}
/**
  验证控制器黑名单
*/
- (void)testBlackVCList{
    TestAccount *test = [[TestAccount alloc]init];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:test.accessServerUrl akId:test.accessKeyID akSecret:test.accessKeySecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
    config.monitorInfoType = FTMonitorInfoTypeAll;
    config.blackVCList = @[@"UITestVC"];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self trackMethodWithConfig:config];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount==lastCount);

}
/**
  验证UI白名单
*/
- (void)testWhiteViewList{
    TestAccount *test = [[TestAccount alloc]init];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:test.accessServerUrl akId:test.accessKeyID akSecret:test.accessKeySecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
    config.whiteViewClass = @[UITableView.class];
    config.monitorInfoType = FTMonitorInfoTypeAll;
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self trackMethodWithConfig:config];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-lastCount==1);
}
/**
  验证UI黑名单
*/
- (void)testBlackViewList{
    TestAccount *account = [[TestAccount alloc]init];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:account.accessServerUrl akId:account.accessKeyID akSecret:account.accessKeySecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
    config.blackViewClass = @[UITableView.class];
    config.monitorInfoType = FTMonitorInfoTypeAll;
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self trackMethodWithConfig:config];
    
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-lastCount==1);
    
}
/**
  模拟点击操作
*/
- (void)trackMethodWithConfig:(FTMobileConfig *)config{
//    [FTMobileAgent startWithConfigOptions:config];
    FTAutoTrack *track = [FTAutoTrack new];
    [track startWithConfig:config];
    
    NSString *invokeMethod = @"track:withCpn:WithClickView:";
     
    SEL startMethod = NSSelectorFromString(invokeMethod);

    IMP imp = [track methodForSelector:startMethod];
     
    void (*func)(id, SEL,id,id,id) = (void (*)(id,SEL,id,id,id))imp;
     func(track,startMethod,@"click",self.testVC,self.testVC.tableView);
     func(track,startMethod,@"click",self.testVC,self.testVC.firstButton);
}
@end
