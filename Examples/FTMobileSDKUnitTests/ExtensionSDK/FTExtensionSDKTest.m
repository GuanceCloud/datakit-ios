//
//  FTExtensionSDKTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/11/10.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <KIF/KIF.h>
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTMobileExtension.h"
#import "FTExtensionDataManager.h"
#import "FTMobileConfig+Private.h"
#import "FTLoggerConfig+Private.h"
#import "FTRumConfig+Private.h"
#import "HttpEngineTestUtil.h"
#import "FTRumManager.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTTrackerEventDBTool.h"
#import "FTLogger+Private.h"
#import "FTTrackDataManager.h"
@interface FTExtensionSDKTest : XCTestCase

@end

@implementation FTExtensionSDKTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}
- (void)saveMobileSdkConfig{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        NSString *appid = [processInfo environment][@"APP_ID"];
        NSString *datakitUrl = [processInfo environment][@"ACCESS_SERVER_URL"];
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrl];
        
        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.networkTraceType = FTNetworkTraceTypeSkywalking;
        traceConfig.enableLinkRumData = YES;
        FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        [FTExtensionDataManager sharedInstance].groupIdentifierArray =  @[@"group.com.ft.widget.demo"];
        [[FTExtensionDataManager sharedInstance] writeMobileConfig:[config convertToDictionary]];
        [[FTExtensionDataManager sharedInstance] writeRumConfig:[rumConfig convertToDictionary]];
        [[FTExtensionDataManager sharedInstance] writeTraceConfig:[traceConfig convertToDictionary]];
        [[FTExtensionDataManager sharedInstance] writeLoggerConfig:[loggerConfig convertToDictionary]];
    });
}
- (void)setExtensionSDK{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FTExtensionConfig *config = [[FTExtensionConfig alloc]initWithGroupIdentifier:@"group.com.ft.widget.demo"];
        config.enableSDKDebugLog = YES;
        config.enableRUMAutoTraceResource = YES;
        config.enableTracerAutoTrace = YES;
        config.memoryMaxCount = 100;
        [FTExtensionManager startWithExtensionConfig:config];
    });
    [[FTExtensionDataManager sharedInstance] deleteEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTExtensionDataManager sharedInstance] deleteEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
}

