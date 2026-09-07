//
//  ft_sdk_iosTestUnitTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by hulilei on 2019/12/19.
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

#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTTrackDataManager.h"
#import "FTTrackerEventDBTool.h"
#import "FTBaseInfoHandler.h"
#import "FTRecordModel.h"
#import "FTMobileAgent+Private.h"
#import "FTMobileAgent.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import <objc/runtime.h>
#import "NSString+FTAdd.h"
#import "FTJSONUtil.h"
#import "FTPresetProperty.h"
#import "FTGlobalRumManager+Private.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
#import "FTSDKConfig+Private.h"
#import "FTLoggerConfig+Private.h"
#import "FTRumConfig+Private.h"
#import "FTNetworkMock.h"
#import "FTTestUtils.h"
#import "FTTrackDataManager+Test.h"
#import "FTDataUploadWorker.h"
#import "FTInternalConstants.h"
#import "FTUserInfo.h"
#import "FTDefaultActionTrackingHandler.h"
#import "FTDefaultUIKitViewTrackingHandler.h"
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
- (void)dealReceiveScriptMessage:(id)message slotId:(int64_t)slotID info:(id)info;
@end

@interface FTIOSWebViewDelegateStub : NSObject <FTWKWebViewLogDelegate, FTWKWebViewRumDelegate>
@property (nonatomic, assign) NSUInteger logCount;
@property (nonatomic, assign) NSUInteger rumCount;
@property (nonatomic, strong) NSDictionary *lastLog;
@property (nonatomic, assign) BOOL linkToNativeRum;
@end

@implementation FTIOSWebViewDelegateStub
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

@interface FTMobileAgentTests : KIFTestCase
@property (nonatomic, strong) FTSDKConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;

@end


@implementation FTMobileAgentTests

