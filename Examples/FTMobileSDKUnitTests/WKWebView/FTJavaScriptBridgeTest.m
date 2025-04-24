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
#import "FTConstants.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTMobileAgentVersion.h"
#import "FTMobileConfig+Private.h"
#import "FTWKWebViewHandler.h"

@interface FTWKWebViewHandler (Testing)
@property (nonatomic, strong) NSMapTable *webViewRequestTable;

- (id)getWebViewBridge:(WKWebView *)webView;
@end

typedef void(^FTTraceRequest)(NSURLRequest *);
@interface FTJavaScriptBridgeTest : KIFTestCase<WKNavigationDelegate,FTWKWebViewRumDelegate>
@property (nonatomic, strong) TestWKWebViewVC *viewController;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) FTTraceRequest block;
@property (nonatomic, strong) XCTestExpectation *loadExpect;
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
}
- (void)setsdk{
    [self setSDK:nil];
}
- (void)setSDK:(NSDictionary *)pkgInfo{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.autoSync = NO;
    if(pkgInfo && pkgInfo.count>0){
        [pkgInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [config addPkgInfo:key value:obj];
        }];
    }
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
/// 1.验证有webview传入数据添加
/// 2.验证数据格式
///   基础 tags :
///    与 native sdk 一致：
///    sdk_name
///    sdk_version
///    service
///    新增 tag 字段：
///    sdk_pkg_info:{@"web":"version"}
///    is_web_view
///   其余与 native SDK 一致
///
///   rum 相关调整：
///   session_id： 与 native SDK 一致
///   is_active: false
///   其余与 webview 一致
///
- (void)testAddRumViewData{
    [self addRumViewData:NO];
}
- (void)testAddRumViewData_Nanosecond{
    [self addRumViewData:YES];
}
///    新增 tag 字段：
///    sdk_pkg_info:{@"web":"version",addPkgInfo}
///    is_web_view
///   其余与 native SDK 一致
- (void)testAddPkgInfo{
    [self addRumViewData:YES addPkgInfo:@{
        @"test_sdk1":@"1.0.0",
        @"test_sdk2":@"1.0.1",
                                        }];
}
- (void)addRumViewData:(BOOL)nano{
    [self addRumViewData:nano addPkgInfo:nil];
}
- (void)addRumViewData:(BOOL)nano addPkgInfo:(NSDictionary *)info{
    [self setSDK:info];
    long long smallTime = [NSDate ft_currentNanosecondTimeStamp];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [self.viewController ft_load:url.absoluteString];
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    XCTestExpectation *jsScript = [self expectationWithDescription:@"请求超时timeout!"];
    if(nano){
        [self.viewController test_addWebViewRumViewNano:^{
            [jsScript fulfill];
        }];
    }else{
        [self.viewController test_addWebViewRumView:^{
            [jsScript fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *datas =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;
    [datas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[FT_OPDATA];
        NSString *measurement = opdata[FT_KEY_SOURCE];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_RUM_SOURCE_VIEW]) {
            if(tags[FT_IS_WEBVIEW]){
                NSDictionary *field = opdata[FT_FIELDS];
                NSInteger errorCount = [field[FT_KEY_VIEW_ERROR_COUNT] integerValue];
                NSInteger resourceCount = [field[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
                NSInteger longTaskCount = [field[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
                NSString *viewName = tags[FT_KEY_VIEW_NAME];
                NSDictionary *tags = opdata[FT_TAGS];
                XCTAssertTrue(errorCount == 0);
                XCTAssertTrue(longTaskCount == 0);
                XCTAssertTrue(resourceCount == 0);
                XCTAssertTrue([viewName isEqualToString:@"testJSBridge"]);

                // rum 相关调整
                XCTAssertFalse([tags[FT_RUM_KEY_SESSION_ID] isEqualToString:@"12345"]);
                XCTAssertTrue([field[FT_KEY_IS_ACTIVE] isEqual:@(NO)]);
                NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithDictionary:@{@"web":@"3.0.19"}];
                [infoDict addEntriesFromDictionary:info];
                XCTAssertTrue([tags[FT_SDK_PKG_INFO] isEqualToDictionary:infoDict]);
                XCTAssertTrue([tags[FT_SDK_VERSION] isEqualToString:SDK_VERSION]);
                XCTAssertFalse([tags[FT_SDK_NAME] isEqualToString:@"df_web_rum_sdk"]);
                XCTAssertFalse([tags[FT_KEY_SERVICE] isEqualToString:@"browser"]);
                XCTAssertTrue(obj.tm>smallTime && obj.tm < [NSDate ft_currentNanosecondTimeStamp]);
                hasViewData = YES;
            }
        }
    }];
    XCTAssertTrue(hasViewData);
    [FTMobileAgent shutDown];
}
-(void)testloadFileURL{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [self.viewController test_loadFileURL:url allowingReadAccessToURL:url];
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    XCTestExpectation *jsScript = [self expectationWithDescription:@"请求超时timeout!"];
    [self.viewController test_addWebViewRumView:^{
        [jsScript fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *datas =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;
    [datas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[FT_OP];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[FT_OPDATA];
        NSString *measurement = opdata[FT_KEY_SOURCE];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_RUM_SOURCE_VIEW]) {
            if(tags[FT_IS_WEBVIEW]){
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
    [FTMobileAgent shutDown];
}
- (void)testReloadTrace{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    __block NSString *spanid;
    __block BOOL hasTrace = NO;
    self.block = ^(NSURLRequest *request){
        if([request.URL isEqual:url]){
            if(spanid){
                XCTAssertFalse([spanid isEqualToString:request.allHTTPHeaderFields[FT_NETWORK_DDTRACE_TRACEID]]);
                hasTrace = YES;
            }else{
                spanid = request.allHTTPHeaderFields[FT_NETWORK_DDTRACE_TRACEID];
            }
        }
    };
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [self.viewController ft_load:url.absoluteString];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [self.viewController ft_reload];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    XCTAssertTrue(hasTrace);
}
-(void)testSDKShutDownWebViewBridge{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [FTMobileAgent shutDown];
    NSInteger oldCount =[[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.viewController test_loadFileURL:url allowingReadAccessToURL:url];
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    XCTestExpectation *jsScript = [self expectationWithDescription:@"请求超时timeout!"];
    [self.viewController test_addWebViewRumView:^{
        [jsScript fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSInteger newCount =[[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == oldCount);
}
-(void)testSDKShutDownWebViewTrace{
    [self setsdk];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    __block NSString *spanid;
    __block BOOL reloadSuccess = NO;
    self.block = ^(NSURLRequest *request){
        if([request.URL isEqual:url]){
            if(spanid){
                XCTAssertTrue([spanid isEqualToString:request.allHTTPHeaderFields[FT_NETWORK_DDTRACE_TRACEID]]);                reloadSuccess = YES;
            }else{
                spanid = request.allHTTPHeaderFields[FT_NETWORK_DDTRACE_TRACEID];
            }
        }
    };
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [self.viewController ft_load:url.absoluteString];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.loadExpect = [self expectationWithDescription:@"请求超时timeout!"];
    [FTMobileAgent shutDown];
    [self.viewController ft_reload];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    XCTAssertTrue(reloadSuccess);
}
- (void)testMapTableWeakReferenceWebView{
    WKWebView *webView = [[WKWebView alloc]init];
    NSURLRequest *orRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http:mock.com"]];
    [FTWKWebViewHandler sharedInstance].rumTrackDelegate = self;
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:webView];
    [[FTWKWebViewHandler sharedInstance] addWebView:webView request:orRequest];
    id request = [[FTWKWebViewHandler sharedInstance].webViewRequestTable objectForKey:webView];
    XCTAssertTrue(request == orRequest);
    id bridge = [[FTWKWebViewHandler sharedInstance] getWebViewBridge:webView];
    XCTAssertTrue(bridge != nil);
    webView = nil;
    id bridge2 = [[FTWKWebViewHandler sharedInstance] getWebViewBridge:webView];
    XCTAssertTrue(bridge2 == nil);
    XCTAssertNil([[FTWKWebViewHandler sharedInstance].webViewRequestTable objectForKey:webView]);
}
- (void)testSameWebViewAddBridge_moreThanOnce{
    WKWebView *webView = [[WKWebView alloc]init];
    [FTWKWebViewHandler sharedInstance].rumTrackDelegate = self;
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:webView];
    id bridge = [[FTWKWebViewHandler sharedInstance] getWebViewBridge:webView];
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:webView];
    id bridge2 = [[FTWKWebViewHandler sharedInstance] getWebViewBridge:webView];
    XCTAssertTrue(bridge != nil);
    XCTAssertTrue(bridge2 != nil);
    XCTAssertTrue(bridge == bridge2);
}
- (void)dealReceiveScriptMessage:(id )message slotId:(NSUInteger)slotId{
    
}
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if(self.block){
        self.block(navigationAction.request);
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation{
    [self.loadExpect fulfill];
    self.loadExpect = nil;
}
@end
