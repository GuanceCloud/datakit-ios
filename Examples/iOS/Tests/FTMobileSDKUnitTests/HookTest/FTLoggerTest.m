//
//  FTLoggerTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2021/6/21.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
#import "XCTestCase+Utils.h"
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent+Private.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRecordModel.h"
#import "FTTrackDataManager.h"
#import "FTModelHelper.h"
#import "FTLog.h"
#import "FTInnerLog.h"
#import "FTFileLogger.h"
#import "FTTestUtils.h"
#import "FTLogger+Private.h"
#import "FTMobileConfig+Private.h"
#import "FTLoggerConfig+Private.h"
#import "FTRumConfig+Private.h"
#import "FTRemoteConfigModel+Test.h"
#import "FTWebViewLogEventMapper.h"
#import "FTInternalConstants.h"
#import "FTHTTPClient.h"
#import "FTDataUploadWorker.h"

@interface FTDataUploadWorker (WebViewLogUploadTesting)
- (BOOL)flushWithType:(NSString *)type maxBatchesPerUploadPass:(NSInteger)maxBatchesPerUploadPass;
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
    return @"web-view-thread-probe";
}
@end

@interface FTLoggerTest : XCTestCase<FTLoggerDataWriteProtocol>

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, strong) XCTestExpectation *logExpectation;
@property (nonatomic, strong) XCTestExpectation *webViewLogExpectation;
@property (nonatomic, copy) NSDictionary *lastLogTags;
@property (nonatomic, copy) NSDictionary *lastLogFields;
@property (nonatomic, assign) long long lastLogTime;
@property (nonatomic, assign) BOOL lastLogLinkRum;
@end