- (void)testWebViewHandlerRoutesToInjectedDelegates {
    // No Logger or RUM singleton is needed to test Bridge routing.
    for (NSNumber *rumFirst in @[@NO, @YES]) {
        FTWKWebViewHandler *handler = [[FTWKWebViewHandler alloc] init];
        FTIOSWebViewDelegateStub *delegate = [[FTIOSWebViewDelegateStub alloc] init];
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
        [handler dealReceiveScriptMessage:log slotId:0 info:nil];
        [handler dealReceiveScriptMessage:rum slotId:0 info:nil];
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
        [handler dealReceiveScriptMessage:@{@"name": @"log", @"data": @[]} slotId:0 info:nil];
        [handler dealReceiveScriptMessage:log slotId:0 info:nil];
        [handler dealReceiveScriptMessage:rum slotId:0 info:nil];
        XCTAssertEqual(delegate.logCount, 1U);
        XCTAssertEqual(delegate.rumCount, 1U);
        XCTAssertEqual(delegate.lastLog, payload);
        XCTAssertTrue(delegate.linkToNativeRum);

        [handler startWithEnableTraceWebView:NO rumDelegate:delegate];
        [handler dealReceiveScriptMessage:log slotId:0 info:nil];
        [handler dealReceiveScriptMessage:rum slotId:0 info:nil];
        XCTAssertEqual(delegate.logCount, 2U);
        XCTAssertEqual(delegate.rumCount, 1U);
        XCTAssertFalse(delegate.linkToNativeRum);
        [handler startWithEnableTraceWebView:YES rumDelegate:nil];
        [handler dealReceiveScriptMessage:log slotId:0 info:nil];
        XCTAssertFalse(delegate.linkToNativeRum);

        [handler startWithEnableTraceWebView:YES rumDelegate:delegate];
        [handler startWithEnableWebViewLog:NO logDelegate:delegate];
        [handler dealReceiveScriptMessage:log slotId:0 info:nil];
        [handler dealReceiveScriptMessage:rum slotId:0 info:nil];
        XCTAssertEqual(delegate.logCount, 3U);
        XCTAssertEqual(delegate.rumCount, 2U);
        [handler startWithEnableWebViewLog:YES logDelegate:delegate];
        [handler dealReceiveScriptMessage:log slotId:0 info:nil];
        XCTAssertEqual(delegate.logCount, 4U);
        XCTAssertTrue(delegate.linkToNativeRum);

        __weak FTIOSWebViewDelegateStub *weakDelegate = delegate;
        delegate = nil;
        XCTAssertNil(weakDelegate);
        XCTAssertNoThrow([handler dealReceiveScriptMessage:log slotId:0 info:nil]);
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
    /**
     * Set Environment Variables for ft-sdk-iosTestUnitTests
     * Additionally add isUnitTests = 1 to prevent SDK startup in AppDelegate from affecting unit tests
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [FTMobileAgent shutDown];
}
- (void)waitForUploadWorkerIdleWithTimeout:(NSTimeInterval)timeout{
    FTDataUploadWorker *worker = [FTTrackDataManager sharedInstance].dataUploadWorker;
    dispatch_queue_t networkQueue = [worker valueForKey:@"networkQueue"];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        dispatch_sync(networkQueue, ^{});
        BOOL isUploading = [[worker valueForKey:@"isUploading"] boolValue];
        BOOL hasPendingUpload = [[worker valueForKey:@"hasPendingUpload"] boolValue];
        if (!isUploading && !hasPendingUpload) {
            return;
        }
        [NSThread sleepForTimeInterval:0.01];
    }
    XCTFail(@"Upload worker did not become idle within %.2f seconds", timeout);
}
- (void)setRightSDKConfig{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)testAgentRuntimeTypesAreIndependent {
    XCTAssertEqual(NSClassFromString(@"FTSDKAgent"), FTSDKAgent.class);
    XCTAssertEqual(NSClassFromString(@"FTMobileAgent"), FTMobileAgent.class);
    XCTAssertNotEqual(FTSDKAgent.class, FTMobileAgent.class);
    XCTAssertEqual(class_getSuperclass(FTSDKAgent.class), NSObject.class);
    XCTAssertEqual(class_getSuperclass(FTMobileAgent.class), NSObject.class);

    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(FTMobileAgent.class, &ivarCount);
    free(ivars);
    XCTAssertEqual(ivarCount, 0);
}

- (void)testMobileAgentForwardsToSDKAgent {
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc] initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    FTMobileAgent *compatibilityAgent = [FTMobileAgent sharedInstance];
    FTSDKAgent *sdkAgent = [FTSDKAgent sharedInstance];
    XCTAssertNotEqual((id)compatibilityAgent, (id)sdkAgent);
    XCTAssertTrue([compatibilityAgent isMemberOfClass:FTMobileAgent.class]);
    XCTAssertTrue([sdkAgent isMemberOfClass:FTSDKAgent.class]);

    [compatibilityAgent bindUserWithUserID:@"compatibility-user"];
    XCTAssertEqualObjects([FTPresetProperty sharedInstance].rumDynamicTags[FT_USER_ID], @"compatibility-user");

    [FTMobileAgent shutDown];
#if NS_BLOCK_ASSERTIONS
    XCTAssertNil([FTSDKAgent sharedInstance]);
    XCTAssertNil([FTMobileAgent sharedInstance]);
#else
    XCTAssertThrows([FTSDKAgent sharedInstance]);
    XCTAssertThrows([FTMobileAgent sharedInstance]);
#endif

    [FTMobileAgent startWithConfigOptions:config];
    XCTAssertEqual([FTMobileAgent sharedInstance], compatibilityAgent);
    XCTAssertNotEqual([FTSDKAgent sharedInstance], sdkAgent);
}

#pragma mark ========== User data binding ==========
/// Test compatibility adaptation for old user binding logic in version 1.3.6 and below
/// Old: key: ft_userid
///      value: user_id
///
/// New: key: FT_USER_INFO
///      value: User data dictionary
- (void)testAdaptOldUserSet{
    [[NSUserDefaults standardUserDefaults] setValue:@"old_user" forKey:@"ft_userid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    FTUserInfo *userInfo = [[FTUserInfo alloc]init];
    NSString *userid = userInfo.userId;
    XCTAssertTrue([userid isEqualToString:@"old_user"]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ft_userid"];
}
/**
 * Test user binding
 * Verify: Get RUM data to check if userid matches the set value
 */
- (void)testBindUser{
    [self setRightSDKConfig];
   
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser"];
    NSDictionary *dict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSString *userid = dict[FT_USER_ID];
    XCTAssertTrue([userid isEqualToString:@"testBindUser"]);
}
- (void)testBindUserWithNameEmail{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser2" userName:@"name1" userEmail:@"111@qq.com"];
    NSDictionary *dict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSString *userid = dict[FT_USER_ID];
    NSString *username = dict[FT_USER_NAME];
    NSString *useremail = dict[FT_USER_EMAIL];
    XCTAssertTrue([userid isEqualToString:@"testBindUser2"]);
    XCTAssertTrue([username isEqualToString:@"name1"]);
    XCTAssertTrue([useremail isEqualToString:@"111@qq.com"]);
}
- (void)testBindUserWithNameEmailAndExtra{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testBindUser3" userName:@"name2" userEmail:@"222@qq.com" extra:@{@"user_age":@1}];
    NSDictionary *dict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSString *userid = dict[FT_USER_ID];
    NSString *username = dict[FT_USER_NAME];
    NSString *useremail = dict[FT_USER_EMAIL];
    NSNumber *userage = dict[@"user_age"];
    XCTAssertTrue([userid isEqualToString:@"testBindUser3"]);
    XCTAssertTrue([username isEqualToString:@"name2"]);
    XCTAssertTrue([useremail isEqualToString:@"222@qq.com"]);
    XCTAssertTrue([userage isEqual:@1]);

}
/**
 * Test user switching
 * Verify: Check if user information in upload data is correct before and after user switching
 */
-(void)testChangeUser{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testChangeUser1"];
    NSDictionary *dict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
     NSString *userid = dict[@"userid"];
    XCTAssertTrue([userid isEqualToString:@"testChangeUser1"]);

    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testChangeUser2"];
    NSDictionary *newDict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSString *newUserid = newDict[@"userid"];
   XCTAssertTrue([newUserid isEqualToString:@"testChangeUser2"]);
}
/**
 * User unbinding
 * Verify: After logout, userid changes and is_signin becomes F
 */
-(void)testUserlogout{
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"ft_sessionid"];
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"testUserlogout" userName:@"name" userEmail:@"email" extra:@{@"ft_key":@"ft_value"}];
    
    [[FTMobileAgent sharedInstance] unbindUser];
    NSDictionary *dict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSString *userid = dict[FT_USER_ID];
    NSString *userName = dict[FT_USER_NAME];
    NSString *userEmail = dict[FT_USER_EMAIL];
    NSString *ft_key = dict[@"ft_key"];
    XCTAssertFalse([userid isEqualToString:@"testUserlogout"]);
    XCTAssertFalse([userName isEqualToString:@"name"]);
    XCTAssertFalse([userEmail isEqualToString:@"email"]);
    XCTAssertFalse([ft_key isEqualToString:@"ft_value"]);
}
#pragma mark ========== Configuration ==========
-(void)testServiceName{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.service = @"testSetServiceName";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([serviceName isEqualToString:@"testSetServiceName"]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumserviceName = [rumtags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([rumserviceName isEqualToString:@"testSetServiceName"]);
}
- (void)testDefaultEnvProperty{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    config.env = @"";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testEnvProperty" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *env = [tags valueForKey:@"env"];
    XCTAssertTrue([env isEqualToString:FTStringFromEnv(Prod)]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumEnv = [rumtags valueForKey:@"env"];
    XCTAssertTrue([rumEnv isEqualToString:FTStringFromEnv(Prod)]);
}
- (void)testEnumConversionFunctions{
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusInfo), @"info");
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusWarning), @"warning");
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusError), @"error");
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusCritical), @"critical");
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusOk), @"ok");
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusDebug), @"debug");
    XCTAssertEqualObjects(FTStringFromLogStatus(StatusCustom), @"unknown");
    XCTAssertEqualObjects(FTStringFromLogStatus((LogStatus)-1), @"info");
    XCTAssertEqualObjects(FTStringFromLogStatus((LogStatus)(StatusCustom + 1)), @"info");
    XCTAssertEqualObjects(FTStringFromLogStatus((LogStatus)NSIntegerMax), @"info");
    XCTAssertEqualObjects(FTStringFromLogStatus((LogStatus)NSUIntegerMax), @"info");

    XCTAssertEqualObjects(FTStringFromEnv(Prod), @"prod");
    XCTAssertEqualObjects(FTStringFromEnv(Gray), @"gray");
    XCTAssertEqualObjects(FTStringFromEnv(Pre), @"pre");
    XCTAssertEqualObjects(FTStringFromEnv(Common), @"common");
    XCTAssertEqualObjects(FTStringFromEnv(Local), @"local");
    XCTAssertEqualObjects(FTStringFromEnv((Env)-1), @"prod");
    XCTAssertEqualObjects(FTStringFromEnv((Env)(Local + 1)), @"prod");
    XCTAssertEqualObjects(FTStringFromEnv((Env)NSIntegerMax), @"prod");
    XCTAssertEqualObjects(FTStringFromEnv((Env)NSUIntegerMax), @"prod");

    XCTAssertEqualWithAccuracy(FTIntervalFromMonitorFrequency(MonitorFrequencyDefault), 0.5, 0.000001);
    XCTAssertEqualWithAccuracy(FTIntervalFromMonitorFrequency(MonitorFrequencyFrequent), 0.1, 0.000001);
    XCTAssertEqualWithAccuracy(FTIntervalFromMonitorFrequency(MonitorFrequencyRare), 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(FTIntervalFromMonitorFrequency((MonitorFrequency)-1), 0.5, 0.000001);
    XCTAssertEqualWithAccuracy(FTIntervalFromMonitorFrequency((MonitorFrequency)(MonitorFrequencyRare + 1)), 0.5, 0.000001);
    XCTAssertEqualWithAccuracy(FTIntervalFromMonitorFrequency((MonitorFrequency)NSUIntegerMax), 0.5, 0.000001);
}
- (void)testSetInvalidEnvTypeFallsBackToProd{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];

    [config setEnvWithType:(FTEnv)-1];
    XCTAssertEqualObjects(config.env, @"prod");

    [config setEnvWithType:(FTEnv)NSIntegerMax];
    XCTAssertEqualObjects(config.env, @"prod");
}
- (void)testEnvProperty{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.env = @"testCustomEnv";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testEnvProperty" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *env = [tags valueForKey:@"env"];
    XCTAssertTrue([env isEqualToString:@"testCustomEnv"]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumEnv = [rumtags valueForKey:@"env"];
    XCTAssertTrue([rumEnv isEqualToString:@"testCustomEnv"]);
}
- (void)testGlobalContext{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = @{@"testGlobalContext":@"testGlobalContext"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"testGlobalContext"] isEqualToString:@"testGlobalContext"]);
}
- (void)testGlobalContext_mutable{
    NSMutableDictionary *context = @{@"testGlobalContext_mutable":@"testGlobalContext_mutable"}.mutableCopy;
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = context;
    [context setValue:@"testGlobalContext" forKey:@"testGlobalContext_mutable"];
    XCTAssertTrue([config.globalContext[@"testGlobalContext_mutable"] isEqualToString:@"testGlobalContext_mutable"]);
    XCTAssertTrue([context[@"testGlobalContext_mutable"] isEqualToString:@"testGlobalContext"]);
}
- (void)testAddPkgInfo{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    XCTAssertNil([config pkgInfo]);
    [config addPkgInfo:@"test_sdk" value:@"1.0.0"];
    XCTAssertTrue([[config pkgInfo] isEqualToDictionary:@{@"test_sdk":@"1.0.0"}]);
    XCTAssertFalse([config pkgInfo] == [config pkgInfo]);
}
- (void)testAppendGlobalContext{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = @{@"testGlobalContext":@"testGlobalContext"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [FTMobileAgent appendGlobalContext:@{@"append_global":@"testAppendGlobalContext"}];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"testGlobalContext"] isEqualToString:@"testGlobalContext"]);
    XCTAssertTrue([tags[@"append_global"] isEqualToString:@"testAppendGlobalContext"]);
    [FTMobileAgent shutDown];
}
- (void)testSyncSleepTimeScope{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.syncSleepTime = -1;
    XCTAssertTrue(config.syncSleepTime == 0);
    config.syncSleepTime = 150;
    XCTAssertTrue(config.syncSleepTime == 150);
    config.syncSleepTime = 99;
    XCTAssertTrue(config.syncSleepTime == 99);
    config.syncSleepTime = 5500;
    XCTAssertTrue(config.syncSleepTime == 5000);
}
- (void)testSyncPageSizeScope{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    XCTAssertTrue(config.syncPageSize == 10);
    config.syncPageSize = -1;
    XCTAssertTrue(config.syncPageSize == 5);
    config.syncPageSize = 150;
    XCTAssertTrue(config.syncPageSize == 150);
    [config setSyncPageSizeWithType:FTSyncPageSizeMax];
    XCTAssertTrue(config.syncPageSize == 50);
    [config setSyncPageSizeWithType:FTSyncPageSizeMini];
    XCTAssertTrue(config.syncPageSize == 5);
    [config setSyncPageSizeWithType:FTSyncPageSizeMedium];
    XCTAssertTrue(config.syncPageSize == 10);
}
- (void)testCompressIntakeRequestsDefaultEnabled{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    XCTAssertTrue(config.compressIntakeRequests);
}
- (void)testAutoSync_NO{
    [FTNetworkMock networkOHHTTPStubs];
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance]
     startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count>0);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async operation timeout"];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(newDatas.count>=oldDatas.count);
}
- (void)testAutoSync_YES{
    [FTNetworkMock networkOHHTTPStubs];
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance]
     startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count>0);
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self waitForUploadWorkerIdleWithTimeout:30];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(newDatas.count<oldDatas.count);
}
#pragma mark ========== copy ==========
- (void)testSDKConfigCopy{
    FTSDKConfig *datakitConfig = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    datakitConfig.enableSDKDebugLog = YES;
    datakitConfig.globalContext = @{@"aa":@"bb"};
    datakitConfig.service = @"testsdk";
    // enableDataIntegerCompatible defaults to YES
    XCTAssertTrue(datakitConfig.enableDataIntegerCompatible == YES);
    datakitConfig.enableDataIntegerCompatible = NO;
    [datakitConfig setEnvWithType:FTEnvLocal];
    XCTAssertTrue(datakitConfig.dbCacheLimit == 100*1024*1024);
    datakitConfig.dbCacheLimit = 10;
    XCTAssertTrue(datakitConfig.dbCacheLimit == 30*1024*1024);
    datakitConfig.dbCacheLimit = 60*1024*1024;
    XCTAssertTrue(datakitConfig.dbCacheLimit == 60*1024*1024);
    XCTAssertTrue(datakitConfig.enableLimitWithDbSize == NO);
    XCTAssertTrue(datakitConfig.dbDiscardType == FTDBDiscard);
    datakitConfig.dbDiscardType = FTDBDiscardOldest;
    XCTAssertTrue(datakitConfig.remoteConfiguration == NO);
    XCTAssertTrue(datakitConfig.remoteConfigMiniUpdateInterval == 12*60*60);
    datakitConfig.remoteConfigMiniUpdateInterval = -1;
    XCTAssertTrue(datakitConfig.remoteConfigMiniUpdateInterval == 0);
    datakitConfig.remoteConfiguration = YES;
    datakitConfig.allowWebViewHost = @[];
    FTSDKConfig *copyConfig = [datakitConfig copy];
    XCTAssertTrue(copyConfig.enableSDKDebugLog == datakitConfig.enableSDKDebugLog);
    XCTAssertTrue([copyConfig.datakitUrl isEqualToString:datakitConfig.datakitUrl]);
    XCTAssertTrue([copyConfig.env isEqualToString:datakitConfig.env]);
    XCTAssertTrue([copyConfig.service isEqualToString:datakitConfig.service]);
    XCTAssertTrue([copyConfig.globalContext isEqual:datakitConfig.globalContext]);
    XCTAssertTrue(copyConfig.enableDataIntegerCompatible == datakitConfig.enableDataIntegerCompatible);
    XCTAssertTrue(copyConfig.dbCacheLimit == datakitConfig.dbCacheLimit);
    XCTAssertTrue(copyConfig.dbDiscardType == datakitConfig.dbDiscardType == FTDBDiscardOldest);
    XCTAssertTrue(copyConfig.enableLimitWithDbSize == datakitConfig.enableLimitWithDbSize);
    XCTAssertTrue(copyConfig.remoteConfiguration == datakitConfig.remoteConfiguration);
    XCTAssertTrue(copyConfig.remoteConfigMiniUpdateInterval == datakitConfig.remoteConfigMiniUpdateInterval);
    XCTAssertTrue(copyConfig.allowWebViewHostConfigured);
    XCTAssertEqualObjects(copyConfig.allowWebViewHost, @[]);

    FTSDKConfig *explicitNilConfig = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    explicitNilConfig.allowWebViewHost = nil;
    FTSDKConfig *explicitNilCopy = [explicitNilConfig copy];
    XCTAssertTrue(explicitNilCopy.allowWebViewHostConfigured);
    XCTAssertNil(explicitNilCopy.allowWebViewHost);
    FTSDKConfig *datawayConfig = [[FTSDKConfig alloc]initWithDatawayUrl:self.url clientToken:@"clientToken"];
    FTSDKConfig *copy = [datawayConfig copy];
    XCTAssertTrue([copy.datawayUrl isEqualToString:datawayConfig.datawayUrl]);
    XCTAssertTrue([copy.clientToken isEqualToString:datawayConfig.clientToken]);
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
    FTSDKConfig *legacyBase = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    [FTMobileAgent startWithConfigOptions:legacyBase];
    FTRumConfig *legacyRum = [[FTRumConfig alloc] initWithAppid:self.appid];
    legacyRum.allowWebViewHost = @[@"legacy.example.com"];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:legacyRum];
    XCTAssertEqualObjects([[FTSDKAgent sharedInstance] effectiveAllowWebViewHost], @[@"legacy.example.com"]);
    [FTMobileAgent shutDown];

    FTSDKConfig *explicitNilBase = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
    explicitNilBase.allowWebViewHost = nil;
    [FTMobileAgent startWithConfigOptions:explicitNilBase];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:legacyRum];
    XCTAssertNil([[FTSDKAgent sharedInstance] effectiveAllowWebViewHost]);
    [FTMobileAgent shutDown];

    FTSDKConfig *remoteBase = [[FTSDKConfig alloc] initWithDatakitUrl:self.url];
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
    rumConfig.sampleRate = 50;
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableResourceHostIP = YES;
    rumConfig.enableTrackAppANR = YES;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.enableTrackAppFreeze = YES;
    rumConfig.errorMonitorType = FTErrorMonitorMemory;
    rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorCpu;
    rumConfig.monitorFrequency = FTMonitorFrequencyFrequent;
    rumConfig.resourceUrlHandler = ^BOOL(NSURL *url) {
        return NO;
    };
    FTViewTrackingHandler viewStrategy = (FTViewTrackingHandler)[[NSObject alloc]init];
    rumConfig.viewTrackingHandler = viewStrategy;
    id<FTSwiftUIViewTrackingHandler> swiftUIStrategy = (id<FTSwiftUIViewTrackingHandler>)[[NSObject alloc]init];
    rumConfig.swiftUIViewTrackingHandler = swiftUIStrategy;
    FTActionTrackingHandler actionStrategy = (FTActionTrackingHandler)[[NSObject alloc]init];
    rumConfig.actionTrackingHandler = actionStrategy;
    XCTAssertTrue(rumConfig.sessionOnErrorSampleRate == 0);
    XCTAssertTrue(rumConfig.rumCacheLimitCount == 100000);
    rumConfig.rumCacheLimitCount = 1000;
    XCTAssertTrue(rumConfig.rumCacheLimitCount == 10000);
    rumConfig.rumDiscardType = FTRUMDiscardOldest;
    rumConfig.globalContext = @{@"aa":@"bb"};
    rumConfig.sessionOnErrorSampleRate = 50;
    FTRumConfig *copyRumConfig = [rumConfig copy];
    XCTAssertTrue(copyRumConfig.sessionOnErrorSampleRate == 50);
    XCTAssertTrue(copyRumConfig.sampleRate == rumConfig.sampleRate);
    XCTAssertTrue(copyRumConfig.enableTraceUserAction == rumConfig.enableTraceUserAction);
    XCTAssertTrue(copyRumConfig.enableTraceUserView == rumConfig.enableTraceUserView);
    XCTAssertTrue(copyRumConfig.enableTraceUserResource == rumConfig.enableTraceUserResource);
    XCTAssertTrue(copyRumConfig.enableResourceHostIP == rumConfig.enableResourceHostIP);
    XCTAssertTrue(copyRumConfig.enableTrackAppANR == rumConfig.enableTrackAppANR);
    XCTAssertTrue(copyRumConfig.enableTrackAppCrash == rumConfig.enableTrackAppCrash);
    XCTAssertTrue(copyRumConfig.enableTrackAppFreeze == rumConfig.enableTrackAppFreeze);
    XCTAssertTrue(copyRumConfig.errorMonitorType == rumConfig.errorMonitorType);
    XCTAssertTrue(copyRumConfig.deviceMetricsMonitorType == rumConfig.deviceMetricsMonitorType);
    XCTAssertTrue(copyRumConfig.monitorFrequency == rumConfig.monitorFrequency);
    XCTAssertTrue([copyRumConfig.globalContext isEqual:rumConfig.globalContext]);
    XCTAssertTrue([copyRumConfig.resourceUrlHandler isEqual:rumConfig.resourceUrlHandler]);
    XCTAssertTrue([copyRumConfig.viewTrackingHandler isEqual:rumConfig.viewTrackingHandler]);
    XCTAssertTrue([copyRumConfig.swiftUIViewTrackingHandler isEqual:rumConfig.swiftUIViewTrackingHandler]);
    XCTAssertTrue([copyRumConfig.actionTrackingHandler isEqual:rumConfig.actionTrackingHandler]);
    XCTAssertTrue(copyRumConfig.freezeDurationMs == rumConfig.freezeDurationMs);
    XCTAssertTrue(copyRumConfig.rumDiscardType == rumConfig.rumDiscardType);
    XCTAssertTrue(copyRumConfig.rumCacheLimitCount == rumConfig.rumCacheLimitCount);
    XCTAssertTrue([copyRumConfig.debugDescription isEqualToString:rumConfig.debugDescription]);
}
// block not processed
- (void)testRUMConfigInitWithDict{
    XCTAssertNil([[FTRumConfig alloc]initWithDictionary:nil]);
    FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
    rumConfig.resourceUrlHandler = ^BOOL(NSURL *url) {
        return NO;
    };
    NSDictionary *dict = [rumConfig convertToDictionary];
    FTRumConfig *newRum = [[FTRumConfig alloc]initWithDictionary:dict];
    XCTAssertTrue(rumConfig.enableTrackAppANR == newRum.enableTrackAppANR);
    XCTAssertTrue(rumConfig.enableTraceUserView == newRum.enableTraceUserView);
    XCTAssertTrue(rumConfig.sampleRate == newRum.sampleRate);
    XCTAssertTrue(rumConfig.enableTrackAppCrash == newRum.enableTrackAppCrash);
    XCTAssertTrue(rumConfig.enableTraceUserAction == newRum.enableTraceUserAction);
    XCTAssertTrue(rumConfig.enableTrackAppFreeze == newRum.enableTrackAppFreeze);
    XCTAssertTrue(rumConfig.errorMonitorType == newRum.errorMonitorType);
    XCTAssertTrue(rumConfig.deviceMetricsMonitorType == newRum.deviceMetricsMonitorType);
    XCTAssertTrue(rumConfig.monitorFrequency == newRum.monitorFrequency);
    XCTAssertTrue(rumConfig.globalContext == newRum.globalContext);
    XCTAssertFalse(rumConfig.resourceUrlHandler == newRum.resourceUrlHandler);
    XCTAssertTrue(rumConfig.freezeDurationMs == newRum.freezeDurationMs);
}
- (void)testTraceConfigCopy{
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = YES;
    traceConfig.enableLinkRumData = YES;
    traceConfig.sampleRate = 50;
    traceConfig.networkTraceType = FTNetworkTraceTypeTraceparent;
    FTTraceConfig *copyTraceConfig = [traceConfig copy];
    XCTAssertTrue(copyTraceConfig.enableAutoTrace == traceConfig.enableAutoTrace);
    XCTAssertTrue(copyTraceConfig.enableLinkRumData == traceConfig.enableLinkRumData);
    XCTAssertTrue(copyTraceConfig.samplerate == traceConfig.sampleRate);
    XCTAssertTrue(copyTraceConfig.networkTraceType == traceConfig.networkTraceType);
    XCTAssertTrue([copyTraceConfig.debugDescription isEqualToString:traceConfig.debugDescription]);
}
- (void)testTraceConfigInitWithDict{
    XCTAssertNil([[FTTraceConfig alloc]initWithDictionary:nil]);
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    NSDictionary *dict = [traceConfig convertToDictionary];
    FTTraceConfig *newTrace = [[FTTraceConfig alloc]initWithDictionary:dict];
    XCTAssertTrue(traceConfig.enableAutoTrace == newTrace.enableAutoTrace);
    XCTAssertTrue(traceConfig.networkTraceType == newTrace.networkTraceType);
    XCTAssertTrue(traceConfig.sampleRate == newTrace.sampleRate);
    XCTAssertTrue(traceConfig.enableLinkRumData == newTrace.enableLinkRumData);
}
- (void)testLoggerConfigCopy{
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    XCTAssertFalse(loggerConfig.enableWebViewLog);
    loggerConfig.enableCustomLog = YES;
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.sampleRate = 50;
    loggerConfig.discardType = FTDiscard;
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusOk)];
    loggerConfig.printCustomLogToConsole = YES;
    loggerConfig.globalContext = @{@"aa":@"bb"};
    FTLoggerConfig *copyLoggerConfig = [loggerConfig copy];
    XCTAssertTrue(copyLoggerConfig.enableCustomLog == loggerConfig.enableCustomLog);
    XCTAssertTrue(copyLoggerConfig.enableWebViewLog == loggerConfig.enableWebViewLog);
    XCTAssertTrue(copyLoggerConfig.sampleRate == loggerConfig.sampleRate);
    XCTAssertTrue(copyLoggerConfig.discardType == loggerConfig.discardType);
    XCTAssertTrue(copyLoggerConfig.enableLinkRumData == loggerConfig.enableLinkRumData);
    XCTAssertTrue([copyLoggerConfig.logLevelFilter isEqual: loggerConfig.logLevelFilter]);
    XCTAssertTrue([copyLoggerConfig.globalContext isEqual: loggerConfig.globalContext]);
    XCTAssertTrue(loggerConfig.printCustomLogToConsole == copyLoggerConfig.printCustomLogToConsole);
    XCTAssertTrue([copyLoggerConfig.debugDescription isEqualToString:loggerConfig.debugDescription]);

}
- (void)testLoggerConfigInitWithDict{
    XCTAssertNil([[FTLoggerConfig alloc]initWithDictionary:nil]);
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.printCustomLogToConsole = YES;
    loggerConfig.enableCustomLog = YES;
    loggerConfig.enableWebViewLog = YES;
    loggerConfig.enableLinkRumData = YES;
    NSDictionary *dict = [loggerConfig convertToDictionary];
    FTLoggerConfig *newLogger = [[FTLoggerConfig alloc]initWithDictionary:dict];
    XCTAssertTrue(loggerConfig.logLevelFilter == newLogger.logLevelFilter);
    XCTAssertTrue(loggerConfig.globalContext == newLogger.globalContext);
    XCTAssertTrue(loggerConfig.samplerate == newLogger.samplerate);
    XCTAssertTrue(loggerConfig.enableLinkRumData == newLogger.enableLinkRumData);
    XCTAssertTrue(loggerConfig.enableWebViewLog == newLogger.enableWebViewLog);
    XCTAssertTrue(loggerConfig.printCustomLogToConsole == newLogger.printCustomLogToConsole);
}
- (void)testShutDown{
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    logger.enableLinkRumData = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:self.appid];
    rum.enableTrackAppANR = YES;
    rum.enableTraceUserView = YES;
    rum.enableTrackAppCrash = YES;
    rum.enableTrackAppFreeze = YES;
    rum.enableTraceUserAction = YES;
    rum.enableTraceUserResource = YES;
    rum.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    FTTraceConfig *trace = [[FTTraceConfig alloc]init];
    trace.enableAutoTrace = YES;
    trace.enableLinkRumData = YES;
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:trace];
    
    [tester waitForTimeInterval:0.5];
    CFTimeInterval duration = [FTTestUtils functionElapsedTime:^{
        [FTMobileAgent shutDown];
    }];
    XCTAssertTrue(duration<0.1);
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertThrows([FTMobileAgent sharedInstance]);
    // Log collection is disabled
    for (int i = 0; i<20; i++) {
        [[FTLogger sharedInstance] info:@"test" property:nil];
    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManager] getDatasCount] == count);
    // RUM Action, View, Resource collection is disabled
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
    [[FTExternalDataManager sharedManager] startViewWithName:@"test"];
    [[FTExternalDataManager sharedManager] startAction:@"testClick" actionType:@"click" property:nil];
    [[FTExternalDataManager sharedManager] startAction:@"testClick" actionType:@"click" property:nil];

    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios" message:@"testMessage" stack:@"testStack"];
    [[tester waitForViewWithAccessibilityLabel:@"Network data collection"] tap];
    [[tester waitForViewWithAccessibilityLabel:@"Network data collection"] tap];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    // Trace functionality is disabled, RUM Resource collection is disabled
    [self networkUploadHandler:^(NSURLResponse *response, NSDictionary *requestHeader, NSError *error) {
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertFalse([requestHeader.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[requestHeader[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManager] getDatasCount] == count);
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSDictionary *requestHeader ,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
   
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,task.currentRequest.allHTTPHeaderFields,error):nil;
    }];

    [task resume];
}

