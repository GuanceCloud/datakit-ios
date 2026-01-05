//
//  FTRemoteConfigTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/6/10.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTRemoteConfigurationRequest.h"
#import "FTMobileAgent.h"
#import "FTMobileConfig+Private.h"
#import "FTLoggerConfig+Private.h"
#import "FTRumConfig+Private.h"
#import "FTConstants.h"
#import "OHHTTPStubs.h"
#import "FTJSONUtil.h"
#import "FTRemoteConfigManager.h"
#import "FTLogger.h"
#import "FTTrackDataManager+Test.h"
#import "FTDataUploadWorker.h"
#import "XCTestCase+Utils.h"
#import "FTRemoteConfigModel+Test.h"
#import "FTRemoteConfigError.h"
#import "FTConfig+RemoteConfig.h"

@interface FTDataUploadWorker (Testing)
@property (nonatomic, assign,readonly) int uploadPageSize;
@property (nonatomic, assign,readonly) int syncSleepTime;
@property (nonatomic, strong,readonly) dispatch_queue_t networkQueue;
@end
@interface FTLogger (Testing)
@property (nonatomic, strong,readonly) NSSet *logLevelFilterSet;
@property (nonatomic, strong,readonly) dispatch_queue_t loggerQueue;
@property (nonatomic, strong,readonly) FTLoggerConfig *config;
@end
@interface FTRemoteConfigManager (Testing)
@property (nonatomic, strong) FTRemoteConfigModel *lastRemoteModel;
- (void)saveRemoteConfig:(NSDictionary<NSString *, id> *)remoteConfig;
@end