@implementation FTLoggerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [[FTLogger sharedInstance] shutDown];
    self.logExpectation = nil;
    self.webViewLogExpectation = nil;
    self.lastLogTags = nil;
    self.lastLogFields = nil;
    self.lastLogTime = 0;
    self.lastLogLinkRum = NO;
}
- (void)testWebViewLogMapper {
    NSDictionary *event = @{
        @"date": @1700000000123LL,
        @"_gc": @{ @"sdk_name": @"df_web_rum_sdk", @"sdk_version": @"3.3.6" },
        @"application": @{ @"id": @"browser-app" },
        @"session": @{ @"id": @"browser-session", @"type": @"user" },
        @"view": @{ @"id": @"browser-view", @"url_query": @"q=1" },
        @"user_action": @{ @"id": @"browser-action" },
        @"error": @{ @"source": @"source", @"type": @"TypeError", @"message": @"failure", @"stack": @"stack" },
        @"http": @{ @"url": @"https://example.com/path", @"status_code": @404 },
        @"message": @{ @"nested": @(YES) },
        @"status": @"warn",
        @"service": @"browser-service",
        @"custom_number": @42,
        @"custom_object": @{ @"nested": @(YES) },
    };

    FTWebViewLogEvent *mapped = [FTWebViewLogEventMapper mapEvent:event];
    XCTAssertNotNil(mapped);
    XCTAssertEqualObjects(mapped.content, @"{\"nested\":true}");
    XCTAssertEqualObjects(mapped.status, @"warning");
    XCTAssertEqual(mapped.time, 1700000000123000000LL);
    XCTAssertEqualObjects(mapped.tags[FT_IS_WEBVIEW], @(YES));
    XCTAssertEqualObjects(mapped.tags[FT_SDK_NAME], @"df_web_rum_sdk");
    XCTAssertEqualObjects(mapped.tags[FT_SDK_VERSION], @"3.3.6");
    XCTAssertEqualObjects(mapped.tags[FT_KEY_SERVICE], @"browser-service");
    XCTAssertEqualObjects(mapped.tags[FT_RUM_KEY_SESSION_ID], @"browser-session");
    XCTAssertEqualObjects(mapped.tags[FT_KEY_VIEW_ID], @"browser-view");
    XCTAssertEqualObjects(mapped.tags[FT_KEY_ACTION_ID], @"browser-action");
    XCTAssertEqualObjects(mapped.fields[@"error_message"], @"failure");
    XCTAssertEqualObjects(mapped.fields[@"error_stack"], @"stack");
    XCTAssertEqualObjects(mapped.fields[@"custom_number"], @42);
    XCTAssertEqualObjects(mapped.fields[@"custom_object"], @"{\"nested\":true}");
    XCTAssertNotNil(mapped.fields[@"application"]);

    [FTWebViewLogEventMapper replaceRumLinkDataInEvent:mapped
                                          applicationId:@"native-app"
                                               sessionId:@"native-session"];
    XCTAssertEqualObjects(mapped.tags[FT_APP_ID], @"native-app");
    XCTAssertEqualObjects(mapped.tags[FT_RUM_KEY_SESSION_ID], @"native-session");
    XCTAssertEqualObjects([FTJSONUtil dictionaryWithJsonString:mapped.fields[@"application"]][@"id"], @"native-app");
    XCTAssertEqualObjects([FTJSONUtil dictionaryWithJsonString:mapped.fields[@"session"]][@"id"], @"native-session");
    XCTAssertEqualObjects(mapped.tags[FT_KEY_VIEW_ID], @"browser-view");
    XCTAssertEqualObjects(mapped.tags[FT_KEY_ACTION_ID], @"browser-action");

    [FTWebViewLogEventMapper removeRumLinkDataFromEvent:mapped];
    XCTAssertNil(mapped.tags[FT_APP_ID]);
    XCTAssertNil(mapped.tags[FT_RUM_KEY_SESSION_ID]);
    XCTAssertNil(mapped.tags[FT_KEY_VIEW_ID]);
    XCTAssertNil(mapped.tags[FT_KEY_ACTION_ID]);
    XCTAssertNil(mapped.fields[@"application"]);
    XCTAssertNil(mapped.fields[@"session"]);
    XCTAssertNil(mapped.fields[@"view"]);
    XCTAssertNil(mapped.fields[@"user_action"]);
}
- (void)testWebViewLogMapperValidationAndTimeFallback {
    XCTAssertNil([FTWebViewLogEventMapper mapEvent:@{}]);
    XCTAssertNil([FTWebViewLogEventMapper mapEvent:(NSDictionary *)@[]]);

    long long before = [NSDate ft_currentNanosecondTimeStamp];
    FTWebViewLogEvent *mapped = [FTWebViewLogEventMapper mapEvent:@{ @"message": @123, @"date": @"invalid", @"status": @"" }];
    long long after = [NSDate ft_currentNanosecondTimeStamp];
    XCTAssertEqualObjects(mapped.content, @"123");
    XCTAssertEqualObjects(mapped.status, @"info");
    XCTAssertGreaterThanOrEqual(mapped.time, before);
    XCTAssertLessThanOrEqual(mapped.time, after);
}
- (void)testWebViewLoggerUsesIndependentSwitchSamplingFilterAndContentLimit {
    FTLoggerConfig *config = [[FTLoggerConfig alloc] init];
    config.enableCustomLog = NO;
    config.printCustomLogToConsole = NO;
    config.enableWebViewLog = YES;
    config.sampleRate = 100;
    config.logLevelFilter = @[@(FTStatusWarning)];
    [[FTLogger sharedInstance] startWithLoggerConfig:config writer:self];

    NSString *longMessage = [@"x" stringByPaddingToLength:FT_LOGGING_CONTENT_SIZE + 10 withString:@"x" startingAtIndex:0];
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": longMessage, @"status": @"warn" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    XCTAssertEqualObjects(self.lastLogTags[FT_KEY_STATUS], @"warning");
    XCTAssertEqualObjects(self.lastLogTags[FT_IS_WEBVIEW], @(YES));
    XCTAssertEqual([self.lastLogFields[FT_KEY_MESSAGE] length], FT_LOGGING_CONTENT_SIZE);

    self.lastLogFields = nil;
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"filtered", @"status": @"info" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    XCTAssertNil(self.lastLogFields);

    config.sampleRate = 0;
    config.logLevelFilter = nil;
    [[FTLogger sharedInstance] updateLoggerConfiguration:config];
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"sampled-out" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    XCTAssertNil(self.lastLogFields);

    config.sampleRate = 100;
    config.enableWebViewLog = NO;
    [[FTLogger sharedInstance] updateLoggerConfiguration:config];
    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"disabled" }
                               linkToNativeRum:NO];
    [[FTLogger sharedInstance] syncProcess];
    XCTAssertNil(self.lastLogFields);
}
- (void)testWebViewLogMappingRunsOffMainThread {
    FTLoggerConfig *config = [[FTLoggerConfig alloc] init];
    config.enableWebViewLog = YES;
    [[FTLogger sharedInstance] startWithLoggerConfig:config writer:self];

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
    XCTAssertEqualObjects(self.lastLogFields[FT_KEY_MESSAGE], @"web-view-thread-probe");
}
- (void)testWebViewLogReplacesOnlyNativeApplicationAndSessionLinks {
    [self setRightSDKConfig];
    FTRumConfig *rumConfig = [[FTRumConfig alloc] initWithAppid:self.appid];
    rumConfig.enableTraceWebView = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.enableLinkRumData = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTLogger sharedInstance] setValue:self forKey:@"loggerWriter"];
    [FTModelHelper startView];
    [FTModelHelper startAction];

    XCTestExpectation *webViewLogExpectation = [self expectationWithDescription:@"WebView log linked"];
    self.webViewLogExpectation = webViewLogExpectation;
    [[FTLogger sharedInstance] logWebViewEvent:@{
        @"application": @{ @"id": @"browser-app" },
        @"session": @{ @"id": @"browser-session" },
        @"view": @{ @"id": @"browser-view" },
        @"user_action": @{ @"id": @"browser-action" },
        @"message": @"linked-web-log",
    } linkToNativeRum:YES];
    [self waitForExpectations:@[webViewLogExpectation] timeout:2];

    XCTAssertEqualObjects(self.lastLogTags[FT_APP_ID], self.appid);
    XCTAssertNotEqualObjects(self.lastLogTags[FT_RUM_KEY_SESSION_ID], @"browser-session");
    XCTAssertEqualObjects(self.lastLogTags[FT_KEY_VIEW_ID], @"browser-view");
    XCTAssertEqualObjects(self.lastLogTags[FT_KEY_ACTION_ID], @"browser-action");
    XCTAssertEqualObjects([FTJSONUtil dictionaryWithJsonString:self.lastLogFields[@"application"]][@"id"], self.appid);
    XCTAssertEqualObjects([FTJSONUtil dictionaryWithJsonString:self.lastLogFields[@"session"]][@"id"], self.lastLogTags[FT_RUM_KEY_SESSION_ID]);
    XCTAssertTrue(self.lastLogLinkRum);
}
- (void)testWebViewLogUploadsThroughNativeLoggingEndpointAndDeletesCache {
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"http://127.0.0.1:9529"];
    config.autoSync = NO;
    config.compressIntakeRequests = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.enableCustomLog = NO;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    [[FTLogger sharedInstance] logWebViewEvent:@{ @"message": @"ios-web-upload-log" }
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
    XCTAssertTrue([httpClient.capturedUpload containsString:@"ios-web-upload-log"]);
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 0);
}
- (void)testInnerLogDisabledDoesNotEvaluateArguments{
    [FTLog enableLog:NO];
    __block NSInteger evaluationCount = 0;
    NSString *(^expensiveLogValue)(void) = ^NSString *{
        evaluationCount += 1;
        return @"expensive";
    };
    FTInnerLogDebug(@"%@", expensiveLogValue());
    FTInnerLogInfo(@"%@", expensiveLogValue());
    FTInnerLogError(@"%@", expensiveLogValue());
    FT_CONSOLE_LOG(StatusInfo, @"info", expensiveLogValue(), @{@"value": expensiveLogValue()});
    XCTAssertEqual(evaluationCount, 0);
}
- (void)testEnableCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.printCustomLogToConsole = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount=count+1);
}
- (void)testDisableCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = NO;
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTLogger sharedInstance] info:@"testLoggingMethod" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)testLogCacheLimitCount{
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    XCTAssertTrue(loggerConfig.logCacheLimitCount == 5000);
    loggerConfig.logCacheLimitCount = 500;
    XCTAssertTrue(loggerConfig.logCacheLimitCount == 1000);
    loggerConfig.logCacheLimitCount = 10000;
    XCTAssertTrue(loggerConfig.logCacheLimitCount == 10000);
}
- (void)testDiscardNew{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscard;
    loggerConfig.logCacheLimitCount = 1000;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<1030; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data isEqualToString:@"testData0"]);

    XCTAssertTrue(newCount == 1000);
}

