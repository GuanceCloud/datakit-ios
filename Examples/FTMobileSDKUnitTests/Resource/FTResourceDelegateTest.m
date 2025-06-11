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
    [FTMobileAgent shutDown];
    
}
- (void)sdkNormalSet{
    [self sdkEnableRUMAutoTrace:NO];
}
- (void)sdkEnableRUMAutoTrace:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = enable;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTModelHelper startView];
}
- (void)testUseDelegateDirect{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationDirect hasResource:YES];
}
- (void)testUseDelegateDirect_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationDirect hasResource:YES];
}
- (void)testUseDelegateInherit{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit hasResource:YES];
}
- (void)testUseDelegateInherit_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationInherit hasResource:YES];
}
- (void)testUseDelegateProperty{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationProperty hasResource:YES];
}
- (void)testUseDelegateProperty_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationProperty hasResource:YES];
}
- (void)testDataTaskWithRequestCompletionHandler{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequestCompletionHandler hasResource:YES];
}
- (void)testDataTaskWithRequestCompletionHandler_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequestCompletionHandler hasResource:YES];
}
- (void)testDataTaskWithRequest{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequest hasResource:YES];
}
- (void)testDataTaskWithRequest_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequest hasResource:YES];
}
- (void)testDataTaskWithURLCompletionHandler{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationProperty requestMethod:DataTaskWithURLCompletionHandler hasResource:YES];
}
- (void)testDataTaskWithURLCompletionHandler_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationProperty requestMethod:DataTaskWithURLCompletionHandler hasResource:YES];
}
- (void)testDataTaskWithURL{
    [self sdkNormalSet];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithURL hasResource:YES];
}
- (void)testDataTaskWithURL_enableRUMAutoTrace{
    [self sdkEnableRUMAutoTrace:YES];
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithURL hasResource:YES];
}
- (void)testResourceRequestInterceptor{
    [self resourceRequestInterceptorEnableRUMAutoTrace:NO];
}
- (void)testResourceRequestInterceptor_enableRUMAutoTrace{
    [self resourceRequestInterceptorEnableRUMAutoTrace:YES];
}
-(void)resourceRequestInterceptorEnableRUMAutoTrace:(BOOL)enable{
    [self sdkEnableRUMAutoTrace:enable];
    RequestInterceptor interceptor = ^NSURLRequest * _Nullable(NSURLRequest *request) {
        XCTAssertTrue(request);
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setValue:@"test_requestInterceptor" forHTTPHeaderField:@"test"];
        return newRequest;
    };
    [self startWithTest:InstrumentationInherit requestMethod:DataTaskWithRequest hasResource:YES provider:nil requestInterceptor:interceptor];
}
- (void)testDiffURLSessionPropertyProvider{
    [self diffURLSessionPropertyProviderEnableRUMAutoTrace:NO];
}
- (void)testDiffURLSessionPropertyProvider_enableRUMAutoTrace{
    [self diffURLSessionPropertyProviderEnableRUMAutoTrace:YES];
}
- (void)diffURLSessionPropertyProviderEnableRUMAutoTrace:(BOOL)enable{
    [self sdkEnableRUMAutoTrace:enable];
    ResourcePropertyProvider provider = ^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return @{@"response_body":responseBody};
    };
    XCTestExpectation *expectation= [self expectationWithDescription:@"FirstProvider"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:provider requestInterceptor:nil traceInterceptor:nil completion:^{
        [expectation fulfill];
    }];
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    ResourcePropertyProvider provider2 = ^NSDictionary * _Nullable(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertTrue(request);
        NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return @{@"response_body2":responseBody};
    };
    XCTestExpectation *expectation2= [self expectationWithDescription:@"SecondProvider"];
    HttpEngineTestUtil *engine2 = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:provider2 requestInterceptor:nil traceInterceptor:nil completion:^{
        [expectation2 fulfill];
    }];
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
    [self diffRequestInterceptorEnableRUMAutoTrace:NO];
}
- (void)testDiffRequestInterceptor_enableRUMAutoTrace{
    [self diffRequestInterceptorEnableRUMAutoTrace:YES];
}
- (void)diffRequestInterceptorEnableRUMAutoTrace:(BOOL)enable{
    [self sdkEnableRUMAutoTrace:enable];
    XCTestExpectation *expectation= [self expectationWithDescription:@"FirstRequestInterceptor"];

    RequestInterceptor requestInterceptor = ^NSURLRequest *(NSURLRequest *request){
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setValue:@"testRequestInterceptor" forHTTPHeaderField:@"test1"];
        return newRequest;
    };
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:nil requestInterceptor:requestInterceptor traceInterceptor:nil completion:^{
        [expectation fulfill];
    }];
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
    
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    XCTestExpectation *expectation2= [self expectationWithDescription:@"SecondRequestInterceptor"];
    RequestInterceptor requestInterceptor2 = ^NSURLRequest *(NSURLRequest *request){
        NSMutableURLRequest *newRequest = [request mutableCopy];
        [newRequest setValue:@"testRequestInterceptor" forHTTPHeaderField:@"test2"];
        return newRequest;
    };
    HttpEngineTestUtil *engine2 = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:nil requestInterceptor:requestInterceptor2 traceInterceptor:nil completion:^{
        [expectation2 fulfill];
    }];
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
    [self resourceUrlHandler:YES enableRUMAutoTrace:NO];
}
- (void)testResourceUrlHandlerReturnNO{
    [self resourceUrlHandler:NO enableRUMAutoTrace:NO];
}
- (void)testResourceUrlHandlerReturnYes_enableRUMAutoTrace{
    [self resourceUrlHandler:YES enableRUMAutoTrace:YES];
}
- (void)testResourceUrlHandlerReturnNO_enableRUMAutoTrace{
    [self resourceUrlHandler:YES enableRUMAutoTrace:YES];
}
- (void)resourceUrlHandler:(BOOL)excluded enableRUMAutoTrace:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = enable;
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTModelHelper startView];
    XCTestExpectation *expectation= [self expectationWithDescription:@"testResourceUrlHandlerReturnYes"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:nil requestInterceptor:nil traceInterceptor:nil completion:^{
        [expectation fulfill];
    }];
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
    [self intakeUrl:YES enableRUMAutoTrace:NO];
}
- (void)testIntakeUrlReturnNO{
    [self intakeUrl:NO enableRUMAutoTrace:NO];
}
- (void)testIntakeUrlReturnYes_enableRUMAutoTrace{
    [self intakeUrl:YES enableRUMAutoTrace:YES];
}
- (void)testIntakeUrlReturnNO_enableRUMAutoTrace{
    [self intakeUrl:NO enableRUMAutoTrace:YES];
}
- (void)testIntakeUrlReturnNO_nullUrl{
    [self sdkEnableRUMAutoTrace:NO];
    __block BOOL hasUrl = NO;
    [[FTMobileAgent sharedInstance] isIntakeUrl:^BOOL(NSURL * _Nonnull url) {
        hasUrl = YES;
        return YES;
    }];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.test.com/some/url/string1"]]];
    [task setValue:nil forKey:@"originalRequest"];
    [task setValue:nil forKey:@"currentRequest"];
    [NSThread sleepForTimeInterval:0.2];
    [[FTURLSessionInterceptor shared] interceptTask:task];
    [[FTURLSessionInterceptor shared] shutDown];
    XCTAssertTrue(hasUrl == NO);
}
- (void)testIntakeUrlReturnNO_Url{
    [self sdkEnableRUMAutoTrace:NO];
    __block BOOL hasUrl = NO;

    [[FTMobileAgent sharedInstance] isIntakeUrl:^BOOL(NSURL * _Nonnull url) {
        hasUrl = YES;
        return YES;
    }];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.test.com/some/url/string"]]];
    [[FTURLSessionInterceptor shared] interceptTask:task];
    [[FTURLSessionInterceptor shared] shutDown];
    XCTAssertTrue(hasUrl == YES);
}
- (void)intakeUrl:(BOOL)trace enableRUMAutoTrace:(BOOL)enable{
    [self sdkEnableRUMAutoTrace:enable];
    [[FTMobileAgent sharedInstance] isIntakeUrl:^BOOL(NSURL * _Nonnull url) {
        return trace;
    }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"testResourceUrlHandlerReturnYes"];
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:InstrumentationInherit provider:nil requestInterceptor:nil traceInterceptor:nil completion:^{
        [expectation fulfill];
    }];
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