@interface FTRemoteConfigTest : XCTestCase<FTRemoteConfigurationProtocol>
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation FTRemoteConfigTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [OHHTTPStubs removeAllStubs];
}
- (void)testRequestFormat{
    NSString *datakit = @"http://datakit-test.com";
    NSString *dataWay = @"http://dataway-test.com";
    NSString *token = @"rum-token";
    NSString *appId = @"appid-test";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakit];
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:appId];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    
    FTRemoteConfigurationRequest *request = [[FTRemoteConfigurationRequest alloc]init];
    XCTAssertTrue([request.httpMethod isEqualToString:@"GET"]);
    NSURL *url = request.absoluteURL;
    XCTAssertTrue([url.host isEqualToString:[NSURL URLWithString:datakit].host]);
    NSURLComponents *components = [NSURLComponents componentsWithURL:url
                                             resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = components.queryItems;
    XCTAssertTrue(queryItems.count == 1);
    XCTAssertTrue([queryItems.firstObject.name isEqualToString:@"app_id"]);
    XCTAssertTrue([queryItems.firstObject.value isEqualToString:appId]);
    [FTMobileAgent shutDown];
    
    FTMobileConfig *datawayConfig = [[FTMobileConfig alloc]initWithDatawayUrl:dataWay clientToken:token];
    [FTMobileAgent startWithConfigOptions:datawayConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    
    FTRemoteConfigurationRequest *datawayRequest = [[FTRemoteConfigurationRequest alloc]init];
    XCTAssertTrue([datawayRequest.httpMethod isEqualToString:@"GET"]);
    NSURL *datawayUrl = datawayRequest.absoluteURL;
    XCTAssertTrue([datawayUrl.host isEqualToString:[NSURL URLWithString:dataWay].host]);
    NSURLComponents *datawayComponents = [NSURLComponents componentsWithURL:datawayUrl
                                                    resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *datawayQueryItems = datawayComponents.queryItems;
    XCTAssertTrue(datawayQueryItems.count == 3);
    int count = 0;
    for (NSURLQueryItem *item in datawayQueryItems) {
        if ([item.name isEqualToString:@"app_id"]) {
            count++;
            XCTAssertTrue([item.value isEqualToString:appId]);
        }else if ([item.name isEqualToString:@"token"]){
            count++;
            XCTAssertTrue([item.value isEqualToString:token]);
        }else if ([item.name isEqualToString:@"to_headless"]){
            count++;
            XCTAssertTrue([item.value isEqualToString:@"true"]);
        }
    }
    XCTAssertTrue(count == 3);
    [FTMobileAgent shutDown];
}
- (void)testRemoteConfigMiniUpdateInterval_lessThen{
    [self remoteConfigMiniUpdateIntervalWithLess:YES];
}
- (void)testRemoteConfigMiniUpdateInterval_greaterThen{
    [self remoteConfigMiniUpdateIntervalWithLess:NO];
}
- (void)remoteConfigMiniUpdateIntervalWithLess:(BOOL)less{
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
    __block int rCount = 0;
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteDataCallBack:^(int count) {
        rCount = count;
    } withOriginalRemoteDict:nil];
    NSString *datakit = @"http://datakit-test.com";
    NSString *appId = @"appid-test";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakit];
    config.enableSDKDebugLog = YES;
    config.remoteConfiguration = YES;
    config.remoteConfigMiniUpdateInterval = less?4:1;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:appId];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    [self waitForTimeInterval:2];
    NSDictionary *remoteConfig = [[FTRemoteConfigManager sharedInstance] getLastFetchedRemoteConfig];
    XCTAssertTrue(remoteConfig != nil);
    [FTMobileAgent updateRemoteConfig];
    [self waitForTimeInterval:1];
    if (less) {
        XCTAssertTrue(rCount == 1);
    }else{
        XCTAssertTrue(rCount == 2);
    }
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)testRemoteConfigMerge{
    NSDictionary *testBaseDict = @{
        FT_R_AUTO_SYNC:@(NO),
        FT_ENV:@"test",
        FT_R_SERVICE_NAME:@"test_remote",
        FT_R_SYNC_PAGE_SIZE:@(120),
        FT_R_SYNC_SLEEP_TIME:@(100)
    };
    NSString *datakit = @"http://datakit-test.com";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakit];
    FTMobileConfig *copyConfig = [config copy];
    [copyConfig mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testBaseDict]];
    XCTAssertTrue(config.autoSync == YES && copyConfig.autoSync == NO);
    XCTAssertTrue([config.env isEqualToString:@"prod"] && [copyConfig.env isEqualToString:@"test"]);
    XCTAssertTrue(![config.service isEqualToString:copyConfig.service] && [copyConfig.service isEqualToString:@"test_remote"]);
    XCTAssertTrue(config.syncPageSize != copyConfig.syncPageSize && copyConfig.syncPageSize == 120);
    XCTAssertTrue(config.syncSleepTime != copyConfig.syncSleepTime && copyConfig.syncSleepTime == 100);
    
    NSDictionary *testRumDict = @{
        FT_R_RUM_SAMPLERATE:@(0.5),
        FT_R_RUM_FREEZE_DURATION_MS:@(200),
        FT_R_RUM_ALLOW_WEBVIEW_HOST:@"[\"100.0.0.1\"]",
        FT_R_RUM_ENABLE_TRACE_WEBVIEW:@(NO),
        FT_R_RUM_ENABLE_TRACK_APP_ANR:@(YES),
        FT_R_RUM_ENABLE_TRACE_USER_VIEW:@(YES),
        FT_R_RUM_ENABLE_TRACK_APP_CRASH:@(YES),
        FT_R_RUM_ENABLE_RESOURCE_HOST_IP:@(YES),
        FT_R_RUM_ENABLE_TRACE_USER_ACTION:@(YES),
        FT_R_RUM_ENABLE_TRACE_USER_RESOURCE:@(YES),
        FT_R_RUM_ENABLE_TRACE_APP_FREEZE:@(YES),
        FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE:@(0.5),
    };
    
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"appid"];
    FTRumConfig *copyRumConfig = [rumConfig copy];
    
    [copyRumConfig mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testRumDict]];

    XCTAssertTrue(rumConfig.samplerate != copyRumConfig.samplerate && copyRumConfig.samplerate == 50);
    XCTAssertTrue(rumConfig.enableTrackAppFreeze != copyRumConfig.enableTrackAppFreeze && copyRumConfig.enableTrackAppFreeze == YES);
    XCTAssertTrue(rumConfig.freezeDurationMs != copyRumConfig.freezeDurationMs && copyRumConfig.freezeDurationMs == 200);
    XCTAssertTrue(rumConfig.allowWebViewHost != copyRumConfig.allowWebViewHost && [copyRumConfig.allowWebViewHost isEqualToArray:@[@"100.0.0.1"]]);
    XCTAssertTrue(rumConfig.enableTraceWebView != copyRumConfig.enableTraceWebView && copyRumConfig.enableTraceWebView == NO);
    XCTAssertTrue(rumConfig.enableTrackAppANR != copyRumConfig.enableTrackAppANR && copyRumConfig.enableTrackAppANR == YES);
    XCTAssertTrue(rumConfig.enableTraceUserView != copyRumConfig.enableTraceUserView && copyRumConfig.enableTraceUserView == YES);
    XCTAssertTrue(rumConfig.enableTrackAppANR != copyRumConfig.enableTrackAppANR && copyRumConfig.enableTrackAppANR == YES);
    XCTAssertTrue(rumConfig.enableTrackAppCrash != copyRumConfig.enableTrackAppCrash && copyRumConfig.enableTrackAppCrash == YES);
    XCTAssertTrue(rumConfig.enableResourceHostIP != copyRumConfig.enableResourceHostIP && copyRumConfig.enableResourceHostIP == YES);
    XCTAssertTrue(rumConfig.enableTraceUserAction != copyRumConfig.enableTraceUserAction && copyRumConfig.enableTraceUserAction == YES);
    XCTAssertTrue(rumConfig.enableTraceUserResource != copyRumConfig.enableTraceUserResource && copyRumConfig.enableTraceUserResource == YES);
    XCTAssertTrue(rumConfig.sessionOnErrorSampleRate != copyRumConfig.sessionOnErrorSampleRate && copyRumConfig.sessionOnErrorSampleRate == 50);
    
    NSDictionary *testTraceDict = @{
        FT_R_TRACE_SAMPLERATE:@(0.4),
        FT_R_TRACE_TRACE_TYPE:@"jaeger",
        FT_R_TRACE_ENABLE_AUTO_TRACE:@(YES),
    };
    
    FTTraceConfig *trace = [[FTTraceConfig alloc]init];
    FTTraceConfig *copyTrace = [trace copy];
    
    [copyTrace mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testTraceDict]];

    XCTAssertTrue(trace.samplerate != copyTrace.samplerate && copyTrace.samplerate == 40);
    XCTAssertTrue(trace.networkTraceType != copyTrace.networkTraceType && copyTrace.networkTraceType == FTNetworkTraceTypeJaeger);
    XCTAssertTrue(trace.enableAutoTrace != copyTrace.enableAutoTrace && copyTrace.enableAutoTrace == YES);
    
    
    NSDictionary *testLoggerDict = @{
        FT_R_LOG_SAMPLERATE:@(0.8),
        FT_R_LOG_LEVEL_FILTERS:@"[\"info\",\"error\"]",
        FT_R_LOG_ENABLE_CUSTOM_LOG:@(YES),
    };
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    FTLoggerConfig *copyLogger = [logger copy];
    
    [copyLogger mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testLoggerDict]];

    XCTAssertTrue(logger.samplerate != copyLogger.samplerate && copyLogger.samplerate == 80);
    XCTAssertTrue(logger.enableCustomLog != copyLogger.enableCustomLog && copyLogger.enableCustomLog == YES);
    XCTAssertTrue(![logger.logLevelFilter isEqual:copyLogger.logLevelFilter]);
    NSArray *array = @[@"info",@"error"];
    XCTAssertTrue([copyLogger.logLevelFilter isEqualToArray:array]);
    
    [[FTRemoteConfigManager sharedInstance] shutDown];
}
- (void)testWrongTypeMerge{
    NSDictionary *testBaseDict = @{
        FT_R_AUTO_SYNC:@"false",
        FT_ENV:@(2),
        FT_R_SERVICE_NAME:@(1),
        FT_R_SYNC_PAGE_SIZE:@"120",
        FT_R_SYNC_SLEEP_TIME:@"100"
    };
    NSString *datakit = @"http://datakit-test.com";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakit];
    FTMobileConfig *copyConfig = [config copy];
    
    XCTAssertNoThrow([copyConfig mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testBaseDict]]);
    XCTAssertTrue(config != copyConfig);
    XCTAssertTrue(config.autoSync == copyConfig.autoSync);
    XCTAssertTrue([config.env isEqual:copyConfig.env]);
    XCTAssertTrue([config.service isEqual:copyConfig.service]);
    XCTAssertTrue(config.syncPageSize == copyConfig.syncPageSize);
    XCTAssertTrue(config.syncSleepTime == copyConfig.syncSleepTime);
    
    
    NSDictionary *testRumDict = @{
        FT_R_RUM_SAMPLERATE:@"0.5",
        FT_R_RUM_FREEZE_DURATION_MS:@"qw",
        FT_R_RUM_ALLOW_WEBVIEW_HOST:@"[100.0.0.1]",
        FT_R_RUM_ENABLE_TRACE_WEBVIEW:@"true",
        FT_R_RUM_ENABLE_TRACK_APP_ANR:@"true",
        FT_R_RUM_ENABLE_TRACE_USER_VIEW:@"true",
        FT_R_RUM_ENABLE_TRACK_APP_CRASH:@"true",
        FT_R_RUM_ENABLE_RESOURCE_HOST_IP:@"true",
        FT_R_RUM_ENABLE_TRACE_USER_ACTION:@"true",
        FT_R_RUM_ENABLE_TRACE_USER_RESOURCE:@"true",
        FT_R_RUM_ENABLE_TRACE_APP_FREEZE:@"true",
        FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE:@"1",
    };
    
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"appid"];
    FTRumConfig *copyRumConfig = [rumConfig copy];
    
    XCTAssertNoThrow([copyRumConfig mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testRumDict]]);

    XCTAssertTrue(rumConfig.samplerate == copyRumConfig.samplerate);
    XCTAssertTrue(rumConfig.enableTrackAppFreeze == copyRumConfig.enableTrackAppFreeze);
    XCTAssertTrue(rumConfig.freezeDurationMs == copyRumConfig.freezeDurationMs);
    XCTAssertTrue(rumConfig.allowWebViewHost == copyRumConfig.allowWebViewHost);
    XCTAssertTrue(rumConfig.enableTraceWebView == copyRumConfig.enableTraceWebView);
    XCTAssertTrue(rumConfig.enableTrackAppANR == copyRumConfig.enableTrackAppANR);
    XCTAssertTrue(rumConfig.enableTraceUserView == copyRumConfig.enableTraceUserView);
    XCTAssertTrue(rumConfig.enableTrackAppANR == copyRumConfig.enableTrackAppANR);
    XCTAssertTrue(rumConfig.enableTrackAppCrash == copyRumConfig.enableTrackAppCrash);
    XCTAssertTrue(rumConfig.enableResourceHostIP == copyRumConfig.enableResourceHostIP);
    XCTAssertTrue(rumConfig.enableTraceUserAction == copyRumConfig.enableTraceUserAction);
    XCTAssertTrue(rumConfig.enableTraceUserResource == copyRumConfig.enableTraceUserResource);
    XCTAssertTrue(rumConfig.sessionOnErrorSampleRate == copyRumConfig.sessionOnErrorSampleRate);
    
    NSDictionary *testTraceDict = @{
        FT_R_TRACE_SAMPLERATE:@"0.4",
        FT_R_TRACE_TRACE_TYPE:@"jaeger123",
        FT_R_TRACE_ENABLE_AUTO_TRACE:@"true",
    };
    
    FTTraceConfig *trace = [[FTTraceConfig alloc]init];
    FTTraceConfig *copyTrace = [trace copy];
    
    XCTAssertNoThrow([copyTrace mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testTraceDict]]);

    XCTAssertTrue(trace.samplerate == copyTrace.samplerate);
    XCTAssertTrue(trace.networkTraceType == copyTrace.networkTraceType && copyTrace.networkTraceType == FTNetworkTraceTypeDDtrace);
    XCTAssertTrue(trace.enableAutoTrace == copyTrace.enableAutoTrace);
    
    
    NSDictionary *testLoggerDict = @{
        FT_R_LOG_SAMPLERATE:@"0.8",
        FT_R_LOG_LEVEL_FILTERS:@"[info]",
        FT_R_LOG_ENABLE_CUSTOM_LOG:@"1",
    };
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    FTLoggerConfig *copyLogger = [logger copy];
    
    XCTAssertNoThrow([copyLogger mergeWithRemoteConfigModel:[[FTRemoteConfigModel alloc] initWithDict:testLoggerDict]]);

    XCTAssertTrue(logger.samplerate == copyLogger.samplerate);
    XCTAssertTrue(logger.enableCustomLog == copyLogger.enableCustomLog);
    XCTAssertTrue(logger.logLevelFilter == copyLogger.logLevelFilter);
}
- (void)testDefaultUpdateRemoteConfig{
    
    NSString *datakit = @"http://datakit-test.com";
    NSString *appId = @"appid-test";
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    self.expectation = [self expectationWithDescription:@"UpdateRemoteConfig"];
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakit];
    config.remoteConfiguration = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTRemoteConfigManager sharedInstance].delegate = self;
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:appId];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    FTLoggerConfig *log = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:log];
    
    [self waitForExpectations:@[self.expectation]];
    
    dispatch_sync([FTLogger sharedInstance].loggerQueue, ^{
        XCTAssertTrue([[FTLogger sharedInstance].logLevelFilterSet containsObject:@"logTest"]);
        XCTAssertTrue([FTLogger sharedInstance].config.enableCustomLog == YES);
    });
    XCTAssertTrue([FTTrackDataManager sharedInstance].autoSync == NO);
    dispatch_sync([FTTrackDataManager sharedInstance].dataUploadWorker.networkQueue, ^{
        XCTAssertTrue([FTTrackDataManager sharedInstance].dataUploadWorker.syncSleepTime == 300);
        XCTAssertTrue([FTTrackDataManager sharedInstance].dataUploadWorker.uploadPageSize == 15);
    });
    XCTAssertTrue([[FTRemoteConfigManager sharedInstance] getLastFetchedRemoteConfig] != nil);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (id<OHHTTPStubsDescriptor>)mockRemoteData{
    return [self mockRemoteDataCallBack:nil withOriginalRemoteDict:nil];
}
- (id<OHHTTPStubsDescriptor>)mockRemoteDataCallBack:(nullable void (^)(int))callback withOriginalRemoteDict:(nullable NSDictionary *)originalRemoteDict{
    NSString *datakit = @"http://datakit-test.com";
    NSString *prefix = @"R.appid-test.";
    NSDictionary *defaultOriginalDict = @{
        FT_R_AUTO_SYNC: @NO,
        FT_R_SERVICE_NAME: @"debug",
        FT_R_SYNC_PAGE_SIZE: @15,
        FT_R_SYNC_SLEEP_TIME: @300,
        FT_R_COMPRESS_INTAKE_REQUESTS: @YES,
        FT_R_LOG_LEVEL_FILTERS: @"[\"logTest\"]",
        FT_R_LOG_ENABLE_CUSTOM_LOG: @YES
    };
    NSDictionary *effectiveOriginalDict = originalRemoteDict ?: defaultOriginalDict;
    
    NSMutableDictionary *remoteDict = [NSMutableDictionary dictionary];
    [effectiveOriginalDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *newKey = [NSString stringWithFormat:@"%@%@", prefix, key];
        remoteDict[newKey] = obj;
    }];
    
    NSDictionary *content = @{@"content":remoteDict};
    NSString *contentStr = [FTJSONUtil convertToJsonDataWithObject:content];
    if (!contentStr) {
        contentStr = @"{\"content\": {}}";
    }
    __block int count = 0;
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:[NSURL URLWithString:datakit].host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        count++;
        if (callback) {
            callback(count);
        }
        return [OHHTTPStubsResponse responseWithData:[contentStr dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    return stubs;
}
- (void)remoteConfigurationDidChange{
    if (self.expectation) {
        [[FTMobileAgent sharedInstance] performSelector:@selector(remoteConfigurationDidChange)];
        [self.expectation fulfill];
    }
}
- (void)testUpdateRemoteConfigWithMiniUpdateInterval_disable{
    [self updateRemoteConfigWithMiniUpdateIntervalWithEnable:NO];
}
- (void)testUpdateRemoteConfigWithMiniUpdateInterval_enable_greaterThenInterval{
    [self updateRemoteConfigWithMiniUpdateIntervalWithEnable:YES];
}
- (void)testUpdateRemoteConfigWithMiniUpdateInterval_enable_lessThenInterval{
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [self waitForTimeInterval:1];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"testDisableRemoteConfig"];
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:5 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == NO);
        XCTAssertTrue(error.code == FTRemoteConfigErrorCodeIntervalNotMet);
        [expectation fulfill];
        return model;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)testUpdateRemoteConfigWithMiniUpdateInterval_enable_isFetching{
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [self waitForTimeInterval:1];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"expectation1"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"expectation2"];
    
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == YES);
        [expectation1 fulfill];
        return model;
    }];
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 callback:^(BOOL success, NSDictionary<NSString *,id> * _Nullable config) {
        XCTAssertTrue(success == NO);
        [expectation2 fulfill];
    }];
    [self waitForExpectations:@[expectation1,expectation2] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)testUpdateRemoteConfigCallBack_configFormat{
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
    NSDictionary *remoteDict = @{
        FT_R_AUTO_SYNC: @YES,
        FT_R_SYNC_PAGE_SIZE: @20,
        FT_R_SYNC_SLEEP_TIME: @300,
        FT_R_COMPRESS_INTAKE_REQUESTS: @YES,
        FT_R_LOG_LEVEL_FILTERS: @"[\"logTest\"]",
        FT_R_LOG_ENABLE_CUSTOM_LOG: @YES
    };
    
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteDataCallBack:nil withOriginalRemoteDict:remoteDict];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [self waitForTimeInterval:1];
    
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"expectation1"];
    
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 callback:^(BOOL success, NSDictionary<NSString *,id> * _Nullable config) {
        XCTAssertTrue(success == YES);
        XCTAssertTrue(config != nil && [config isKindOfClass:NSDictionary.class]);
        NSMutableDictionary *content = [NSMutableDictionary dictionaryWithDictionary:config];
        [content removeObjectForKey:@"MD5"];
        XCTAssertTrue([content isEqualToDictionary:remoteDict]);
        [expectation1 fulfill];
    }];
    [self waitForExpectations:@[expectation1] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
/**
 * Verification: No crashes occur when call '+updateRemoteConfig','+updateRemoteConfigWithMiniUpdateInterval' method
 *  during SDK shutdown.
 */
- (void)testSDKShutdown{
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    NSInteger count = 0;
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [FTMobileAgent updateRemoteConfig];
            [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 callback:^(BOOL success, NSDictionary<NSString *,id> * _Nullable config) {
                
            }];
            dispatch_group_leave(group);
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            [FTMobileAgent shutDown];
            [self sdkInitWithRemoteConfiguration:YES interval:60];
        });
        count ++;
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    XCTAssertTrue(count == 1000);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}

