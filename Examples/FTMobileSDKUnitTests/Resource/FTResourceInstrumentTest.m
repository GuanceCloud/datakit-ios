//
//  FTResourceInstrumentTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/5/20.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileSDK.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "TestSessionDelegate.h"
#import "FTNetworkMock.h"
#import "FTSessionTaskHandler.h"
#import <objc/runtime.h>
#import "OHHTTPStubs.h"
#import "FTRequest.h"

/** This class is used to wrap an NSURLSession object during testing. */
@interface FTURLSessionProxy : NSProxy {
    // The wrapped session object.
    id _session;
}

/** @return an instance of the session proxy. */
- (instancetype)initWithSession:(id)session;

@end

@implementation FTURLSessionProxy

- (instancetype)initWithSession:(id)session {
    if (self) {
        _session = session;
    }
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_session methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:_session];
}

@end
@interface FTResourceInstrumentTest : XCTestCase
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation FTResourceInstrumentTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    self.url = [NSURL URLWithString:urlStr];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTNetworkMock registerUrlString:urlStr];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [OHHTTPStubs removeAllStubs];
}
- (FTSessionTaskHandler *)getTraceHandler:(NSURLSessionTask *)task{
    return [[FTURLSessionInterceptor shared] performSelector:@selector(getTraceHandler:) withObject:task];
}
/** Tests that creating a shared session returns a non-nil object. */
- (void)testSharedSession {
    __block NSURLSessionDataTask *dataTask;
    NSURLSession *session = [NSURLSession sharedSession];
    XCTAssertNotNil(session);
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

   dataTask = [session dataTaskWithURL:self.url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation]];
    XCTAssertNil([self getTraceHandler:dataTask]);
}


/** Tests sessionWithConfiguration: with the default configuration returns a non-nil object. */
- (void)testSessionWithDefaultSessionConfiguration {
    [FTNetworkMock networkOHHTTPStubsHandler];
    __block NSURLSessionDataTask *dataTask;
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    XCTAssertNotNil(session);
    dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitAndRunBlockAfterResponse:^{
        XCTAssertNil([self getTraceHandler:dataTask]);
    }];
}

/** Tests sessionWithConfiguration: with an ephemeral configuration returns a non-nil object. */
- (void)testSessionWithEphemeralSessionConfiguration {
    [FTNetworkMock networkOHHTTPStubsHandler];
    __block NSURLSessionDataTask *dataTask;
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    XCTAssertNotNil(session);
    dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitAndRunBlockAfterResponse:^{
        XCTAssertNil([self getTraceHandler:dataTask]);
    }];
}

