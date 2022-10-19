//
//  FTJavaScriptBridgeTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/9/19.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import "TestWKWebViewVC.h"
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool+Test.h"
#import <FTConstants.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import "FTTrackDataManger+Test.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTDateUtil.h>
#import <FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTConstants.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
typedef void(^FTTraceRequest)(NSURLRequest *);
@interface FTJavaScriptBridgeTest : KIFTestCase<WKNavigationDelegate>
@property (nonatomic, strong) TestWKWebViewVC *viewController;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) FTTraceRequest block;

@end

@implementation FTJavaScriptBridgeTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];

    self.viewController = [[TestWKWebViewVC alloc]init];;

    self.tabBarController = [[UITabBarController alloc] init];

    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
    self.navigationController.tabBarItem.title = @"Element";

    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];

    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;

    [self.viewController view];
    [self.viewController viewWillAppear:NO];
    [self.viewController viewDidAppear:NO];
    self.viewController.webView.navigationDelegate = self;
}

- (void)tearDown {
    [self.tabBarController viewWillDisappear:NO];
    [self.tabBarController viewDidDisappear:NO];

    self.window.rootViewController = nil;
    self.tabBarController = nil;
    self.navigationController = nil;
    self.viewController = nil;

    self.window.hidden = YES;
    self.window = nil;
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)setsdk{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)testAddRumViewData{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [self.viewController ft_load:url.absoluteString];
    [tester waitForTimeInterval:2];
    [self.viewController test_addWebViewRumView];
    [tester waitForTimeInterval:3];
    NSArray *datas =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;
    [datas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            if([tags[@"sdk_name"] isEqualToString:@"df_web_rum_sdk"]){
                NSDictionary *field = opdata[FT_FIELDS];
                NSInteger errorCount = [field[FT_KEY_VIEW_ERROR_COUNT] integerValue];
                NSInteger resourceCount = [field[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
                NSInteger longTaskCount = [field[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
                NSString *viewName = tags[FT_KEY_VIEW_NAME];
                XCTAssertTrue(errorCount == 0);
                XCTAssertTrue(longTaskCount == 0);
                XCTAssertTrue(resourceCount == 0);
                XCTAssertTrue([viewName isEqualToString:@"testJSBridge"]);
                hasViewData = YES;
            }
        }
    }];
    XCTAssertTrue(hasViewData);
}
-(void)testloadFileURL{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [self.viewController test_loadFileURL:url allowingReadAccessToURL:url];
    [tester waitForTimeInterval:2];
    [self.viewController test_addWebViewRumView];
    [tester waitForTimeInterval:3];
    NSArray *datas =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;
    [datas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            if([tags[@"sdk_name"] isEqualToString:@"df_web_rum_sdk"]){
                NSDictionary *field = opdata[FT_FIELDS];
                NSInteger errorCount = [field[FT_KEY_VIEW_ERROR_COUNT] integerValue];
                NSInteger resourceCount = [field[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
                NSInteger longTaskCount = [field[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
                NSString *viewName = tags[FT_KEY_VIEW_NAME];
                XCTAssertTrue(errorCount == 0);
                XCTAssertTrue(longTaskCount == 0);
                XCTAssertTrue(resourceCount == 0);
                XCTAssertTrue([viewName isEqualToString:@"testJSBridge"]);
                hasViewData = YES;
            }
        }
    }];
    XCTAssertTrue(hasViewData);
}
- (void)testReloadTrace{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    __block NSString *spanid;
    self.block = ^(NSURLRequest *request){
        if([request.URL isEqual:url]){
            if(spanid){
                XCTAssertFalse([spanid isEqualToString:request.allHTTPHeaderFields[@"x-datadog-trace-id"]]);
            }else{
                spanid = request.allHTTPHeaderFields[@"x-datadog-trace-id"];
            }
        }
    };
    [self.viewController ft_load:url.absoluteString];
    [tester waitForTimeInterval:10];
    [self.viewController ft_reload];
    [tester waitForTimeInterval:5];

}
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if(self.block){
        self.block(navigationAction.request);
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}
@end