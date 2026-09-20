//
//  MacOSAppTests.m
//  MacOSAppTests
//
//  Created by hulilei on 2021/8/2.
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
#import "FTDateUtil.h"
#import "FTRecordModel.h"
#import "FTTrackDataManager.h"
#import "FTTrackerEventDBTool.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTJSONUtil.h"
#import "FTSDKConfig+Private.h"
@interface FTSDKAgent (WebViewLogTesting)
- (nullable NSArray *)effectiveAllowWebViewHost;
- (void)remoteConfigurationDidChange;
@end

#import "FTWKWebViewHandler+Private.h"
#import "FTLogger+Private.h"
#import "FTRemoteConfigManager.h"
#import "FTRemoteConfigModel+Private.h"

@interface FTWKWebViewHandler (ConfigurationTesting)
- (id)getWebViewBridge:(WKWebView *)webView;
- (void)processWebViewBridgeEvent:(id)message slotId:(int64_t)slotID bindInfo:(id)info;
@end

@interface FTMacWebViewDelegateStub : NSObject <FTWKWebViewLogDelegate, FTWKWebViewRumDelegate>
@property (nonatomic, assign) NSUInteger logCount;
@property (nonatomic, assign) NSUInteger rumCount;
@property (nonatomic, strong) NSDictionary *lastLog;
@property (nonatomic, assign) BOOL linkToNativeRum;
@end

@implementation FTMacWebViewDelegateStub
- (void)logWebViewEvent:(NSDictionary *)event linkToNativeRum:(BOOL)linkToNativeRum {
    self.logCount++;
    self.lastLog = event;
    self.linkToNativeRum = linkToNativeRum;
}
- (void)dealRUMWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm {
    self.rumCount++;
}
- (NSString *)getLastHasReplayViewID { return nil; }
- (NSString *)getLastViewName { return nil; }
- (void)bindSRInfo:(NSDictionary *)info containerViewID:(NSString *)viewID {}
@end

@interface MacOSAppTests : XCTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *traceUrl;
@end

@implementation MacOSAppTests

