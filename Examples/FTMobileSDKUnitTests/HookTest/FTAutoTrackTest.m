//
//  FTAutoTrackTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//
#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import "UIViewController+FTAutoTrack.h"
#import "UIView+FTAutoTrack.h"
#import "UITestVC.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent.h"
#import <objc/runtime.h>
#import "FTTrack.h"
#import "FTMobileAgent+Private.h"
#import "FTBaseInfoHandler.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "FTTrackDataManager+Test.h"
#import "DemoViewController.h"
#import "FTConstants.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
#import "TestSessionDelegate.h"
@interface FTAutoTrackTest : KIFTestCase
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
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTrackAppCrash = YES;
    [FTMobileAgent startWithConfigOptions:config];
    FTTraceConfig *trace = [[FTTraceConfig alloc]init];
    trace.enableAutoTrace = YES;
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:trace];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
    // Put setup code here. This method is called before the invocation of each
   
}
- (void)tearDown {
    //    [[FTMobileAgent sharedInstance] resetInstance];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testAutoTableViewClick{
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    DemoViewController *demovc = [[DemoViewController alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:demovc];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
    
    [demovc view];
    [demovc viewWillAppear:NO];
    [demovc viewDidAppear:NO];
    [[tester waitForViewWithAccessibilityLabel:@"BindUser"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"UserLogout"] tap];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[UITableViewCell]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    
}
- (void)testTapGes{
    
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:1];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"LABLE_CLICK"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"LABLE_CLICK"] tap];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            XCTAssertTrue([tags[FT_KEY_ACTION_NAME] isEqualToString:@"[UILabel][lable]"]);
            *stop = YES;
        }
    }];
    
    XCTAssertTrue(newArray.count>0);
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:1];
    
}
- (void)testLongPressGes{
    
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:1];
    [[tester waitForViewWithAccessibilityLabel:@"IMAGE_CLICK"] longPressAtPoint:CGPointZero duration:1];
    [tester waitForTimeInterval:1];
    [[tester waitForViewWithAccessibilityLabel:@"alert cancel"] tap];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[UIImageView]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
}
- (void)testButtonClick{
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"SecondButton"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"SecondButton"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"FirstButton"] tap];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            XCTAssertTrue([tags[FT_KEY_ACTION_NAME] isEqualToString:@"[UIButton][SecondButton]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    
}

- (void)testCollectionViewCellClick{
    
    [[tester waitForViewWithAccessibilityLabel:@"EventFlowLog"] tap];
    [tester waitForTimeInterval:1];
    
    [[tester waitForViewWithAccessibilityLabel:@"cell: 1"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"cell: 2"] tap];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[UICollectionViewCell]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
}
- (void)testResourceUrlHandlerReturnYes{
    [self resourceUrlHandler:YES];
}
- (void)testResourceUrlHandlerReturnNO{
    [self resourceUrlHandler:NO];
}
- (void)resourceUrlHandler:(BOOL)excluded{
    NSURL * rumUrl = [NSURL URLWithString:[[NSProcessInfo processInfo] environment][@"TRACE_URL"]];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"AA"];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.resourceUrlHandler = ^BOOL(NSURL *url) {
        return excluded;
    };
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [FTModelHelper startView];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    [tester waitForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasRes = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            NSURL *url = [NSURL URLWithString:tags[FT_KEY_RESOURCE_URL]];
            XCTAssertTrue([url.host isEqual:rumUrl.host]);
            hasRes = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasRes != excluded);
}
- (void)testIntakeUrlReturnYes{
    [self intakeUrl:YES];
}
- (void)testIntakeUrlReturnNO{
    [self intakeUrl:NO];
}
- (void)intakeUrl:(BOOL)trace{
    [[FTMobileAgent sharedInstance] isIntakeUrl:^BOOL(NSURL * _Nonnull url) {
        return trace;
    }];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [FTModelHelper startView];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    [tester waitForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasRes = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasRes = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasRes == trace);
}
- (void)testActionName{
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
    
    XCTAssertTrue([self.testVC.uiswitch.ft_actionName isEqualToString:@"[UISwitch]Off"]);
    XCTAssertTrue([self.testVC.firstButton.ft_actionName isEqualToString:@"[UIButton][FirstButton]"]);
    XCTAssertTrue([self.testVC.stepper.ft_actionName isEqualToString:@"[UIStepper]0.00"]);
    XCTAssertTrue([self.testVC.label.ft_actionName isEqualToString:@"[UILabel][lable]"]);
    XCTAssertTrue([self.testVC.segmentedControl.ft_actionName isEqualToString:@"[UISegmentedControl]first"]);
    
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    [self networkUpload:session handler:completionHandler];
}
- (void)networkUpload:(NSURLSession *)session handler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,error):nil;
    }];
    
    [task resume];
}
@end
