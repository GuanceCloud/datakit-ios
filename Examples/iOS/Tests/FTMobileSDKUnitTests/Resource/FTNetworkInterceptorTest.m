//
//  FTNetworkInterceptorTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/1/10.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
#import "HttpEngineTestUtil.h"
#import "FTMobileConfig.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool+Test.h"
#import "NSDate+FTUtil.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager+Private.h"
#import "FTRUMManager.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRecordModel.h"
#import "FTURLSessionDelegate.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTTraceContext.h"
#import "FTResourceContentModel.h"
#import "TestSessionDelegate.h"
#import "OHHTTPStubs.h"
#import "FTVisitorIDManager.h"
#import "FTURLSessionInstrumentation.h"
#import "NSURLSessionTask+FTSwizzler.h"
@interface FTURLSessionInterceptor(Testing)
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@interface FTURLSessionInstrumentation (VisitorIDTesting)
- (void)interceptResume:(NSURLSessionTask *)task;
@end

@interface FTNetworkInterceptorTest : XCTestCase

@end

@implementation FTNetworkInterceptorTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [OHHTTPStubs removeAllStubs];
    [[FTVisitorIDManager sharedInstance] shutDown];
    [[FTVisitorIDManager sharedInstance] reset];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [[FTURLSessionInstrumentation sharedInstance] setVisitorIDEnabled:NO];
    [[FTVisitorIDManager sharedInstance] shutDown];
    [[FTVisitorIDManager sharedInstance] reset];
}

- (void)configureVisitorIDForHost:(NSString *)host {
    [[FTVisitorIDManager sharedInstance]
        configureWithEnabled:YES
                  headerName:@"x-visitor"
                         ttl:86400
                  urlMatcher:^BOOL(NSURL *url) {
        return [url.host isEqualToString:host];
    }];
    [[FTURLSessionInstrumentation sharedInstance] setVisitorIDEnabled:YES];
}

- (void)applyVisitorInterceptionToTask:(NSURLSessionTask *)task {
    [[FTURLSessionInstrumentation sharedInstance] interceptResume:task];
}

