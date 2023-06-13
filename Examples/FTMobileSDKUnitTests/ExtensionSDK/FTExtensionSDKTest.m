//
//  FTExtensionSDKTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/11/10.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTMobileExtension.h"
#import "FTExtensionDataManager.h"
#import "FTMobileConfig+Private.h"
#import "HttpEngine.h"
#import "FTRumManager.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTTrackerEventDBTool.h"
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

        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.enableLinkRumData = YES;
        FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        [FTExtensionDataManager sharedInstance].groupIdentifierArray =  @[@"group.com.ft.widget.demo"];
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
    [[FTExternalDataManager sharedManager] addClickActionWithName:@"extensionClick1"];
    [[FTExternalDataManager sharedManager] addClickActionWithName:@"extensionClick2"];
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
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

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
    NSArray *olddatas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    HttpEngine *engine = [[HttpEngine alloc]initWithSessionInstrumentationType:InstrumentationDirect];
    [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
- (void)testTracer{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

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
    [NSThread sleepForTimeInterval:0.5];
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
- (void)testWriteInMobileSDK{
    [self saveMobileSdkConfig];
    [self setExtensionSDK];
    [[FTExtensionManager sharedInstance] logging:@"testCustomLogger" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:0.5];
    NSArray *datas = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:@"group.com.ft.widget.demo"];

    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"test"];
    config.groupIdentifiers = @[@"group.com.ft.widget.demo"];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] trackEventFromExtensionWithGroupIdentifier:@"group.com.ft.widget.demo" completion:^(NSString * _Nonnull groupIdentifier, NSArray * _Nonnull events) {
        [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(datas.count == events.count);
        XCTAssertTrue(count + datas.count == newCount);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] shutDown];
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