- (void)updateRemoteConfigWithMiniUpdateIntervalWithEnable:(BOOL)enable{
    [[FTRemoteConfigManager sharedInstance] saveRemoteConfig:nil];
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    [self sdkInitWithRemoteConfiguration:enable interval:60];
    [self waitForTimeInterval:1];
    NSDictionary *remoteConfig = [[FTRemoteConfigManager sharedInstance] getLastFetchedRemoteConfig];
    if (enable) {
        XCTAssertTrue(remoteConfig != nil);
    }else{
        XCTAssertTrue(remoteConfig == nil);
    }
    XCTestExpectation *expectation = [self expectationWithDescription:@"testDisableRemoteConfig"];
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == enable);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)sdkInitWithRemoteConfiguration:(BOOL)enable interval:(int)interval{
    [self sdkInitWithRemoteConfiguration:enable interval:interval block:nil];
}
- (void)sdkInitWithRemoteConfiguration:(BOOL)enable interval:(int)interval block:(nullable FTRemoteConfigFetchCompletionBlock)block{
    NSString *datakit = @"http://datakit-test.com";
    NSString *appId = @"appid-test";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakit];
    config.remoteConfiguration = enable;
    config.remoteConfigMiniUpdateInterval = interval;
    config.remoteConfigFetchCompletionBlock = block;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:appId];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    FTLoggerConfig *log = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:log];
}
#pragma mark ========== RemoteConfigError ============
- (void)testRemoteConfigError_SDKNotInitialized{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDKNotInitialized"];
    
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == NO);
        XCTAssertEqual(error.code, FTRemoteConfigErrorCodeSDKNotInitialized);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}