/** Tests sessionWithConfiguration: with a background configuration returns a non-nil object. */
- (void)testSessionWithBackgroundSessionConfiguration {
    [FTNetworkMock networkOHHTTPStubs];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"madeUpID"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    XCTAssertNotNil(session);
}
/** Tests instrumenting an NSProxy wrapped NSURLSession object works. */
- (void)testProxyWrappedSharedSession {
    [FTNetworkMock networkOHHTTPStubs];
    Method method = class_getClassMethod([NSURLSession class], @selector(sharedSession));
    IMP originalImp = method_getImplementation(method);
    IMP swizzledImp = imp_implementationWithBlock(^(id session) {
        typedef NSURLSession *(*OriginalImp)(id, SEL);
        NSURLSession *originalSession = ((OriginalImp)originalImp)(session, @selector(sharedSession));
        return [[FTURLSessionProxy alloc] initWithSession:originalSession];
    });
    method_setImplementation(method, swizzledImp);
    XCTAssertEqual([[NSURLSession sharedSession] class], [FTURLSessionProxy class]);
    NSURLSession *session;
    XCTAssertNoThrow(session = [NSURLSession sharedSession]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler"];
    NSURLSessionDataTask *task =
    [session dataTaskWithURL:self.url
           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [task resume];
    XCTAssertNotNil(task);
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    method_setImplementation(method, originalImp);
    XCTAssertNotEqual([[NSURLSession sharedSession] class], [FTURLSessionProxy class]);
}

/** Tests instrumenting an NSProxy wrapped NSURLSession object works. */
- (void)testProxyWrappedSessionWithConfiguration {
    [FTNetworkMock networkOHHTTPStubs];
    Method method = class_getClassMethod([NSURLSession class], @selector(sessionWithConfiguration:));
    IMP originalImp = method_getImplementation(method);
    IMP swizzledImp =
    imp_implementationWithBlock(^(id session, NSURLSessionConfiguration *configuration) {
        typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *);
        NSURLSession *originalSession = ((OriginalImp)originalImp)(
                                                                   session, @selector(sessionWithConfiguration:), configuration);
        return [[FTURLSessionProxy alloc] initWithSession:originalSession];
    });
    method_setImplementation(method, swizzledImp);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    XCTAssertEqual([[NSURLSession sessionWithConfiguration:config] class],
                   [FTURLSessionProxy class]);
    NSURLSession *session;
    XCTAssertNoThrow(session = [NSURLSession sessionWithConfiguration:config]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler"];
    NSURLSessionDataTask *task =
    [session dataTaskWithURL:self.url
           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [task resume];
    XCTAssertNotNil(task);
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    method_setImplementation(method, originalImp);
    XCTAssertNotEqual([[NSURLSession sharedSession] class], [FTURLSessionProxy class]);
}
/** Tests instrumenting an NSProxy wrapped NSURLSession object works. */
- (void)testProxyWrappedSessionWithConfigurationDelegateDelegateQueue {
    [FTNetworkMock networkOHHTTPStubs];
    SEL selector = @selector(sessionWithConfiguration:delegate:delegateQueue:);
    Method method = class_getClassMethod([NSURLSession class], selector);
    IMP originalImp = method_getImplementation(method);
    IMP swizzledImp = imp_implementationWithBlock(
                                                  ^(id session, NSURLSessionConfiguration *configuration, id<NSURLSessionDelegate> *delegate,
                                                    NSOperationQueue *delegateQueue) {
                                                        typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *,
                                                                                             id<NSURLSessionDelegate> *, NSOperationQueue *);
                                                        NSURLSession *originalSession =
                                                        ((OriginalImp)originalImp)(session, selector, configuration, delegate, delegateQueue);
                                                        return [[FTURLSessionProxy alloc] initWithSession:originalSession];
                                                    });
    method_setImplementation(method, swizzledImp);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    XCTAssertEqual([[NSURLSession sessionWithConfiguration:config delegate:nil
                                             delegateQueue:nil] class],
                   [FTURLSessionProxy class]);
    
    NSURLSession *session;
    XCTAssertNoThrow(session = [NSURLSession sessionWithConfiguration:config
                                                             delegate:nil
                                                        delegateQueue:nil]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler"];
    NSURLSessionDataTask *task =
    [session dataTaskWithURL:self.url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    XCTAssertNotNil(task);
    [task resume];
    XCTAssertNotNil([self getTraceHandler:task]);
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    method_setImplementation(method, originalImp);
}

#pragma mark - Testing delegate method wrapping

/** Tests using a nil delegate still results in tracking responses. */
- (void)testSessionWithConfigurationDelegateDelegateQueueWithNilDelegate {
    [FTNetworkMock networkOHHTTPStubs];
    __weak typeof(self) weakSelf = self;
    __block NSURLSessionDataTask *dataTask;
//    [FTNetworkMock registerBeforeHandler:^{
//        XCTAssertNotNil([weakSelf getTraceHandler:dataTask]);
//    }];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:nil
                                                     delegateQueue:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    @autoreleasepool {
        dataTask = [session dataTaskWithRequest:request];
        XCTAssertNotNil(dataTask);
        [dataTask resume];
        XCTAssertNotNil([weakSelf getTraceHandler:dataTask]);
        XCTAssertNotNil(session.delegate);
    }
}

//* Tests that the delegate class isn't instrumented more than once.
- (void)testDelegateClassOnlyRegisteredOnce {
    [FTNetworkMock networkOHHTTPStubsHandler];
    FTURLSessionCompleteTestDelegate *delegate =
    [[FTURLSessionCompleteTestDelegate alloc] init];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitAndRunBlockAfterResponse:^{
        XCTAssertTrue(delegate.URLSessionTaskDidCompleteWithErrorCalledCount == 1);
    }];
}
/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionTaskDidCompleteWithError {
    id<OHHTTPStubsDescriptor> descriptor = [FTNetworkMock networkOHHTTPStubs];
    FTURLSessionCompleteTestDelegate *delegate =
    [[FTURLSessionCompleteTestDelegate alloc] init];
    // This request needs to fail.
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:delegate
                                                     delegateQueue:nil];
    NSURLSessionTask *task;
    @autoreleasepool {
        task = [session dataTaskWithRequest:request];
        [task resume];
        XCTAssertNotNil([self getTraceHandler:task]);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    XCTAssertNil([self getTraceHandler:task]);
    XCTAssertTrue(delegate.URLSessionTaskDidCompleteWithErrorCalledCount==1);
    [OHHTTPStubs removeStub:descriptor];
}
/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionDataTaskDidReceiveData {
    [FTNetworkMock networkOHHTTPStubsHandler];
    @autoreleasepool {
        FTURLSessionCompleteTestDelegate *delegate =
        [[FTURLSessionCompleteTestDelegate alloc] init];
        NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                              delegate:delegate
                                                         delegateQueue:nil];
        NSURLSessionDataTask *dataTask = [session dataTaskWithURL:self.url];
        [dataTask resume];
        XCTAssertNotNil([self getTraceHandler:dataTask]);
        [self waitAndRunBlockAfterResponse:^{
            XCTAssertTrue(delegate.URLSessionDataTaskDidReceiveDataCalledCount == 1);
            XCTAssertNil([self getTraceHandler:dataTask]);
        }];
    }
}
/** Tests that even if a delegate doesn't implement a method, we add it to the delegate class. */
- (void)testDelegateUnimplementedURLSessionTaskDidCompleteWithError {
    [FTNetworkMock networkOHHTTPStubsHandler];
    FTURLSessionNoCompleteTestDelegate *delegate = [[FTURLSessionNoCompleteTestDelegate alloc] init];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    XCTAssertFalse([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:delegate
                                                     delegateQueue:nil];
    XCTAssertTrue([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]);
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitAndRunBlockAfterResponse:^() {
        XCTAssertNil([self getTraceHandler:dataTask]);
    }];
}
/** Tests that even if a delegate doesn't implement a method, we add it to the delegate class. */
- (void)testDelegateUnimplementedURLSessionTaskDidFinishCollectingMetrics {
    [FTNetworkMock networkOHHTTPStubsHandler];
    FTURLSessionNoDidFinishCollectingMetrics *delegate = [[FTURLSessionNoDidFinishCollectingMetrics alloc] init];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    XCTAssertFalse([delegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:delegate
                                                     delegateQueue:nil];
    XCTAssertTrue([delegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]);
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitAndRunBlockAfterResponse:^() {
        XCTAssertNil([self getTraceHandler:dataTask]);
    }];
}

#pragma mark - Testing instance method wrapping

/** Tests that dataTaskWithRequest: returns a non-nil object. */
- (void)testDataTaskWithRequest {
    [FTNetworkMock networkOHHTTPStubs];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    XCTAssertNotNil(dataTask);
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
}

/** Tests that dataTaskWithRequest:completionHandler: returns a non-nil object. */
- (void)testDataTaskWithRequestAndCompletionHandler {
    [FTNetworkMock networkOHHTTPStubs];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];
    void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
    ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        [expectation fulfill];
    };
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:completionHandler];
    XCTAssertNotNil(dataTask);
    [dataTask resume];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}


