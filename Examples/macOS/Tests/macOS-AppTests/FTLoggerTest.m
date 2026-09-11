//
//  FTLoggerTest.m
//  MacOSAppTests
//
//  Created by hulilei on 2023/4/11.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <XCTest/XCTest.h>
#import "FTTestHelper.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTTrackerEventDBTool.h"
#import "FTTrackDataManager.h"
#import "FTRUMManager.h"
#import "FTRecordModel.h"
#import "FTDateUtil.h"
#import "FTJSONUtil.h"
#import "FTLogger+Private.h"
#import "FTWebViewLogEventMapper.h"
#import "FTConfig+RemoteConfig.h"
#import "FTRemoteConfigModel.h"
#import "FTRemoteConfigModel+Private.h"
#import "FTSDKVersion.h"
#import "FTWKWebViewHandler+Private.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTHTTPClient.h"
#import "FTDataUploadWorker.h"
#import <WebKit/WebKit.h>
@interface FTDataUploadWorker (WebViewLogUploadTesting)
- (BOOL)flushWithType:(NSString *)type maxBatchesPerUploadPass:(NSInteger)maxBatchesPerUploadPass;
@end
@interface FTWKWebViewHandler (WebViewLogTesting)
- (nullable id)getWebViewBridge:(WKWebView *)webView;
- (void)processWebViewBridgeEvent:(id)message slotId:(int64_t)slotID bindInfo:(FTBindInfo *)info;
@end
@interface FTWebViewLogHTTPClientStub : FTHTTPClient
@property (nonatomic, copy) NSString *capturedUpload;
@end
@implementation FTWebViewLogHTTPClientStub
- (void)sendRequest:(id<FTRequestProtocol>)request
         completion:(void (^)(NSHTTPURLResponse * _Nullable, NSData * _Nullable, NSError * _Nullable))callback {
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:request.absoluteURL];
    if ([request respondsToSelector:@selector(adaptedRequest:)]) {
        urlRequest = [request adaptedRequest:urlRequest];
    }
    NSString *requestBody = [[NSString alloc] initWithData:urlRequest.HTTPBody encoding:NSUTF8StringEncoding];
    self.capturedUpload = [NSString stringWithFormat:@"%@\n%@\n%@\n%@",
                           NSStringFromClass([(NSObject *)request class]), request.path,
                           request.absoluteURL.absoluteString, requestBody];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.absoluteURL
                                                             statusCode:200
                                                            HTTPVersion:@"HTTP/1.1"
                                                           headerFields:nil];
    callback(response, [NSData data], nil);
}
@end
@interface FTWebViewLogThreadProbe : NSObject
@property (atomic, assign) BOOL descriptionCalledOnMainThread;
@property (nonatomic, strong) XCTestExpectation *descriptionExpectation;
@end
@implementation FTWebViewLogThreadProbe
- (NSString *)description {
    self.descriptionCalledOnMainThread = NSThread.isMainThread;
    [self.descriptionExpectation fulfill];
    self.descriptionExpectation = nil;
    return @"mac-web-view-thread-probe";
}
@end
@interface FTLoggerTest : FTTestHelper <WKNavigationDelegate, FTLoggerDataWriteProtocol>
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, strong) XCTestExpectation *webViewLoadExpectation;
@property (nonatomic, strong) NSWindow *webViewWindow;
@property (nonatomic, copy) NSDictionary *lastWebViewLogFields;

@end

@implementation FTLoggerTest