- (void)testVisitorIDInjectsIntoDataUploadAndDownloadWithoutTraceOrRUMResource {
    [self configureVisitorIDForHost:@"api.example.com"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURL *url = [NSURL URLWithString:@"https://api.example.com/resource"];
    NSMutableURLRequest *uploadRequest = [NSMutableURLRequest requestWithURL:url];
    uploadRequest.HTTPMethod = @"POST";
    NSArray<NSURLSessionTask *> *tasks = @[
        [session dataTaskWithURL:url],
        [session uploadTaskWithRequest:uploadRequest fromData:[@"body" dataUsingEncoding:NSUTF8StringEncoding]],
        [session downloadTaskWithURL:url],
    ];

    NSString *expected = nil;
    for (NSURLSessionTask *task in tasks) {
        [self applyVisitorInterceptionToTask:task];
        NSString *header = [task.currentRequest valueForHTTPHeaderField:@"x-visitor"];
        XCTAssertEqual(header.length, 33);
        XCTAssertTrue([header hasPrefix:@"p"] || [header hasPrefix:@"s"]);
        XCTAssertEqualObjects(task.ft_visitorIDSnapshot.value, header);
        if (expected) {
            XCTAssertEqualObjects(header, expected);
        } else {
            expected = header;
        }
        [task cancel];
    }
    [session invalidateAndCancel];
}

- (void)testVisitorIDMatchingOverwriteUnmatchedPreservationAndInternalExclusion {
    [self configureVisitorIDForHost:@"api.example.com"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];

    NSMutableURLRequest *matchedRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.example.com/one"]];
    [matchedRequest setValue:@"business-value" forHTTPHeaderField:@"x-visitor"];
    NSURLSessionDataTask *matched = [session dataTaskWithRequest:matchedRequest];
    [self applyVisitorInterceptionToTask:matched];
    NSString *managed = [matched.currentRequest valueForHTTPHeaderField:@"x-visitor"];
    XCTAssertNotEqualObjects(managed, @"business-value");
    XCTAssertEqualObjects(managed, matched.ft_visitorIDSnapshot.value);

    NSMutableURLRequest *unmatchedRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://other.example/one"]];
    [unmatchedRequest setValue:@"business-value" forHTTPHeaderField:@"x-visitor"];
    NSURLSessionDataTask *unmatched = [session dataTaskWithRequest:unmatchedRequest];
    [self applyVisitorInterceptionToTask:unmatched];
    XCTAssertEqualObjects([unmatched.currentRequest valueForHTTPHeaderField:@"x-visitor"], @"business-value");
    XCTAssertNil(unmatched.ft_visitorIDSnapshot);

    NSMutableURLRequest *internalRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.example.com/intake"]];
    [internalRequest setValue:@"true" forHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST];
    NSURLSessionDataTask *internal = [session dataTaskWithRequest:internalRequest];
    [self applyVisitorInterceptionToTask:internal];
    XCTAssertNil([internal.currentRequest valueForHTTPHeaderField:@"x-visitor"]);
    XCTAssertNil(internal.ft_visitorIDSnapshot);

    [matched cancel];
    [unmatched cancel];
    [internal cancel];
    [session invalidateAndCancel];
}

- (void)testVisitorIDTaskSnapshotSurvivesResetAndRepeatedResume {
    [self configureVisitorIDForHost:@"api.example.com"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURL *url = [NSURL URLWithString:@"https://api.example.com/one"];
    NSURLSessionDataTask *oldTask = [session dataTaskWithURL:url];
    [self applyVisitorInterceptionToTask:oldTask];
    NSString *oldValue = [oldTask.currentRequest valueForHTTPHeaderField:@"x-visitor"];

    [[FTVisitorIDManager sharedInstance] reset];
    NSString *newValue = [FTVisitorIDManager sharedInstance].snapshot.value;
    XCTAssertNotEqualObjects(newValue, oldValue);
    [self applyVisitorInterceptionToTask:oldTask];
    XCTAssertEqualObjects([oldTask.currentRequest valueForHTTPHeaderField:@"x-visitor"], oldValue);
    XCTAssertEqualObjects(oldTask.ft_visitorIDSnapshot.value, oldValue);

    NSURLSessionDataTask *newTask = [session dataTaskWithURL:url];
    [self applyVisitorInterceptionToTask:newTask];
    XCTAssertEqualObjects([newTask.currentRequest valueForHTTPHeaderField:@"x-visitor"], newValue);

    [oldTask cancel];
    [newTask cancel];
    [session invalidateAndCancel];
}

- (void)testVisitorIDMatcherRunsOnlyWhenCreatingTaskSnapshot {
    __block NSUInteger matcherCalls = 0;
    [[FTVisitorIDManager sharedInstance]
        configureWithEnabled:YES
                  headerName:@"x-visitor"
                         ttl:86400
                  urlMatcher:^BOOL(NSURL *url) {
        matcherCalls += 1;
        return [url.host isEqualToString:@"api.example.com"];
    }];
    [[FTURLSessionInstrumentation sharedInstance] setVisitorIDEnabled:YES];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://api.example.com/start"]];
    [self applyVisitorInterceptionToTask:task];
    NSString *original = task.ft_visitorIDSnapshot.value;
    XCTAssertEqual(matcherCalls, 1u);

    NSMutableURLRequest *rewrittenRequest = [task.currentRequest mutableCopy];
    rewrittenRequest.URL = [NSURL URLWithString:@"https://other.example/final"];
    [task setValue:rewrittenRequest forKey:@"currentRequest"];
    [self applyVisitorInterceptionToTask:task];

    XCTAssertEqual(matcherCalls, 1u);
    XCTAssertEqualObjects(task.ft_visitorIDSnapshot.value, original);
    XCTAssertEqualObjects([task.currentRequest valueForHTTPHeaderField:@"x-visitor"], original);

    [task cancel];
    [session invalidateAndCancel];
}

- (void)testVisitorIDUnmatchedTaskDoesNotMatchAgainAfterRequestChanges {
    __block NSUInteger matcherCalls = 0;
    [[FTVisitorIDManager sharedInstance]
        configureWithEnabled:YES
                  headerName:@"x-visitor"
                         ttl:86400
                  urlMatcher:^BOOL(NSURL *url) {
        matcherCalls += 1;
        return [url.host isEqualToString:@"api.example.com"];
    }];
    [[FTURLSessionInstrumentation sharedInstance] setVisitorIDEnabled:YES];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://other.example/start"]];
    [self applyVisitorInterceptionToTask:task];
    XCTAssertEqual(matcherCalls, 1u);
    XCTAssertTrue(task.ft_visitorIDWasEvaluated);
    XCTAssertNil(task.ft_visitorIDSnapshot);

    NSMutableURLRequest *rewrittenRequest = [task.currentRequest mutableCopy];
    rewrittenRequest.URL = [NSURL URLWithString:@"https://api.example.com/final"];
    [task setValue:rewrittenRequest forKey:@"currentRequest"];
    [self applyVisitorInterceptionToTask:task];

    XCTAssertEqual(matcherCalls, 1u);
    XCTAssertNil(task.ft_visitorIDSnapshot);
    XCTAssertNil([task.currentRequest valueForHTTPHeaderField:@"x-visitor"]);

    [task cancel];
    [session invalidateAndCancel];
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
    config.enableDataFilter = NO;
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
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}
- (nullable NSData *)resourceProviderDataForResponseData:(NSData *)responseData contentType:(nullable NSString *)contentType registeredDelegate:(BOOL)registeredDelegate{
    [OHHTTPStubs removeAllStubs];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://response-body-limit.test/%@", [[NSUUID UUID] UUIDString]]];
    __block BOOL providerCalled = NO;
    __block NSData *providerData = nil;
    ResourcePropertyProvider provider = ^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData * _Nullable data, NSError *error) {
        providerCalled = YES;
        providerData = data;
        return @{};
    };
    [self initSDKEnableAutoTrace:YES resourcePropertyProvider:provider];
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:url.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *headers = contentType ? @{@"Content-Type": contentType} : nil;
        return [OHHTTPStubsResponse responseWithData:responseData statusCode:200 headers:headers];
    }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"request"];
    NSURLSessionDataTask *task = nil;
    NSURLSession *session = nil;
    if(registeredDelegate){
        TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithCompletionHandler:^{
            [expectation fulfill];
        }];
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:delegate delegateQueue:nil];
        task = [session dataTaskWithURL:url];
    }else{
        task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [expectation fulfill];
        }];
    }
    [task resume];
    [self waitForExpectations:@[expectation] timeout:5];
    [NSThread sleepForTimeInterval:0.1];
    dispatch_sync([FTURLSessionInterceptor shared].queue, ^{});
    [session finishTasksAndInvalidate];
    [OHHTTPStubs removeStub:stub];
    XCTAssertTrue(providerCalled);
    return providerData;
}
#pragma mark - RUM
- (void)testResourcePropertyProviderKeepsSmallNonMediaResponseBody{
    NSData *data = [@"small-response" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"application/json" registeredDelegate:YES];
    XCTAssertEqualObjects(providerData, data);
}

