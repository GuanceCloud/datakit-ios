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
#import <FTJSONUtil.h>
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
    if (!_testVC) {
        self.testVC = [[TestWKWebViewVC alloc] init];
    }
    
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
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.networkTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
- (void)setNoTraceConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.networkTrace = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)testNoTrace{
    [self setNoTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(newCount-lastCount == 0);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [self.testVC ft_stopLoading];

    self.testVC = nil;
}

/**
 * 使用 loadRequest 方法发起请求 之后页面跳转 nextLink
 * 验证：nextLink logging数据不增加
 * metrics 中也能采集到 nextLink 请求状态（成功/失败）、请求时间（loading/loadCompleted）
 *
*/
- (void)testWKWebViewNextLink{
    [self setTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    __block NSInteger lastLoggingCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger loggingcount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
        
        XCTAssertTrue(loggingcount>lastLoggingCount);
        lastLoggingCount = loggingcount;
        [self.testVC ft_testNextLink];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [expectation fulfill];
             });
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
    NSInteger newLoggingCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newLoggingCount == lastLoggingCount);
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
/**
 * 使用 loadRequest 方法发起请求 之后页面跳转 nextLink 再进行reload
 * 验证：reload 时 发起的请求 能新增trace数据，header中都添加数据
 * reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url、spanid 都不一致
*/
- (void)testWKWebViewReloadNextLink{
    [self setTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.testVC ft_testNextLink];
        [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:5];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger]getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *reloadModel = [array lastObject];
    FTRecordModel *model = [array objectAtIndex:array.count-2];
    __block NSString *reloadUrl;
    __block NSString *reloadSpanID;
    [self getX_B3_SpanId:reloadModel completionHandler:^(NSString *spanID, NSString *urlStr) {
        reloadUrl = urlStr;
        reloadSpanID = spanID;
    }];
    [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
        XCTAssertFalse([reloadUrl isEqualToString:urlStr]);
        XCTAssertFalse([reloadSpanID isEqualToString:spanID]);
    }];
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
/**
 * loadRequest 方法发起请求
 * 验证： reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url一致 spanid 不一致
*/
- (void)testWKWebViewReloadTrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setTraceConfig];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
   
    [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:8];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
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
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
/**
 * 使用 loadRequest 方法发起请求 之后页面跳转再回退到初始页面 再进行reload
 * 验证：reload 时 发起的请求 都能新增trace数据，header中都添加数据
 * reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url 一致 ，spanid 不一致
*/
- (void)testWKWebViewGobackReloadTrace{
    [self setTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.testVC ft_testNextLink];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.testVC.webView goBack];
            [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:5];
        });
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
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
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
- (void)webviewReload:(XCTestExpectation *)expection{
    [self.testVC ft_reload];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [expection fulfill];
      });
}
- (void)getX_B3_SpanId:(FTRecordModel *)model completionHandler:(void (^)(NSString *spanID,NSString *urlStr))completionHandler{
    NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = [dict valueForKey:@"opdata"];
    NSDictionary *field = [opdata valueForKey:@"field"];
    NSDictionary *content = [FTJSONUtil ft_dictionaryWithJsonString:[field valueForKey:@"message"]];
    NSDictionary *requestContent = [content valueForKey:@"requestContent"];
    NSDictionary *headers = [requestContent valueForKey:@"headers"];
    completionHandler?completionHandler([headers valueForKey:@"X-B3-SpanId"],[requestContent valueForKey:@"url"]):nil;
}
@end