#pragma mark ========== debugDescription ==========

- (NSArray<NSString *> *)getAllPropertyNamesForClass:(Class)cls {
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    NSMutableArray<NSString *> *propertyNames = [NSMutableArray array];
    
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char *propertyName = property_getName(property);
        NSString *name = [NSString stringWithUTF8String:propertyName];
        [propertyNames addObject:name];
    }
    
    free(properties);
    return propertyNames;
}
- (void)verifyDebugDescriptionContainsAllProperties:(id)object{
    [self verifyDebugDescriptionContainsAllProperties:object filters:nil];
}
- (void)verifyDebugDescriptionContainsAllProperties:(id)object filters:(NSArray *)filters{
    NSString *debugDesc = [object debugDescription];
    Class objectClass = [object class];
    NSArray<NSString *> *propertyNames = [self getAllPropertyNamesForClass:objectClass];
    
    NSLog(@"Checking debugDescription for %@", NSStringFromClass(objectClass));
    NSLog(@"Properties found: %@", propertyNames);
    NSLog(@"debugDescription: %@", debugDesc);
    
    for (NSString *propertyName in propertyNames) {
        if ([propertyName isEqualToString:@"hash"] ||
            [propertyName isEqualToString:@"superclass"] ||
            [propertyName isEqualToString:@"description"] ||
            [propertyName isEqualToString:@"debugDescription"]) {
            continue;
        }
        if ([filters containsObject:propertyName]) {
            continue;
        }
        
        BOOL containsProperty = [debugDesc containsString:propertyName];
        XCTAssertTrue(containsProperty, @"debugDescription for %@ should contain property: %@", NSStringFromClass(objectClass), propertyName);
    }
}