- (void)testRemoteConfigError_Disabled{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Disabled"];
    [self sdkInitWithRemoteConfiguration:NO interval:60];
    
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == NO);
        XCTAssertEqual(error.code, FTRemoteConfigErrorCodeDisabled);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}

- (void)testRemoteConfigError_IntervalNotMet{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"IntervalNotMet"];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [self waitForTimeInterval:1];
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:10 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == NO);
        XCTAssertEqual(error.code, FTRemoteConfigErrorCodeIntervalNotMet);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)testRemoteConfigError_Requesting{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == NO);
        XCTAssertEqual(error.code, FTRemoteConfigErrorCodeRequesting);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
#pragma mark ==================FTRemoteConfigFetchCompletionBlock========================

- (void)testFetchCompletionBlock_return_nil_method{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [self waitForTimeInterval:1];

    __block FTRemoteConfigModel *resultModel;
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == YES);
        resultModel = [model copy];
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
    
}
- (void)testFetchCompletionBlock_return_model_method{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    [self sdkInitWithRemoteConfiguration:YES interval:60];
    [self waitForTimeInterval:1];

    __block FTRemoteConfigModel *resultModel;
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == YES);
        resultModel = [model copy];
        model.autoSync = @(NO);
        model.syncPageSize = @(1);
        [expectation fulfill];
        return model;
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertFalse([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}

- (void)testFetchCompletionBlock_return_nil_global{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    __block FTRemoteConfigModel *resultModel;

    [self sdkInitWithRemoteConfiguration:YES interval:60 block:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        resultModel = [model copy];
        [expectation fulfill];
        return nil;
    }];
   
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
    
}

