//
//  FTPropertyTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2020/9/18.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTTrackDataManager.h"
#import "FTBaseInfoHandler.h"
#import "FTRecordModel.h"
#import "FTMobileAgent+Private.h"
#import "FTMobileConfig+Private.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import <objc/runtime.h>
#import <math.h>
#import <FTJSONUtil.h>
#import "NSString+FTAdd.h"
#import "FTPresetProperty.h"
#import "FTRequest.h"
#import "FTHTTPClient.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTLogger+Private.h"
#import "FTUserInfo.h"
#import "FTDataWriterWorker.h"
#import "NSDictionary+FTCopyProperties.h"
@interface FTPresetProperty (Testing)
- (FTUserInfo *)userInfo;
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription;
@end
static id FTPropertyTestCallClassSelector(Class cls, SEL selector) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [cls respondsToSelector:selector] ? [cls performSelector:selector] : nil;
#pragma clang diagnostic pop
}

static NSArray<NSString *> *FTPropertyTestPropertyNamesForClass(Class cls) {
    NSMutableArray<NSString *> *propertyNames = [NSMutableArray array];
    Class baseModelClass = NSClassFromString(@"FTPresetPropertyModel");
    while (cls && cls != baseModelClass && cls != NSObject.class) {
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            const char *name = property_getName(properties[i]);
            if (name) {
                [propertyNames addObject:[NSString stringWithUTF8String:name]];
            }
        }
        free(properties);
        cls = class_getSuperclass(cls);
    }
    return [propertyNames copy];
}

static NSDictionary *FTPropertyTestLastLogTags(void) {
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    return dict[FT_OPDATA][FT_TAGS];
}
static void FTPropertyTestAssertContainsKeys(XCTestCase *testCase, NSDictionary *tags, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        XCTAssertNotNil(tags[key], @"%@ should contain %@", testCase.name, key);
    }
}
static void FTPropertyTestAssertMissingKeys(XCTestCase *testCase, NSDictionary *tags, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        XCTAssertNil(tags[key], @"%@ should not contain %@", testCase.name, key);
    }
}

@interface FTPropertyTest : XCTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTPropertyTest

- (void)setUp {
    /**
     * Set Environment Variables for ft-sdk-iosTestUnitTests
     * Additionally add isUnitTests = 1 to prevent SDK from affecting unit tests when starting in AppDelegate
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    [[FTPresetProperty sharedInstance] clearUser];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSetEmptyEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    NSDictionary *dict = [[FTPresetProperty sharedInstance] rumTags];
    NSString *env = dict[@"env"];
    XCTAssertTrue([env isEqualToString:@"prod"]);
    [FTMobileAgent shutDown];
}
- (void)testSetEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [config setEnvWithType:FTEnvPre];
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    NSDictionary *dict = [[FTPresetProperty sharedInstance] rumTags];
    NSString *env = dict[@"env"];
    XCTAssertTrue([env isEqualToString:@"pre"]);
    [FTMobileAgent shutDown];
}
/**
 * url is empty string
 * Verification standard: when url is empty string, FTMobileAgent calling - startWithConfigOptions: will crash as true
 */
- (void)testSetEmptyUrl{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:@""];

    XCTAssertNoThrow([FTMobileAgent startWithConfigOptions:config]);
    [FTMobileAgent shutDown];
}
- (void)testIllegalUrl{
    XCTestExpectation *expect = [self expectationWithDescription:@"Request timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:@"111"];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    [[FTMobileAgent sharedInstance] logging:@"testIllegalUrl" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getAllDatas] lastObject];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTHTTPClient new] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        NSInteger statusCode = httpResponse.statusCode;
        BOOL success = (statusCode >=200 && statusCode < 500);
        XCTAssertTrue(!success);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [FTMobileAgent shutDown];
}
/**
 * After setting appid, Rum is enabled
 * Verification: Rum data can be written normally
 */
- (void)testSetAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addRumData];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    [FTMobileAgent shutDown];
}
/**
 * When appid is not set, Rum is disabled
 * Verification: Rum data cannot be written normally
 */