- (void)testRumData{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    [[FTExternalDataManager sharedManager] startViewWithName:@"TestRum"];
    [[FTExternalDataManager sharedManager] startAction:@"extensionClick1" actionType:@"click" property:nil];
    [tester waitForTimeInterval:0.1];
    [[FTExternalDataManager sharedManager] startAction:@"extensionClick2" actionType:@"click" property:nil];
    [NSThread sleepForTimeInterval:2];
    NSArray *datas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTAssertTrue(datas.count>olddatas.count);
    __block BOOL hasAction = NO;
    [datas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *op = dict[@"dataType"];
        NSString *measurement = dict[@"eventType"];
        if ([op isEqualToString:@"RUM"]&&[measurement isEqualToString:FT_RUM_SOURCE_ACTION]) {
            NSDictionary *tags = dict[FT_TAGS];
            XCTAssertTrue([tags[FT_KEY_ACTION_NAME] isEqualToString:@"extensionClick1"]);
            hasAction = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasAction);
}
- (void)testRumResource{
    [self saveMobileSdkConfig]; 
    [self setExtensionSDK];
    [[FTExternalDataManager sharedManager] startViewWithName:@"testRumResource"];
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    [self networkUpload:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    FTRUMManager *manager = [[FTExtensionManager sharedInstance] valueForKey:@"rumManager"];
    [manager syncProcess];
    NSArray *newDatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];

    XCTAssertTrue(newDatas.count>olddatas.count);
}
- (void)testRumResourceDelegate{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    [[FTExternalDataManager sharedManager] startViewWithName:@"testRumResourceDelegate"];
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async operation timeout"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit completion:^{
        [expectation fulfill];
    }];
    [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    FTRUMManager *manager = [[FTExtensionManager sharedInstance] valueForKey:@"rumManager"];
    [manager syncProcess];
    NSArray *newDatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];

    XCTAssertTrue(newDatas.count>olddatas.count);
}
- (void)testTracer{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    [[FTExternalDataManager sharedManager] startViewWithName:@"testTracer"];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    [self networkUpload:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    FTRUMManager *manager = [[FTExtensionManager sharedInstance] valueForKey:@"rumManager"];
    [manager syncProcess];
    NSArray *newDatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    __block BOOL hasResource = NO;
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary  *dict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *op = dict[@"dataType"];
        NSString *measurement = dict[@"eventType"];
        if ([op isEqualToString:@"RUM"]&&[measurement isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            NSDictionary *tags = dict[FT_TAGS];
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
            hasResource = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResource);
}
- (void)testCustomLogger{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    [[FTExtensionManager sharedInstance] logging:@"testCustomLogger" status:FTStatusInfo];
    [[FTExtensionManager sharedInstance] logging:@"testCustomLogger" status:FTStatusInfo];
    [[FTLogger sharedInstance] syncProcess];
    NSArray *newDatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTAssertTrue(newDatas.count>olddatas.count);
    __block BOOL hasLogger = NO;
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *op = dict[@"dataType"];
        if ([op isEqualToString:@"Logging"]) {
            NSString *content = dict[FT_KEY_CONTENT];
            XCTAssertTrue([content isEqualToString:@"testCustomLogger"]);
            hasLogger = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasLogger);
}
- (void)testMaxCount{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    for (int i = 0; i<120; i++) {
        [[FTExtensionManager sharedInstance] logging:[NSString stringWithFormat:@"testMaxCount:%d",i] status:FTStatusInfo];
    }
    [NSThread sleepForTimeInterval:0.5];
    NSArray *newDatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTAssertTrue(newDatas.count>olddatas.count);
    XCTAssertTrue(newDatas.count == 100);
}
- (void)testWriteInMobileSDK_BindUserData_globalContext{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    [[FTExtensionManager sharedInstance] logging:@"testCustomLogger" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:0.5];
    [[FTLogger sharedInstance] syncProcess];
    NSArray *datas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];

    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:@"test"];
    config.groupIdentifiers = @[@"group.com.ft.widget.demo"];
    config.autoSync = NO;
    config.globalContext = @{@"ft_key":@"ft_value"};
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    logger.enableLinkRumData = YES;
    logger.globalContext = @{@"log_key":@"log_value"};
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:@"aaa"];
    rum.globalContext = @{@"rum_key":@"rum_value"};
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    [FTMobileAgent appendGlobalContext:@{@"ft_key1":@"ft_value"}];
    [FTMobileAgent appendRUMGlobalContext:@{@"rum_key1":@"rum_value"}];
    [FTMobileAgent appendLogGlobalContext:@{@"log_key1":@"log_value"}];
    
    [[FTMobileAgent sharedInstance] bindUserWithUserID:@"test_id" userName:@"BindUserData" userEmail:@"aaa@a.com" extra:@{@"extra_key":@"extra_value"}];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    [FTMobileAgent clearAllData];
    [[FTMobileAgent sharedInstance] trackEventFromExtensionWithGroupIdentifier:@"group.com.ft.widget.demo" completion:^(NSString * _Nonnull groupIdentifier, NSArray * _Nonnull events) {
        XCTAssertTrue(datas.count == events.count);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[FT_USER_ID] isEqualToString:@"test_id"]);
    XCTAssertTrue([tags[FT_USER_NAME] isEqualToString:@"BindUserData"]);
    XCTAssertTrue([tags[FT_USER_EMAIL] isEqualToString:@"aaa@a.com"]);
    XCTAssertTrue([tags[@"extra_key"] isEqualToString:@"extra_value"]);
    XCTAssertTrue([tags[@"rum_key1"] isEqualToString:@"rum_value"]);
    XCTAssertTrue([tags[@"rum_key"] isEqualToString:@"rum_value"]);
    XCTAssertTrue([tags[@"log_key"] isEqualToString:@"log_value"]);
    XCTAssertTrue([tags[@"log_key1"] isEqualToString:@"log_value"]);
    XCTAssertTrue([tags[@"ft_key"] isEqualToString:@"ft_value"]);
    XCTAssertTrue([tags[@"ft_key1"] isEqualToString:@"ft_value"]);
    NSString *custom_keys = tags[FT_RUM_CUSTOM_KEYS];
    NSArray *keys = [NSJSONSerialization JSONObjectWithData:[custom_keys dataUsingEncoding:kCFStringEncodingUTF8] options:0 error:nil];
    XCTAssertTrue(keys.count == 2);
    XCTAssertTrue([keys containsObject:@"rum_key1"]);
    XCTAssertTrue([keys containsObject:@"rum_key"]);
    [FTMobileAgent shutDown];
}
- (void)networkUpload:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler{
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:completionHandler];
    
    [task resume];
}
@end