- (void)testWebViewHandlerRoutesToInjectedDelegates {
    // No Logger or RUM singleton is needed to test Bridge routing.
    for (NSNumber *rumFirst in @[@NO, @YES]) {
        FTWKWebViewHandler *handler = [[FTWKWebViewHandler alloc] init];
        FTMacWebViewDelegateStub *delegate = [[FTMacWebViewDelegateStub alloc] init];
        XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], @"null");
        [handler setAllowWebViewHost:@[]];
        XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], @"\"[]\"");
        [handler setAllowWebViewHost:@[@"shared.example.com"]];
        NSString *hosts = [handler valueForKey:@"allowWebViewHostsString"];
        NSDictionary *payload = @{@"message": @"injected"};
        NSDictionary *log = @{@"name": @"log", @"data": payload};
        NSDictionary *rum = @{@"name": @"rum", @"data": @{
            @"measurement": @"action", @"tags": @{}, @"fields": @{@"action_name": @"web"}, @"time": @1000
        }};
        WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero];
        [handler innerEnableWebView:webView];
        XCTAssertNil([handler getWebViewBridge:webView]);

        if (rumFirst.boolValue) {
            [handler startWithEnableTraceWebView:YES rumDelegate:delegate];
        } else {
            [handler startWithEnableWebViewLog:YES logDelegate:delegate];
        }
        [handler innerEnableWebView:webView];
        id bridge = [handler getWebViewBridge:webView];
        XCTAssertNotNil(bridge);
        [handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil];
        [handler processWebViewBridgeEvent:rum slotId:0 bindInfo:nil];
        XCTAssertEqual(delegate.logCount, rumFirst.boolValue ? 0U : 1U);
        XCTAssertEqual(delegate.rumCount, rumFirst.boolValue ? 1U : 0U);
        XCTAssertFalse(delegate.linkToNativeRum);

        if (rumFirst.boolValue) {
            [handler startWithEnableWebViewLog:YES logDelegate:delegate];
        } else {
            [handler startWithEnableTraceWebView:YES rumDelegate:delegate];
        }
        [handler innerEnableWebView:webView];
        XCTAssertEqual([handler getWebViewBridge:webView], bridge);
        XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], hosts);
        [handler setAllowWebViewHost:nil];
        XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], @"null");
        // Successful routing below verifies that host configuration preserves both delegates.
        delegate.logCount = 0;
        delegate.rumCount = 0;
        [handler processWebViewBridgeEvent:@{@"name": @"log", @"data": @[]} slotId:0 bindInfo:nil];
        [handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil];
        [handler processWebViewBridgeEvent:rum slotId:0 bindInfo:nil];
        XCTAssertEqual(delegate.logCount, 1U);
        XCTAssertEqual(delegate.rumCount, 1U);
        XCTAssertEqual(delegate.lastLog, payload);
        XCTAssertTrue(delegate.linkToNativeRum);

        [handler startWithEnableTraceWebView:NO rumDelegate:delegate];
        [handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil];
        [handler processWebViewBridgeEvent:rum slotId:0 bindInfo:nil];
        XCTAssertEqual(delegate.logCount, 2U);
        XCTAssertEqual(delegate.rumCount, 1U);
        XCTAssertFalse(delegate.linkToNativeRum);
        [handler startWithEnableTraceWebView:YES rumDelegate:nil];
        [handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil];
        XCTAssertFalse(delegate.linkToNativeRum);

        [handler startWithEnableTraceWebView:YES rumDelegate:delegate];
        [handler startWithEnableWebViewLog:NO logDelegate:delegate];
        [handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil];
        [handler processWebViewBridgeEvent:rum slotId:0 bindInfo:nil];
        XCTAssertEqual(delegate.logCount, 3U);
        XCTAssertEqual(delegate.rumCount, 2U);
        [handler startWithEnableWebViewLog:YES logDelegate:delegate];
        [handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil];
        XCTAssertEqual(delegate.logCount, 4U);
        XCTAssertTrue(delegate.linkToNativeRum);

        __weak FTMacWebViewDelegateStub *weakDelegate = delegate;
        delegate = nil;
        XCTAssertNil(weakDelegate);
        XCTAssertNoThrow([handler processWebViewBridgeEvent:log slotId:0 bindInfo:nil]);
        [handler disableWebView:webView];
    }
}
- (void)testWebViewModuleStartupDoesNotReapplyOtherModule {
    for (NSNumber *rumFirst in @[@NO, @YES]) {
        FTMobileConfig *base = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://example.com"];
        base.autoSync = NO;
        base.enableDataFilter = NO;
        base.allowWebViewHost = @[@"base.example.com"];
        [FTMobileAgent startWithConfigOptions:base];
        FTSDKAgent *agent = [FTSDKAgent sharedInstance];
        FTWKWebViewHandler *handler = [FTWKWebViewHandler sharedInstance];
        NSString *baseHosts = [handler valueForKey:@"allowWebViewHostsString"];
        XCTAssertTrue([baseHosts containsString:@"base.example.com"]);
        FTRumConfig *rum = [[FTRumConfig alloc] initWithAppid:@"webview-config-test"];
        rum.enableTraceWebView = YES;
        FTLoggerConfig *logger = [[FTLoggerConfig alloc] init];
        logger.enableWebViewLog = YES;
        if (rumFirst.boolValue) {
            [agent startRumWithConfigOptions:rum];
            // A merged, non-hot-effective RUM value must not be applied by Logger startup.
            FTRumConfig *activeRum = [agent valueForKey:@"rumConfig"];
            activeRum.enableTraceWebView = NO;
            FTSDKConfig *activeBase = [agent valueForKey:@"sdkConfig"];
            activeBase.remoteAllowWebViewHost = @[];
            [agent startLoggerWithConfigOptions:logger];
        } else {
            [agent startLoggerWithConfigOptions:logger];
            // RUM startup must not restore an earlier Logger config over its runtime switch.
            [handler startWithEnableWebViewLog:NO logDelegate:[FTLogger sharedInstance]];
            [agent startRumWithConfigOptions:rum];
        }
        XCTAssertTrue([[handler valueForKey:@"enableTraceWebView"] boolValue]);
        XCTAssertEqual([[handler valueForKey:@"enableWebViewLog"] boolValue], rumFirst.boolValue);
        XCTAssertEqual([handler valueForKey:@"logDelegate"], [FTLogger sharedInstance]);
        XCTAssertNotNil([handler valueForKey:@"rumTrackDelegate"]);
        NSString *hosts = [handler valueForKey:@"allowWebViewHostsString"];
        XCTAssertEqualObjects(hosts, baseHosts);
        FTRemoteConfigManager *remoteManager = [FTRemoteConfigManager sharedInstance];
        FTRemoteConfigModel *previousModel = remoteManager.lastRemoteModel;
        @try {
            for (NSNumber *enableLog in @[@NO, @YES]) {
                FTRemoteConfigModel *remote = [[FTRemoteConfigModel alloc] initWithDict:@{
                    @"logEnableWebViewLog": enableLog, @"rumEnableTraceWebView": @NO, @"rumAllowWebViewHost": @"[]"
                }];
                [remoteManager setValue:remote forKey:@"lastRemoteModel"];
                [agent remoteConfigurationDidChange];
                XCTAssertEqualObjects([handler valueForKey:@"enableWebViewLog"], enableLog);
                XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], hosts);
                XCTAssertTrue([[handler valueForKey:@"enableTraceWebView"] boolValue]);
                XCTAssertEqual([handler valueForKey:@"logDelegate"], [FTLogger sharedInstance]);
            }
        } @finally {
            [remoteManager setValue:previousModel forKey:@"lastRemoteModel"];
        }
        [FTMobileAgent shutDown];
    }
}


- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.traceUrl = [processInfo environment][@"TRACE_URL"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testSDKInit{
    XCTAssertThrows([FTMobileAgent sharedInstance]);
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    XCTAssertNoThrow([FTMobileAgent sharedInstance]);
    [FTMobileAgent shutDown];
}
- (void)testSDKConfigService{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    [[FTMobileAgent sharedInstance] logging:@"testSDKConfigService" status:FTStatusOk];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[FT_KEY_SERVICE] isEqualToString:@"df_rum_macos"]);

    [FTMobileAgent shutDown];
}
- (void)testSDKConfigEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    [[FTMobileAgent sharedInstance] logging:@"testSDKConfigService" status:FTStatusOk];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"env"] isEqualToString:@"prod"]);
    [FTMobileAgent shutDown];
}
- (void)testSDKConfigCustomEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.env = @"custom";
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    [[FTMobileAgent sharedInstance] logging:@"testSDKConfigService" status:FTStatusOk];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"env"] isEqualToString:@"custom"]);
    [FTMobileAgent shutDown];
}
- (void)testSDKConfigCopy{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.globalContext = @{@"aa":@"bb"};
    config.service = @"testsdk";
    config.version = @"1.1.1";
    config.env = @"local";
    FTMobileConfig *copyConfig = [config copy];
    XCTAssertTrue(copyConfig.enableSDKDebugLog == config.enableSDKDebugLog);
    XCTAssertTrue([copyConfig.env isEqualTo:config.env]);
    XCTAssertTrue([copyConfig.service isEqualTo:config.service]);
    XCTAssertTrue([copyConfig.version isEqualTo:config.version]);
    XCTAssertTrue([copyConfig.globalContext isEqual:config.globalContext]);
}
- (void)testWebViewConfigCopy {
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    config.allowWebViewHost = @[];
    FTSDKConfig *copyConfig = [config copy];
    XCTAssertTrue(copyConfig.allowWebViewHostConfigured);
    XCTAssertEqualObjects(copyConfig.allowWebViewHost, @[]);

    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc] init];
    XCTAssertFalse(loggerConfig.enableWebViewLog);
    loggerConfig.enableWebViewLog = YES;
    FTLoggerConfig *copyLoggerConfig = [loggerConfig copy];
    XCTAssertTrue(copyLoggerConfig.enableWebViewLog);
}
- (void)testWebViewHostConfigurationIsIndependentOfModuleStartup {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *cases = @[
        @{@"expected": @[@"legacy.example.com"]},
        @{@"base": NSNull.null, @"expected": NSNull.null},
        @{@"base": @[], @"expected": @[]},
        @{@"base": @[@"base.example.com"], @"expected": @[@"base.example.com"]},
        @{@"base": @[@"base.example.com"], @"remote": @[], @"expected": @[]},
        @{@"base": NSNull.null, @"remote": @[@"remote.example.com"], @"expected": @[@"remote.example.com"]}
    ];
    for (NSDictionary *testCase in cases) {
        for (NSNumber *rumFirst in @[@NO, @YES]) {
            FTSDKConfig *base = [[FTSDKConfig alloc] initWithDatakitUrl:@"https://example.com"];
            base.autoSync = NO;
            base.enableDataFilter = NO;
            if (testCase[@"base"]) {
                base.allowWebViewHost = testCase[@"base"] == NSNull.null ? nil : testCase[@"base"];
            }
            base.remoteAllowWebViewHost = testCase[@"remote"];
            [FTMobileAgent startWithConfigOptions:base];
            FTSDKAgent *agent = [FTSDKAgent sharedInstance];
            FTWKWebViewHandler *handler = [FTWKWebViewHandler sharedInstance];
            NSString *initialHosts = [handler valueForKey:@"allowWebViewHostsString"];
            FTRumConfig *rum = [[FTRumConfig alloc] initWithAppid:@"webview-host-test"];
            rum.enableTraceWebView = YES;
            rum.allowWebViewHost = @[@"legacy.example.com"];
            FTLoggerConfig *logger = [[FTLoggerConfig alloc] init];
            logger.enableWebViewLog = YES;
            if (rumFirst.boolValue) {
                [agent startRumWithConfigOptions:rum];
                NSString *rumHosts = [handler valueForKey:@"allowWebViewHostsString"];
                [agent startLoggerWithConfigOptions:logger];
                XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], rumHosts);
            } else {
                [agent startLoggerWithConfigOptions:logger];
                XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], initialHosts);
                [agent startRumWithConfigOptions:rum];
            }
            NSArray *expectedHosts = testCase[@"expected"] == NSNull.null ? nil : testCase[@"expected"];
            XCTAssertEqualObjects([agent effectiveAllowWebViewHost], expectedHosts);
            NSString *expectedString = @"null";
            if (expectedHosts) {
                NSString *json = [FTJSONUtil convertToJsonDataWithObject:expectedHosts];
                expectedString = [NSString stringWithFormat:@"\"%@\"", [json stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
            }
            XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], expectedString);
            if (testCase[@"base"] || testCase[@"remote"]) {
                XCTAssertEqualObjects([handler valueForKey:@"allowWebViewHostsString"], initialHosts);
            }
            [FTMobileAgent shutDown];
        }
    }