-(void)testSetEmptyAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    XCTAssertThrows([[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig]);
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addRumData];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);
    [FTMobileAgent shutDown];
}
- (void)testDataModifier{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([key isEqualToString: FT_APPLICATION_UUID]) {
            return @"xxx";
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumTags];
    XCTAssertTrue(rumTags.count > 1);
    [rumTags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString: FT_APPLICATION_UUID]) {
            XCTAssertTrue([obj isEqualToString:@"xxx"]);
        }
    }];
    [FTMobileAgent shutDown];
}
- (void)testDataModifier_return_nil{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([key isEqualToString: FT_APPLICATION_UUID]) {
            return @"xxx";
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumTags];
    XCTAssertTrue(rumTags.count > 1);
    [rumTags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString: FT_APPLICATION_UUID]) {
            XCTAssertTrue([obj isEqualToString:@"xxx"]);
        }
    }];
    [FTMobileAgent shutDown];
}
- (void)testApplyModifierNilReturnEmptyDictionary{
    NSDictionary *dict = [[FTPresetProperty sharedInstance] applyModifier:nil];
    XCTAssertNotNil(dict);
    XCTAssertTrue([dict isKindOfClass:NSDictionary.class]);
    XCTAssertEqual(dict.count, 0);
}
- (void)testApplyModifierOnlyNormalizesDictionaryWithoutModifier{
    NSDictionary *dict = @{
        @1:@"number_key",
        @"null":[NSNull null],
        @"nan":NSDecimalNumber.notANumber,
        @"infinity":@(INFINITY),
        @"set":[NSSet setWithObjects:@"a", @"b", nil],
        @"date":[NSDate dateWithTimeIntervalSince1970:0],
        @"nested":@{@"valid":@"value", @"invalid":NSDecimalNumber.notANumber}
    };
    NSDictionary *normalizedDict = [[FTPresetProperty sharedInstance] applyModifier:dict];
    XCTAssertEqualObjects(normalizedDict[@1], @"number_key");
    XCTAssertEqualObjects(normalizedDict[@"null"], [NSNull null]);
    XCTAssertEqualObjects(normalizedDict[@"nan"], NSDecimalNumber.notANumber);
    XCTAssertEqualObjects(normalizedDict[@"infinity"], @(INFINITY));
    XCTAssertTrue([normalizedDict[@"set"] isKindOfClass:NSSet.class]);
    XCTAssertTrue([normalizedDict[@"date"] isKindOfClass:NSDate.class]);
    XCTAssertEqualObjects(normalizedDict[@"nested"][@"valid"], @"value");
    XCTAssertEqualObjects(normalizedDict[@"nested"][@"invalid"], NSDecimalNumber.notANumber);
}

