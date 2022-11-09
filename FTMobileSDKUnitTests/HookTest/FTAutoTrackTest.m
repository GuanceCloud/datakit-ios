//
//  FTAutoTrackTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//
#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import <UIViewController+FTAutoTrack.h>
#import <UIView+FTAutoTrack.h>
#import "UITestVC.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <objc/runtime.h>
#import <FTTrack.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTBaseInfoHandler.h>
#import <FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import "FTDateUtil.h"
#import "FTTrackDataManger+Test.h"
#import "DemoViewController.h"
#import "FTConstants.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTrackAppCrash = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    // Put setup code here. This method is called before the invocation of each
   
}
- (void)tearDown {
//    [[FTMobileAgent sharedInstance] resetInstance];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
  测试当前控制器获取是否正确
*/
- (void)testControllerOfTheView{
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
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    __block UIViewController *currentVC;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        currentVC = [self.testVC.firstButton ft_currentViewController];
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    XCTAssertEqualObjects(self.testVC, currentVC);
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
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_RUM_KEY_ACTION_NAME];
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
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];

    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            XCTAssertTrue([tags[FT_RUM_KEY_ACTION_NAME] isEqualToString:@"[UILabel]"]);
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

    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_RUM_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[UIImageView]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:1];
}
- (void)testButtonClick{
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"SecondButton"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"SecondButton"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"FirstButton"] tap];

    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            XCTAssertTrue([tags[FT_RUM_KEY_ACTION_NAME] isEqualToString:@"[UIButton][SecondButton]"]);
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
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_RUM_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[UICollectionViewCell]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
}
- (void)testAutoTrackResource{
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [tester waitForTimeInterval:1];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
 
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [NSThread sleepForTimeInterval:1];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasRes = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]) {
            hasRes = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasRes);
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];

    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,error):nil;
    }];

    [task resume];
}
@end