#pragma clang diagnostic pop
}
- (void)testWebViewHostPriority {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    FTMobileConfig *legacyBase = [[FTMobileConfig alloc] initWithDatakitUrl:self.url];
    [FTMobileAgent startWithConfigOptions:legacyBase];
    FTRumConfig *legacyRum = [[FTRumConfig alloc] initWithAppid:@"webview-host-app"];
    legacyRum.allowWebViewHost = @[@"legacy.example.com"];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:legacyRum];
    XCTAssertEqualObjects([[FTSDKAgent sharedInstance] effectiveAllowWebViewHost], @[@"legacy.example.com"]);
    [FTMobileAgent shutDown];

    FTMobileConfig *explicitNilBase = [[FTMobileConfig alloc] initWithDatakitUrl:self.url];
    explicitNilBase.allowWebViewHost = nil;
    [FTMobileAgent startWithConfigOptions:explicitNilBase];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:legacyRum];
    XCTAssertNil([[FTSDKAgent sharedInstance] effectiveAllowWebViewHost]);
    [FTMobileAgent shutDown];

    FTMobileConfig *remoteBase = [[FTMobileConfig alloc] initWithDatakitUrl:self.url];
    remoteBase.allowWebViewHost = @[@"base.example.com"];
    [FTMobileAgent startWithConfigOptions:remoteBase];
    FTSDKConfig *activeBase = [[FTSDKAgent sharedInstance] valueForKey:@"sdkConfig"];
    activeBase.remoteAllowWebViewHost = @[];
    XCTAssertEqualObjects([[FTSDKAgent sharedInstance] effectiveAllowWebViewHost], @[]);
    [FTMobileAgent shutDown];