- (void)testPresetPropertyModelCodingKeysCoverNormalProperties{
    NSArray<NSString *> *classNames = @[@"FTBasePropertyModel", @"FTRUMPropertyModel", @"FTLogPropertyModel"];
    for (NSString *className in classNames) {
        Class cls = NSClassFromString(className);
        XCTAssertNotNil(cls);
        NSDictionary *codingKeys = FTPropertyTestCallClassSelector(cls, @selector(ft_codingKeys)) ?: @{};
        NSSet *flattenNames = FTPropertyTestCallClassSelector(cls, @selector(ft_flattenPropertyNames)) ?: [NSSet set];
        NSSet *ignoredNames = FTPropertyTestCallClassSelector(cls, @selector(ft_ignoredPropertyNames)) ?: [NSSet set];
        for (NSString *propertyName in FTPropertyTestPropertyNamesForClass(cls)) {
            if ([flattenNames containsObject:propertyName] || [ignoredNames containsObject:propertyName]) {
                continue;
            }
            XCTAssertNotNil(codingKeys[propertyName], @"%@.%@ should be declared in ft_codingKeys", className, propertyName);
        }
    }
}
- (void)testConfigConvertToDictionaryNilServiceNoCrash{
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDictionary:@{}];
    XCTAssertNotNil(config.service);
    NSDictionary *dict = [config convertToDictionary];
    XCTAssertEqualObjects(dict[@"service"], config.service);
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:dict]);

    FTMobileConfig *emptyServiceConfig = [[FTMobileConfig alloc] initWithDictionary:@{@"service":[NSNull null]}];
    XCTAssertNotNil(emptyServiceConfig.service);
    XCTAssertNoThrow([emptyServiceConfig convertToDictionary]);
}
- (void)testPresetPropertyNilPkgInfoDoesNotOutputEmptyDictionary{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumTags];
    XCTAssertNil(rumTags[FT_SDK_PKG_INFO]);
    [FTMobileAgent shutDown];
}
- (void)testAppendGlobalContextNilNoCrash{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    XCTAssertNoThrow([FTMobileAgent appendGlobalContext:nil]);
    XCTAssertNoThrow([FTMobileAgent appendRUMGlobalContext:nil]);
    XCTAssertNoThrow([FTMobileAgent appendLogGlobalContext:nil]);
    XCTAssertNotNil([[FTPresetProperty sharedInstance] rumDynamicTags]);
    XCTAssertNotNil([[FTPresetProperty sharedInstance] loggerDynamicTags]);
    [FTMobileAgent shutDown];
}
- (void)testDataWriterNilTagsFieldsNoCrash{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    FTDataWriterWorker *writer = [FTTrackDataManager sharedInstance].dataWriterWorker;
    XCTAssertNoThrow([writer rumWrite:FT_RUM_SOURCE_ACTION tags:nil fields:nil dynamicContext:nil time:[NSDate ft_currentNanosecondTimeStamp]]);
    XCTAssertNoThrow([writer loggingTags:nil field:nil time:[NSDate ft_currentNanosecondTimeStamp] linkRum:NO]);
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *rumDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    NSArray *logDatas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(rumDatas.count > 0);
    XCTAssertTrue(logDatas.count > 0);
    [FTMobileAgent shutDown];
}
- (void)testPresetRUMAndLoggerTagsContainOwnedKeys{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"global_key":@"global_value"};
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.globalContext = @{@"rum_key":@"rum_value"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.globalContext = @{@"log_key":@"log_value"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"log_user" userName:@"log_name" userEmail:@"log@test.com"];
    [[FTPresetProperty sharedInstance] connectivityChanged:YES typeDescription:@"wifi"];

    NSArray *baseKeys = @[FT_APPLICATION_UUID, FT_COMMON_PROPERTY_DEVICE_UUID, FT_KEY_SERVICE, FT_VERSION, FT_ENV, FT_SDK_VERSION, FT_SDK_NAME, @"global_key"];
    NSArray *rumKeys = @[FT_COMMON_PROPERTY_DEVICE, FT_COMMON_PROPERTY_DEVICE_MODEL, FT_COMMON_PROPERTY_OS, FT_COMMON_PROPERTY_OS_VERSION, FT_COMMON_PROPERTY_OS_VERSION_MAJOR, FT_CPU_ARCH, FT_APP_ID, FT_NETWORK_TYPE, FT_USER_ID, FT_USER_NAME, FT_USER_EMAIL, FT_IS_SIGNIN, @"rum_key"];
    NSArray *logKeys = @[@"log_key"];
    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumTags];
    NSDictionary *loggerTags = [[FTPresetProperty sharedInstance] loggerTags];

    FTPropertyTestAssertContainsKeys(self, rumTags, baseKeys);
    FTPropertyTestAssertContainsKeys(self, rumTags, rumKeys);
    FTPropertyTestAssertContainsKeys(self, loggerTags, baseKeys);
    FTPropertyTestAssertContainsKeys(self, loggerTags, logKeys);
    FTPropertyTestAssertMissingKeys(self, loggerTags, rumKeys);
    [FTMobileAgent shutDown];
}
- (void)testLogWithoutRUMDoesNotIncludeRUMTags{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"log_user" userName:@"log_name" userEmail:@"log@test.com"];

    FTDataWriterWorker *writer = [FTTrackDataManager sharedInstance].dataWriterWorker;
    [writer loggingTags:nil field:@{FT_KEY_MESSAGE:@"log"} time:[NSDate ft_currentNanosecondTimeStamp] linkRum:YES];

    NSDictionary *tags = FTPropertyTestLastLogTags();
    NSArray *rumOnlyKeys = @[FT_APP_ID, FT_NETWORK_TYPE, FT_USER_ID, FT_USER_NAME, FT_USER_EMAIL, FT_IS_SIGNIN];
    FTPropertyTestAssertMissingKeys(self, tags, rumOnlyKeys);
    [FTMobileAgent shutDown];
}
- (void)testLogLinkRumControlsRUMTags{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.globalContext = @{@"rum_key":@"rum_value"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"log_user" userName:@"log_name" userEmail:@"log@test.com"];
    [[FTPresetProperty sharedInstance] connectivityChanged:YES typeDescription:@"wifi"];

    FTDataWriterWorker *writer = [FTTrackDataManager sharedInstance].dataWriterWorker;
    NSArray *rumLinkedKeys = @[FT_APP_ID, FT_NETWORK_TYPE, FT_USER_ID, FT_USER_NAME, FT_USER_EMAIL, FT_IS_SIGNIN, @"rum_key"];

    [writer loggingTags:nil field:@{FT_KEY_MESSAGE:@"log"} time:[NSDate ft_currentNanosecondTimeStamp] linkRum:NO];
    FTPropertyTestAssertMissingKeys(self, FTPropertyTestLastLogTags(), rumLinkedKeys);
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];

    [writer loggingTags:nil field:@{FT_KEY_MESSAGE:@"log"} time:[NSDate ft_currentNanosecondTimeStamp] linkRum:YES];
    NSDictionary *tags = FTPropertyTestLastLogTags();
    FTPropertyTestAssertContainsKeys(self, tags, rumLinkedKeys);

    XCTAssertEqualObjects(tags[FT_USER_ID], @"log_user");
    XCTAssertEqualObjects(tags[FT_USER_NAME], @"log_name");
    XCTAssertEqualObjects(tags[FT_USER_EMAIL], @"log@test.com");
    XCTAssertEqualObjects(tags[FT_IS_SIGNIN], @"T");
    XCTAssertEqualObjects(tags[FT_NETWORK_TYPE], @"wifi");
    [FTMobileAgent shutDown];
}
- (void)testNetworkTypeDataModifierUsesNetworkTypeKey{
    __block NSString *modifierKey = nil;
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([value isEqual:@"wifi"]) {
            modifierKey = key;
            return @"cellular";
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    FTPresetProperty *preset = [FTPresetProperty sharedInstance];
    [preset connectivityChanged:YES typeDescription:@"wifi"];

    XCTAssertEqualObjects(modifierKey, FT_NETWORK_TYPE);
    XCTAssertEqualObjects([preset rumTags][FT_NETWORK_TYPE], @"cellular");
    [FTMobileAgent shutDown];
}
- (void)testRecordModelNilTagsFieldsNoCrash{
    FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_RUM_SOURCE_ACTION op:FT_DATA_TYPE_RUM tags:nil fields:nil tm:[NSDate ft_currentNanosecondTimeStamp]];
    XCTAssertNotNil(model);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opData = dict[FT_OPDATA];
    XCTAssertEqualObjects(opData[FT_TAGS], @{});
    XCTAssertEqualObjects(opData[FT_FIELDS], @{});
}
- (void)testDataModifier_globalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"sdk_config":@"sdk"};
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([key isEqualToString:@"rum_config"]) {
            return @"rum_xxx";
        }else if ([key isEqualToString:@"logger_config"]){
            return @"logger_xxx";
        }else if([key isEqualToString:@"sdk_config"]){
            return @"sdk_xxx";
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"rum_config":@"rum"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.globalContext = @{@"logger_config":@"logger"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
   
    
    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumTags];
    XCTAssertTrue(rumTags.count > 1);
    [rumTags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:@"rum_config"]) {
            XCTAssertTrue([obj isEqualToString:@"rum_xxx"]);
        }else if([key isEqualToString:@"sdk_config"]){
            XCTAssertTrue([obj isEqualToString:@"sdk_xxx"]);
        }
    }];
    NSDictionary *loggerTags = [[FTPresetProperty sharedInstance] loggerTags];
    XCTAssertTrue(loggerTags.count > 1);
    [loggerTags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:@"logger_config"]) {
            XCTAssertTrue([obj isEqualToString:@"logger_xxx"]);
        }
    }];
    [FTMobileAgent shutDown];
}
- (void)testDataModifier_appendGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([key isEqualToString:@"append_rum"]) {
            return @"rum_***";
        }else if ([key isEqualToString:@"append_sdk"]){
            return @"sdk_***";
        }else if ([key isEqualToString:@"append_log"]){
            return @"log_***";
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [FTMobileAgent appendRUMGlobalContext:@{@"append_rum":@"rum",@"key":@"value"}];
    [FTMobileAgent appendGlobalContext:@{@"append_sdk":@"sdk",@"key2":@"value"}];
    [FTMobileAgent appendLogGlobalContext:@{@"append_log":@"log",@"key3":@"value"}];

    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSDictionary *logTags = [[FTPresetProperty sharedInstance] loggerDynamicTags];
    XCTAssertTrue(rumTags.count >= 6);
    XCTAssertTrue(logTags.count >= 4);
    XCTAssertEqualObjects(rumTags[@"append_rum"], @"rum_***");
    XCTAssertEqualObjects(rumTags[@"append_sdk"], @"sdk_***");
    XCTAssertEqualObjects(rumTags[@"key"], @"value");
    XCTAssertEqualObjects(rumTags[@"key2"], @"value");
    XCTAssertEqualObjects(logTags[@"append_log"], @"log_***");
    XCTAssertEqualObjects(logTags[@"append_sdk"], @"sdk_***");
    XCTAssertEqualObjects(logTags[@"key3"], @"value");
    XCTAssertEqualObjects(logTags[@"key2"], @"value");
    [FTMobileAgent shutDown];
}
- (void)testAppendModuleContextBeforeModuleStartIsDiscarded{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];

    [FTMobileAgent appendGlobalContext:@{@"early_base":@"base"}];
    [FTMobileAgent appendRUMGlobalContext:@{@"early_rum":@"rum"}];
    [FTMobileAgent appendLogGlobalContext:@{@"early_log":@"log"}];

    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumTags];
    NSDictionary *logTags = [[FTPresetProperty sharedInstance] loggerTags];
    XCTAssertEqualObjects(rumTags[@"early_base"], @"base");
    XCTAssertEqualObjects(logTags[@"early_base"], @"base");
    XCTAssertNil(rumTags[@"early_rum"]);
    XCTAssertNil(logTags[@"early_log"]);

    [FTMobileAgent appendRUMGlobalContext:@{@"late_rum":@"rum"}];
    [FTMobileAgent appendLogGlobalContext:@{@"late_log":@"log"}];
    NSDictionary *updatedRumTags = [[FTPresetProperty sharedInstance] rumTags];
    NSDictionary *updatedLogTags = [[FTPresetProperty sharedInstance] loggerTags];
    XCTAssertEqualObjects(updatedRumTags[@"late_rum"], @"rum");
    XCTAssertEqualObjects(updatedLogTags[@"late_log"], @"log");
    [FTMobileAgent shutDown];
}
- (void)testRUMTagsReflectUpdates{
    FTPresetProperty *preset = [FTPresetProperty sharedInstance];
    [preset startWithVersion:@"1.0.0"
                  sdkVersion:@"2.0.0"
                         env:@"test"
                     service:@"test_service"
               globalContext:@{@"init_key": @"init_value"}
                     pkgInfo:nil];
    [preset setRUMAppID:@"test_app" sampleRate:100 sessionOnErrorSampleRate:0 rumGlobalContext:@{@"rum_key": @"rum_value"}];

    NSDictionary *firstTags = [preset rumTags];
    NSDictionary *secondTags = [preset rumTags];
    XCTAssertEqualObjects(firstTags, secondTags);
    XCTAssertEqualObjects(secondTags[@"init_key"], @"init_value");
    XCTAssertEqualObjects(secondTags[@"rum_key"], @"rum_value");

    [preset appendGlobalContext:@{@"global_added": @"global_value"}];
    NSDictionary *globalTags = [preset rumTags];
    XCTAssertNotEqualObjects(firstTags, globalTags);
    XCTAssertEqualObjects(globalTags[@"global_added"], @"global_value");

    [preset appendRUMGlobalContext:@{@"rum_added": @"rum_added_value"}];
    NSDictionary *rumTags = [preset rumTags];
    XCTAssertEqualObjects(rumTags[@"rum_added"], @"rum_added_value");
    XCTAssertTrue([rumTags[FT_RUM_CUSTOM_KEYS] containsString:@"rum_added"]);

    [preset updateUser:@"test_user" name:@"test_name" email:@"test@test.com" extra:@{@"extra": @"value"}];
    NSDictionary *userTags = [preset rumTags];
    XCTAssertEqualObjects(userTags[FT_USER_ID], @"test_user");
    XCTAssertEqualObjects(userTags[FT_USER_NAME], @"test_name");
    XCTAssertEqualObjects(userTags[@"extra"], @"value");

    [preset clearUser];
    NSDictionary *clearedUserTags = [preset rumTags];
    XCTAssertNotEqualObjects(userTags, clearedUserTags);
    XCTAssertNotEqualObjects(clearedUserTags[FT_USER_ID], @"test_user");
    XCTAssertNil(clearedUserTags[FT_USER_NAME]);
    XCTAssertNil(clearedUserTags[@"extra"]);

    [preset shutDown];
    XCTAssertEqualObjects([preset rumTags], @{});
}
- (void)testLineDataModifier_update{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"sdk_config":@"sdk"};
    config.lineDataModifier = ^NSDictionary<NSString *,id> * _Nullable(NSString * _Nonnull measurement, NSDictionary<NSString *,id> * _Nonnull data) {
        if ([measurement isEqualToString:FT_RUM_SOURCE_VIEW]) {
            return @{@"tag1":@"value3",@"field1":@"value4"};
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"rum_config":@"rum"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.globalContext = @{@"logger_config":@"logger"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSDictionary *tags = @{@"tag1":@"value1"};
    NSDictionary *fields = @{@"field1":@"value1"};
    NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:FT_RUM_SOURCE_VIEW tags:@{@"tag1":@"value1"} fields:@{@"field1":@"value1"}];
    XCTAssertFalse([array[0] isEqual:tags]);
    XCTAssertFalse([array[1] isEqual:fields]);
    XCTAssertTrue([array[0][@"tag1"] isEqualToString:@"value3"]);
    XCTAssertTrue([array[1][@"field1"] isEqualToString:@"value4"]);
    [FTMobileAgent shutDown];
}
- (void)testLineDataModifier_append{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"sdk_config":@"sdk"};
    config.lineDataModifier = ^NSDictionary<NSString *,id> * _Nullable(NSString * _Nonnull measurement, NSDictionary<NSString *,id> * _Nonnull data) {
        if ([measurement isEqualToString:FT_RUM_SOURCE_VIEW]) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:data];
            [dict setValue:@"111" forKey:@"111"];
            return dict;
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"rum_config":@"rum"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.globalContext = @{@"logger_config":@"logger"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSDictionary *tags = @{@"tag1":@"value1"};
    NSDictionary *fields = @{@"field1":@"value1"};
    NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:FT_RUM_SOURCE_VIEW tags:@{@"tag1":@"value1"} fields:@{@"field1":@"value1"}];
    XCTAssertTrue([array[0] isEqual:tags]);
    XCTAssertTrue([array[1] isEqual:fields]);
    [FTMobileAgent shutDown];
}
- (void)testLineDataModifier_measurement{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"sdk_config":@"sdk"};
    config.lineDataModifier = ^NSDictionary<NSString *,id> * _Nullable(NSString * _Nonnull measurement, NSDictionary<NSString *,id> * _Nonnull data) {
        if ([measurement isEqualToString:FT_RUM_SOURCE_ACTION]) {
            return @{@"tag1":@"value3",@"field1":@"value4"};;
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"rum_config":@"rum"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.globalContext = @{@"logger_config":@"logger"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSDictionary *tags = @{@"tag1":@"value1"};
    NSDictionary *fields = @{@"field1":@"value1"};
    NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:FT_RUM_SOURCE_VIEW tags:@{@"tag1":@"value1"} fields:@{@"field1":@"value1"}];
    XCTAssertTrue([array[0] isEqual:tags]);
    XCTAssertTrue([array[1] isEqual:fields]);
    [FTMobileAgent shutDown];
}
- (void)testLineDataModifier_return_nil{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"sdk_config":@"sdk"};
    config.lineDataModifier = ^NSDictionary<NSString *,id> * _Nullable(NSString * _Nonnull measurement, NSDictionary<NSString *,id> * _Nonnull data) {
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"rum_config":@"rum"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.globalContext = @{@"logger_config":@"logger"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSDictionary *tags = @{@"tag1":@"value1"};
    NSDictionary *fields = @{@"field1":@"value1"};
    NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:@"view" tags:@{@"tag1":@"value1"} fields:@{@"field1":@"value1"}];
    XCTAssertTrue([array[0] isEqual:tags]);
    XCTAssertTrue([array[1] isEqual:fields]);
    [FTMobileAgent shutDown];
}
- (void)testModifier_rum_log{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.globalContext = @{@"sdk_config":@"sdk"};
    __block BOOL hasRumProperty = NO;
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([key isEqualToString:@"append_rum"]) {
            return @"append_rum_***";
        }else if ([key isEqualToString:@"rum_config"]){
            return @"rum_***";
        }else if ([key isEqualToString:@"logger_config"]){
            return @"log_***";
        }else if ([key isEqualToString:@"action_name"]){
            hasRumProperty = YES;
        }
        return nil;
    };
    config.lineDataModifier = ^NSDictionary<NSString *,id> * _Nullable(NSString * _Nonnull measurement, NSDictionary<NSString *,id> * _Nonnull data) {
        if ([measurement isEqualToString:FT_RUM_SOURCE_ACTION]) {
            return @{@"field2":@"value4"};;
        }else if ([measurement isEqualToString:FT_LOGGER_SOURCE]){
            return @{@"field1":@"value3"};
        }else if ([measurement isEqualToString:FT_LOGGER_TVOS_SOURCE]){
            return @{@"field1":@"value3"};
        }
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"rum_config":@"rum"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.globalContext = @{@"logger_config":@"logger"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testModifier_rum_log" property:@{@"field1":@"value1"}];
    [[FTLogger sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    [[FTExternalDataManager sharedManager] addAction:@"testModifier_rum_log" actionType:@"click" property:@{@"field2":@"value2"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    __block BOOL hasLog = NO,hasRum = NO;
    [FTModelHelper resolveModelArray:datas dataTypeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, NSString * _Nonnull type, BOOL * _Nonnull stop){
        if ([type isEqualToString:FT_DATA_TYPE_RUM]) {
            if (fields[@"field2"]) {
                XCTAssertTrue([fields[@"field2"] isEqualToString:@"value4"]);
                hasRum = YES;
            }
            XCTAssertTrue([tags[@"rum_config"] isEqualToString:@"rum_***"]);
        }else if ([type isEqualToString:FT_DATA_TYPE_LOGGING]){
            XCTAssertTrue([fields[@"field1"] isEqualToString:@"value3"]);
            XCTAssertTrue([tags[@"logger_config"] isEqualToString:@"log_***"]);
            hasLog = YES;
        }
    }];
    XCTAssertTrue(hasRumProperty);
    XCTAssertTrue(hasLog);
    XCTAssertTrue(hasRum);
    [FTMobileAgent shutDown];
}
 
- (void)testConcurrentReadWriteThreadSafety {
    
    FTPresetProperty *preset = [FTPresetProperty sharedInstance];
    [preset startWithVersion:@"1.0.0"
                  sdkVersion:@"2.0.0"
                         env:@"test"
                     service:@"test_service"
               globalContext:@{@"init_key": @"init_value"}
                     pkgInfo:@{@"pkg_name": @"test_pkg"}];
    [preset setRUMAppID:@"aaa" sampleRate:100 sessionOnErrorSampleRate:0 rumGlobalContext:@{@"a":@"b"}];
    [preset setLogGlobalContext:@{@"log_init":@"log_value"}];
    
    NSInteger writeThreadCount = 5;
    NSInteger readThreadCount = 10;
    NSInteger operationCountPerThread = 100;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent read/write completed"];
    expectation.expectedFulfillmentCount = writeThreadCount + readThreadCount;
    
    for (NSInteger i = 0; i < writeThreadCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (NSInteger j = 0; j < operationCountPerThread; j++) {
                NSString *key = [NSString stringWithFormat:@"write_key_%ld_%ld", i, j];
                NSString *value = [NSString stringWithFormat:@"write_value_%ld_%ld", i, j];
                [preset appendGlobalContext:@{key: value}];
                [preset appendLogGlobalContext:@{key: value}];
                [preset appendRUMGlobalContext:@{[NSString stringWithFormat:@"rum_key_%ld_%ld", i, j]: value}];
                [preset updateUser:[NSString stringWithFormat:@"write_key_%ld_%ld", i, j] name:[NSString stringWithFormat:@"rum_key_%ld_%ld", i, j] email:[NSString stringWithFormat:@"%ld@test.com", (long)i] extra:@{key: value}];
                if (j % 10 == 0) {
                    [preset clearUser];
                }

            }
            [expectation fulfill];
        });
    }
    
    for (NSInteger i = 0; i < readThreadCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (NSInteger j = 0; j < operationCountPerThread; j++) {
                NSDictionary *rumDynamicTags = preset.rumDynamicTags;
                NSDictionary *loggerDynamicTags = preset.loggerDynamicTags;

            
                XCTAssertNotNil(rumDynamicTags, @"RUM dynamic tags should not be nil (thread: %ld, op: %ld)", i, j);
                XCTAssertNotNil(loggerDynamicTags, @"Log dynamic tags should not be nil (thread: %ld, op: %ld)", i, j);

                XCTAssertTrue([loggerDynamicTags isKindOfClass:[NSDictionary class]], @"Log Dynamic tags should be NSDictionary");
                XCTAssertTrue([rumDynamicTags isKindOfClass:[NSDictionary class]], @"RUM dynamic tags should be NSDictionary");
            }
            [expectation fulfill];
        });
    }
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Concurrent read/write timeout: %@", error.localizedDescription);
        }
    }];
    
    NSDictionary *finalDynamicLog = preset.loggerDynamicTags;
    NSDictionary *finalDynamicRUM = preset.rumDynamicTags;
    XCTAssertGreaterThan(finalDynamicLog.count, 0, @"Final dynamic Log context should have data");
    XCTAssertGreaterThan(finalDynamicRUM.count, 0, @"Final dynamic RUM context should have data");
}
- (void)testShutDownDataRelease {
    FTPresetProperty *preset = [FTPresetProperty sharedInstance];
    [preset startWithVersion:@"1.0.0"
                  sdkVersion:@"2.0.0"
                         env:@"test"
                     service:@"test_service"
               globalContext:@{@"test_key": @"test_value"}
                     pkgInfo:@{@"pkg_name": @"test_pkg"}];
    [preset appendGlobalContext:@{@"shutdown_key": @"shutdown_value"}];
    [preset updateUser:@"test_user" name:@"test_name" email:@"test@test.com" extra:@{@"extra": @"value"}];
    
    
    [preset shutDown];
    
    NSDictionary *loggerTags = preset.loggerTags;
    NSDictionary *rumTags = preset.rumTags;
    FTUserInfo *user = preset.userInfo;
    NSString *rumCustomKeys = [preset.rumDynamicTags valueForKey:FT_RUM_CUSTOM_KEYS];
    
    XCTAssertTrue(loggerTags == nil || [loggerTags isEqual:@{}], @"log tags should be nil or empty after shutdown");
    XCTAssertTrue(rumTags == nil || [rumTags isEqual:@{}], @"rum tags context should be nil or empty after shutdown");
    XCTAssertTrue(rumTags == nil || [rumTags isEqual:@{}], @"RUM tags should be nil or empty after shutdown");
    XCTAssertNotNil(user, @"User info should not be nil after shutdown");
    XCTAssertNil(rumCustomKeys, @"RUM custom keys should be nil after shutdown");
    
    [preset appendGlobalContext:@{@"after_shutdown": @"value"}];
    NSDictionary *afterShutdownTags = preset.rumDynamicTags;
    XCTAssertNotNil(afterShutdownTags, @"Operation after shutdown should not crash");
}
- (void)testSDKShutDown{
    NSInteger startThreadCount = 5;
    NSInteger shutdownThreadCount = 5;
    NSInteger operationCountPerThread = 100;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent read/write completed"];
    expectation.expectedFulfillmentCount = startThreadCount + shutdownThreadCount;
    
    for (NSInteger i = 0; i < startThreadCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (NSInteger j = 0; j < operationCountPerThread; j++) {
                [self startProperty];
            }
            [expectation fulfill];
        });
    }
    
    for (NSInteger i = 0; i < shutdownThreadCount; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (NSInteger j = 0; j < operationCountPerThread; j++) {
                [[FTPresetProperty sharedInstance] shutDown];
            }
            [expectation fulfill];
        });
    }
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Concurrent read/write timeout: %@", error.localizedDescription);
        }
    }];
    
}
- (void)startProperty{
    FTPresetProperty *preset = [FTPresetProperty sharedInstance];
    [preset startWithVersion:@"1.0.0"
                  sdkVersion:@"2.0.0"
                         env:@"test"
                     service:@"test_service"
               globalContext:@{@"test_key": @"test_value"}
                     pkgInfo:@{@"pkg_name": @"test_pkg"}];
    [preset appendGlobalContext:@{@"shutdown_key": @"shutdown_value"}];
    [preset setRUMAppID:@"111" sampleRate:100 sessionOnErrorSampleRate:100 rumGlobalContext:@{@"a":@"b"}];
    [preset setLogGlobalContext:@{@"c":@"d"}];
    [preset updateUser:@"test_user" name:@"test_name" email:@"test@test.com" extra:@{@"extra": @"value"}];
}
- (void)addRumData{
    [FTModelHelper startView];
    [FTModelHelper addActionWithContext:nil];
}
@end