- (void)testFetchCompletionBlock_return_model_global{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    __block FTRemoteConfigModel *resultModel;

    [self sdkInitWithRemoteConfiguration:YES interval:60 block:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        resultModel = [model copy];
        model.syncPageSize = @(2);
        [expectation fulfill];
        return model;
    }];
    
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertFalse([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
    
}
- (void)testFetchCompletionBlock_return_model{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Requesting2"];

    __block FTRemoteConfigModel *resultModel;

    [self sdkInitWithRemoteConfiguration:YES interval:60 block:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        resultModel = [model copy];
        resultModel.syncPageSize = @(2);
        [expectation fulfill];
        return resultModel;
    }];
    
    [self waitForTimeInterval:1];

    __block FTRemoteConfigModel *resultModel2;
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == YES);
        resultModel2 = [model copy];
        resultModel2.syncPageSize = @(1);
        [expectation2 fulfill];
        return resultModel2;
    }];
    
    [self waitForExpectations:@[expectation,expectation2] timeout:10];
    XCTAssertFalse([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    XCTAssertTrue([resultModel2.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)testFetchCompletionBlock_return_nil{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteData];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Requesting2"];

    __block FTRemoteConfigModel *resultModel;

    [self sdkInitWithRemoteConfiguration:YES interval:60 block:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        model.serviceName = @"a";
        resultModel = [model copy];
        [expectation fulfill];
        return nil;
    }];
    
    [self waitForTimeInterval:1];

    __block FTRemoteConfigModel *resultModel2;
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:0 completion:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        XCTAssertTrue(success == YES);
        model.serviceName = @"b";
        resultModel2 = [model copy];
        [expectation2 fulfill];
        return nil;
    }];
    
    [self waitForExpectations:@[expectation,expectation2] timeout:10];
    XCTAssertFalse([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    XCTAssertFalse([resultModel2.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}

#pragma mark ==================FTRemoteConfig custom content========================

- (void)testCustomContent{
    id<OHHTTPStubsDescriptor> stubs = [self mockRemoteDataCallBack:nil withOriginalRemoteDict:@{@"vips":@"[\"user1\"]"}];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Requesting"];
    __block FTRemoteConfigModel *resultModel;

    [self sdkInitWithRemoteConfiguration:YES interval:60 block:^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        resultModel = [model copy];
        XCTAssertTrue([content[@"vips"] isEqualToString:@"[\"user1\"]"]);
        [expectation fulfill];
        return nil;
    }];
   
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue([resultModel.toDictionary isEqualToDictionary:[[FTRemoteConfigManager sharedInstance].lastRemoteModel toDictionary]]);
    NSDictionary *dict = [[FTRemoteConfigManager sharedInstance] getLastFetchedRemoteConfig];
    XCTAssertTrue([dict[@"vips"] isEqualToString:@"[\"user1\"]"]);
    
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}

@end
