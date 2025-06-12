//
//  FTNetworkInterceptorTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/1/10.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "HttpEngineTestUtil.h"
#import "FTMobileConfig.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool+Test.h"
#import "NSDate+FTUtil.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRecordModel.h"
#import "FTURLSessionDelegate.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTTraceContext.h"
#import "OHHTTPStubs.h"
@interface FTNetworkInterceptorTest : XCTestCase

@end

@implementation FTNetworkInterceptorTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [OHHTTPStubs removeAllStubs];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
}
- (void)initSDKEnableAutoTrace:(BOOL)enable{
    [self initSDKEnableAutoTrace:enable traceInterceptor:nil];
}
- (void)initSDKEnableAutoTrace:(BOOL)enable resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider{
    [self initSDKEnableAutoTrace:enable resourcePropertyProvider:resourcePropertyProvider traceInterceptor:nil errorFilter:nil];
}
- (void)initSDKEnableAutoTrace:(BOOL)enable traceInterceptor:(TraceInterceptor)traceInterceptor{
    [self initSDKEnableAutoTrace:enable resourcePropertyProvider:nil traceInterceptor:traceInterceptor errorFilter:nil];
}
- (void)initSDKEnableAutoTrace:(BOOL)enable
      resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider
              traceInterceptor:(TraceInterceptor)traceInterceptor
                   errorFilter:(SessionTaskErrorFilter)errorFilter
{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    if(resourcePropertyProvider){
        rumConfig.resourcePropertyProvider = resourcePropertyProvider;
    }
    if (errorFilter) {
        rumConfig.sessionTaskErrorFilter = errorFilter;
    }
    rumConfig.enableTraceUserResource = enable;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = enable;
    if(traceInterceptor){
        traceConfig.traceInterceptor = traceInterceptor;
    }
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
#pragma mark - RUM
- (void)testResourceLocalErrorFilter_session{
    [self resourceLocalErrorFilter:YES enableGlobal:NO];
}
- (void)testResourceLocalErrorFilter_global{
    [self resourceLocalErrorFilter:NO enableGlobal:YES];
}
- (void)testResourceLocalErrorFilter_priority{
    [self resourceLocalErrorFilter:YES enableGlobal:YES];
}
- (void)resourceLocalErrorFilter:(BOOL)enableSession enableGlobal:(BOOL)enableGlobal{
    [self initSDKEnableAutoTrace:YES resourcePropertyProvider:nil traceInterceptor:nil errorFilter:enableGlobal?^BOOL(NSError * _Nonnull error) {
        if (error.code == NSURLErrorBadURL) {
            return YES;
        }
        return NO;
    }:nil];
    NSURL *url = [NSURL URLWithString:@"http://test.error-filter.com"];
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey:@"An asynchronous load has been canceled."}];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
    FTURLSessionDelegate *ftDelegate = [[FTURLSessionDelegate alloc]init];
    if (enableSession) {
        ftDelegate.errorFilter = ^BOOL(NSError * _Nonnull error) {
            if (error.code == NSURLErrorCancelled) {
                return YES;
            }
            return NO;
        };
    }
    XCTestExpectation *expectation = [self expectationWithDescription:@"request"];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:ftDelegate delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [task resume];
    
    [self waitForExpectations:@[expectation]];
    [NSThread sleepForTimeInterval:0.5];

    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block int hasResourceCount = 0, hasErrorCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceCount ++;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasErrorCount ++;
        }
    }];
    XCTAssertTrue(hasResourceCount == 1);
    if (enableSession) {
        XCTAssertTrue(hasErrorCount == 0);
    }else if (enableGlobal){
        XCTAssertTrue(hasErrorCount == 1);
    }
    [OHHTTPStubs removeStub:stubs];
}
/**
 *  RumAutoTrace = NO
 *  Session.ResourcePropertyProvider != nil
 *  Global.ResourcePropertyProvider = nil
 * 验证: - RUM-Resource_Count = 2
 *      - 自定义采集的 URLSession: Count = 1 , fields 中添加 ResourcePropertyProvider 自定义的参数成功
 *      - 其他 URLSession : Count = 0
 */
