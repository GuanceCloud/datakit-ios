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
#import "FTAutoTrack+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "FTUploadTool+Test.h"
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>

@interface FTAutoTrackTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) NSString *akId;
@property (nonatomic, copy) NSString *akSecret;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *token;
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
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.akId =[processInfo environment][@"ACCESS_KEY_ID"];
    self.akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
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
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];

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
 * 验证UI黑名单
*/
- (void)testBlackViewList{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];

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
 * page_desc vtp_desc
 * 验证： xml写入  模拟点击后 验证新的数据是否包含 页面描述信息
 */
-(void)testPageVtpDesc{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url datawayToken:self.token akId:self.akId akSecret:self.akSecret enableRequestSigning:YES];
    
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.enabledPageVtpDesc = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
    config.monitorInfoType = FTMonitorInfoTypeAll;
    [self trackMethodWithConfig:config];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    FTRecordModel *model = [array lastObject];
    NSDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = item[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSString *desc = field[@"page_desc"];
    NSString *vtp_desc =field[@"vtp_desc"];
    XCTAssertTrue([desc isEqualToString:@"UI测试页面"]);
    XCTAssertTrue([vtp_desc isEqualToString:@"测试点击事件"]);
}
/**
  模拟点击操作
*/
- (void)trackMethodWithConfig:(FTMobileConfig *)config{
    FTAutoTrack *track = [FTAutoTrack new];
    [track startWithConfig:config];
    
    NSString *invokeMethod = @"track:withCpn:WithClickView:";
     
    SEL startMethod = NSSelectorFromString(invokeMethod);

    IMP imp = [track methodForSelector:startMethod];
     
    void (*func)(id, SEL,id,id,id) = (void (*)(id,SEL,id,id,id))imp;
    func(track,startMethod,@"click",self.testVC,self.testVC.tableView);
    func(track,startMethod,@"click",self.testVC,self.testVC.firstButton);
    [NSThread sleepForTimeInterval:2];
}
@end