- (void)testResourcePropertyProviderKeepsMaxSizedNonMediaResponseBody{
    NSMutableData *data = [NSMutableData dataWithLength:512 * 1024];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"application/json" registeredDelegate:YES];
    XCTAssertEqualObjects(providerData, data);
}

- (void)testResourcePropertyProviderDropsOversizedNonMediaResponseBody{
    NSMutableData *data = [NSMutableData dataWithLength:512 * 1024 + 1];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"application/json" registeredDelegate:YES];
    XCTAssertNil(providerData);
}

- (void)testResourcePropertyProviderDropsImageResponseBody{
    NSData *data = [@"media-response" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"image/png" registeredDelegate:YES];
    XCTAssertNil(providerData);
}

- (void)testResourcePropertyProviderDropsVideoResponseBody{
    NSData *data = [@"media-response" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"video/mp4" registeredDelegate:YES];
    XCTAssertNil(providerData);
}

- (void)testResourcePropertyProviderDropsAudioResponseBody{
    NSData *data = [@"media-response" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"audio/mpeg" registeredDelegate:YES];
    XCTAssertNil(providerData);
}

- (void)testResourcePropertyProviderDropsOctetStreamResponseBody{
    NSData *data = [@"media-response" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"application/octet-stream" registeredDelegate:YES];
    XCTAssertNil(providerData);
}