- (void)testResourcePropertyProvider_URLSession{
    [self resourcePropertyProviderWithAutoTrace:NO enableSession:YES enableGlobal:NO];
}
/**
 *  RumAutoTrace = YES
 *  Session.ResourcePropertyProvider != nil
 *  Global.ResourcePropertyProvider = nil
 * 验证: - RUM-Resource_Count = 2
 *      - 自定义采集的 URLSession: Count = 1 , fields.contains Session.ResourcePropertyProvider returns
 *      - 其他 URLSession : Count = 1 , fields not contains
 */
- (void)testResourcePropertyProvider_URLSession_AutoTrace{
    [self resourcePropertyProviderWithAutoTrace:YES enableSession:YES enableGlobal:NO];
}
/**
 *  RumAutoTrace = YES
 *  Session.ResourcePropertyProvider = nil
 *  Global.ResourcePropertyProvider != nil
 *  验证: - RUM-Resource_Count = 2
 *      - 自定义采集的 URLSession: Count = 1，fields.contains Global.ResourcePropertyProvider returns
 *      - 其他 URLSession : Count = 1 , fields.contains Global.ResourcePropertyProvider returns
 */
- (void)testResourcePropertyProvider_Global{
    [self resourcePropertyProviderWithAutoTrace:YES enableSession:NO enableGlobal:YES];
}
/**
 *  RumAutoTrace = YES
 *  Session.ResourcePropertyProvider != nil
 *  Global.ResourcePropertyProvider != nil
 * 验证: - RUM-Resource_Count = 2
 *      - 自定义采集的 URLSession: Count = 1，fields.contains Session.ResourcePropertyProvider returns
 *      - 其他 URLSession : Count = 1 , fields.contains Global.ResourcePropertyProvider returns
 */
- (void)testResourcePropertyProvider_Priority{
    [self resourcePropertyProviderWithAutoTrace:YES enableSession:YES enableGlobal:YES];
}
- (void)resourcePropertyProviderWithAutoTrace:(BOOL)autoTrace enableSession:(BOOL)enableSession
                                 enableGlobal:(BOOL)enableGlobal{
    ResourcePropertyProvider sessionProvider = enableSession?^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssertTrue([body isEqualToString:@"111"]);
        return @{@"s_request_body":body,@"s_response_data":responseBody};
    }:nil;
    ResourcePropertyProvider globalProvider = enableGlobal?^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return @{@"g_request_body":body,@"g_response_data":responseData};
    }:nil;
    [self initSDKEnableAutoTrace:autoTrace resourcePropertyProvider:globalProvider];
    XCTestExpectation *sessionExpectation = [self expectationWithDescription:@"Session"];
    XCTestExpectation *globalExpectation = [self expectationWithDescription:@"Global"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:sessionProvider requestInterceptor:nil traceInterceptor:nil completion:^{
        [sessionExpectation fulfill];
    }];
    [engine network:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

    }];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    url = [url URLByAppendingPathComponent:@"global"];
    NSURLSessionTask *globalTask = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [globalExpectation fulfill];
    }];
    [globalTask resume];
  
    [self waitForExpectations:@[sessionExpectation,globalExpectation] timeout:30];
    
    [NSThread sleepForTimeInterval:0.5];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block int hasResourceCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceCount ++;
            NSString *requestUrl = tags[FT_KEY_RESOURCE_URL];
            if(enableSession){
                if(![requestUrl containsString:@"global"]){
                    XCTAssertTrue([fields.allKeys containsObject:@"s_request_body"]);
                    XCTAssertTrue([fields.allKeys containsObject:@"s_response_data"]);
                }else{
                    if(enableGlobal){
                        XCTAssertTrue([fields.allKeys containsObject:@"g_request_body"]);
                        XCTAssertTrue([fields.allKeys containsObject:@"g_response_data"]);
                    }
                }
            }else{
                if (enableGlobal) {
                    XCTAssertTrue([fields.allKeys containsObject:@"g_request_body"]);
                    XCTAssertTrue([fields.allKeys containsObject:@"g_response_data"]);
                }
            }
            
        }
    }];
    if(autoTrace){
        XCTAssertTrue(hasResourceCount == 2);
    }else{
        XCTAssertTrue(hasResourceCount == 1);
    }
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
#pragma mark - Trace
/**
 * 验证：- 自定义采集的 URLSession Trace 自定义成功
 *      - 其他 URLSession 无 Trace 添加
 */