/** Tests that dataTaskWithUrl:completionHandler: returns a non-nil object. */
- (void)testDataTaskWithUrlAndCompletionHandler {
    [FTNetworkMock networkOHHTTPStubs];
    NSURLSession *session = [NSURLSession sharedSession];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];
    void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
    ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        [expectation fulfill];
    };
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:self.url completionHandler:completionHandler];
    XCTAssertNotNil(dataTask);
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNil([self getTraceHandler:dataTask]);
}

/** Validate that it works with NSMutableURLRequest URLs across data, upload, and download. */
- (void)testMutableRequestURLs{
    [FTNetworkMock networkOHHTTPStubs];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:self.url];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    XCTAssertNotNil([self getTraceHandler:dataTask]);
}

- (void)testSDKUploadLoggingRequest{
    [FTNetworkMock networkOHHTTPStubs];
    FTLoggingRequest *loggingRequest = [[FTLoggingRequest alloc]init];
    NSURLRequest *URLRequest = [NSURLRequest requestWithURL:loggingRequest.absoluteURL];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    XCTAssertNil([self getTraceHandler:dataTask]);
}
- (void)testSDKUploadRumRequest{
    __block NSURLSessionDataTask *dataTask;
    __weak typeof(self) weakSelf = self;
    [FTNetworkMock networkOHHTTPStubs];
    FTLoggingRequest *loggingRequest = [[FTLoggingRequest alloc]init];
    NSURLRequest *URLRequest = [NSURLRequest requestWithURL:loggingRequest.absoluteURL];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    XCTAssertNil([weakSelf getTraceHandler:dataTask]);
}
- (void)waitAndRunBlockAfterResponse:(void (^)(void))block {
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [FTNetworkMock registerHandler:^{
        block();
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10];
}
@end