- (void)testResourcePropertyProviderKeepsOversizedCompletionHandlerResponseBody{
    NSMutableData *data = [NSMutableData dataWithLength:512 * 1024 + 1];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"application/json" registeredDelegate:NO];
    XCTAssertEqualObjects(providerData, data);
}

- (void)testResourcePropertyProviderKeepsMediaCompletionHandlerResponseBody{
    NSData *data = [@"media-response" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providerData = [self resourceProviderDataForResponseData:data contentType:@"image/png" registeredDelegate:NO];
    XCTAssertEqualObjects(providerData, data);
}

- (void)testResourceContentModelOnlyConvertsResponseBodyForErrorResource{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://test.com"]];
    request.HTTPMethod = @"GET";
    NSData *data = [@"response-body" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *successResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                     statusCode:200
                                                                    HTTPVersion:@"1.1"
                                                                   headerFields:@{@"Content-Type": @"text/plain"}];
    FTResourceContentModel *successModel = [[FTResourceContentModel alloc] initWithRequest:request response:successResponse data:data error:nil];
    XCTAssertEqualObjects(successModel.responseBody, @"");

    NSHTTPURLResponse *errorResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                   statusCode:500
                                                                  HTTPVersion:@"1.1"
                                                                 headerFields:@{@"Content-Type": @"text/plain"}];
    FTResourceContentModel *statusErrorModel = [[FTResourceContentModel alloc] initWithRequest:request response:errorResponse data:data error:nil];
    XCTAssertEqualObjects(statusErrorModel.responseBody, @"response-body");

    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    FTResourceContentModel *networkErrorModel = [[FTResourceContentModel alloc] initWithRequest:request response:successResponse data:data error:networkError];
    XCTAssertEqualObjects(networkErrorModel.responseBody, @"response-body");
}

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
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
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
 *  Verification: - RUM-Resource_Count = 2
 *      - Custom collected URLSession: Count = 1, fields successfully added ResourcePropertyProvider custom parameters
 *      - Other URLSession: Count = 0
 */
- (void)testResourcePropertyProvider_URLSession{
    [self resourcePropertyProviderWithAutoTrace:NO enableSession:YES enableGlobal:NO];
}
/**
 *  RumAutoTrace = YES
 *  Session.ResourcePropertyProvider != nil
 *  Global.ResourcePropertyProvider = nil
 *  Verification: - RUM-Resource_Count = 2
 *      - Custom collected URLSession: Count = 1, fields.contains Session.ResourcePropertyProvider returns
 *      - Other URLSession: Count = 1, fields not contains
 */
- (void)testResourcePropertyProvider_URLSession_AutoTrace{
    [self resourcePropertyProviderWithAutoTrace:YES enableSession:YES enableGlobal:NO];
}
/**
 *  RumAutoTrace = YES
 *  Session.ResourcePropertyProvider = nil
 *  Global.ResourcePropertyProvider != nil
 *   Verification: - RUM-Resource_Count = 2
 *      - Custom collected URLSession: Count = 1, fields.contains Global.ResourcePropertyProvider returns
 *      - Other URLSession: Count = 1, fields.contains Global.ResourcePropertyProvider returns
 */