- (void)testUseURLSessionInterceptorTraceResource{
    [self URLSessionInterceptorTraceResourceWithEnableRUMAutoTrace:NO];
}
// 使用 `FTURLSessionInterceptor` 自定义添加resource，同时开启 RUMAutoTrace，使用 FTURLSessionDelegate 自定义采集，不影响 resource 正确采集。
// 始终只采集 一条 resource 数据
// 可能会多次添加 trace ，后面添加的覆盖前面的 （最后一次生效）
// extraProvider 的添加，第一次添加后 resource 采集就会结束，后续的添加无效。（第一次生效）
- (void)testUseURLSessionInterceptorTraceResource_enableRUMAutoTrace{
    [self URLSessionInterceptorTraceResourceWithEnableRUMAutoTrace:YES];
}
- (void)URLSessionInterceptorTraceResourceWithEnableRUMAutoTrace:(BOOL)enable{
    [self sdkEnableRUMAutoTrace:enable];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [[FTURLSessionInterceptor shared] interceptRequest:request];
    __block NSURLSessionTask *task = [[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [[FTURLSessionInterceptor shared] taskReceivedData:task data:data];
        [[FTURLSessionInterceptor shared] taskCompleted:task error:error extraProvider:^NSDictionary * _Nullable(NSURLRequest * _Nullable request, NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error) {
            return @{@"ft_test":@"1"};
        } errorFilter:nil];
        [expectation fulfill];
    }];
    [task resume];
    [[FTURLSessionInterceptor shared] interceptTask:task];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block NSInteger hasResourceCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceCount += 1;
            XCTAssertTrue([fields.allKeys containsObject:@"ft_test"]);
            NSString *requestHeader = [fields valueForKey:FT_KEY_REQUEST_HEADER];
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            NSString *span = [NSString stringWithFormat:@"%@:%@",FT_NETWORK_DDTRACE_SPANID,tags[FT_KEY_SPANID]];
            XCTAssertTrue([requestHeader containsString:span]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
            NSString *trace = [NSString stringWithFormat:@"%@:%@",FT_NETWORK_DDTRACE_TRACEID,tags[FT_KEY_TRACEID]];
            XCTAssertTrue([requestHeader containsString:trace]);
        }
    }];
    XCTAssertTrue(hasResourceCount == 1);
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    [[FTURLSessionInterceptor shared] taskMetricsCollected:task metrics:metrics];
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
    HttpEngineTestUtil *engine = [[HttpEngineTestUtil alloc]initWithSessionInstrumentationType:type provider:provider requestInterceptor:requestInterceptor traceInterceptor:nil completion:^{
        [expectation fulfill];
    }];
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
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceCount += 1;
            if(provider){
                XCTAssertTrue([fields.allKeys containsObject:@"response_body"]);
            }
            NSString *requestHeader = [fields valueForKey:FT_KEY_REQUEST_HEADER];
            if(requestInterceptor){
                XCTAssertTrue([requestHeader containsString:@"test:test_requestInterceptor"]);
                XCTAssertFalse([tags.allKeys containsObject:FT_KEY_SPANID]);
                XCTAssertFalse([tags.allKeys containsObject:FT_KEY_TRACEID]);
            }else{
                XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
                NSString *span = [NSString stringWithFormat:@"%@:%@",FT_NETWORK_DDTRACE_SPANID,tags[FT_KEY_SPANID]];
                XCTAssertTrue([requestHeader containsString:span]);
                XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
                NSString *trace = [NSString stringWithFormat:@"%@:%@",FT_NETWORK_DDTRACE_TRACEID,tags[FT_KEY_TRACEID]];
                XCTAssertTrue([requestHeader containsString:trace]);
            }
        }
    }];
    XCTAssertTrue(hasResourceCount == 1);
}
@end
