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

typedef NS_ENUM(NSUInteger,TestSessionResquestMethod){
    DataTaskWithRequestCompletionHandler,
    DataTaskWithRequest,
    DataTaskWithURLCompletionHandler,
    DataTaskWithURL,
};
@interface FTResourceDelegateTest : XCTestCase

@end

@implementation FTResourceDelegateTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTGlobalRumManager sharedInstance].rumManager applicationWillTerminate];
    [[FTMobileAgent sharedInstance] resetInstance];

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
    [[FTMobileAgent sharedInstance] logout];
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
    [[FTMobileAgent sharedInstance] logout];
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
- (void)testInnerURLFilter{
    [self sdkInnerURLTestSet];
    [self startWithTest:InstrumentationDirect hasResource:NO];
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
- (void)startWithTest:(TestSessionInstrumentationType)type hasResource:(BOOL)has{
    [self sdkNormalSet];
    [self startWithTest:type requestMethod:DataTaskWithRequestCompletionHandler hasResource:has];
}
- (void)startWithTest:(TestSessionInstrumentationType)type requestMethod:(TestSessionResquestMethod)requestMethod hasResource:(BOOL)has{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:type expectation:expectation];
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
    [[FTGlobalRumManager sharedInstance].rumManager applicationWillTerminate];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResource = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResource == has);
}
@end