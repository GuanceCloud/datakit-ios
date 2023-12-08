//
//  FTResourceDelegateTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/10/24.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "HttpEngineTestUtil.h"
#import "FTMobileConfig.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool+Test.h"
#import "FTDateUtil.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRecordModel.h"
#import "FTURLSessionDelegate.h"

typedef NS_ENUM(NSUInteger,TestSessionRequestMethod){
    DataTaskWithRequestCompletionHandler,
    DataTaskWithRequest,
    DataTaskWithURLCompletionHandler,
    DataTaskWithURL,
};
@interface FTResourceDelegateTest : XCTestCase<NSURLSessionDataDelegate>

@end

@implementation FTResourceDelegateTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTMobileAgent sharedInstance] shutDown];
    
}
- (void)sdkNormalSet{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [FTModelHelper startView];
}
- (void)sdkInnerURLTestSet{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"TRACE_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [FTModelHelper startView];
}
- (void)testUseDelegateDirect{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationDirect hasResource:YES];
}
- (void)testUseDelegateInherit{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit hasResource:YES];
}
- (void)testUseDelegateProperty{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationProperty hasResource:YES];
}
- (void)testDataTaskWithRequestCompletionHandler{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequestCompletionHandler hasResource:YES];
}
- (void)testDataTaskWithRequest{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequest hasResource:YES];
}
- (void)testDataTaskWithURLCompletionHandler{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationProperty requestMethod:DataTaskWithURLCompletionHandler hasResource:YES];
}
- (void)testDataTaskWithURL{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithURL hasResource:YES];
}
- (void)testResourcePropertyProvider{
    [self sdkNormalSet];
    ResourcePropertyProvider provider = ^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssertTrue([body isEqualToString:@"111"]);
        return @{@"request_body":body,@"response_body":responseBody};
    };
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequestCompletionHandler hasResource:YES provider:provider];
}
- (void)testResourceRequestInterceptor{
    [self sdkNormalSet];
    RequestInterceptor interceptor = ^NSURLRequest * _Nullable(NSURLRequest *request) {
        XCTAssertTrue(request);
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setValue:@"test_requestInterceptor" forHTTPHeaderField:@"test"];
        return newRequest;
    };
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequest hasResource:YES provider:nil requestInterceptor:interceptor];
}
- (void)testDiffURLSessionPropertyProvider{
    [self sdkNormalSet];
    ResourcePropertyProvider provider = ^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return @{@"response_body":responseBody};
    };
    XCTestExpectation *expectation= [self expectationWithDescription:@"FirstProvider"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit expectation:expectation provider:provider requestInterceptor:nil];
    [engine network];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource = YES;
            *stop = YES;
            XCTAssertTrue([fields.allKeys containsObject:@"response_body"]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
        }
    }];
    XCTAssertTrue(hasResource);
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    ResourcePropertyProvider provider2 = ^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return @{@"response_body2":responseBody};
    };
    XCTestExpectation *expectation2= [self expectationWithDescription:@"SecondProvider"];
    HttpEngineTestUtil *engine2 = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit expectation:expectation2 provider:provider2 requestInterceptor:nil];
    [engine2 network];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray2 = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource2 = NO;
    [FTModelHelper resolveModelArray:newArray2 callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource2 = YES;
            *stop = YES;
            XCTAssertTrue([fields.allKeys containsObject:@"response_body2"]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
        }
    }];
    XCTAssertTrue(hasResource2);
}
- (void)testDiffRequestInterceptor{
    [self sdkNormalSet];
    XCTestExpectation *expectation= [self expectationWithDescription:@"FirstRequestInterceptor"];

    RequestInterceptor requestInterceptor = ^NSURLRequest *(NSURLRequest *request){
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setValue:@"testRequestInterceptor" forHTTPHeaderField:@"test1"];
        return newRequest;
    };
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit expectation:expectation provider:nil requestInterceptor:requestInterceptor];
    [engine network];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource = YES;
            *stop = YES;
            NSString *requestHeader = [fields valueForKey:FT_KEY_REQUEST_HEADER];
            XCTAssertTrue([requestHeader containsString:@"test1:testRequestInterceptor"]);
            XCTAssertFalse([requestHeader containsString:@"test2:testRequestInterceptor"]);
        }
    }];
    XCTAssertTrue(hasResource);
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    XCTestExpectation *expectation2= [self expectationWithDescription:@"SecondRequestInterceptor"];
    RequestInterceptor requestInterceptor2 = ^NSURLRequest *(NSURLRequest *request){
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setValue:@"testRequestInterceptor" forHTTPHeaderField:@"test2"];
        return newRequest;
    };
    HttpEngineTestUtil *engine2 = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit expectation:expectation2 provider:nil requestInterceptor:requestInterceptor2];
    [engine2 network];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray2 = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource2 = NO;
    [FTModelHelper resolveModelArray:newArray2 callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource2 = YES;
            *stop = YES;
            NSString *requestHeader = [fields valueForKey:FT_KEY_REQUEST_HEADER];
            XCTAssertFalse([requestHeader containsString:@"test1:testRequestInterceptor"]);
            XCTAssertTrue([requestHeader containsString:@"test2:testRequestInterceptor"]);
        }
    }];
    XCTAssertTrue(hasResource2);
}
- (void)testResourceUrlHandlerReturnYes{
    [self resourceUrlHandler:YES];
}
- (void)testResourceUrlHandlerReturnNO{
    [self resourceUrlHandler:NO];
}
- (void)resourceUrlHandler:(BOOL)excluded{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.resourceUrlHandler = ^BOOL(NSURL *url) {
        return excluded;
    };
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [FTModelHelper startView];
    XCTestExpectation *expectation= [self expectationWithDescription:@"testResourceUrlHandlerReturnYes"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit expectation:expectation provider:nil requestInterceptor:nil];
    [engine network];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResource!=excluded);
}
- (void)testIntakeUrlReturnYes{
    [self intakeUrl:YES];
}
- (void)testIntakeUrlReturnNO{
    [self intakeUrl:NO];
}
- (void)intakeUrl:(BOOL)trace{
    [self sdkNormalSet];
    [[FTMobileAgent sharedInstance] isIntakeUrl:^BOOL(NSURL * _Nonnull url) {
        return trace;
    }];
    XCTestExpectation *expectation= [self expectationWithDescription:@"testResourceUrlHandlerReturnYes"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit expectation:expectation provider:nil requestInterceptor:nil];
    [engine network];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResource == trace);
}
- (void)startWithTest:(TestSessionInstrumentationType)type hasResource:(BOOL)has{
    [self sdkNormalSet];
    [self startWithTest:type requestMethod:DataTaskWithRequestCompletionHandler hasResource:has];
}
- (void)startWithTest:(TestSessionInstrumentationType)type requestMethod:(TestSessionRequestMethod)requestMethod hasResource:(BOOL)has{
    [self startWithTest:type requestMethod:requestMethod hasResource:has provider:nil];
}
- (void)startWithTest:(TestSessionInstrumentationType)type requestMethod:(TestSessionRequestMethod)requestMethod hasResource:(BOOL)has provider:(ResourcePropertyProvider)provider{
    [self startWithTest:type requestMethod:requestMethod hasResource:has provider:provider requestInterceptor:nil];
}
- (void)startWithTest:(TestSessionInstrumentationType)type requestMethod:(TestSessionRequestMethod)requestMethod hasResource:(BOOL)has provider:(ResourcePropertyProvider)provider requestInterceptor:(RequestInterceptor)requestInterceptor{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:type expectation:expectation provider:provider requestInterceptor:requestInterceptor];
    switch (requestMethod){
        case DataTaskWithRequestCompletionHandler:
            if(type != InstrumentationDirect){
                [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
               
                }];
            }
        break;
        case DataTaskWithRequest:
            [engine network];
            break;
        case DataTaskWithURLCompletionHandler:
            [engine urlNetwork:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
           
            }];
            break;
        case DataTaskWithURL:
            [engine urlNetwork];
            break;
    }
    if(type == InstrumentationDirect){
        [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [expectation fulfill];
        }];
    }
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource = YES;
            *stop = YES;
            if(provider){
                XCTAssertTrue([fields.allKeys containsObject:@"response_body"]);
            }
            if(requestInterceptor){
                NSString *requestHeader = [fields valueForKey:FT_KEY_REQUEST_HEADER];
                XCTAssertTrue([requestHeader containsString:@"test:test_requestInterceptor"]);
            }
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
        }
    }];
    XCTAssertTrue(hasResource == has);
}
@end