- (void)testTraceInterceptor_URLSession{
    [self traceInterceptorWithAutoTrace:NO enableSession:YES enableGlobal:NO];
}
/**
 * 验证：- 自定义采集的 URLSession Trace 自定义成功
 *      - 其他 URLSession 通过 AutoTrace 添加 Trace 成功
 */
- (void)testTraceInterceptor_URLSession_AutoTrace{
    [self traceInterceptorWithAutoTrace:YES enableSession:YES enableGlobal:NO];
}
/**
 * 验证：- 自定义采集的 URLSession 未设置 traceInterceptor Trace 添加成功
 *      - 其他 URLSession Trace 添加成功
 *      - AutoTrace 不生效
 */
- (void)testTraceInterceptor_Global{
    [self traceInterceptorWithAutoTrace:YES enableSession:NO enableGlobal:YES];
}
/**
 * 同时添加 URLSession 级的 traceInterceptor, Global traceInterceptor 以及 AutoTrace
 *  验证：- URLSession > Global > AutoTrace
 *       - 自定义采集的 URLSession: URLSession-traceInterceptor 生效
 *       - 其他 URLSession: Global-traceInterceptor 生效
 */
- (void)testTraceInterceptor_Priority{
    [self traceInterceptorWithAutoTrace:YES enableSession:YES enableGlobal:YES];
}
- (void)traceInterceptorWithAutoTrace:(BOOL)autoTrace enableSession:(BOOL)enableSession
                         enableGlobal:(BOOL)enableGlobal{
    TraceInterceptor traceInterceptor = enableSession? ^FTTraceContext *(NSURLRequest *request) {
        XCTAssertTrue(request);
        FTTraceContext *context = [FTTraceContext new];
        context.traceHeader = @{@"session_test_trace_key":@"trace_value"};
        context.traceId = @"session_traceID";
        context.spanId = @"session_spanID";
        return context;
    }:nil;
    TraceInterceptor globalTraceInterceptor = enableGlobal? ^FTTraceContext *(NSURLRequest *request) {
        XCTAssertTrue(request);
        FTTraceContext *context = [FTTraceContext new];
        context.traceHeader = @{@"global_test_trace_key":@"trace_value"};
        context.traceId = @"global_traceID";
        context.spanId = @"global_spanID";
        return context;
    }:nil;
    [self initSDKEnableAutoTrace:autoTrace traceInterceptor:globalTraceInterceptor];
    XCTestExpectation *sessionExpectation = [self expectationWithDescription:@"SessionTraceInterceptor"];
    XCTestExpectation *globalExpectation = [self expectationWithDescription:@"GlobalTraceInterceptor"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:nil requestInterceptor:nil traceInterceptor:traceInterceptor completion:^{
        [sessionExpectation fulfill];
    }];
    NSURLSessionTask *sessionTask = [engine network];
    if(enableSession){
        XCTAssertTrue([sessionTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"session_test_trace_key"]);
        XCTAssertFalse([sessionTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"global_test_trace_key"]);
    }else if (enableGlobal){
            XCTAssertFalse([sessionTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"session_test_trace_key"]);
            XCTAssertTrue([sessionTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"global_test_trace_key"]);
    }
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURLSessionTask *globalTask = [session dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [globalExpectation fulfill];
    }];
    [globalTask resume];
    XCTAssertFalse([globalTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"session_test_trace_key"]);
    if(enableGlobal){
        XCTAssertTrue([globalTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"global_test_trace_key"]);
    }
    [self waitForExpectations:@[sessionExpectation,globalExpectation] timeout:30];
    
    [NSThread sleepForTimeInterval:0.5];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block int hasResourceCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceCount ++;
            NSString *requestHeader = fields[FT_KEY_REQUEST_HEADER];
            if([requestHeader containsString:@"global_test_trace_key"]){
                XCTAssertTrue([tags[FT_KEY_SPANID] isEqualToString:@"global_spanID"]);
                XCTAssertTrue([tags[FT_KEY_TRACEID] isEqualToString:@"global_traceID"]);
            }else if([requestHeader containsString:@"session_test_trace_key"]){
                XCTAssertTrue([tags[FT_KEY_SPANID] isEqualToString:@"session_spanID"]);
                XCTAssertTrue([tags[FT_KEY_TRACEID] isEqualToString:@"session_traceID"]);
            }
        }
    }];
    if(autoTrace){
        XCTAssertTrue(hasResourceCount == 2);
    }else{
        XCTAssertTrue(hasResourceCount == 1);
    }
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
@end
