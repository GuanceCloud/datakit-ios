//
//  FTWKWebViewTraceTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/18.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestWKWebViewVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "FTUploadTool+Test.h"
#import <FTBaseInfoHander.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import <FTMobileAgent/NSDate+FTAdd.h>

@interface FTWKWebViewTraceTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) TestWKWebViewVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTWKWebViewTraceTest

- (void)setUp {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[TestWKWebViewVC alloc] init];
    
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
- (void)setTraceConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
       NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
       NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
       NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
       NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
       FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
       config.networkTrace = YES;
       [FTMobileAgent startWithConfigOptions:config];
       [FTMobileAgent sharedInstance].upTool.isUploading = YES;
       [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
- (void)setNoTraceConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
       NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
       NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
       NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
       NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
       FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
       config.networkTrace = NO;
       [FTMobileAgent startWithConfigOptions:config];
       [FTMobileAgent sharedInstance].upTool.isUploading = YES;
       [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testNoTrace{
    [self setNoTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(newCount-lastCount == 0);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 * loadRequest 方法发起请求
 * 验证： trace 到的数据 url与请求url一致 header中有trace数据
 */
- (void)testWKWebViewTrace{
    [self setTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(newCount-lastCount == 1);
        FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging] lastObject];
        [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
            XCTAssertTrue(spanID.length>0);
            XCTAssertTrue([urlStr isEqualToString:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"]);
        }];
       
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 * loadRequest 方法发起请求
 * 验证： reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url一致 spanid 不一致
*/
- (void)testWKWebViewReloadTrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
   
    [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:4];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *reloadModel = [array lastObject];
    FTRecordModel *model = [array objectAtIndex:array.count-2];
    __block NSString *reloadUrl;
    __block NSString *reloadSpanID;
    [self getX_B3_SpanId:reloadModel completionHandler:^(NSString *spanID, NSString *urlStr) {
        reloadUrl = urlStr;
        reloadSpanID = spanID;
    }];
    [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
        XCTAssertTrue([reloadUrl isEqualToString:urlStr]);
        XCTAssertFalse([reloadSpanID isEqualToString:spanID]);
    }];
}
/**
 * 使用 loadRequest 方法发起请求 之后页面跳转再回退到初始页面 再进行reload
 * 验证：reload 时 发起的请求 都能新增trace数据，header中都添加数据
 * reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url 一致 ，spanid 不一致
*/
- (void)testWKWebViewGobackReloadTrace{
    [self setTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.testVC ft_load:@"https://github.com/CloudCare"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.testVC.webView goBack];
            [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:5];
        });
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-lastCount == 3);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *reloadModel = [array lastObject];
    FTRecordModel *model = [array objectAtIndex:array.count-3];
    __block NSString *reloadUrl;
    __block NSString *reloadSpanID;
    [self getX_B3_SpanId:reloadModel completionHandler:^(NSString *spanID, NSString *urlStr) {
        reloadUrl = urlStr;
        reloadSpanID = spanID;
    }];
    [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
        XCTAssertTrue([reloadUrl isEqualToString:urlStr]);
        XCTAssertFalse([reloadSpanID isEqualToString:spanID]);
    }];
}
- (void)webviewReload:(XCTestExpectation *)expection{
    [self.testVC ft_reload];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [expection fulfill];
      });
}
- (void)getX_B3_SpanId:(FTRecordModel *)model completionHandler:(void (^)(NSString *spanID,NSString *urlStr))completionHandler{
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = [dict valueForKey:@"opdata"];
    NSDictionary *field = [opdata valueForKey:@"field"];
    NSDictionary *content = [FTBaseInfoHander ft_dictionaryWithJsonString:[field valueForKey:@"__content"]];
    NSDictionary *requestContent = [content valueForKey:@"requestContent"];
    NSDictionary *headers = [requestContent valueForKey:@"headers"];
    completionHandler?completionHandler([headers valueForKey:@"X-B3-SpanId"],[requestContent valueForKey:@"url"]):nil;
}

@end