- (void)testResourcePropertyProvider_Global{
    [self resourcePropertyProviderWithAutoTrace:YES enableSession:NO enableGlobal:YES];
}
/**
 *  RumAutoTrace = YES
 *  Session.ResourcePropertyProvider != nil
 *  Global.ResourcePropertyProvider != nil
 *  Verification: - RUM-Resource_Count = 2
 *      - Custom collected URLSession: Count = 1, fields.contains Session.ResourcePropertyProvider returns
 *      - Other URLSession: Count = 1, fields.contains Global.ResourcePropertyProvider returns
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
    
    dispatch_sync([FTURLSessionInterceptor shared].queue, ^{});

    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
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
    XCTAssertEqual(hasResourceCount, autoTrace ? 2 : 1);
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}
#pragma mark - Trace
/**
 *  Verification: - Custom collected URLSession Trace custom successfully
 *      - Other URLSession no Trace added
 */
- (void)testTraceInterceptor_URLSession{
    [self traceInterceptorWithAutoTrace:NO enableSession:YES enableGlobal:NO];
}
/**
 *  Verification: - Custom collected URLSession Trace custom successfully
 *      - Other URLSession through AutoTrace successfully added Trace
 */
- (void)testTraceInterceptor_URLSession_AutoTrace{
    [self traceInterceptorWithAutoTrace:YES enableSession:YES enableGlobal:NO];
}
/**
 *  Verification: - Custom collected URLSession no traceInterceptor Trace added successfully
 *      - Other URLSession Trace added successfully
 *      - AutoTrace does not take effect
 */
- (void)testTraceInterceptor_Global{
    [self traceInterceptorWithAutoTrace:YES enableSession:NO enableGlobal:YES];
}
/**
 *  Add URLSession-level traceInterceptor, Global traceInterceptor, and AutoTrace simultaneously
 *   Verification: - URLSession > Global > AutoTrace
 *       - Custom collected URLSession: URLSession-traceInterceptor effective
 *       - Other URLSession: Global-traceInterceptor effective
 */
- (void)testTraceInterceptor_Priority{
    [self traceInterceptorWithAutoTrace:YES enableSession:YES enableGlobal:YES];
}
- (void)testTraceContextCopiesMutableTraceHeader{
    FTTraceContext *context = [FTTraceContext new];
    NSMutableDictionary *traceHeader = [@{@"trace_key": @"trace_value"} mutableCopy];
    context.traceHeader = traceHeader;

    traceHeader[@"trace_key"] = @"mutated_value";
    traceHeader[@"extra_key"] = @"extra_value";

    XCTAssertEqualObjects(context.traceHeader[@"trace_key"], @"trace_value");
    XCTAssertNil(context.traceHeader[@"extra_key"]);
    XCTAssertFalse([context.traceHeader isKindOfClass:[NSMutableDictionary class]]);
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
    
    NSOperationQueue *callbackQueue = [[NSOperationQueue alloc] init];
    callbackQueue.maxConcurrentOperationCount = 1;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                        delegate:nil delegateQueue:callbackQueue];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURLSessionTask *globalTask = [session dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // Automatic resource completion runs after this user callback returns.
        // This operation cannot run until the serial delegate callback has finished.
        [callbackQueue addOperationWithBlock:^{ [globalExpectation fulfill]; }];
    }];
    [globalTask resume];
    XCTAssertFalse([globalTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"session_test_trace_key"]);
    if(enableGlobal){
        XCTAssertTrue([globalTask.currentRequest.allHTTPHeaderFields.allKeys containsObject:@"global_test_trace_key"]);
    }
    [self waitForExpectations:@[sessionExpectation,globalExpectation] timeout:30];
    [session finishTasksAndInvalidate];
    dispatch_sync([FTURLSessionInterceptor shared].queue, ^{});
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
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
    XCTAssertEqual(hasResourceCount, autoTrace ? 2 : 1);
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}
@end