- (void)setUp {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    [FTMobileAgent shutDown];
    self.webViewLoadExpectation = nil;
    [self.webViewWindow close];
    self.webViewWindow = nil;
    self.lastWebViewLogFields = nil;
}
- (void)testWebViewLogMapperAndRemoteConfiguration {
    FTRemoteConfigModel *remote = [[FTRemoteConfigModel alloc] initWithDict:@{
        @"logEnableWebViewLog": @(YES),
        @"rumAllowWebViewHost": @"[]",
    }];
    XCTAssertEqualObjects(remote.logEnableWebViewLog, @(YES));
    XCTAssertEqualObjects(remote.rumAllowWebViewHost, @[]);
    XCTAssertEqualObjects(remote.toDictionary[@"rumAllowWebViewHost"], @"[]");

    FTLoggerConfig *remoteLogger = [[FTLoggerConfig alloc] init];
    [remoteLogger mergeWithRemoteConfigModel:remote];
    XCTAssertTrue(remoteLogger.enableWebViewLog);

    FTWebViewLogEvent *event = [FTWebViewLogEventMapper mapEvent:@{
        @"date": @1700000000123LL,
        @"_gc": @{ @"sdk_name": @"df_web_rum_sdk", @"sdk_version": @"3.3.6" },
        @"application": @{ @"id": @"browser-app" },
        @"session": @{ @"id": @"browser-session" },
        @"view": @{ @"id": @"browser-view" },
        @"user_action": @{ @"id": @"browser-action" },
        @"error": @{ @"message": @"failure", @"stack": @"stack" },
        @"message": @[@"complex", @1],
        @"status": @"warn",
        @"custom": @{ @"nested": @(YES) },
    }];
    XCTAssertEqualObjects(event.content, @"[\"complex\",1]");
    XCTAssertEqualObjects(event.status, @"warning");
    XCTAssertEqual(event.time, 1700000000123000000LL);
    XCTAssertEqualObjects(event.tags[FT_IS_WEBVIEW], @(YES));
    XCTAssertEqualObjects(event.fields[@"error_message"], @"failure");
    XCTAssertEqualObjects(event.fields[@"custom"], @"{\"nested\":true}");

    [FTWebViewLogEventMapper replaceRumLinkDataInEvent:event applicationId:@"native-app" sessionId:@"native-session"];
    XCTAssertEqualObjects(event.tags[FT_APP_ID], @"native-app");
    XCTAssertEqualObjects(event.tags[FT_RUM_KEY_SESSION_ID], @"native-session");
    XCTAssertEqualObjects(event.tags[FT_KEY_VIEW_ID], @"browser-view");
    XCTAssertEqualObjects(event.tags[FT_KEY_ACTION_ID], @"browser-action");
    [FTWebViewLogEventMapper removeRumLinkDataFromEvent:event];
    XCTAssertNil(event.tags[FT_APP_ID]);
    XCTAssertNil(event.tags[FT_RUM_KEY_SESSION_ID]);
    XCTAssertNil(event.tags[FT_KEY_VIEW_ID]);
    XCTAssertNil(event.tags[FT_KEY_ACTION_ID]);
}
- (void)testWebViewLogUsesNativeLoggerStorageAndCollisionRules {
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.env = @"native-env";
    config.service = @"native-service";
    [FTMobileAgent startWithConfigOptions:config];

    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableCustomLog = NO;
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.enableLinkRumData = NO;
    loggerConfig.globalContext = @{ @"global_tag": @"native", @"browser_custom": @"native" };
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    [[FTLogger sharedInstance] logWebViewEvent:@{
        @"_gc": @{ @"sdk_name": @"df_web_rum_sdk", @"sdk_version": @"3.3.6" },
        @"application": @{ @"id": @"browser-app" },
        @"session": @{ @"id": @"browser-session" },
        @"view": @{ @"id": @"browser-view" },
        @"user_action": @{ @"id": @"browser-action" },
        @"message": @"mac-web-log",
        @"status": @"info",
        @"service": @"browser-service",
        @"env": @"browser-env",
        @"browser_custom": @"browser",
    } linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];

    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING] lastObject];
    NSDictionary *opdata = [FTJSONUtil dictionaryWithJsonString:model.data][FT_OPDATA];
    NSDictionary *tags = opdata[FT_TAGS];
    NSDictionary *fields = opdata[FT_FIELDS];
    XCTAssertEqualObjects(opdata[FT_KEY_SOURCE], FT_LOGGER_MACOS_SOURCE);
    XCTAssertEqualObjects(fields[FT_KEY_MESSAGE], @"mac-web-log");
    XCTAssertEqualObjects(tags[FT_IS_WEBVIEW], @(YES));
    XCTAssertEqualObjects(tags[FT_KEY_SERVICE], @"browser-service");
    XCTAssertEqualObjects(tags[FT_SDK_NAME], FT_SDK_NAME_VALUE);
    XCTAssertEqualObjects(tags[FT_SDK_VERSION], SDK_VERSION);
    XCTAssertEqualObjects(tags[FT_SDK_PKG_INFO][@"web"], @"3.3.6");
    XCTAssertEqualObjects(tags[@"env"], @"native-env");
    XCTAssertEqualObjects(tags[@"browser_custom"], @"native");
    XCTAssertNil(tags[FT_APP_ID]);
    XCTAssertNil(tags[FT_RUM_KEY_SESSION_ID]);
    XCTAssertNil(tags[FT_KEY_VIEW_ID]);
    XCTAssertNil(tags[FT_KEY_ACTION_ID]);
}
- (void)testWebViewLogUsesLoggerSamplingAndLevelFilter {
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableCustomLog = NO;
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.sampleRate = 0;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"sampled-out", @"status": @"warning" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 0);

    loggerConfig.sampleRate = 100;
    loggerConfig.logLevelFilter = @[@(FTStatusWarning)];
    [[FTLogger sharedInstance] updateLoggerConfiguration:loggerConfig];
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"filtered", @"status": @"info" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"accepted", @"status": @"warn" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 1);
}
- (void)testWebViewLogMappingRunsOffMainThread {
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableWebViewLog = YES;
    [[FTLogger sharedInstance] startWithLoggerConfig:loggerConfig writer:self];

    FTWebViewLogThreadProbe *probe = [FTWebViewLogThreadProbe new];
    XCTestExpectation *descriptionExpectation = [self expectationWithDescription:@"Map WebView Log off main thread"];
    probe.descriptionExpectation = descriptionExpectation;
    void (^sendEvent)(void) = ^{
        [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": probe }
                                   linkToNativeRum:NO];
    };
    if (NSThread.isMainThread) {
        sendEvent();
    } else {
        dispatch_sync(dispatch_get_main_queue(), sendEvent);
    }

    [self waitForExpectations:@[descriptionExpectation] timeout:2];
    [[FTLogger sharedInstance] syncProcess];
    XCTAssertFalse(probe.descriptionCalledOnMainThread);
    XCTAssertEqualObjects(self.lastWebViewLogFields[FT_KEY_MESSAGE], @"mac-web-view-thread-probe");
}
- (void)testLogOnlyWKWebViewBridgeInstallsAndRoutesSubsequentValidEvent {
    // The macOS test host may initialize the SDK before XCTest invokes this
    // test. Reset it so the logger configuration below is always the first one.
    [FTMobileAgent shutDown];
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.enableCustomLog = NO;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 240)];
    self.webViewWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 320, 240)
                                                     styleMask:NSWindowStyleMaskTitled
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
    self.webViewWindow.contentView = webView;
    [self.webViewWindow orderFront:nil];
    [[FTWKWebViewHandler sharedInstance] enableWebView:webView];
    webView.navigationDelegate = self;
    self.webViewLoadExpectation = [self expectationWithDescription:@"WebView loaded"];
    [webView loadHTMLString:@"<html><body>WebView Log</body></html>" baseURL:[NSURL URLWithString:@"https://example.com"]];
    [self waitForExpectations:@[self.webViewLoadExpectation] timeout:10];

    XCTAssertNotNil([[FTWKWebViewHandler sharedInstance] getWebViewBridge:webView]);
    XCTestExpectation *scriptExpectation = [self expectationWithDescription:@"Bridge installed"];
    [webView evaluateJavaScript:@"typeof FTWebViewJavascriptBridge.sendEvent" completionHandler:^(id result, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(result, @"function");
        [scriptExpectation fulfill];
    }];
    [self waitForExpectations:@[scriptExpectation] timeout:10];

    FTBindInfo *bindInfo = [[FTBindInfo alloc] init];
    bindInfo.container = webView;
    [[FTWKWebViewHandler sharedInstance] processWebViewBridgeEvent:@{ @"name": @"log", @"data": @{ @"status": @"info" } }
                                                           slotId:webView.hash
                                                              bindInfo:bindInfo];
    [[FTWKWebViewHandler sharedInstance] processWebViewBridgeEvent:@{ @"name": @"log", @"data": @{ @"message": @"mac-bridge-log", @"status": @"info" } }
                                                           slotId:webView.hash
                                                              bindInfo:bindInfo];
    [[FTLogger sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *records = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    XCTAssertEqual(records.count, 1);
    FTRecordModel *model = records.lastObject;
    NSDictionary *opdata = [FTJSONUtil dictionaryWithJsonString:model.data][FT_OPDATA];
    XCTAssertEqualObjects(opdata[FT_FIELDS][FT_KEY_MESSAGE], @"mac-bridge-log");
    XCTAssertEqualObjects(opdata[FT_TAGS][FT_IS_WEBVIEW], @(YES));
}
- (void)testWebViewLogUploadsThroughNativeLoggingEndpointAndDeletesCache {
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.compressIntakeRequests = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.enableCustomLog = NO;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"mac-web-upload-log" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 1);

    FTWebViewLogHTTPClientStub *httpClient = [[FTWebViewLogHTTPClientStub alloc] initWithTimeoutIntervalForRequest:1];
    FTDataUploadWorker *uploadWorker = [[FTDataUploadWorker alloc] initWithSyncPageSize:10 syncSleepTime:0];
    uploadWorker.httpClient = httpClient;
    [uploadWorker flushWithType:FT_DATA_TYPE_LOGGING maxBatchesPerUploadPass:1];
    [uploadWorker invalidateAndCancelPendingUploads];

    XCTAssertTrue([httpClient.capturedUpload containsString:@"/v1/write/logging"], @"%@", httpClient.capturedUpload);
    XCTAssertTrue([httpClient.capturedUpload containsString:@"mac-web-upload-log"]);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 0);
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.webViewLoadExpectation) {
        [self.webViewLoadExpectation fulfill];
        self.webViewLoadExpectation = nil;
    }
}
- (void)loggingTags:(nullable NSDictionary *)tags
               field:(nullable NSDictionary *)field
                time:(long long)time
             linkRum:(BOOL)linkRum {
    self.lastWebViewLogFields = field;
}
- (void)testEnableCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount=count+1);
}
- (void)testLogSource{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLogSource" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *records = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [records lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[FT_OPDATA];
    XCTAssertEqualObjects(opdata[FT_KEY_SOURCE], FT_LOGGER_MACOS_SOURCE);
}
- (void)testDisbleCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = NO;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)testDiscardNew{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscard;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<5030; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data isEqualToString:@"testData0"]);

    XCTAssertTrue(newCount == 5000);
}

