//
//  ft_sdk_iosTestUnitTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by hulilei on 2019/12/19.
//  Copyright © 2019 hll. All rights reserved.
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
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
#import "FTMobileConfig+Private.h"
#import "FTNetworkMock.h"
#import "FTTestUtils.h"
#import "FTTrackDataManager+Test.h"
#import "FTDataUploadWorker.h"
@interface FTMobileAgentTests : KIFTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, strong) XCTestExpectation *expectation;

@end


@implementation FTMobileAgentTests

- (void)setUp {
    /**
     * Set Environment Variables for ft-sdk-iosTestUnitTests
     * Additionally add isUnitTests = 1 to prevent SDK startup in AppDelegate from affecting unit tests
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [FTMobileAgent shutDown];
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
#pragma mark ========== User data binding ==========
/// Test compatibility adaptation for old user binding logic in version 1.3.6 and below
/// Old: key: ft_userid
///      value: user_id
///
/// New: key: FT_USER_INFO
///      value: User data dictionary
- (void)testAdaptOldUserSet{
    [self setRightSDKConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[NSUserDefaults standardUserDefaults] setValue:@"old_user" forKey:@"ft_userid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[FTMobileAgent sharedInstance] syncProcess];
    [FTMobileAgent shutDown];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
   
    NSDictionary *dict  = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSString *userid = dict[FT_USER_ID];
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.service = @"testSetServiceName";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([serviceName isEqualToString:@"testSetServiceName"]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumserviceName = [rumtags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([rumserviceName isEqualToString:@"testSetServiceName"]);
}
- (void)testDefaultEnvProperty{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    config.env = @"";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testEnvProperty" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance]insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *env = [tags valueForKey:@"env"];
    XCTAssertTrue([env isEqualToString:FTEnvStringMap[FTEnvProd]]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumEnv = [rumtags valueForKey:@"env"];
    XCTAssertTrue([rumEnv isEqualToString:FTEnvStringMap[FTEnvProd]]);
}
- (void)testEnvProperty{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.env = @"testCustomEnv";
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testEnvProperty" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    NSString *env = [tags valueForKey:@"env"];
    XCTAssertTrue([env isEqualToString:@"testCustomEnv"]);
    [FTModelHelper startView];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *rumArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *rumModel = [rumArray lastObject];
    NSDictionary *rumdict = [FTJSONUtil dictionaryWithJsonString:rumModel.data];
    NSDictionary *rumop = rumdict[FT_OPDATA];
    NSDictionary *rumtags = rumop[FT_TAGS];
    NSString *rumEnv = [rumtags valueForKey:@"env"];
    XCTAssertTrue([rumEnv isEqualToString:@"testCustomEnv"]);
}
- (void)testGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = @{@"testGlobalContext":@"testGlobalContext"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"testGlobalContext"] isEqualToString:@"testGlobalContext"]);
}
- (void)testGlobalContext_mutable{
    NSMutableDictionary *context = @{@"testGlobalContext_mutable":@"testGlobalContext_mutable"}.mutableCopy;
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = context;
    [context setValue:@"testGlobalContext" forKey:@"testGlobalContext_mutable"];
    XCTAssertTrue([config.globalContext[@"testGlobalContext_mutable"] isEqualToString:@"testGlobalContext_mutable"]);
    XCTAssertTrue([context[@"testGlobalContext_mutable"] isEqualToString:@"testGlobalContext"]);
}
- (void)testAddPkgInfo{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    XCTAssertNil([config pkgInfo]);
    [config addPkgInfo:@"test_sdk" value:@"1.0.0"];
    XCTAssertTrue([[config pkgInfo] isEqualToDictionary:@{@"test_sdk":@"1.0.0"}]);
    XCTAssertFalse([config pkgInfo] == [config pkgInfo]);
}
- (void)testAppendGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    config.globalContext = @{@"testGlobalContext":@"testGlobalContext"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [FTMobileAgent appendGlobalContext:@{@"append_global":@"testAppendGlobalContext"}];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[FT_OPDATA];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"testGlobalContext"] isEqualToString:@"testGlobalContext"]);
    XCTAssertTrue([tags[@"append_global"] isEqualToString:@"testAppendGlobalContext"]);
    [FTMobileAgent shutDown];
}
- (void)testSyncSleepTimeScope{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
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
- (void)testAutoSync_NO{
    [FTNetworkMock networkOHHTTPStubs];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance]
     startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count>0);
    [[FTTrackDataManager sharedInstance].dataUploadWorker addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    self.expectation = [self expectationWithDescription:@"Async operation timeout"];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(newDatas.count>=oldDatas.count);
    [[FTTrackDataManager sharedInstance].dataUploadWorker removeObserver:self forKeyPath:@"isUploading"];
}
- (void)testAutoSync_YES{
    [FTNetworkMock networkOHHTTPStubs];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance]
     startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] logging:@"testAutoSync" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count>0);
    [[FTTrackDataManager sharedInstance].dataUploadWorker addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    self.expectation = [self expectationWithDescription:@"Async operation timeout"];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
   
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(newDatas.count<oldDatas.count);
    [[FTTrackDataManager sharedInstance].dataUploadWorker removeObserver:self forKeyPath:@"isUploading"];
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"isUploading"]){
        FTTrackDataManager *manager = object;
        NSNumber *isUploading = [manager valueForKey:@"isUploading"];
        if(isUploading.boolValue == NO){
            [self.expectation fulfill];
            self.expectation = nil;
        }
        
    }
}
#pragma mark ========== copy ==========
- (void)testSDKConfigCopy{
    FTMobileConfig *datakitConfig = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
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
    FTMobileConfig *copyConfig = [datakitConfig copy];
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
    FTMobileConfig *datawayConfig = [[FTMobileConfig alloc]initWithDatawayUrl:self.url clientToken:@"clientToken"];
    FTMobileConfig *copy = [datawayConfig copy];
    XCTAssertTrue([copy.datawayUrl isEqualToString:datawayConfig.datawayUrl]);
    XCTAssertTrue([copy.clientToken isEqualToString:datawayConfig.clientToken]);
}
- (void)testRUMConfigCopy{
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"app_id1111"];
    rumConfig.samplerate = 50;
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
    rumConfig.viewTrackingStrategy = ^FTRumView * _Nullable(UIViewController * _Nonnull viewController) {
        return nil;
    };
    XCTAssertTrue(rumConfig.sessionOnErrorSampleRate == 0);
    XCTAssertTrue(rumConfig.rumCacheLimitCount == 100000);
    rumConfig.rumCacheLimitCount = 1000;
    XCTAssertTrue(rumConfig.rumCacheLimitCount == 10000);
    rumConfig.rumDiscardType = FTRUMDiscardOldest;
    rumConfig.globalContext = @{@"aa":@"bb"};
    rumConfig.sessionOnErrorSampleRate = 50;
    FTRumConfig *copyRumConfig = [rumConfig copy];
    XCTAssertTrue(copyRumConfig.sessionOnErrorSampleRate == 50);
    XCTAssertTrue(copyRumConfig.samplerate == rumConfig.samplerate);
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
    XCTAssertTrue([copyRumConfig.viewTrackingStrategy isEqual:rumConfig.viewTrackingStrategy]);
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
    XCTAssertTrue(rumConfig.samplerate == newRum.samplerate);
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
    traceConfig.samplerate = 50;
    traceConfig.networkTraceType = FTNetworkTraceTypeTraceparent;
    FTTraceConfig *copyTraceConfig = [traceConfig copy];
    XCTAssertTrue(copyTraceConfig.enableAutoTrace == traceConfig.enableAutoTrace);
    XCTAssertTrue(copyTraceConfig.enableLinkRumData == traceConfig.enableLinkRumData);
    XCTAssertTrue(copyTraceConfig.samplerate == traceConfig.samplerate);
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
    XCTAssertTrue(traceConfig.samplerate == newTrace.samplerate);
    XCTAssertTrue(traceConfig.enableLinkRumData == newTrace.enableLinkRumData);
}
- (void)testLoggerConfigCopy{
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.samplerate = 50;
    loggerConfig.discardType = FTDiscard;
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusOk)];
    loggerConfig.printCustomLogToConsole = YES;
    loggerConfig.globalContext = @{@"aa":@"bb"};
    FTLoggerConfig *copyLoggerConfig = [loggerConfig copy];
    XCTAssertTrue(copyLoggerConfig.enableCustomLog == loggerConfig.enableCustomLog);
    XCTAssertTrue(copyLoggerConfig.samplerate == loggerConfig.samplerate);
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
    loggerConfig.enableLinkRumData = YES;
    NSDictionary *dict = [loggerConfig convertToDictionary];
    FTLoggerConfig *newLogger = [[FTLoggerConfig alloc]initWithDictionary:dict];
    XCTAssertTrue(loggerConfig.logLevelFilter == newLogger.logLevelFilter);
    XCTAssertTrue(loggerConfig.globalContext == newLogger.globalContext);
    XCTAssertTrue(loggerConfig.samplerate == newLogger.samplerate);
    XCTAssertTrue(loggerConfig.enableLinkRumData == newLogger.enableLinkRumData);
    XCTAssertTrue(loggerConfig.printCustomLogToConsole == newLogger.printCustomLogToConsole);
}
- (void)testShutDown{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
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
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertThrows([FTMobileAgent sharedInstance]);
    // Log collection is disabled
    for (int i = 0; i<20; i++) {
        [[FTLogger sharedInstance] info:@"test" property:nil];
    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManger] getDatasCount] == count);
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
    XCTAssertTrue([[FTTrackerEventDBTool sharedManger] getDatasCount] == count);
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
@end