- (void)testFTSDKConfigDebugDescription {
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:@"https://datakit.example.com"];
    
    config.env = @"test-env";
    config.datawayUrl = @"https://dataway.example.com";
    config.clientToken = @"clientToken";
    config.service = @"test-service";
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = @{@"key": @"value"};
    config.groupIdentifiers = @[@"group1"];
    config.remoteConfiguration = YES;
    config.remoteConfigMiniUpdateInterval = 3600;
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        return nil;
    };
    config.lineDataModifier = ^NSDictionary<NSString *,id> * _Nullable(NSString * _Nonnull measurement, NSDictionary<NSString *,id> * _Nonnull data) {
        return nil;
    };
    config.remoteConfigFetchCompletionBlock = ^FTRemoteConfigModel * _Nullable(BOOL success, NSError * _Nullable error, FTRemoteConfigModel * _Nullable model, NSDictionary<NSString *,id> * _Nullable content) {
        return nil;
    };
    [config addPkgInfo:@"key" value:@"value"];
    
    [self verifyDebugDescriptionContainsAllProperties:config filters:@[@"version",@"metricsUrl"]];
}

- (void)testFTRumConfigDebugDescription {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test-appid"];
    
    config.samplerate = 75;
    config.sessionOnErrorSampleRate = 100;
    config.enableTraceUserAction = YES;
    config.enableTraceUserView = YES;
    config.enableTraceUserResource = YES;
    config.enableTrackAppCrash = YES;
    config.enableTrackAppFreeze = YES;
    config.freezeDurationMs = 300;
    config.enableTrackAppANR = YES;
    config.globalContext = @{@"rum-key": @"rum-value"};
    config.rumCacheLimitCount = 50000;
    config.rumDiscardType = FTRUMDiscardOldest;
    config.enableTraceWebView = NO;
    config.allowWebViewHost = @[@"test"];
    config.resourceUrlHandler = ^BOOL(NSURL * _Nonnull url) {
        return YES;
    };
    config.resourcePropertyProvider = ^NSDictionary<NSString *,id> * _Nullable(NSURLRequest * _Nullable request, NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error) {
        return nil;
    };
    config.sessionTaskErrorFilter = ^BOOL(NSError * _Nonnull error) {
        return YES;
    };
    config.issueDataProvider = ^NSDictionary<NSString *,id> * _Nullable(FTIssueInfo * _Nonnull issue) {
        return nil;
    };
    config.viewTrackingHandler = [[FTDefaultUIKitViewTrackingHandler alloc]init];
    config.swiftUIViewTrackingHandler = [[FTDefaultSwiftUIViewTrackingHandler alloc]init];
    config.actionTrackingHandler = [[FTDefaultActionTrackingHandler alloc]init];
    [self verifyDebugDescriptionContainsAllProperties:config filters:@[@"samplerate",@"enableUIKitViewLoadingTime"]];
}

- (void)testFTLoggerConfigDebugDescription {
    FTLoggerConfig *config = [[FTLoggerConfig alloc] init];
    
    config.discardType = FTDiscardOldest;
    config.samplerate = 80;
    config.enableLinkRumData = YES;
    config.enableCustomLog = YES;
    config.printCustomLogToConsole = YES;
    config.logCacheLimitCount = 3000;
    config.logLevelFilter = @[@(FTStatusInfo), @(FTStatusError)];
    config.globalContext = @{@"logger-key": @"logger-value"};
    
    [self verifyDebugDescriptionContainsAllProperties:config filters:@[@"samplerate"]];
}

- (void)testFTTraceConfigDebugDescription {
    FTTraceConfig *config = [[FTTraceConfig alloc] init];
    
    config.samplerate = 90;
    config.enableLinkRumData = YES;
    config.networkTraceType = FTNetworkTraceTypeZipkinMultiHeader;
    config.enableAutoTrace = YES;
    config.traceInterceptor = ^FTTraceContext * _Nullable(NSURLRequest * _Nonnull request) {
        return nil;
    };
    [self verifyDebugDescriptionContainsAllProperties:config filters:@[@"samplerate"]];
}

@end
