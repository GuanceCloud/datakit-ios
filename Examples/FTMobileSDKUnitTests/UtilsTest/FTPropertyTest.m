//
//  FTPropertyTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/18.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTTrackDataManager.h"
#import "FTBaseInfoHandler.h"
#import "FTRecordModel.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import <objc/runtime.h>
#import <FTJSONUtil.h>
#import "NSString+FTAdd.h"
#import "FTPresetProperty.h"
#import "FTRequest.h"
#import "FTHTTPClient.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTLogger+Private.h"
@interface FTPropertyTest : XCTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTPropertyTest

- (void)setUp {
    /**
     * 设置 ft-sdk-iosTestUnitTests 的 Environment Variables
     * 额外 添加 isUnitTests = 1 防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}

- (void)tearDown {
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
 * url 为 空字符串
 * 验证标准：url为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
 */
- (void)testSetEmptyUrl{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:@""];
    
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
- (void)testIllegalUrl{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:@"111"];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    [[FTMobileAgent sharedInstance] logging:@"testIllegalUrl" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
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
 * 设置 appid 后 Rum 开启
 * 验证： Rum 数据能正常写入
 */
- (void)testSetAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:_appid];
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addRumData];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    [FTMobileAgent shutDown];
}
/**
 * 未设置 appid  Rum 关闭
 * 验证： Rum 数据不能正常写入
 */
-(void)testSetEmptyAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    XCTAssertThrows([[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig]);
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addRumData];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
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
    [FTMobileAgent appendRUMGlobalContext:@{@"append_rum":@"rum",@"key":@"value"}];
    [FTMobileAgent appendGlobalContext:@{@"append_sdk":@"sdk",@"key2":@"value"}];
    [FTMobileAgent appendLogGlobalContext:@{@"append_log":@"log",@"key3":@"value"}];

    NSDictionary *rumTags = [[FTPresetProperty sharedInstance] rumDynamicTags];
    NSDictionary *logTags = [[FTPresetProperty sharedInstance] loggerDynamicTags];
    XCTAssertTrue(rumTags.count == 7);
    XCTAssertTrue(logTags.count == 4);
    __block NSInteger count = 0;
    [rumTags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:@"append_rum"]) {
            XCTAssertTrue([obj isEqualToString:@"rum_***"]);
            count++;
        }else if ([key isEqualToString:@"append_sdk"]) {
            XCTAssertTrue([obj isEqualToString:@"sdk_***"]);
            count++;
        }else if ([key isEqualToString:@"key"]) {
            XCTAssertTrue([obj isEqualToString:@"value"]);
            count++;
        }else if ([key isEqualToString:@"key2"]) {
            XCTAssertTrue([obj isEqualToString:@"value"]);
            count++;
        }
    }];
    [logTags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:@"append_log"]) {
            XCTAssertTrue([obj isEqualToString:@"log_***"]);
            count++;
        }else if ([key isEqualToString:@"append_sdk"]) {
            XCTAssertTrue([obj isEqualToString:@"sdk_***"]);
            count++;
        }else if ([key isEqualToString:@"key3"]) {
            XCTAssertTrue([obj isEqualToString:@"value"]);
            count++;
        }else if ([key isEqualToString:@"key2"]) {
            XCTAssertTrue([obj isEqualToString:@"value"]);
            count++;
        }
    }];
    XCTAssertTrue(count == 8);
    [FTMobileAgent shutDown];
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
    config.dataModifier = ^id _Nullable(NSString * _Nonnull key, id  _Nonnull value) {
        if ([key isEqualToString:@"append_rum"]) {
            return @"append_rum_***";
        }else if ([key isEqualToString:@"rum_config"]){
            return @"rum_***";
        }else if ([key isEqualToString:@"logger_config"]){
            return @"log_***";
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
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
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
    XCTAssertTrue(hasLog);
    XCTAssertTrue(hasRum);
    [FTMobileAgent shutDown];
}
    
- (void)addRumData{
    [FTModelHelper startView];
    [FTModelHelper addActionWithContext:nil];
}
@end