- (void)testDiscardOldBulk{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscardOldest;
    loggerConfig.logCacheLimitCount = 500;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    for (int i = 0; i<1050; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 1000);
}
- (void)testLogLevelFilter{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusInfo)];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testLoggingMethod" property:nil];
    
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount>count);
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethodError" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
    NSInteger newCount2 =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount2 == newCount);
}
- (void)testCustomLogLevelFilter{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusInfo),@"test"];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] log:@"testCustomLogLevelFilter" status:@"test"];
    
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount>count);
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethodError" status:FTStatusError];
    [[FTLogger sharedInstance] log:@"testCustomLogLevelFilter" status:@"custom"];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
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
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
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
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] unbindUser];
}
-(void)testSetEmptyLoggerServiceName{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
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
#if TARGET_OS_TV
    NSString  *service = FT_TVOS_SERVICE_NAME;
#else
    NSString  *service = FT_DEFAULT_SERVICE_NAME;
#endif
    XCTAssertTrue([serviceName isEqualToString:service]);
}
- (void)testLogSource{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLogSource" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSString *sourceStr = [op valueForKey:FT_KEY_SOURCE];
#if TARGET_OS_TV
    NSString  *source = FT_LOGGER_TVOS_SOURCE;
#else
    NSString  *source = FT_LOGGER_SOURCE;
#endif
    XCTAssertTrue([sourceStr isEqualToString:source]);
}
- (void)testEnableLinkRumData_setLoggerFirst{
    self.logExpectation = [[XCTestExpectation alloc]initWithDescription:@"logWrite"];
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTLogger sharedInstance] setValue:self forKey:@"loggerWriter"];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];
    
    [self waitForExpectations:@[self.logExpectation] timeout:1];
}
- (void)testEnableLinkRumData_setRUMFirst{
    self.logExpectation = [[XCTestExpectation alloc]initWithDescription:@"logWrite"];
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTLogger sharedInstance] setValue:self forKey:@"loggerWriter"];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];
  
    [self waitForExpectations:@[self.logExpectation] timeout:1];
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
    [FTMobileAgent shutDown];
}
- (void)testSampleRate0{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.samplerate = 0;
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
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
- (void)testGlobalContext_mutable{
    [self setRightSDKConfig];
    NSMutableDictionary *globalContext = @{@"logger_id":@"logger_id_1"}.mutableCopy;
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.globalContext = globalContext;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [globalContext setValue:@"logger_mutable" forKey:@"logger_mutable"];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext_mutable" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"logger_id"] isEqualToString:@"logger_id_1"]);
    XCTAssertFalse([tags.allKeys containsObject:@"logger_mutable"]);
}
- (void)testAddPkgInfo{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [config addPkgInfo:@"test_sdk" value:@"1.0.0"];
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testAddPkgInfo" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[FT_SDK_PKG_INFO] isEqualToDictionary:@{@"test_sdk":@"1.0.0"}]);
    
}
- (void)testLoggerFormat_sdkName{
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testSdkName" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[FT_SDK_NAME] isEqualToString:FT_SDK_NAME_VALUE]);
}
- (void)testAppendLogGlobalContext{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.globalContext = @{@"logger_id":@"logger_id_1"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [FTMobileAgent appendLogGlobalContext:@{@"append_logger":@"logger_id_2"}];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"logger_id"] isEqualToString:@"logger_id_1"]);
    XCTAssertTrue([tags[@"append_logger"] isEqualToString:@"logger_id_2"]);
}
- (void)testLogger_Property{
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
- (void)testLogger_mutableProperty{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSMutableDictionary *property = @{@"logger_property":@"testLoggerProperty"}.mutableCopy;
    [[FTMobileAgent sharedInstance] logging:@"testLoggerProperty" status:FTStatusInfo property:property];
    [property setValue:@"logger_property_add" forKey:@"testLoggerProperty_add"];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *fields = op[FT_FIELDS];
    XCTAssertTrue([fields[@"logger_property"] isEqualToString:@"testLoggerProperty"]);
    XCTAssertFalse([fields.allKeys containsObject:@"logger_property_add"]);
}
- (void)testLoggerStatus{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testInfo" property:nil];
    [[FTLogger sharedInstance] error:@"testError" property:nil];
    [[FTLogger sharedInstance] warning:@"testWarning" property:nil];
    [[FTLogger sharedInstance] critical:@"testCritical" property:nil];
    [[FTLogger sharedInstance] ok:@"testOk" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    NSInteger count = 0;
    NSDictionary *logStatus = @{@"testInfo":@"info",
                                @"testError":@"error",
                                @"testWarning":@"warning",
                                @"testCritical":@"critical",
                                @"testOk":@"ok"
    };
    for (FTRecordModel *model in newDatas) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *op = dict[@"opdata"];
        NSDictionary *tags = op[FT_TAGS];
        NSDictionary *fields = op[FT_FIELDS];
        NSString *message = fields[@"message"];
        NSString *status = tags[@"status"];
        if([logStatus.allKeys containsObject:message]){
            count ++;
            XCTAssertTrue([status isEqualToString:logStatus[message]]);
        }
    }
    XCTAssertTrue(count == 5);
}
- (void)testCustomLoggerStatus{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.printCustomLogToConsole = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] log:@"testCustomLoggerStatus" status:@"test"];
    
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    BOOL hasLogger = NO;
    for (FTRecordModel *model in newDatas) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *op = dict[@"opdata"];
        NSDictionary *tags = op[FT_TAGS];
        NSDictionary *fields = op[FT_FIELDS];
        NSString *message = fields[@"message"];
        NSString *status = tags[@"status"];
        if([message isEqualToString:@"testCustomLoggerStatus"]){
            hasLogger = YES;
            XCTAssertTrue([status isEqualToString:@"test"]);
            break;
        }
    }
}
- (void)testInvalidLoggerStatusFallsBackWithoutCrash{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    [[FTLogger sharedInstance] log:@"negativeStatus" statusType:(FTLogStatus)-1 property:nil];
    [[FTLogger sharedInstance] log:@"largeStatus" statusType:(FTLogStatus)NSIntegerMax property:nil];
    [[FTLogger sharedInstance] log:@"missingCustomStatus" status:@"" property:nil];

    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    NSDictionary *expectedStatuses = @{
        @"negativeStatus": @"info",
        @"largeStatus": @"info",
        @"missingCustomStatus": @"unknown",
    };
    NSMutableSet *matchedMessages = [NSMutableSet set];
    for (FTRecordModel *model in newDatas) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *op = dict[FT_OPDATA];
        NSDictionary *tags = op[FT_TAGS];
        NSDictionary *fields = op[FT_FIELDS];
        NSString *message = fields[FT_KEY_MESSAGE];
        NSString *expectedStatus = expectedStatuses[message];
        if (expectedStatus) {
            XCTAssertEqualObjects(tags[FT_KEY_STATUS], expectedStatus);
            [matchedMessages addObject:message];
        }
    }
    XCTAssertEqual(matchedMessages.count, expectedStatuses.count);
}
- (void)testPrintCustomLogToConsole{
    [[FTLog sharedInstance] registerInnerLogCacheToDefaultPath];
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.printCustomLogToConsole = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTLogger sharedInstance] info:@"testPrintCustomLogToConsole" property:nil];
    [[FTLogger sharedInstance] syncProcess];
    [self waitForTimeInterval:1];
    NSArray *array =  [[FTLog sharedInstance] valueForKey:@"loggers"];
    BOOL hasFileLogger = NO;
    FTLogFileInfo *logFileInfo;
    NSString *logs = nil;
    for (id object in array) {
        if([object isKindOfClass:FTFileLogger.class]){
            FTFileLogger *fileLogger = (FTFileLogger *)object;
            NSData *data;
            dispatch_sync(fileLogger.loggerQueue, ^{
              
            });
            hasFileLogger = YES;
            logFileInfo = [fileLogger valueForKey:@"currentLogFileInfo"];
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:logFileInfo.filePath];
            data = [fileHandle readDataToEndOfFile];
            logs = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            break;
        }
    }
    NSLog(@"testPrintCustomLogToConsole:logs %@",logs);
    XCTAssertTrue([logs containsString:@"[IOS APP]"]);
    XCTAssertTrue([logs containsString:@"testPrintCustomLogToConsole"]);
}
- (void)testSDKShutDown{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSInteger oldCount = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    [[FTLogger sharedInstance] info:@"testLoggingMethod" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    CFTimeInterval duration = [FTTestUtils functionElapsedTime:^{
        [FTMobileAgent shutDown];
    }];
    XCTAssertTrue(duration<0.1);
    XCTAssertTrue(count>oldCount);
    [[FTLogger sharedInstance] error:@"testSDKShutDown" property:nil];
    [[FTLogger sharedInstance] warning:@"testSDKShutDown" property:nil];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertNoThrow([[FTLogger sharedInstance] ok:@"testSDKShutDown" property:nil]);
    XCTAssertTrue(count == newCount);
}
- (void)testSDKShutDownFlushesPendingLogCache{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    [[FTLogger sharedInstance] info:@"testSDKShutDownFlushesPendingLogCache" property:nil];
    [[FTLogger sharedInstance] syncProcess];
    XCTAssertEqual([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING], 0);

    [FTMobileAgent shutDown];

    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertEqual(datas.count, 1);
    FTRecordModel *model = datas.lastObject;
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *fields = op[FT_FIELDS];
    XCTAssertEqualObjects(fields[FT_KEY_MESSAGE], @"testSDKShutDownFlushesPendingLogCache");
}
/**
 *  verify: No crashes occur when add log data and update remote configuration during SDK shutdown.
 */
- (void)testLoggerShutdown{
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.logLevelFilter = @[@(2)];
    [[FTLogger sharedInstance] startWithLoggerConfig:loggerConfig writer:self];
    
   
    FTLoggerConfig *remote = [[FTLoggerConfig alloc]init];
    remote.samplerate = 80;
    remote.logLevelFilter = @[@"info"];
    remote.enableCustomLog = YES;
    
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    NSInteger count = 0;
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [[FTLogger sharedInstance] updateLoggerConfiguration:remote];
            [[FTLogger sharedInstance] info:@"testLoggerShutdown" property:nil];
            dispatch_group_leave(group);
        });
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [[FTLogger sharedInstance] shutDown];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[FTLogger sharedInstance] startWithLoggerConfig:loggerConfig writer:self];
            });
        });
        count ++;
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    XCTAssertTrue(count == 1000);
    [[FTLogger sharedInstance] shutDown];
}
- (void)testLongTimeLogCache{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<101; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[FTLogger sharedInstance] info:[NSString stringWithFormat:@"testLongTimeLogCache%d",i] property:nil];
        });
    }
    sleep(1);
    for (int i = 0; i<101; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[FTLogger sharedInstance] info:[NSString stringWithFormat:@"testLongTimeLogCache%d",i] property:nil];
        });
    }
    XCTestExpectation *expect = [self expectationWithDescription:@"Requesttimeout!"];
 
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(newCount == 202);
}
// Test multiple threads to store log arrays
- (void)testLogAsync_insertCacheToDB{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<101; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[FTLogger sharedInstance] info:[NSString stringWithFormat:@"testLongTimeLogCache%d",i] property:nil];
        });
        if(i%5==0){
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [[FTTrackDataManager sharedInstance] insertCacheToDB];
            });
        }
    }
    sleep(1);
    for (int i = 0; i<101; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[FTLogger sharedInstance] info:[NSString stringWithFormat:@"testLongTimeLogCache%d",i] property:nil];
        });
        if(i%5==0){
            [[FTTrackDataManager sharedInstance] insertCacheToDB];
        }
    }
    XCTestExpectation *expect = [self expectationWithDescription:@"Request timeout!"];
 
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(newCount == 202);
}
- (void)testLogFile{
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] registerInnerLogCacheToLogsDirectory:nil fileNamePrefix:nil];
    [self logFile:nil fileName:nil];
}
- (void)testRegisterInnerLogCacheToLogs_LogsDirectory{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"TestFTLogs"];
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] registerInnerLogCacheToLogsDirectory:logsDirectory fileNamePrefix:nil];
    [self logFile:logsDirectory fileName:nil];
}
- (void)testRegisterInnerLogCacheToLogs_FileName{
    NSString *fileName = [[NSUUID UUID] UUIDString];
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] registerInnerLogCacheToLogsDirectory:nil fileNamePrefix:fileName];
    [self logFile:nil fileName:fileName];
}
- (void)testRegisterInnerLogCacheToLogsFilePath{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"TestFTLogs"];
    NSString *filePath = [logsDirectory stringByAppendingPathComponent:@"ALog.log"];
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] registerInnerLogCacheToLogsFilePath:filePath];
    [self logFile:logsDirectory fileName:@"ALog"];
}
- (void)testRegisterInnerLogCacheToDefaultPath{
#if !TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#endif
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"FTLogs"];

    [FTLog enableLog:YES];
    [[FTLog sharedInstance] registerInnerLogCacheToDefaultPath];
    [self logFile:logsDirectory fileName:@"FTLog"];
}
- (void)testLogFileMaximumFileSize{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"TestFTLogsFileSize1"];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:logsDirectory error:&error];
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] registerInnerLogCacheToLogsDirectory:logsDirectory fileNamePrefix:nil];
    [[FTLog sharedInstance] userLog:NO message:@"testLogFileMaximumFileSize" level:StatusInfo status:@"info" property:nil];
    NSArray *array =  [[FTLog sharedInstance] valueForKey:@"loggers"];
    FTFileLogger *fileLogger;
    FTLogFileInfo *logFileInfo;
    for (id object in array) {
        if([object isKindOfClass:FTFileLogger.class]){
            fileLogger = (FTFileLogger *)object;
            logFileInfo = [fileLogger valueForKey:@"currentLogFileInfo"];
            break;
        }
    }
    fileLogger.maximumFileSize = 1024;
    for (int i = 0; i<2; i++) {
        FTInnerLogInfo(@"count:%d 11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",i);
    }
    [[FTLog sharedInstance] userLog:NO message:@"testLogFileMaximumFileSize" level:StatusInfo status:@"info"  property:nil];
    FTLogFileInfo *currentFileInfo = [fileLogger valueForKey:@"currentLogFileInfo"];
    XCTAssertTrue(currentFileInfo != logFileInfo);
    NSData *file = [[NSFileManager defaultManager] contentsAtPath:logFileInfo.filePath];
    XCTAssertTrue(file.length<1024*1.8);
    [[FTLog sharedInstance] shutDown];
    [[NSFileManager defaultManager] removeItemAtPath:[logFileInfo.filePath stringByDeletingLastPathComponent] error:&error];
}
- (void)testLogFilesDiskQuota{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"TestLogFilesDiskQuota_start"];
    FTLogFileManager *fileManager = [[FTLogFileManager alloc]initWithLogsDirectory:logsDirectory fileNamePrefix:nil];
    fileManager.logFilesDiskQuota = 2*1024;
    FTFileLogger *fileLogger = [[FTFileLogger alloc]initWithLogFileManager:fileManager];
    fileLogger.maximumFileSize = 1024;
    FTLogFileInfo *currentFileInfo = [fileLogger valueForKey:@"currentLogFileInfo"];
    NSString *firstFilePath = currentFileInfo.filePath;
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] performSelector:@selector(addLogger:) withObject:fileLogger];
    [[FTLog sharedInstance] userLog:NO message:@"testLogFilesDiskQuota" level:StatusInfo status:@"info" property:nil];
    for (int i = 0; i<10; i++) {
        FTInnerLogInfo(@"count:%d 11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",i);
    }
    [[FTLog sharedInstance] userLog:NO message:@"testLogFilesDiskQuota_end" level:StatusInfo status:@"info" property:nil];
    NSArray *array = [fileManager performSelector:@selector(sortedLogFileInfos)];
    unsigned long long totalSize = 0;
    for (FTLogFileInfo *info in array) {
        XCTAssertFalse([info.fileName isEqualToString:firstFilePath]);
        totalSize += info.fileSize;
    }
    FTLogFileInfo *oldestFile = [array lastObject];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:oldestFile.filePath];
    NSData *data = [fileHandle readDataToEndOfFile];
    NSString *logs = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertFalse([logs containsString:@"TestLogFilesDiskQuota_start"]);
    XCTAssertTrue(totalSize<2*1024*1024);
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:logsDirectory error:&error];
}
- (void)testBackupDirectoryOrder{
    FTLogFileManager *fileManager = [[FTLogFileManager alloc]initWithLogsDirectory:nil fileNamePrefix:@"testBackupDirectoryOrder.A"];
    FTFileLogger *fileLogger = [[FTFileLogger alloc]initWithLogFileManager:fileManager];
    fileLogger.maximumFileSize = 1024;
    [FTLog enableLog:YES];
    [[FTLog sharedInstance] performSelector:@selector(addLogger:) withObject:fileLogger];
    [[FTLog sharedInstance] userLog:NO message:@"testBackupDirectoryOrder_Start" level:StatusInfo status:@"info" property:nil];
    for (int i = 0; i<10; i++) {
        FTInnerLogInfo(@"count:%d 11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",i);
    }
    [[FTLog sharedInstance] userLog:NO message:@"testBackupDirectoryOrder_End" level:StatusInfo status:@"info" property:nil];
    
    NSArray *array = [fileManager performSelector:@selector(sortedLogFileInfos)];

    FTLogFileInfo *info = [array lastObject];
    XCTAssertTrue([info.fileName  containsString:@"testBackupDirectoryOrder.A"]);
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:info.filePath];
    NSData *data = [fileHandle readDataToEndOfFile];
    NSString *logs = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertTrue([logs containsString:@"testBackupDirectoryOrder_Start"]);
}
- (void)logFile:(NSString *)path fileName:(NSString *)fileName{
    NSDate *date = [NSDate date];
    NSString *dateStr = [date ft_stringWithBaseFormat];
    dateStr = [dateStr stringByAppendingString:@"testLogFile"];
    FTInnerLogInfo(@"%@",dateStr);
    [[FTLog sharedInstance] userLog:NO message:@"testLogFileUserLog" level:StatusInfo status:@"info"  property:nil];
    NSArray *array =  [[FTLog sharedInstance] valueForKey:@"loggers"];
    BOOL hasFileLogger = NO;
    FTLogFileInfo *logFileInfo;
    for (id object in array) {
        if([object isKindOfClass:FTFileLogger.class]){
            FTFileLogger *fileLogger = (FTFileLogger *)object;
            NSData *data;
            dispatch_sync(fileLogger.loggerQueue, ^{
              
            });
            hasFileLogger = YES;
            logFileInfo = [fileLogger valueForKey:@"currentLogFileInfo"];
            if (path) {
                NSString *filePath = [logFileInfo.filePath stringByDeletingLastPathComponent];
                NSLog(@"path:%@\n filePath:%@",path,filePath);
                XCTAssertTrue([path isEqualToString:filePath]);
            }
            if(fileName){
                XCTAssertTrue([logFileInfo.fileName hasPrefix:fileName]);
            }
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:logFileInfo.filePath];
            data = [fileHandle readDataToEndOfFile];
            NSString *logs = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            XCTAssertTrue([logs containsString:dateStr]);
            XCTAssertTrue([logs containsString:@"testLogFileUserLog"]);
            break;
        }
    }
    XCTAssertTrue(hasFileLogger);
    [[FTLog sharedInstance] shutDown];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:[logFileInfo.filePath stringByDeletingLastPathComponent] error:&error];
}
-(void)logging:(NSString *)content status:(NSString *)status tags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time{
    
}
- (void)loggingTags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time linkRum:(BOOL)linkRum {
    self.lastLogTags = tags;
    self.lastLogFields = field;
    self.lastLogTime = time;
    self.lastLogLinkRum = linkRum;
    if (self.webViewLogExpectation) {
        [self.webViewLogExpectation fulfill];
        self.webViewLogExpectation = nil;
    }
    if (self.logExpectation) {
        XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
        XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
        XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
        XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_ID]);
        [self.logExpectation fulfill];
    }
}

@end