#pragma clang diagnostic pop
}
- (void)testRUMConfigCopy{
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"app_id1111"];
    rumConfig.samplerate = 50;
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTrackAppANR = YES;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.enableTrackAppFreeze = YES;
    rumConfig.errorMonitorType = FTErrorMonitorMemory;
    rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorCpu;
    rumConfig.monitorFrequency = FTMonitorFrequencyFrequent;
    rumConfig.globalContext = @{@"aa":@"bb"};
    FTRumConfig *copyRumConfig = [rumConfig copy];
    XCTAssertTrue(copyRumConfig.samplerate == rumConfig.samplerate);
    XCTAssertTrue(copyRumConfig.enableTraceUserAction == rumConfig.enableTraceUserAction);
    XCTAssertTrue(copyRumConfig.enableTraceUserView == rumConfig.enableTraceUserView);
    XCTAssertTrue(copyRumConfig.enableTraceUserResource == rumConfig.enableTraceUserResource);
    XCTAssertTrue(copyRumConfig.enableTrackAppANR == rumConfig.enableTrackAppANR);
    XCTAssertTrue(copyRumConfig.enableTrackAppCrash == rumConfig.enableTrackAppCrash);
    XCTAssertTrue(copyRumConfig.enableTrackAppFreeze == rumConfig.enableTrackAppFreeze);
    XCTAssertTrue(copyRumConfig.errorMonitorType == rumConfig.errorMonitorType);
    XCTAssertTrue(copyRumConfig.deviceMetricsMonitorType == rumConfig.deviceMetricsMonitorType);
    XCTAssertTrue(copyRumConfig.monitorFrequency == rumConfig.monitorFrequency);
    XCTAssertTrue([copyRumConfig.globalContext isEqual:rumConfig.globalContext]);

}
- (void)testTraceConfigCopy{
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = YES;
    traceConfig.enableLinkRumData = YES;
    traceConfig.samplerate = 50;
    traceConfig.networkTraceType = FTNetworkTraceTypeTraceparent;
    FTTraceConfig *copyTraceConfig = [traceConfig copy];
    XCTAssertTrue(copyTraceConfig.enableAutoTrace == traceConfig.enableAutoTrace);
    XCTAssertTrue(copyTraceConfig.enableLinkRumData == traceConfig.enableLinkRumData);
    XCTAssertTrue(copyTraceConfig.samplerate == traceConfig.samplerate);
    XCTAssertTrue(copyTraceConfig.networkTraceType == traceConfig.networkTraceType);
}
- (void)testLoggerConfigCopy{
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.samplerate = 50;
    loggerConfig.discardType = FTDiscard;
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.printCustomLogToConsole = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusOk)];
    loggerConfig.globalContext = @{@"aa":@"bb"};
    FTLoggerConfig *copyLoggerConfig = [loggerConfig copy];
    XCTAssertTrue(copyLoggerConfig.enableCustomLog == loggerConfig.enableCustomLog);
    XCTAssertTrue(copyLoggerConfig.samplerate == loggerConfig.samplerate);
    XCTAssertTrue(copyLoggerConfig.discardType == loggerConfig.discardType);
    XCTAssertTrue(copyLoggerConfig.enableLinkRumData == loggerConfig.enableLinkRumData);
    XCTAssertTrue(copyLoggerConfig.printCustomLogToConsole == loggerConfig.printCustomLogToConsole);
    XCTAssertTrue([copyLoggerConfig.logLevelFilter isEqual: loggerConfig.logLevelFilter]);
    XCTAssertTrue([copyLoggerConfig.globalContext isEqual: loggerConfig.globalContext]);


}


@end