- (void)testDiscardOldBulk{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscardOldest;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    for (int i = 0; i<5045; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 5000);
}
- (void)testLogLevelFilter{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusInfo)];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount>count);
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethodError" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount2 =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount2 == newCount);

}
- (void)testEmptyStringMessageLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)testNotSetLoggerConfig{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    [[FTMobileAgent sharedInstance] logging:@"testNotSetLoggerConfig" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}
-(void)testSetEmptyLoggerServiceName{
    [self setRightSDKConfig];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue(serviceName.length>0);
}
- (void)testEnableLinkRumData{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTExternalDataManager sharedManager] startViewWithName:@"TestLoggerLinkRumData"];
    [[FTExternalDataManager sharedManager] startAction:@"EnableLinkRumDataClick" actionType:@"click" property:nil];
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];

    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags =opdata[FT_TAGS];
    XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
    XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
}
- (void)testDisableLinkRumData{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = NO;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];

    [[FTMobileAgent sharedInstance] syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags =opdata[FT_TAGS];
    XCTAssertFalse([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
    XCTAssertFalse([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);

}
- (void)testSampleRate0{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.samplerate = 0;
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
    NSLog(@"testSampleRate0");
    [[FTMobileAgent sharedInstance] syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    XCTAssertTrue(oldDatas.count == newDatas.count);
}
- (void)testSampleRate100{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count+1 == newDatas.count);

}
- (void)testGlobalContext{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.globalContext = @{@"logger_id":@"logger_id_1"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"logger_id"] isEqualToString:@"logger_id_1"]);

}
- (void)testLoggerProperty{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggerProperty" status:FTStatusInfo property:@{@"logger_property":@"testLoggerProperty"}];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *fields = op[FT_FIELDS];
    XCTAssertTrue([fields[@"logger_property"] isEqualToString:@"testLoggerProperty"]);
}


@end
