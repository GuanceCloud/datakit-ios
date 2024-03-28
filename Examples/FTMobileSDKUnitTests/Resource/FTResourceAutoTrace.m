//
//  FTResourceAutoTrace.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/24.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//
#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTTrackerEventDBTool.h"
#import "FTConstants.h"
#import "FTRUMManager.h"
#import "TestSessionDelegate.h"
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
@interface FTResourceAutoTrace : KIFTestCase

@end

@implementation FTResourceAutoTrace

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)initSDKWithEnableAutoTraceResource:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = enable;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
}
- (void)testAutoTraceResource_NoDelegate{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:nil trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testDisableAutoTraceResource_NoDelegate{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:nil trace:NO completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testURLSessionCreateBeforeSDKInit_NoDelegate{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testAutoTraceResource_DelegateNoneMethod{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_None *delegate = [[TestSessionDelegate_None alloc]init];
    [self networkUploadHandler:delegate trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testDisableAutoTraceResource_DelegateNoneMethod{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_None *delegate = [[TestSessionDelegate_None alloc]init];
    [self networkUploadHandler:delegate trace:NO completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateNoneMethod{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_None *delegate = [[TestSessionDelegate_None alloc]init];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testAutoTraceResource_DelegateAllMethod{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithTestExpectation:expectation];
    [self networkUploadHandler:delegate trace:YES completionHandler:nil];
}
- (void)testDisableAutoTraceResource_DelegateAllMethod{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithTestExpectation:expectation];
    [self networkUploadHandler:delegate trace:NO completionHandler:nil];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateAllMethod{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithTestExpectation:expectation];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session trace:YES completionHandler:nil];
}
- (void)testAutoTraceResource_DelegateNoCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_NoCollectingMetrics *delegate = [[TestSessionDelegate_NoCollectingMetrics alloc]initWithTestExpectation:expectation];
    [self networkUploadHandler:delegate trace:YES completionHandler:nil];
}
- (void)testDisableAutoTraceResource_DelegateNoCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_NoCollectingMetrics *delegate = [[TestSessionDelegate_NoCollectingMetrics alloc]initWithTestExpectation:expectation];
    [self networkUploadHandler:delegate trace:NO completionHandler:nil];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateNoCollectingMetrics{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_NoCollectingMetrics *delegate = [[TestSessionDelegate_NoCollectingMetrics alloc]initWithTestExpectation:expectation];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session trace:YES completionHandler:nil];
}
- (void)testAutoTraceResource_DelegateOnlyCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_OnlyCollectingMetrics *delegate = [[TestSessionDelegate_OnlyCollectingMetrics alloc]init];
    [self networkUploadHandler:delegate trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
   
}
- (void)testDisableAutoTraceResource_DelegateOnlyCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_OnlyCollectingMetrics *delegate = [[TestSessionDelegate_OnlyCollectingMetrics alloc]init];
    [self networkUploadHandler:delegate trace:NO completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateOnlyCollectingMetrics{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    TestSessionDelegate_OnlyCollectingMetrics *delegate = [[TestSessionDelegate_OnlyCollectingMetrics alloc]init];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)networkUploadHandler:(id<NSURLSessionDelegate>)delegate trace:(BOOL)trace completionHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSession *session;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];

    if(delegate){
        session = [NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    } else {
        session = [NSURLSession sessionWithConfiguration:config];
    }
    [self networkUploadHandlerSession:session trace:trace completionHandler:completionHandler];
}
- (void)networkUploadHandlerSession:(NSURLSession *)session trace:(BOOL)trace completionHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    [FTModelHelper startView];
    [FTModelHelper addAction];
    
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    NSURLSessionTask *task;
    if(completionHandler){
        task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            completionHandler?completionHandler(response,error):nil;
        }];
    }else{
        task = [session dataTaskWithRequest:request];
    }
    [task resume];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [tester waitForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasRes = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasRes = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasRes==trace);
}
@end
