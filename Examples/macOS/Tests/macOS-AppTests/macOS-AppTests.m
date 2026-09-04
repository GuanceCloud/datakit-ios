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
@end
@interface MacOSAppTests : XCTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *traceUrl;
@end

@implementation MacOSAppTests

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
