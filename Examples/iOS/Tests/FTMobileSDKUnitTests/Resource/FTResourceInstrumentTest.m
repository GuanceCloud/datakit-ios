//
//  FTResourceInstrumentTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/5/20.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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
#import "GuanceSDK.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "TestSessionDelegate.h"
#import "FTNetworkMock.h"
#import "FTSessionTaskHandler.h"
#import <objc/runtime.h>
#import "OHHTTPStubs.h"
#import "FTRequest.h"
#import "FTInternalConstants.h"
#import "FTURLSessionInstrumentation.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager+Private.h"
#import "FTRUMManager.h"
#import "NSURLSessionTask+FTSwizzler.h"
#import "FTDataFilterPullRequest.h"
#import "FTRemoteConfigurationRequest.h"
#import "FTResourceContentModel.h"
#import "FTRumResourceProtocol.h"
#import "FTTracerProtocol.h"
#import "FTBaseInfoHandler.h"
#import "FTDateUtil.h"
#import "FTDURLSessionDelegate.h"
#import "FTURLConnectionHandler.h"
#import "FTURLConnectionInstrumentation.h"
#import "FTURLConnectionDelegate.h"
#import "FTURLConnectionDelegateInstrumentor.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTTraceContext.h"

@interface FTURLSessionInstrumentation()
- (BOOL)isFTIntakeRequest:(NSURLRequest *)request;
- (void)interceptResume:(NSURLSessionTask *)task;
@end
@interface FTURLConnectionInstrumentation (Testing)
- (nullable id)prepareRequest:(NSURLRequest *)request delegate:(nullable id)delegate;
- (void)activateHandler:(FTURLConnectionHandler *)handler;
- (void)finishPreparingHandler:(FTURLConnectionHandler *)handler;
@end
@interface FTURLSessionInterceptor()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, weak, nullable) id<FTRumResourceProtocol> rumResourceHandler;
@property (nonatomic, copy, nullable) FTResourceUrlHandler resourceUrlHandler;
@property (nonatomic, copy, nullable) ResourcePropertyProvider resourcePropertyProvider;
@property (nonatomic, copy, nullable) SessionTaskErrorFilter sessionTaskErrorFilter;
- (FTSessionTaskHandler *)getTraceHandler:(id)key;
- (void)setTracer:(id<FTTracerProtocol>)tracer;
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom;
- (void)taskWebSocketDidOpen:(NSURLSessionTask *)task extraProvider:(nullable ResourcePropertyProvider)extraProvider;
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error;
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider errorFilter:(nullable SessionTaskErrorFilter)errorFilter;
- (void)handleTaskCompleted:(NSURLSessionTask *)task response:(nullable NSURLResponse *)response error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider errorFilter:(nullable SessionTaskErrorFilter)errorFilter endTime:(uint64_t)endTime;
@end
@interface FTDURLSessionDelegate (WebSocketTesting)
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionTask *)task didOpenWithProtocol:(nullable NSString *)protocol;
@end
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

@interface FTURLSessionSnapshotRumResourceHandler : NSObject<FTRumResourceProtocol>
@property (nonatomic, strong) FTResourceContentModel *content;
@property (nonatomic, strong) FTResourceMetricsModel *metrics;
@property (nonatomic, copy) NSString *spanID;
@property (nonatomic, copy) NSString *traceID;
@property (nonatomic, assign) NSInteger startCount;
@property (nonatomic, assign) NSInteger stopCount;
@property (nonatomic, assign) NSInteger addCount;
@property (nonatomic, copy) NSDictionary *stopProperty;
@property (nonatomic, copy) NSString *startKey;
@property (nonatomic, copy) NSString *stopKey;
@property (nonatomic, copy) NSString *addKey;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSDate *stopDate;
@end

@implementation FTURLSessionSnapshotRumResourceHandler
- (void)startResourceWithKey:(NSString *)key {
    self.startCount += 1;
}
- (void)startResourceWithKey:(NSString *)key property:(NSDictionary *)property {
    self.startCount += 1;
    self.startKey = key;
}
- (void)startResourceWithKey:(NSString *)key property:(NSDictionary *)property time:(NSDate *)time {
    self.startCount += 1;
    self.startKey = key;
    self.startDate = time;
}
- (void)stopResourceWithKey:(NSString *)key {
    self.stopCount += 1;
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property {
    self.stopCount += 1;
    self.stopKey = key;
    self.stopProperty = property;
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property time:(NSDate *)time {
    self.stopCount += 1;
    self.stopKey = key;
    self.stopProperty = property;
    self.stopDate = time;
}
- (void)addResourceWithKey:(NSString *)key metrics:(FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content {
    self.content = content;
    self.metrics = metrics;
    self.addKey = key;
    self.addCount += 1;
}
- (void)addResourceWithKey:(NSString *)key metrics:(FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(NSString *)spanID traceID:(NSString *)traceID {
    self.content = content;
    self.metrics = metrics;
    self.spanID = spanID;
    self.traceID = traceID;
    self.addKey = key;
    self.addCount += 1;
}
@end

@interface FTURLConnectionProbeInputStream : NSInputStream
@property (nonatomic, assign) NSUInteger readCount;
@end

@implementation FTURLConnectionProbeInputStream
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    self.readCount += 1;
    return 0;
}
- (BOOL)getBuffer:(uint8_t * _Nullable *)buffer length:(NSUInteger *)len { return NO; }
- (BOOL)hasBytesAvailable { return NO; }
- (void)open {}
- (void)close {}
- (NSStreamStatus)streamStatus { return NSStreamStatusNotOpen; }
@end

@interface FTURLConnectionDelegateTestClock : NSObject <FTURLConnectionClock>
@property (nonatomic, strong) NSDate *currentDate;
@property (nonatomic, assign) uint64_t currentContinuousTime;
@end

@implementation FTURLConnectionDelegateTestClock
- (NSDate *)date { return self.currentDate; }
- (uint64_t)continuousTime { return self.currentContinuousTime; }
@end

// No Foundation initializer/network activity: only the callback's connection
// identity and original request are needed for deterministic hook unit tests.
@interface FTURLConnectionCallbackConnection : NSObject
@property (nonatomic, copy) NSURLRequest *originalRequest;
@end
@implementation FTURLConnectionCallbackConnection
@end

@interface FTURLConnectionChallengeSender : NSObject <NSURLAuthenticationChallengeSender>
@end
@implementation FTURLConnectionChallengeSender
- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {}
- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {}
- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {}
- (void)performDefaultHandlingForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {}
- (void)rejectProtectionSpaceAndContinueWithChallenge:(NSURLAuthenticationChallenge *)challenge {}
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface FTURLConnectionForwardingDelegate : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong, nullable) NSURLRequest *redirectResult;
@property (nonatomic, strong, nullable) NSCachedURLResponse *cacheResult;
@property (nonatomic, assign) BOOL useCredentialStorage;
@property (nonatomic, assign) NSUInteger redirectCalls;
@property (nonatomic, assign) NSUInteger responseCalls;
@property (nonatomic, assign) NSUInteger dataCalls;
@property (nonatomic, assign) NSUInteger finishCalls;
@property (nonatomic, assign) NSUInteger failureCalls;
@property (nonatomic, strong, nullable) NSData *lastData;
@property (nonatomic, strong, nullable) NSThread *lastCallbackThread;
@property (nonatomic, assign) NSUInteger uploadCalls;
@property (nonatomic, strong) NSInputStream *streamResult;
@property (nonatomic, strong) NSURLAuthenticationChallenge *lastChallenge;
@property (nonatomic, assign) NSUInteger challengeCalls;
@end

@implementation FTURLConnectionForwardingDelegate
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    self.redirectCalls += 1;
    self.lastCallbackThread = NSThread.currentThread;
    return self.redirectResult;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.responseCalls += 1;
    self.lastCallbackThread = NSThread.currentThread;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    self.dataCalls += 1;
    self.lastData = data;
    self.lastCallbackThread = NSThread.currentThread;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.finishCalls += 1;
    self.lastCallbackThread = NSThread.currentThread;
}
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytes
 totalBytesWritten:(NSInteger)total totalBytesExpectedToWrite:(NSInteger)expected {
    self.uploadCalls += 1;
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.failureCalls += 1;
    self.lastCallbackThread = NSThread.currentThread;
}
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return self.cacheResult;
}
- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection {
    return self.useCredentialStorage;
}
- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request {
    return self.streamResult;
}
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    self.challengeCalls += 1;
    self.lastChallenge = challenge;
}
@end

@interface FTURLConnectionRedirectChildDelegate : FTURLConnectionForwardingDelegate
@property (nonatomic, strong) NSURL *finalURL;
@property (nonatomic, assign) BOOL rejectsRedirect;
@end
@implementation FTURLConnectionRedirectChildDelegate
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    NSMutableURLRequest *result = [[super connection:connection willSendRequest:request redirectResponse:response] mutableCopy];
    result.URL = self.finalURL;
    return self.rejectsRedirect ? nil : result;
}
@end

@interface FTURLConnectionDownloadOnlyDelegate : NSObject <NSURLConnectionDownloadDelegate>
@end
@implementation FTURLConnectionDownloadOnlyDelegate
- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL {}
@end

@interface FTURLConnectionThrowingDelegate : FTURLConnectionForwardingDelegate
@property (nonatomic, assign) BOOL throwsOnData;
@end
@implementation FTURLConnectionThrowingDelegate
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (self.throwsOnData) {
        @throw [NSException exceptionWithName:@"FTBusinessException" reason:@"test" userInfo:nil];
    }
    [super connection:connection didReceiveData:data];
}
@end

@interface FTURLConnectionThrowingHandler : FTURLConnectionHandler
@end
@implementation FTURLConnectionThrowingHandler
- (void)didReceiveData:(NSData *)data {
    @throw [NSException exceptionWithName:@"FTObservationException" reason:@"test" userInfo:nil];
}
@end

// Matches the observation/decision selector set in Creator 2.x's
// HttpAsynConnection. This is a native fixture, not Cocos engine validation.
@interface FTURLConnectionCocosStyleDelegate : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, assign) NSUInteger responseCalls;
@property (nonatomic, assign) NSUInteger dataCalls;
@property (nonatomic, assign) NSUInteger finishCalls;
@property (nonatomic, assign) NSUInteger failureCalls;
@property (nonatomic, assign) NSUInteger challengeCalls;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSData *lastData;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSURLAuthenticationChallenge *challenge;
@property (nonatomic, strong) NSThread *callbackThread;
@property (nonatomic, copy) dispatch_block_t onFinish;
@end

@implementation FTURLConnectionCocosStyleDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.responseCalls += 1;
    self.response = response;
    self.callbackThread = NSThread.currentThread;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    self.dataCalls += 1;
    self.lastData = data;
    self.callbackThread = NSThread.currentThread;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.finishCalls += 1;
    self.callbackThread = NSThread.currentThread;
    if (self.onFinish) self.onFinish();
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.failureCalls += 1;
    self.error = error;
    self.callbackThread = NSThread.currentThread;
}
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    self.challengeCalls += 1;
    self.challenge = challenge;
}
@end
#pragma clang diagnostic pop

@interface FTURLSessionSnapshotTracer : NSObject<FTTracerProtocol>
@property (nonatomic, assign) BOOL enableAutoTrace;
@property (nonatomic, assign) BOOL enableLinkRumData;
@property (nonatomic, copy) NSDictionary *lastUnpackedHeader;
@end

@implementation FTURLSessionSnapshotTracer
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url {
    return @{};
}
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url handler:(UnpackTraceHeaderHandler)handler {
    if (handler) {
        handler(@"generated-trace", @"generated-span");
    }
    return @{};
}
- (void)unpackTraceHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler {
    self.lastUnpackedHeader = [header copy];
    if (handler) {
        handler(header[@"x-trace-id"], header[@"x-span-id"]);
    }
}
@end

@interface FTWebSocketTestClock : NSObject
@property (atomic, assign) uint64_t time;
@end
@implementation FTWebSocketTestClock
@end


// Models the task snapshot visible at the real metrics callback boundary.
@interface FTWebSocketMetricsTestTask : NSObject<NSCopying>
@property (nonatomic, strong) NSURLRequest *currentRequest;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) NSURLSessionTaskState state;
@end
@implementation FTWebSocketMetricsTestTask
- (BOOL)ft_isWebSocketTask { return YES; }
- (BOOL)ft_hasCompletion { return NO; }
- (NSURL *)ft_webSocketResourceURL { return self.currentRequest.URL; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@interface FTWebSocketTestTransactionMetrics : NSURLSessionTaskTransactionMetrics
@end
@implementation FTWebSocketTestTransactionMetrics
- (NSURLSessionTaskMetricsResourceFetchType)resourceFetchType { return NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad; }
@end
@interface FTWebSocketTestTaskMetrics : NSURLSessionTaskMetrics
@end
@implementation FTWebSocketTestTaskMetrics
- (NSDateInterval *)taskInterval {
    return [[NSDateInterval alloc] initWithStartDate:[NSDate dateWithTimeIntervalSince1970:1700000000] duration:4];
}
- (NSArray *)transactionMetrics { return @[[FTWebSocketTestTransactionMetrics new]]; }
@end

// An existing customer forwards only the three callbacks required before WebSocket support.
@interface FTWebSocketLegacyForwardingDelegate : NSObject<FTURLSessionDelegateProviding, NSURLSessionDataDelegate>
@property (nonatomic, strong) FTURLSessionDelegate *ftURLSessionDelegate;
@end
@implementation FTWebSocketLegacyForwardingDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    [self.ftURLSessionDelegate URLSession:session dataTask:task didReceiveData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    [self.ftURLSessionDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.ftURLSessionDelegate URLSession:session task:task didCompleteWithError:error];
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
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [OHHTTPStubs removeAllStubs];
}
- (void)waitForURLSessionInterceptorQueue {
    dispatch_sync([FTURLSessionInterceptor shared].queue, ^{});
}
- (void)waitForTraceHandlerReleasedWithTask:(NSURLSessionTask *)task timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        [self waitForURLSessionInterceptorQueue];
        if ([[FTURLSessionInterceptor shared] getTraceHandler:task] == nil) {
            return;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    [self waitForURLSessionInterceptorQueue];
}

- (FTURLConnectionHandler *)urlConnectionHandlerWithRequest:(NSURLRequest *)request
                                                    provider:(ResourcePropertyProvider)provider
                                                 errorFilter:(SessionTaskErrorFilter)errorFilter
                                                      writer:(id<FTRumResourceProtocol>)writer {
    return [[FTURLConnectionHandler alloc] initWithRequest:request
                                           resourceEnabled:YES
                                                  provider:provider
                                               errorFilter:errorFilter
                                        rumResourceHandler:writer];
}

- (void)testURLConnectionHandlerUsesNetworkBoundariesAndExactBodyBytes {
    NSURL *url = [NSURL URLWithString:@"https://urlconnection.example.test/exact"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    __block NSURLRequest *providerRequest;
    __block NSURLResponse *providerResponse;
    __block NSData *providerData;
    __block NSError *providerError;
    ResourcePropertyProvider provider = ^NSDictionary *(NSURLRequest *observedRequest,
                                                        NSURLResponse *observedResponse,
                                                        NSData *data,
                                                        NSError *error) {
        providerRequest = observedRequest;
        providerResponse = observedResponse;
        providerData = data;
        providerError = error;
        return @{@"provider_value": @7};
    };
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request
                                                                    provider:provider
                                                                 errorFilter:nil
                                                                      writer:writer];
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
    NSDate *terminalDate = [NSDate dateWithTimeIntervalSince1970:1700000009];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                              statusCode:201
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{@"Content-Length": @"999"}];

    XCTAssertTrue([handler recordStartWithDate:startDate continuousTime:1000000000]);
    XCTAssertFalse([handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000005]
                                  continuousTime:6000000000]);
    [handler activate];
    [handler reportStartIfNeeded];
    [handler didReceiveResponse:response];
    [handler didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
    [handler didReceiveData:[@"defgh" dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertTrue([handler recordTerminalWithResponse:nil
                                                error:nil
                                                 date:terminalDate
                                       continuousTime:5500000000]);
    XCTAssertFalse([handler recordTerminalWithResponse:nil
                                                 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]
                                                  date:[NSDate dateWithTimeIntervalSince1970:1700000012]
                                        continuousTime:12000000000]);
    [handler reportTerminalIfNeeded];
    [handler reportTerminalIfNeeded];

    XCTAssertEqual(writer.startCount, 1);
    XCTAssertEqual(writer.stopCount, 1);
    XCTAssertEqual(writer.addCount, 1);
    XCTAssertEqualObjects(writer.startKey, handler.identifier);
    XCTAssertEqualObjects(writer.stopKey, handler.identifier);
    XCTAssertEqualObjects(writer.addKey, handler.identifier);
    XCTAssertEqualObjects(writer.startDate, startDate);
    XCTAssertEqualObjects(writer.stopDate, terminalDate);
    XCTAssertEqual(writer.metrics.fetchStartNsTimeInterval, 1700000000000000000LL);
    XCTAssertEqual(writer.metrics.fetchEndNsTimeInterval, 1700000004500000000LL);
    XCTAssertEqualObjects(writer.metrics.fetchInterval, @4500000000LL);
    XCTAssertEqualObjects(writer.metrics.requestSize, @4);
    XCTAssertEqualObjects(writer.metrics.responseSize, @8);
    XCTAssertTrue(writer.metrics.disableHeaderSizeFallback);
    XCTAssertTrue(writer.metrics.connectionReuseUnavailable);
    XCTAssertEqual(writer.metrics.dnsStartNsTimeInterval, 0);
    XCTAssertEqual(writer.metrics.connectStartNsTimeInterval, 0);
    XCTAssertEqual(writer.metrics.sslStartNsTimeInterval, 0);
    XCTAssertEqual(writer.metrics.requestStartNsTimeInterval, 0);
    XCTAssertEqual(writer.metrics.responseStartNsTimeInterval, 0);
    XCTAssertNil(writer.metrics.remoteAddress);
    XCTAssertNil(writer.metrics.resourceHttpProtocol);
    XCTAssertEqualObjects(writer.content.url, url);
    XCTAssertEqualObjects(writer.content.httpMethod, @"POST");
    XCTAssertEqual(writer.content.httpStatusCode, 201);
    XCTAssertNil(writer.content.error);
    XCTAssertEqualObjects(providerRequest.URL, url);
    XCTAssertEqual(providerResponse, response);
    XCTAssertEqualObjects(providerData, [@"abcdefgh" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertNil(providerError);
    XCTAssertEqualObjects(writer.stopProperty, @{@"provider_value": @7});
}

- (void)testURLConnectionHandlerDoesNotReportAConnectionThatNeverStarted {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/unstarted"]];
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:writer];
    [handler activate];
    XCTAssertTrue([handler recordTerminalWithResponse:nil
                                                error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]
                                                 date:[NSDate dateWithTimeIntervalSince1970:1700000010]
                                       continuousTime:9000000000]);
    [handler reportTerminalIfNeeded];
    XCTAssertEqual(handler.state, FTURLConnectionHandlerStateTerminal);
    XCTAssertEqual(writer.startCount, 0);
    XCTAssertEqual(writer.stopCount, 0);
    XCTAssertEqual(writer.addCount, 0);
}

- (void)testURLConnectionHandlerTerminalRaceHasOneWinner {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/race"]];
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:writer];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [handler activate];
    __block NSUInteger winners = 0;
    dispatch_apply(100, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        BOOL won = [handler recordTerminalWithResponse:nil
                                                error:index % 2 ? nil : [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]
                                                 date:[NSDate dateWithTimeIntervalSince1970:1700000001 + index]
                                       continuousTime:200 + index];
        if (won) {
            @synchronized (handler) {
                winners += 1;
            }
        }
    });
    [handler reportTerminalIfNeeded];
    [handler didReceiveData:[NSMutableData dataWithLength:32]];
    [handler reportTerminalIfNeeded];
    XCTAssertEqual(winners, 1u);
    XCTAssertEqual(writer.startCount, 1);
    XCTAssertEqual(writer.stopCount, 1);
    XCTAssertEqual(writer.addCount, 1);
    XCTAssertEqualObjects(writer.metrics.responseSize, @0);
}

- (void)testURLConnectionHandlerOnlyBuffersUpTo512KiBForProvider {
    NSURL *url = [NSURL URLWithString:@"https://urlconnection.example.test/buffer"];
    for (NSNumber *bodySize in @[@(512 * 1024), @(512 * 1024 + 1)]) {
        __block NSData *providerData;
        FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
        FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:[NSURLRequest requestWithURL:url]
                                                                        provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
            providerData = data;
            return @{};
        } errorFilter:nil writer:writer];
        [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
        [handler activate];
        NSUInteger firstChunk = MIN(bodySize.unsignedIntegerValue, 300 * 1024);
        [handler didReceiveData:[NSMutableData dataWithLength:firstChunk]];
        [handler didReceiveData:[NSMutableData dataWithLength:bodySize.unsignedIntegerValue - firstChunk]];
        [handler recordTerminalWithResponse:nil error:nil date:[NSDate dateWithTimeIntervalSince1970:1700000001] continuousTime:200];
        [handler reportTerminalIfNeeded];
        XCTAssertEqualObjects(writer.metrics.responseSize, bodySize);
        if (bodySize.unsignedIntegerValue == 512 * 1024) {
            XCTAssertEqual(providerData.length, 512 * 1024);
        } else {
            XCTAssertNil(providerData);
        }
    }
}

- (void)testURLConnectionHandlerCountsWithoutBufferingWhenProviderIsAbsent {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/no-provider"]];
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:writer];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [handler activate];
    [handler didReceiveData:[NSMutableData dataWithLength:700 * 1024]];
    [handler recordTerminalWithResponse:nil error:nil date:[NSDate dateWithTimeIntervalSince1970:1700000001] continuousTime:200];
    [handler reportTerminalIfNeeded];
    XCTAssertEqualObjects(writer.metrics.responseSize, @(700 * 1024));
    XCTAssertEqual(writer.content.responseBody.length, 0u);
}

- (void)testURLConnectionHandlerDoesNotReadHTTPBodyStream {
    FTURLConnectionProbeInputStream *stream = [FTURLConnectionProbeInputStream new];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/stream"]];
    request.HTTPMethod = @"POST";
    request.HTTPBodyStream = stream;
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:writer];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [handler activate];
    [handler recordTerminalWithResponse:nil error:nil date:[NSDate dateWithTimeIntervalSince1970:1700000001] continuousTime:200];
    [handler reportTerminalIfNeeded];
    XCTAssertEqual(stream.readCount, 0u);
    XCTAssertNil(writer.metrics.requestSize);
    XCTAssertTrue(writer.metrics.disableHeaderSizeFallback);
}

- (void)testURLConnectionUploadProgressOverridesHTTPBodyFallback {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/upload-progress"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSMutableData dataWithLength:100];
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:writer];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [handler activate];
    [handler didSendBodyDataWithTotalBytesWritten:20];
    [handler didSendBodyDataWithTotalBytesWritten:35];
    [handler didSendBodyDataWithTotalBytesWritten:30];
    [handler recordTerminalWithResponse:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]
                                  date:[NSDate dateWithTimeIntervalSince1970:1700000001] continuousTime:200];
    [handler reportTerminalIfNeeded];
    XCTAssertEqualObjects(writer.metrics.requestSize, @35);
}

- (void)testURLConnectionHandlerFiltersErrorBeforeProviderAndContent {
    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    __block NSError *filteredProviderError = networkError;
    __block NSUInteger filterCalls = 0;
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/filter"]]
                                                                    provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        filteredProviderError = error;
        return @{};
    } errorFilter:^BOOL(NSError *error) {
        filterCalls += 1;
        XCTAssertEqual(error, networkError);
        return YES;
    } writer:writer];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [handler activate];
    [handler recordTerminalWithResponse:nil error:networkError date:[NSDate dateWithTimeIntervalSince1970:1700000001] continuousTime:200];
    [handler reportTerminalIfNeeded];
    XCTAssertEqual(filterCalls, 1u);
    XCTAssertNil(filteredProviderError);
    XCTAssertNil(writer.content.error);
}

- (void)testURLConnectionHandlerUsesUniqueIdentifiers {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/same"]];
    FTURLConnectionHandler *first = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:nil];
    FTURLConnectionHandler *second = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:nil];
    XCTAssertNotEqualObjects(first.identifier, second.identifier);
    XCTAssertEqual(first.identifier.length, 32u);
    XCTAssertEqual(second.identifier.length, 32u);
}

- (FTURLConnectionInstrumentation *)urlConnectionInstrumentationWithResource:(BOOL)resourceEnabled
                                                                        trace:(BOOL)traceEnabled
                                                                         link:(BOOL)linkEnabled
                                                                   sampleRate:(int)sampleRate
                                                                  interceptor:(TraceInterceptor)interceptor
                                                                       writer:(id<FTRumResourceProtocol>)writer {
    FTURLConnectionInstrumentation *instrumentation = [FTURLConnectionInstrumentation new];
    [instrumentation setRumResourceHandler:writer];
    [instrumentation setEnableAutoRumResource:resourceEnabled
                           resourceUrlHandler:nil
                     resourcePropertyProvider:nil
                       sessionTaskErrorFilter:nil];
    [instrumentation setTraceEnableAutoTrace:traceEnabled
                           enableLinkRumData:linkEnabled
                                  sampleRate:sampleRate
                                   traceType:DDtrace
                            traceInterceptor:interceptor
                                 serviceName:@"urlconnection-tests"];
    return instrumentation;
}

- (void)testURLConnectionResourceAndTraceSwitchesAreIndependent {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/switches"]];
    for (NSNumber *resourceValue in @[@NO, @YES]) {
        for (NSNumber *traceValue in @[@NO, @YES]) {
            BOOL resourceEnabled = resourceValue.boolValue;
            BOOL traceEnabled = traceValue.boolValue;
            FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
            FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:resourceEnabled
                                                                                                         trace:traceEnabled
                                                                                                          link:YES
                                                                                                    sampleRate:100
                                                                                                   interceptor:nil
                                                                                                        writer:writer];
            id preparation = [instrumentation prepareRequest:request delegate:nil];
            if (!resourceEnabled && !traceEnabled) {
                XCTAssertNil(preparation);
                continue;
            }
            XCTAssertNotNil(preparation);
            NSURLRequest *preparedRequest = [preparation valueForKey:@"request"];
            FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
            XCTAssertTrue(FTRequestIsOwnedByURLConnection(preparedRequest));
            if (traceEnabled) {
                XCTAssertGreaterThan([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID].length, 0u);
                XCTAssertGreaterThan([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID].length, 0u);
                XCTAssertEqualObjects(handler.traceID, [preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID]);
                XCTAssertEqualObjects(handler.spanID, [preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID]);
            } else {
                XCTAssertNil([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID]);
                XCTAssertNil(handler.traceID);
                XCTAssertNil(handler.spanID);
            }
            [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
            [instrumentation activateHandler:handler];
            [instrumentation handler:handler didReachTerminalWithResponse:nil error:nil];
            [instrumentation syncProcess];
            XCTAssertEqual(writer.startCount, resourceEnabled ? 1 : 0);
            XCTAssertEqual(writer.stopCount, resourceEnabled ? 1 : 0);
            XCTAssertEqual(writer.addCount, resourceEnabled ? 1 : 0);
        }
    }
}

- (void)testURLConnectionExistingTraceHeaderHasPriorityAndMatchesResourceLink {
    __block NSUInteger interceptorCalls = 0;
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:YES
                                                                                                  link:YES
                                                                                            sampleRate:100
                                                                                           interceptor:^FTTraceContext *(NSURLRequest *request) {
        interceptorCalls += 1;
        return nil;
    } writer:writer];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/existing"]];
    [request setValue:@"123456789" forHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID];
    [request setValue:@"987654321" forHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID];
    id preparation = [instrumentation prepareRequest:request delegate:nil];
    NSURLRequest *preparedRequest = [preparation valueForKey:@"request"];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    XCTAssertEqual(interceptorCalls, 0u);
    XCTAssertEqualObjects([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID], @"123456789");
    XCTAssertEqualObjects([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID], @"987654321");
    XCTAssertEqualObjects(handler.traceID, @"123456789");
    XCTAssertEqualObjects(handler.spanID, @"987654321");
    XCTAssertNil(handler.injectedTraceHeaders);
}

- (void)testURLConnectionCustomTraceContextAndNilVeto {
    FTTraceContext *context = [FTTraceContext new];
    context.traceId = @"context-trace";
    context.spanId = @"context-span";
    context.traceHeader = @{
        FT_NETWORK_DDTRACE_TRACEID: @"222",
        FT_NETWORK_DDTRACE_SPANID: @"333",
        @"X-Custom-Trace": @"custom-value",
    };
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:YES
                                                                                                  link:YES
                                                                                            sampleRate:100
                                                                                           interceptor:^FTTraceContext *(NSURLRequest *request) {
        return context;
    } writer:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/custom"]];
    id preparation = [instrumentation prepareRequest:request delegate:nil];
    NSURLRequest *preparedRequest = [preparation valueForKey:@"request"];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    XCTAssertEqualObjects([preparedRequest valueForHTTPHeaderField:@"X-Custom-Trace"], @"custom-value");
    XCTAssertEqualObjects([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID], handler.traceID);
    XCTAssertEqualObjects([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID], handler.spanID);

    FTURLConnectionInstrumentation *vetoInstrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                      trace:YES
                                                                                                       link:YES
                                                                                                 sampleRate:100
                                                                                                interceptor:^FTTraceContext *(NSURLRequest *request) {
        return nil;
    } writer:nil];
    id vetoPreparation = [vetoInstrumentation prepareRequest:request delegate:nil];
    NSURLRequest *vetoRequest = [vetoPreparation valueForKey:@"request"];
    FTURLConnectionHandler *vetoHandler = [vetoPreparation valueForKey:@"handler"];
    XCTAssertNil([vetoRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID]);
    XCTAssertNil([vetoRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID]);
    XCTAssertNil(vetoHandler.traceID);
    XCTAssertNil(vetoHandler.spanID);
}

- (void)testURLConnectionSamplingUpdatesBeforeNextRequest {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/sampling"]];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:NO
                                                                                                 trace:YES
                                                                                                  link:YES
                                                                                            sampleRate:0
                                                                                           interceptor:nil
                                                                                                writer:nil];
    NSURLRequest *unsampledRequest = [[instrumentation prepareRequest:request delegate:nil] valueForKey:@"request"];
    XCTAssertEqualObjects([unsampledRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SAMPLING_PRIORITY], @"-1");
    [instrumentation updateTraceSampleRate:100];
    NSURLRequest *sampledRequest = [[instrumentation prepareRequest:request delegate:nil] valueForKey:@"request"];
    XCTAssertEqualObjects([sampledRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SAMPLING_PRIORITY], @"2");
}

- (void)testURLConnectionLinkDisabledInjectsHeadersWithoutResourceTraceTags {
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:YES
                                                                                                  link:NO
                                                                                            sampleRate:100
                                                                                           interceptor:nil
                                                                                                writer:nil];
    id preparation = [instrumentation prepareRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/no-link"]]
                                             delegate:nil];
    NSURLRequest *preparedRequest = [preparation valueForKey:@"request"];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    XCTAssertGreaterThan([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID].length, 0u);
    XCTAssertGreaterThan([preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID].length, 0u);
    XCTAssertNil(handler.traceID);
    XCTAssertNil(handler.spanID);
}

- (void)testURLConnectionOwnerAndSDKRequestsAreExcluded {
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:YES
                                                                                                  link:YES
                                                                                            sampleRate:100
                                                                                           interceptor:nil
                                                                                                writer:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/owner"]];
    id preparation = [instrumentation prepareRequest:request delegate:nil];
    NSURLRequest *ownedRequest = [preparation valueForKey:@"request"];
    XCTAssertTrue(FTRequestIsOwnedByURLConnection(ownedRequest));
    XCTAssertNil([instrumentation prepareRequest:ownedRequest delegate:nil]);

    NSMutableURLRequest *SDKRequest = [request mutableCopy];
    [SDKRequest setValue:@"true" forHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST];
    XCTAssertNil([instrumentation prepareRequest:SDKRequest delegate:nil]);
}

- (void)testURLConnectionOwnerSurvivesNSURLProtocolStyleForwardToNSURLSession {
    FTURLConnectionInstrumentation *urlConnectionInstrumentation =
        [self urlConnectionInstrumentationWithResource:YES
                                                  trace:NO
                                                   link:NO
                                             sampleRate:100
                                            interceptor:nil
                                                 writer:nil];
    NSURLRequest *sourceRequest = [NSURLRequest requestWithURL:
        [NSURL URLWithString:@"https://urlconnection.example.test/protocol-forward"]];
    NSURLRequest *ownedRequest = [[urlConnectionInstrumentation prepareRequest:sourceRequest delegate:nil]
                                  valueForKey:@"request"];
    XCTAssertTrue(FTRequestIsOwnedByURLConnection(ownedRequest));

    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURLSessionDataTask *forwardedTask = [session dataTaskWithRequest:ownedRequest];
    XCTAssertTrue(FTRequestIsOwnedByURLConnection(forwardedTask.currentRequest));
    [[FTURLSessionInstrumentation sharedInstance] interceptResume:forwardedTask];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:forwardedTask]);

    NSURLSessionDataTask *ordinaryTask = [session dataTaskWithRequest:sourceRequest];
    [[FTURLSessionInstrumentation sharedInstance] interceptResume:ordinaryTask];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:ordinaryTask]);

    NSError *cancelError = [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorCancelled
                                            userInfo:nil];
    [[FTURLSessionInterceptor shared] taskCompleted:ordinaryTask
                                             error:cancelError
                                     extraProvider:nil];
    [self waitForURLSessionInterceptorQueue];
    [forwardedTask cancel];
    [ordinaryTask cancel];
    [session invalidateAndCancel];
}

- (void)testURLConnectionCrossOriginRedirectRemovesOnlyInjectedHeaders {
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:YES
                                                                                                  link:YES
                                                                                            sampleRate:100
                                                                                           interceptor:nil
                                                                                                writer:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://first.example.test/start"]];
    id preparation = [instrumentation prepareRequest:request delegate:nil];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    NSDictionary<NSString *, NSString *> *originalInjectedHeaders = [handler.injectedTraceHeaders copy];
    XCTAssertGreaterThan(originalInjectedHeaders.count, 0u);

    NSMutableURLRequest *redirect = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://second.example.test/final"]];
    [originalInjectedHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [redirect setValue:value forHTTPHeaderField:key];
    }];
    [redirect setValue:@"business" forHTTPHeaderField:@"X-Business"];
    NSURLRequest *effectiveRedirect = [instrumentation handler:handler redirectedRequest:redirect response:nil];
    XCTAssertEqualObjects([effectiveRedirect valueForHTTPHeaderField:@"X-Business"], @"business");
    for (NSString *key in originalInjectedHeaders) {
        XCTAssertNil([effectiveRedirect valueForHTTPHeaderField:key]);
    }
    XCTAssertNil(handler.traceID);
    XCTAssertNil(handler.spanID);
    XCTAssertNil(handler.injectedTraceHeaders);
    XCTAssertTrue(FTRequestIsOwnedByURLConnection(effectiveRedirect));
}

- (void)testURLConnectionSameOriginRedirectKeepsInjectedContext {
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:YES
                                                                                                  link:YES
                                                                                            sampleRate:100
                                                                                           interceptor:nil
                                                                                                writer:nil];
    id preparation = [instrumentation prepareRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://same.example.test:443/start"]]
                                             delegate:nil];
    NSURLRequest *preparedRequest = [preparation valueForKey:@"request"];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    NSMutableURLRequest *redirect = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://same.example.test/final"]];
    [handler.injectedTraceHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [redirect setValue:value forHTTPHeaderField:key];
    }];
    NSURLRequest *effectiveRedirect = [instrumentation handler:handler redirectedRequest:redirect response:nil];
    XCTAssertEqualObjects([effectiveRedirect valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID],
                          [preparedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID]);
    XCTAssertEqualObjects(handler.traceID, [effectiveRedirect valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID]);
    XCTAssertEqualObjects(handler.spanID, [effectiveRedirect valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID]);
}

- (void)testURLConnectionDefaultDelegateObservesCallbacksWithoutAddingDecisionMethods {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (NSNumber *fails in @[@NO, @YES]) {
        FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
        FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                     trace:NO
                                                                                                      link:NO
                                                                                                sampleRate:100
                                                                                               interceptor:nil
                                                                                                    writer:writer];
        FTURLConnectionDelegateTestClock *clock = [FTURLConnectionDelegateTestClock new];
        clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
        clock.currentContinuousTime = 1000000000;
        [instrumentation setValue:clock forKey:@"clock"];
        __block NSUInteger providerCalls = 0;
        __block NSData *observedData;
        __block NSURLResponse *observedResponse;
        __block NSError *observedError;
        [instrumentation setEnableAutoRumResource:YES resourceUrlHandler:nil resourcePropertyProvider:
            ^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
                providerCalls += 1;
                observedData = data;
                observedResponse = response;
                observedError = error;
                return nil;
            } sessionTaskErrorFilter:nil];

        NSURL *url = [NSURL URLWithString:@"https://urlconnection.example.test/default-delegate"];
        id preparation = [instrumentation prepareRequest:[NSURLRequest requestWithURL:url] delegate:nil];
        FTURLConnectionDelegate *delegate = [preparation valueForKey:@"delegate"];
        FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
        XCTAssertEqual(delegate.class, FTURLConnectionDelegate.class);
        NSURLConnection *connection = (id)[FTURLConnectionCallbackConnection new];
        [FTURLConnectionInstrumentation associateHandler:handler withConnection:connection];
        XCTAssertEqual([FTURLConnectionInstrumentation handlerForConnection:connection], handler);
        XCTAssertFalse([delegate respondsToSelector:@selector(connection:willCacheResponse:)]);
        XCTAssertFalse([delegate respondsToSelector:@selector(connectionShouldUseCredentialStorage:)]);
        XCTAssertFalse([delegate respondsToSelector:@selector(connection:willSendRequestForAuthenticationChallenge:)]);
        XCTAssertFalse([delegate respondsToSelector:@selector(connection:didReceiveAuthenticationChallenge:)]);
        XCTAssertFalse([delegate respondsToSelector:@selector(connection:needNewBodyStream:)]);

        [handler recordStartWithDate:clock.currentDate continuousTime:clock.currentContinuousTime];
        [instrumentation activateHandler:handler];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200
                                                              HTTPVersion:@"HTTP/1.1" headerFields:nil];
        NSURLRequest *redirect = [NSURLRequest requestWithURL:
            [NSURL URLWithString:@"https://urlconnection.example.test/default-final"]];
        XCTAssertEqualObjects([delegate connection:connection willSendRequest:redirect redirectResponse:response].URL, redirect.URL);
        [delegate connection:connection didReceiveResponse:response];
        [delegate connection:connection didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
        [delegate connection:connection didReceiveData:[@"defgh" dataUsingEncoding:NSUTF8StringEncoding]];
        [delegate connection:connection didSendBodyData:9 totalBytesWritten:9 totalBytesExpectedToWrite:9];

        NSDate *terminalDate = [NSDate dateWithTimeIntervalSince1970:1700000004.5];
        clock.currentDate = terminalDate;
        clock.currentContinuousTime = 5500000000;
        NSError *error = fails.boolValue ? [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil] : nil;
        if (error) {
            [delegate connection:connection didFailWithError:error];
        } else {
            [delegate connectionDidFinishLoading:connection];
        }
        // Delayed processing and repeated/late callbacks cannot replace the first terminal.
        clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000100];
        clock.currentContinuousTime = 101000000000;
        [delegate connection:connection didReceiveData:[@"late" dataUsingEncoding:NSUTF8StringEncoding]];
        [delegate connectionDidFinishLoading:connection];
        [delegate connection:connection didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
        [instrumentation syncProcess];

        XCTAssertEqual(providerCalls, 1u);
        XCTAssertEqualObjects(observedData, [@"abcdefgh" dataUsingEncoding:NSUTF8StringEncoding]);
        XCTAssertEqual(observedResponse, response);
        XCTAssertEqualObjects(observedError, error);
        XCTAssertEqual(writer.startCount, 1);
        XCTAssertEqual(writer.stopCount, 1);
        XCTAssertEqual(writer.addCount, 1);
        XCTAssertEqualObjects(writer.startKey, handler.identifier);
        XCTAssertEqualObjects(writer.stopKey, handler.identifier);
        XCTAssertEqualObjects(writer.addKey, handler.identifier);
        XCTAssertEqualObjects(writer.stopDate, terminalDate);
        XCTAssertEqual(writer.metrics.fetchStartNsTimeInterval, 1700000000000000000LL);
        XCTAssertEqual(writer.metrics.fetchEndNsTimeInterval, 1700000004500000000LL);
        XCTAssertEqualObjects(writer.metrics.fetchInterval, @4500000000LL);
        XCTAssertEqualObjects(writer.metrics.responseSize, @8);
        XCTAssertEqualObjects(writer.metrics.requestSize, @9);
        XCTAssertEqual(writer.content.httpStatusCode, 200);
        XCTAssertEqualObjects(writer.content.error, error);
        [instrumentation shutDown];
    }
#pragma clang diagnostic pop
}

- (void)testURLConnectionDelegateHooksPreserveIdentityDecisionsAndCallbackThread {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                 trace:NO
                                                                                                  link:NO
                                                                                            sampleRate:100
                                                                                           interceptor:nil
                                                                                                writer:writer];
    NSURL *url = [NSURL URLWithString:@"https://urlconnection.example.test/delegate"];
    FTURLConnectionForwardingDelegate *applicationDelegate = [FTURLConnectionForwardingDelegate new];
    IMP cacheIMP = class_getMethodImplementation(applicationDelegate.class, @selector(connection:willCacheResponse:));
    IMP streamIMP = class_getMethodImplementation(applicationDelegate.class, @selector(connection:needNewBodyStream:));
    IMP authenticationIMP = class_getMethodImplementation(applicationDelegate.class, @selector(connection:willSendRequestForAuthenticationChallenge:));
    applicationDelegate.redirectResult = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/final"]];
    applicationDelegate.useCredentialStorage = YES;
    id preparation = [instrumentation prepareRequest:[NSURLRequest requestWithURL:url] delegate:applicationDelegate];
    id<NSURLConnectionDataDelegate> delegate = [preparation valueForKey:@"delegate"];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    XCTAssertEqual((id)delegate, applicationDelegate);
    XCTAssertEqual(object_getClass(delegate), FTURLConnectionForwardingDelegate.class);
    XCTAssertEqual(class_getMethodImplementation(object_getClass(delegate), @selector(connection:willCacheResponse:)), cacheIMP);
    XCTAssertEqual(class_getMethodImplementation(object_getClass(delegate), @selector(connection:needNewBodyStream:)), streamIMP);
    XCTAssertEqual(class_getMethodImplementation(object_getClass(delegate), @selector(connection:willSendRequestForAuthenticationChallenge:)), authenticationIMP);
    NSURLConnection *connection = (id)[FTURLConnectionCallbackConnection new];
    [FTURLConnectionInstrumentation associateHandler:handler withConnection:connection];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [instrumentation activateHandler:handler];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    NSCachedURLResponse *inputCache = [[NSCachedURLResponse alloc] initWithResponse:response data:[@"input" dataUsingEncoding:NSUTF8StringEncoding]];
    NSCachedURLResponse *outputCache = [[NSCachedURLResponse alloc] initWithResponse:response data:[@"output" dataUsingEncoding:NSUTF8StringEncoding]];
    applicationDelegate.cacheResult = outputCache;
    XCTAssertTrue([delegate respondsToSelector:@selector(connection:willCacheResponse:)]);
    XCTAssertEqual([delegate connection:connection willCacheResponse:inputCache], outputCache);
    XCTAssertTrue([delegate connectionShouldUseCredentialStorage:connection]);
    applicationDelegate.streamResult = [FTURLConnectionProbeInputStream new];
    XCTAssertEqual([delegate connection:connection needNewBodyStream:handler.request], applicationDelegate.streamResult);
    XCTAssertEqual(((FTURLConnectionProbeInputStream *)applicationDelegate.streamResult).readCount, 0u);
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:@"urlconnection.example.test" port:443 protocol:@"https" realm:nil authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
    NSURLAuthenticationChallenge *challenge = [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:space proposedCredential:nil previousFailureCount:0 failureResponse:nil error:nil sender:[FTURLConnectionChallengeSender new]];
    [delegate connection:connection willSendRequestForAuthenticationChallenge:challenge];
    XCTAssertEqual(applicationDelegate.lastChallenge, challenge);
    XCTAssertEqual(applicationDelegate.challengeCalls, 1u);

    NSURLRequest *redirectResult = [delegate connection:connection
                                     willSendRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/system-redirect"]]
                                    redirectResponse:response];
    XCTAssertEqualObjects(redirectResult.URL, applicationDelegate.redirectResult.URL);
    XCTAssertEqual(applicationDelegate.redirectCalls, 1u);

    __block NSThread *callbackThread;
    dispatch_queue_t callbackQueue = dispatch_queue_create("com.ft.urlconnection.callback-test", DISPATCH_QUEUE_SERIAL);
    dispatch_sync(callbackQueue, ^{
        callbackThread = NSThread.currentThread;
        [delegate connection:connection didReceiveResponse:response];
        [delegate connection:connection didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
    });
    XCTAssertEqual(applicationDelegate.lastCallbackThread, callbackThread);
    XCTAssertEqual(applicationDelegate.responseCalls, 1u);
    XCTAssertEqual(applicationDelegate.dataCalls, 1u);
    XCTAssertEqualObjects(applicationDelegate.lastData, [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);

    [delegate connectionDidFinishLoading:connection];
    [delegate connection:connection didReceiveData:[@"late" dataUsingEncoding:NSUTF8StringEncoding]];
    [delegate connection:connection didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
    [instrumentation syncProcess];
    XCTAssertEqual(applicationDelegate.finishCalls, 1u);
    XCTAssertEqual(applicationDelegate.failureCalls, 1u);
    XCTAssertEqual(applicationDelegate.dataCalls, 2u);
    XCTAssertEqual(writer.startCount, 1);
    XCTAssertEqual(writer.stopCount, 1);
    XCTAssertEqual(writer.addCount, 1);
    XCTAssertEqualObjects(writer.metrics.responseSize, @3);

    applicationDelegate.redirectResult = nil;
    XCTAssertNil([delegate connection:connection
                   willSendRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://other.example.test/cancel"]]
                  redirectResponse:response]);
    XCTAssertEqual(applicationDelegate.redirectCalls, 2u);
#pragma clang diagnostic pop
}

- (NSURLConnection *)callbackConnectionWithPreparation:(id)preparation {
    FTURLConnectionCallbackConnection *connection = [FTURLConnectionCallbackConnection new];
    connection.originalRequest = [preparation valueForKey:@"request"];
    [FTURLConnectionInstrumentation associateHandler:[preparation valueForKey:@"handler"] withConnection:(id)connection];
    return (id)connection;
}

- (void)testURLConnectionHooksAddDefaultsToOriginalClassWithoutChangingISA {
    NSString *name = [@"FTConnectionEmpty_" stringByAppendingString:[NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    Class originalClass = objc_allocateClassPair(NSObject.class, name.UTF8String, 0);
    objc_registerClassPair(originalClass);
    NSObject *delegate = [originalClass new];
    NSObject *untouched = [originalClass new];
    IMP classIMP = class_getMethodImplementation(originalClass, @selector(class));
    IMP respondsIMP = class_getMethodImplementation(originalClass, @selector(respondsToSelector:));
    __weak id weakDelegate = delegate;
    XCTAssertFalse([untouched respondsToSelector:@selector(connection:didReceiveData:)]);
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:delegate]);
    XCTAssertEqual(delegate.class, originalClass);
    XCTAssertEqual(object_getClass(delegate), originalClass);
    XCTAssertEqual(class_getSuperclass(originalClass), NSObject.class);
    XCTAssertEqual(class_getMethodImplementation(originalClass, @selector(class)), classIMP);
    XCTAssertEqual(class_getMethodImplementation(originalClass, @selector(respondsToSelector:)), respondsIMP);
    XCTAssertTrue([delegate respondsToSelector:@selector(connection:didReceiveData:)]);
    XCTAssertTrue([untouched respondsToSelector:@selector(connection:didReceiveData:)]);
    XCTAssertFalse([[NSObject new] respondsToSelector:@selector(connection:didReceiveData:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(connection:willCacheResponse:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(connectionShouldUseCredentialStorage:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(connection:willSendRequestForAuthenticationChallenge:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(connection:needNewBodyStream:)]);
    IMP dataIMP = class_getMethodImplementation(originalClass, @selector(connection:didReceiveData:));
    IMP redirectIMP = class_getMethodImplementation(originalClass, @selector(connection:willSendRequest:redirectResponse:));
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:delegate]);
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:untouched]);
    XCTAssertEqual(object_getClass(delegate), originalClass);
    XCTAssertEqual(class_getMethodImplementation(originalClass, @selector(connection:didReceiveData:)), dataIMP);
    XCTAssertEqual(class_getMethodImplementation(originalClass, @selector(connection:willSendRequest:redirectResponse:)), redirectIMP);
    // No handler means no Resource, no singleton creation, and pass-through redirect.
    [[FTURLConnectionInstrumentation existingInstance] shutDown];
    XCTAssertNil([FTURLConnectionInstrumentation existingInstance]);
    NSURLConnection *untracked = (id)[FTURLConnectionCallbackConnection new];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/untracked"]];
    id<NSURLConnectionDataDelegate> observer = (id)untouched;
    XCTAssertEqual([observer connection:untracked willSendRequest:request redirectResponse:nil], request);
    [observer connection:untracked didReceiveResponse:nil];
    [observer connection:untracked didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
    [observer connection:untracked didSendBodyData:3 totalBytesWritten:3 totalBytesExpectedToWrite:3];
    [observer connectionDidFinishLoading:untracked];
    [observer connection:untracked didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
    XCTAssertNil([FTURLConnectionInstrumentation existingInstance]);
    // The instrumentor must not retain application delegates.
    delegate = nil;
    XCTAssertNil(weakDelegate);
}

- (void)testURLConnectionHooksLeaveUnsupportedDelegatesUntouched {
    NSObject *rootDelegate = [NSObject new];
    XCTAssertFalse([FTURLConnectionDelegateInstrumentor instrumentDelegate:rootDelegate]);
    XCTAssertEqual(object_getClass(rootDelegate), NSObject.class);
    XCTAssertFalse([rootDelegate respondsToSelector:@selector(connection:didReceiveData:)]);
    FTURLConnectionDownloadOnlyDelegate *download = [FTURLConnectionDownloadOnlyDelegate new];
    Class downloadClass = object_getClass(download);
    XCTAssertFalse([FTURLConnectionDelegateInstrumentor instrumentDelegate:download]);
    XCTAssertEqual(object_getClass(download), downloadClass);
    XCTAssertFalse([download respondsToSelector:@selector(connectionDidFinishLoading:)]);
    FTURLSessionProxy *proxy = [[FTURLSessionProxy alloc] initWithSession:[FTURLConnectionForwardingDelegate new]];
    Class proxyClass = object_getClass(proxy);
    XCTAssertFalse([FTURLConnectionDelegateInstrumentor instrumentDelegate:proxy]);
    XCTAssertEqual(object_getClass(proxy), proxyClass);
}

- (void)testURLConnectionHooksDoNotShadowFastForwardedObservations {
    NSString *name = [@"FTConnectionForwarder_" stringByAppendingString:[NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    Class forwardingClass = objc_allocateClassPair(NSObject.class, name.UTF8String, 0);
    SEL dataSelector = @selector(connection:didReceiveData:);
    // Store the target on the instance, not in the process-lifetime IMP block.
    static char targetKey;
    class_addMethod(forwardingClass, @selector(forwardingTargetForSelector:), imp_implementationWithBlock(^id(id object, SEL selector) {
        return selector == dataSelector ? objc_getAssociatedObject(object, &targetKey) : nil;
    }), method_getTypeEncoding(class_getInstanceMethod(NSObject.class, @selector(forwardingTargetForSelector:))));
    objc_registerClassPair(forwardingClass);
    NSObject *delegate = [forwardingClass new];
    FTURLConnectionForwardingDelegate *target = [FTURLConnectionForwardingDelegate new];
    objc_setAssociatedObject(delegate, &targetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    XCTAssertFalse([delegate respondsToSelector:dataSelector]);
    XCTAssertFalse([FTURLConnectionDelegateInstrumentor instrumentDelegate:delegate]);
    XCTAssertEqual(object_getClass(delegate), forwardingClass);
    XCTAssertEqual(class_getInstanceMethod(forwardingClass, dataSelector), NULL);
    XCTAssertEqual(class_getInstanceMethod(forwardingClass, @selector(connection:didFailWithError:)), NULL);
    NSData *data = [@"forwarded" dataUsingEncoding:NSUTF8StringEncoding];
    [(id<NSURLConnectionDataDelegate>)delegate connection:(id)[FTURLConnectionCallbackConnection new] didReceiveData:data];
    XCTAssertEqual(target.dataCalls, 1u);
    XCTAssertEqual(target.lastData, data);
}

- (void)testURLConnectionCocosStyleDelegateAddsOnlyMissingCallbacksAndRegistersIdempotently {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // A fresh class isolates method installation from other test registrations.
    NSString *name = [@"FTCocosStyle_" stringByAppendingString:[NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    Class originalClass = objc_allocateClassPair(FTURLConnectionCocosStyleDelegate.class, name.UTF8String, 0);
    objc_registerClassPair(originalClass);
    FTURLConnectionCocosStyleDelegate *delegate = [originalClass new];
    FTURLConnectionCocosStyleDelegate *secondDelegate = [originalClass new];
    FTURLConnectionCocosStyleDelegate *untouched = [originalClass new];
    id originalPointer = delegate;
    SEL redirect = @selector(connection:willSendRequest:redirectResponse:);
    SEL upload = @selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:);
    SEL authentication = @selector(connection:willSendRequestForAuthenticationChallenge:);
    IMP originalAuthentication = class_getMethodImplementation(originalClass, authentication);
    IMP originalClassIMP = class_getMethodImplementation(originalClass, @selector(class));
    IMP originalRespondsIMP = class_getMethodImplementation(originalClass, @selector(respondsToSelector:));
    XCTAssertFalse([delegate respondsToSelector:redirect]);
    XCTAssertFalse([delegate respondsToSelector:upload]);

    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES trace:NO link:YES sampleRate:100 interceptor:nil writer:writer];
    FTURLConnectionDelegateTestClock *clock = [FTURLConnectionDelegateTestClock new];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
    clock.currentContinuousTime = 1000000000;
    [instrumentation setValue:clock forKey:@"clock"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://cocos-style.example.test/start"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [@"request-body" dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"123" forHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID];
    [request setValue:@"456" forHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID];
    id preparation = [instrumentation prepareRequest:request delegate:delegate];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    NSURLConnection *connection = [self callbackConnectionWithPreparation:preparation];
    XCTAssertEqual([preparation valueForKey:@"delegate"], originalPointer);
    XCTAssertEqual(delegate.class, originalClass);
    Class installedClass = object_getClass(delegate);
    XCTAssertEqual(installedClass, originalClass);
    XCTAssertEqual(class_getSuperclass(installedClass), FTURLConnectionCocosStyleDelegate.class);
    XCTAssertEqual(class_getInstanceSize(installedClass), class_getInstanceSize(originalClass));
    XCTAssertEqual(class_getMethodImplementation(installedClass, @selector(class)), originalClassIMP);
    XCTAssertEqual(class_getMethodImplementation(installedClass, @selector(respondsToSelector:)), originalRespondsIMP);
    XCTAssertEqual(class_getMethodImplementation(installedClass, authentication), originalAuthentication);
    XCTAssertTrue([delegate respondsToSelector:redirect]);
    XCTAssertTrue([delegate respondsToSelector:upload]);
    XCTAssertTrue([untouched respondsToSelector:redirect]);
    XCTAssertTrue([untouched respondsToSelector:upload]);

    // The same class is shared by all instances; registering any of them again
    // must keep every previously installed IMP.
    IMP registeredDataIMP = class_getMethodImplementation(installedClass, @selector(connection:didReceiveData:));
    IMP registeredRedirectIMP = class_getMethodImplementation(installedClass, redirect);
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:delegate]);
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:secondDelegate]);
    XCTAssertEqual(object_getClass(secondDelegate), installedClass);
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:secondDelegate]);
    XCTAssertEqual(object_getClass(delegate), installedClass);
    XCTAssertEqual(class_getMethodImplementation(installedClass, @selector(connection:didReceiveData:)), registeredDataIMP);
    XCTAssertEqual(class_getMethodImplementation(installedClass, redirect), registeredRedirectIMP);
    unsigned int count = 0;
    Method *methods = class_copyMethodList(installedClass, &count);
    NSMutableSet *ownSelectors = [NSMutableSet set];
    for (unsigned int index = 0; index < count; index++) {
        [ownSelectors addObject:NSStringFromSelector(method_getName(methods[index]))];
    }
    free(methods);
    XCTAssertEqualObjects(ownSelectors, ([NSSet setWithArray:@[NSStringFromSelector(redirect), NSStringFromSelector(upload), @"connection:didReceiveData:", @"connection:didReceiveResponse:", @"connection:didFailWithError:", @"connectionDidFinishLoading:"]]));
    XCTAssertFalse([delegate respondsToSelector:@selector(connection:willCacheResponse:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(connection:needNewBodyStream:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(connectionShouldUseCredentialStorage:)]);

    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:request.URL.host port:443 protocol:@"https" realm:nil authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
    NSURLAuthenticationChallenge *challenge = [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:space proposedCredential:nil previousFailureCount:0 failureResponse:nil error:nil sender:[FTURLConnectionChallengeSender new]];
    [delegate connection:connection willSendRequestForAuthenticationChallenge:challenge];
    XCTAssertEqual(delegate.challenge, challenge);
    XCTAssertEqual(delegate.challengeCalls, 1u);
    XCTAssertTrue([handler recordStartWithDate:clock.currentDate continuousTime:clock.currentContinuousTime]);
    [instrumentation activateHandler:handler];
    NSMutableURLRequest *redirectRequest = [[preparation valueForKey:@"request"] mutableCopy];
    redirectRequest.URL = [NSURL URLWithString:@"https://cocos-style.example.test/final"];
    NSURLRequest *effectiveRedirect = [(id<NSURLConnectionDataDelegate>)delegate connection:connection willSendRequest:redirectRequest redirectResponse:nil];
    XCTAssertEqualObjects(effectiveRedirect.URL, redirectRequest.URL);
    XCTAssertEqualObjects([effectiveRedirect valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID], @"123");
    XCTAssertEqualObjects([effectiveRedirect valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID], @"456");
    [(id<NSURLConnectionDataDelegate>)delegate connection:connection didSendBodyData:9 totalBytesWritten:9 totalBytesExpectedToWrite:9];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:redirectRequest.URL statusCode:201 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Length": @"999"}];
    NSData *lastChunk = [@"defgh" dataUsingEncoding:NSUTF8StringEncoding];
    delegate.onFinish = ^{
        // Business callback work is outside the terminal timestamp, no sleeps.
        clock.currentContinuousTime = 9000000000;
    };
    __block NSThread *callbackThread;
    dispatch_sync(dispatch_queue_create("com.ft.urlconnection.cocos-shape", DISPATCH_QUEUE_SERIAL), ^{
        callbackThread = NSThread.currentThread;
        [delegate connection:connection didReceiveResponse:response];
        [delegate connection:connection didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
        [delegate connection:connection didReceiveData:lastChunk];
        clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000002.5];
        clock.currentContinuousTime = 3500000000;
        [delegate connectionDidFinishLoading:connection];
    });
    [instrumentation syncProcess];
    XCTAssertEqual(delegate.callbackThread, callbackThread);
    XCTAssertEqual(delegate.response, response);
    XCTAssertEqual(delegate.lastData, lastChunk);
    XCTAssertEqual(delegate.responseCalls, 1u);
    XCTAssertEqual(delegate.dataCalls, 2u);
    XCTAssertEqual(delegate.finishCalls, 1u);
    XCTAssertEqual(delegate.failureCalls, 0u);
    XCTAssertEqual(writer.startCount, 1);
    XCTAssertEqual(writer.stopCount, 1);
    XCTAssertEqual(writer.addCount, 1);
    XCTAssertEqualObjects(writer.startKey, handler.identifier);
    XCTAssertEqualObjects(writer.stopKey, handler.identifier);
    XCTAssertEqualObjects(writer.addKey, handler.identifier);
    XCTAssertEqualObjects(writer.metrics.responseSize, @8);
    XCTAssertEqualObjects(writer.metrics.requestSize, @9);
    XCTAssertEqual(writer.metrics.fetchStartNsTimeInterval, 1700000000000000000LL);
    XCTAssertEqual(writer.metrics.fetchEndNsTimeInterval, 1700000002500000000LL);
    XCTAssertEqual(writer.metrics.fetchEndNsTimeInterval - writer.metrics.fetchStartNsTimeInterval, 2500000000LL);
    XCTAssertEqualObjects(writer.startDate, [NSDate dateWithTimeIntervalSince1970:1700000000]);
    XCTAssertEqualObjects(writer.stopDate, [NSDate dateWithTimeIntervalSince1970:1700000002.5]);
    XCTAssertEqualObjects(writer.traceID, @"123");
    XCTAssertEqualObjects(writer.spanID, @"456");
    // The class-wide defaults do not enroll another instance's untracked request.
    NSURLConnection *untracked = (id)[FTURLConnectionCallbackConnection new];
    [untouched connection:untracked didReceiveData:[@"untracked" dataUsingEncoding:NSUTF8StringEncoding]];
    [untouched connectionDidFinishLoading:untracked];
    [instrumentation syncProcess];
    XCTAssertEqual(untouched.dataCalls, 1u);
    XCTAssertEqual(untouched.finishCalls, 1u);
    XCTAssertEqual(writer.addCount, 1);
    XCTAssertEqualObjects(writer.metrics.responseSize, @8);
    [instrumentation shutDown];
#pragma clang diagnostic pop
}

- (void)testURLConnectionRedirectHookObservesOnlyTheFinalSuperclassReturn {
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES trace:YES link:YES sampleRate:100 interceptor:nil writer:writer];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/start"]];
    [request setValue:@"123" forHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID];
    [request setValue:@"456" forHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID];
    FTURLConnectionForwardingDelegate *parent = [FTURLConnectionForwardingDelegate new];
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:parent]);
    FTURLConnectionRedirectChildDelegate *delegate = [FTURLConnectionRedirectChildDelegate new];
    NSMutableURLRequest *intermediate = [request mutableCopy];
    intermediate.URL = [NSURL URLWithString:@"https://other.example.test/intermediate"];
    delegate.redirectResult = intermediate;
    delegate.finalURL = [NSURL URLWithString:@"https://urlconnection.example.test/final"];
    id preparation = [instrumentation prepareRequest:request delegate:delegate];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    NSURLConnection *connection = [self callbackConnectionWithPreparation:preparation];
    NSURLRequest *result = [delegate connection:connection willSendRequest:request redirectResponse:nil];
    XCTAssertEqualObjects(result.URL, delegate.finalURL);
    XCTAssertEqualObjects(handler.request.URL, delegate.finalURL);
    // Observing the intermediate parent return would incorrectly clear linking.
    XCTAssertEqualObjects(handler.traceID, @"123");
    XCTAssertEqualObjects(handler.spanID, @"456");
    XCTAssertEqualObjects([result valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID], @"123");
    XCTAssertEqualObjects([result valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID], @"456");
    XCTAssertEqual(delegate.redirectCalls, 1u);
    delegate.rejectsRedirect = YES;
    XCTAssertNil([delegate connection:connection willSendRequest:request redirectResponse:nil]);
    XCTAssertEqual(delegate.redirectCalls, 2u);
    XCTAssertEqualObjects(handler.request.URL, delegate.finalURL);
    [instrumentation shutDown];
}

- (void)checkURLConnectionSuperclassHooksParentFirst:(BOOL)parentFirst callsSuper:(BOOL)callsSuper overridesData:(BOOL)overridesData {
    // Fresh classes ensure each registration order is really exercised, even
    // when XCTest repeats this test in the same process.
    NSString *suffix = [NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    Class parent = objc_allocateClassPair(NSObject.class, [@"FTConnectionParent_" stringByAppendingString:suffix].UTF8String, 0);
    SEL selector = @selector(connection:didReceiveData:);
    const char *encoding = method_getTypeEncoding(class_getInstanceMethod(FTURLConnectionDelegate.class, selector));
    __block NSUInteger parentCalls = 0;
    __block NSUInteger childCalls = 0;
    class_addMethod(parent, selector, imp_implementationWithBlock(^(id object, NSURLConnection *connection, NSData *data) {
        parentCalls += 1;
    }), encoding);
    objc_registerClassPair(parent);
    Class child = objc_allocateClassPair(parent, [@"FTConnectionChild_" stringByAppendingString:suffix].UTF8String, 0);
    if (overridesData) {
        class_addMethod(child, selector, imp_implementationWithBlock(^(id object, NSURLConnection *connection, NSData *data) {
            childCalls += 1;
            if (callsSuper) {
                IMP parentIMP = method_getImplementation(class_getInstanceMethod(parent, selector));
                ((void (*)(id, SEL, NSURLConnection *, NSData *))parentIMP)(object, selector, connection, data);
            }
        }), encoding);
    }
    objc_registerClassPair(child);
    id parentDelegate = [parent new];
    id childDelegate = [child new];
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:parentFirst ? parentDelegate : childDelegate]);
    XCTAssertTrue([FTURLConnectionDelegateInstrumentor instrumentDelegate:parentFirst ? childDelegate : parentDelegate]);

    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES trace:NO link:NO sampleRate:100 interceptor:nil writer:writer];
    FTURLConnectionDelegateTestClock *clock = [FTURLConnectionDelegateTestClock new];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000002];
    clock.currentContinuousTime = 3000000000;
    [instrumentation setValue:clock forKey:@"clock"];
    id preparation = [instrumentation prepareRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/hierarchy"]] delegate:childDelegate];
    XCTAssertEqual([preparation valueForKey:@"delegate"], childDelegate);
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    NSURLConnection *connection = [self callbackConnectionWithPreparation:preparation];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:1000000000];
    [instrumentation activateHandler:handler];
    [(id<NSURLConnectionDataDelegate>)childDelegate connection:connection didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
    [(id<NSURLConnectionDataDelegate>)childDelegate connection:connection didReceiveData:[@"defgh" dataUsingEncoding:NSUTF8StringEncoding]];
    [(id<NSURLConnectionDataDelegate>)childDelegate connectionDidFinishLoading:connection];
    [instrumentation syncProcess];
    XCTAssertEqual(childCalls, overridesData ? 2u : 0u);
    XCTAssertEqual(parentCalls, !overridesData || callsSuper ? 2u : 0u);
    XCTAssertEqualObjects(writer.metrics.responseSize, @8);
    XCTAssertEqualObjects(writer.metrics.fetchInterval, @2000000000LL);
    XCTAssertEqualObjects(writer.addKey, handler.identifier);
    XCTAssertEqual(writer.startCount, 1);
    XCTAssertEqual(writer.stopCount, 1);
    XCTAssertEqual(writer.addCount, 1);
    [instrumentation shutDown];
}

- (void)testURLConnectionSuperclassHooksObserveExactlyOnceInBothRegistrationOrders {
    for (NSNumber *parentFirst in @[@YES, @NO]) {
        for (NSNumber *callsSuper in @[@YES, @NO]) {
            [self checkURLConnectionSuperclassHooksParentFirst:parentFirst.boolValue callsSuper:callsSuper.boolValue overridesData:YES];
        }
        [self checkURLConnectionSuperclassHooksParentFirst:parentFirst.boolValue callsSuper:NO overridesData:NO];
    }
}

- (void)testURLConnectionHooksKeepConcurrentSameDelegateRequestsSeparate {
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES trace:NO link:NO sampleRate:100 interceptor:nil writer:writer];
    FTURLConnectionDelegateTestClock *clock = [FTURLConnectionDelegateTestClock new];
    [instrumentation setValue:clock forKey:@"clock"];
    FTURLConnectionForwardingDelegate *delegate = [FTURLConnectionForwardingDelegate new];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/same-url"]];
    id first = [instrumentation prepareRequest:request delegate:delegate];
    id second = [instrumentation prepareRequest:request delegate:delegate];
    XCTAssertEqual([first valueForKey:@"delegate"], delegate);
    XCTAssertEqual([second valueForKey:@"delegate"], delegate);
    FTURLConnectionHandler *firstHandler = [first valueForKey:@"handler"];
    FTURLConnectionHandler *secondHandler = [second valueForKey:@"handler"];
    XCTAssertNotEqualObjects(firstHandler.identifier, secondHandler.identifier);
    NSURLConnection *firstConnection = [self callbackConnectionWithPreparation:first];
    NSURLConnection *secondConnection = [self callbackConnectionWithPreparation:second];
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1700000000];
    [firstHandler recordStartWithDate:start continuousTime:1000000000];
    [secondHandler recordStartWithDate:start continuousTime:1000000000];
    [instrumentation activateHandler:firstHandler];
    [instrumentation activateHandler:secondHandler];
    [delegate connection:firstConnection didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
    [delegate connection:secondConnection didReceiveData:[@"1234567" dataUsingEncoding:NSUTF8StringEncoding]];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000001];
    clock.currentContinuousTime = 2000000000;
    [delegate connectionDidFinishLoading:firstConnection];
    [instrumentation syncProcess];
    XCTAssertEqualObjects(writer.addKey, firstHandler.identifier);
    XCTAssertEqualObjects(writer.metrics.responseSize, @3);
    XCTAssertEqualObjects(writer.metrics.fetchInterval, @1000000000LL);
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000002];
    clock.currentContinuousTime = 3000000000;
    [delegate connectionDidFinishLoading:secondConnection];
    [delegate connectionDidFinishLoading:firstConnection];
    [delegate connection:firstConnection didReceiveData:[@"late" dataUsingEncoding:NSUTF8StringEncoding]];
    [instrumentation syncProcess];
    XCTAssertEqualObjects(writer.addKey, secondHandler.identifier);
    XCTAssertEqualObjects(writer.metrics.responseSize, @7);
    XCTAssertEqualObjects(writer.metrics.fetchInterval, @2000000000LL);
    XCTAssertEqual(writer.startCount, 2);
    XCTAssertEqual(writer.stopCount, 2);
    XCTAssertEqual(writer.addCount, 2);
    XCTAssertEqual(delegate.dataCalls, 3u); // Late business callbacks are not suppressed.
    XCTAssertEqual(delegate.finishCalls, 3u);
    [instrumentation shutDown];
    [delegate connection:secondConnection didReceiveData:[@"after-shutdown" dataUsingEncoding:NSUTF8StringEncoding]];
    [delegate connectionDidFinishLoading:secondConnection];
    [instrumentation syncProcess];
    XCTAssertEqual(delegate.dataCalls, 4u);
    XCTAssertEqual(delegate.finishCalls, 4u);
    XCTAssertEqual(writer.addCount, 2);
}

- (void)testURLConnectionHookScopeRestoresAfterBusinessExceptionAndIsolatesObserverException {
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *instrumentation = [self urlConnectionInstrumentationWithResource:YES trace:NO link:NO sampleRate:100 interceptor:nil writer:writer];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/exception"]];
    FTURLConnectionThrowingDelegate *delegate = [FTURLConnectionThrowingDelegate new];
    id preparation = [instrumentation prepareRequest:request delegate:delegate];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    NSURLConnection *connection = [self callbackConnectionWithPreparation:preparation];
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:1000000000];
    [instrumentation activateHandler:handler];
    delegate.throwsOnData = YES;
    XCTAssertThrowsSpecificNamed([delegate connection:connection didReceiveData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]], NSException, @"FTBusinessException");
    delegate.throwsOnData = NO;
    [delegate connection:connection didReceiveData:[@"de" dataUsingEncoding:NSUTF8StringEncoding]];
    [delegate connectionDidFinishLoading:connection];
    [instrumentation syncProcess];
    XCTAssertEqualObjects(writer.metrics.responseSize, @5);
    XCTAssertEqual(delegate.dataCalls, 1u);

    FTURLConnectionThrowingHandler *throwingHandler = [[FTURLConnectionThrowingHandler alloc] initWithRequest:request resourceEnabled:YES provider:nil errorFilter:nil rumResourceHandler:writer];
    throwingHandler.instrumentation = instrumentation;
    throwingHandler.generation = handler.generation;
    [FTURLConnectionInstrumentation associateHandler:throwingHandler withConnection:connection];
    XCTAssertNoThrow([delegate connection:connection didReceiveData:[@"x" dataUsingEncoding:NSUTF8StringEncoding]]);
    XCTAssertEqual(delegate.dataCalls, 2u);
    [instrumentation shutDown];
}

- (void)testURLConnectionPreparationResolvesEarlyReturnedInstanceOnlyByExactUUID {
    // The real initializer/factory entry-point tests complement this isolated
    // ownership test; this is not a substitute for running Foundation/ARC tests.
    [[FTURLConnectionInstrumentation existingInstance] shutDown];
    FTURLConnectionInstrumentation *instrumentation = [FTURLConnectionInstrumentation sharedInstance];
    FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
    [instrumentation setRumResourceHandler:writer];
    [instrumentation setEnableAutoRumResource:YES resourceUrlHandler:nil resourcePropertyProvider:nil sessionTaskErrorFilter:nil];
    FTURLConnectionDelegateTestClock *clock = [FTURLConnectionDelegateTestClock new];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000002];
    clock.currentContinuousTime = 3000000000;
    [instrumentation setValue:clock forKey:@"clock"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/early"]];
    id preparation = [instrumentation prepareRequest:request delegate:nil];
    FTURLConnectionHandler *handler = [preparation valueForKey:@"handler"];
    id<NSURLConnectionDataDelegate> delegate = [preparation valueForKey:@"delegate"];
    FTURLConnectionCallbackConnection *returnedConnection = [FTURLConnectionCallbackConnection new];
    returnedConnection.originalRequest = [preparation valueForKey:@"request"];
    FTURLConnectionCallbackConnection *untrackedConnection = [FTURLConnectionCallbackConnection new];
    untrackedConnection.originalRequest = request; // Same URL is deliberately insufficient.
    XCTAssertNil([FTURLConnectionInstrumentation handlerForConnection:(id)untrackedConnection]);
    [handler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:1000000000];
    [delegate connection:(id)returnedConnection didReceiveData:[@"early" dataUsingEncoding:NSUTF8StringEncoding]];
    [delegate connectionDidFinishLoading:(id)returnedConnection];
    [instrumentation syncProcess];
    XCTAssertEqual(writer.startCount, 0); // No Resource until init has returned non-nil.
    XCTAssertEqual(writer.addCount, 0);
    [instrumentation finishPreparingHandler:handler];
    [instrumentation activateHandler:handler];
    [instrumentation syncProcess];
    XCTAssertEqualObjects(writer.metrics.responseSize, @5);
    XCTAssertEqualObjects(writer.metrics.fetchInterval, @2000000000LL);
    XCTAssertEqualObjects(writer.addKey, handler.identifier);
    XCTAssertEqual(writer.addCount, 1);
    FTURLConnectionCallbackConnection *lateCopy = [FTURLConnectionCallbackConnection new];
    lateCopy.originalRequest = returnedConnection.originalRequest;
    XCTAssertNil([FTURLConnectionInstrumentation handlerForConnection:(id)lateCopy]);
    [instrumentation shutDown];
    [delegate connectionDidFinishLoading:(id)returnedConnection];
    XCTAssertNil([FTURLConnectionInstrumentation existingInstance]);
    XCTAssertEqual(writer.addCount, 1);
}

- (void)testURLConnectionLateTerminalAfterShutdownCannotEnterRestartedGeneration {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://urlconnection.example.test/generation"]];
    FTURLSessionSnapshotRumResourceHandler *oldWriter = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *oldInstrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                     trace:NO
                                                                                                      link:NO
                                                                                                sampleRate:100
                                                                                               interceptor:nil
                                                                                                    writer:oldWriter];
    id oldPreparation = [oldInstrumentation prepareRequest:request delegate:nil];
    FTURLConnectionHandler *oldHandler = [oldPreparation valueForKey:@"handler"];
    [oldHandler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000000] continuousTime:100];
    [oldInstrumentation activateHandler:oldHandler];
    [oldInstrumentation syncProcess];
    XCTAssertEqual(oldWriter.startCount, 1);
    [oldInstrumentation shutDown];

    FTURLSessionSnapshotRumResourceHandler *newWriter = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLConnectionInstrumentation *newInstrumentation = [self urlConnectionInstrumentationWithResource:YES
                                                                                                     trace:NO
                                                                                                      link:NO
                                                                                                sampleRate:100
                                                                                               interceptor:nil
                                                                                                    writer:newWriter];
    id newPreparation = [newInstrumentation prepareRequest:request delegate:nil];
    FTURLConnectionHandler *newHandler = [newPreparation valueForKey:@"handler"];
    [newHandler recordStartWithDate:[NSDate dateWithTimeIntervalSince1970:1700000010] continuousTime:1000];
    [newInstrumentation activateHandler:newHandler];
    [newInstrumentation handler:newHandler didReachTerminalWithResponse:nil error:nil];
    [newInstrumentation syncProcess];

    [oldInstrumentation handler:oldHandler
     didReachTerminalWithResponse:nil
                           error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
    [oldInstrumentation syncProcess];
    XCTAssertEqual(oldWriter.stopCount, 0);
    XCTAssertEqual(oldWriter.addCount, 0);
    XCTAssertEqual(newWriter.startCount, 1);
    XCTAssertEqual(newWriter.stopCount, 1);
    XCTAssertEqual(newWriter.addCount, 1);
}


- (void)testURLConnectionMetricsDoNotFallBackToHeadersOrInventPhases {
    [FTModelHelper startViewWithName:@"URLConnectionFields"];
    NSURL *url = [NSURL URLWithString:@"https://urlconnection.example.test/rum-fields"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"777" forHTTPHeaderField:@"Content-Length"];
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
    FTURLConnectionHandler *handler = [self urlConnectionHandlerWithRequest:request provider:nil errorFilter:nil writer:rumManager];
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{@"Content-Length": @"999"}];
    [handler recordStartWithDate:startDate continuousTime:1000000000];
    [handler activate];
    [handler didReceiveResponse:response];
    [handler didReceiveData:[NSMutableData dataWithLength:4]];
    [handler recordTerminalWithResponse:nil error:nil date:[NSDate dateWithTimeIntervalSince1970:1700000003] continuousTime:4000000000];
    [handler reportTerminalIfNeeded];
    [rumManager syncProcess];

    __block NSUInteger count = 0;
    [FTModelHelper resolveModelArray:[[FTTrackerEventDBTool sharedManager] getAllDatas]
                         timeCallBack:^(NSString *source, NSDictionary *tags, NSDictionary *fields, long long time, BOOL *stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && [tags[FT_KEY_RESOURCE_URL] isEqualToString:url.absoluteString]) {
            count += 1;
            XCTAssertEqual(time, 1700000000000000000LL);
            XCTAssertEqualObjects(fields[FT_DURATION], @3000000000LL);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_SIZE], @4);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_REQUEST_SIZE], @0);
            XCTAssertNil(fields[FT_KEY_RESOURCE_CONNECTION_REUSE]);
            XCTAssertNil(fields[FT_KEY_RESOURCE_DNS]);
            XCTAssertNil(fields[FT_KEY_RESOURCE_TCP]);
            XCTAssertNil(fields[FT_KEY_RESOURCE_SSL]);
            XCTAssertNil(fields[FT_KEY_RESOURCE_TTFB]);
        }
    }];
    XCTAssertEqual(count, 1u);
}

- (void)testURLSessionRequestSnapshotCapturesStableRequestAttributes {
    NSURL *url = [NSURL URLWithString:@"https://snapshot.example.com/direct"];
    NSMutableData *body = [[@"body" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = body;
    [request setValue:@"start" forHTTPHeaderField:@"X-Snapshot"];
    NSData *requestBody = request.HTTPBody;

    FTURLSessionRequestSnapshot *snapshot = [FTURLSessionRequestSnapshot snapshotWithRequest:request];
    [request setValue:@"mutated" forHTTPHeaderField:@"X-Snapshot"];
    request.HTTPMethod = @"GET";

    XCTAssertEqualObjects(snapshot.URL, url);
    XCTAssertEqualObjects(snapshot.HTTPMethod, @"PUT");
    XCTAssertEqualObjects(snapshot.allHTTPHeaderFields[@"X-Snapshot"], @"start");
    XCTAssertEqualObjects(snapshot.request.URL, url);
    XCTAssertEqualObjects(snapshot.request.HTTPMethod, @"PUT");
    XCTAssertEqualObjects(snapshot.request.allHTTPHeaderFields[@"X-Snapshot"], @"start");
    XCTAssertTrue(snapshot.HTTPBody == requestBody);
}
- (void)testInterceptTaskStoresCurrentRequestSnapshot {
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURL *url = [NSURL URLWithString:@"https://snapshot.example.com/start"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [@"initial-body" dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"start" forHTTPHeaderField:@"X-Snapshot"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    [[FTURLSessionInterceptor shared] interceptTask:task];

    NSMutableURLRequest *mutatedRequest = [NSMutableURLRequest requestWithURL:url];
    mutatedRequest.HTTPMethod = @"GET";
    mutatedRequest.HTTPBody = [@"mutated-body" dataUsingEncoding:NSUTF8StringEncoding];
    [mutatedRequest setValue:@"mutated" forHTTPHeaderField:@"X-Snapshot"];
    [task setValue:mutatedRequest forKey:@"currentRequest"];

    [self waitForURLSessionInterceptorQueue];
    FTSessionTaskHandler *handler = [[FTURLSessionInterceptor shared] getTraceHandler:task];

    XCTAssertEqualObjects(handler.request.allHTTPHeaderFields[@"X-Snapshot"], @"start");
    XCTAssertEqualObjects(handler.request.HTTPMethod, @"POST");
    XCTAssertEqualObjects([[NSString alloc] initWithData:handler.request.HTTPBody encoding:NSUTF8StringEncoding], @"initial-body");

    [task cancel];
    [session invalidateAndCancel];
}
- (void)testTaskCompletedUsesStartRequestSnapshotForTraceHeader {
    FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
    FTURLSessionSnapshotRumResourceHandler *rumResourceHandler = [FTURLSessionSnapshotRumResourceHandler new];
    FTURLSessionSnapshotTracer *tracer = [FTURLSessionSnapshotTracer new];
    tracer.enableLinkRumData = YES;
    interceptor.rumResourceHandler = rumResourceHandler;
    [interceptor setTracer:tracer];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURL *url = [NSURL URLWithString:@"https://snapshot.example.com/complete"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"start" forHTTPHeaderField:@"X-Snapshot"];
    [request setValue:@"start-trace" forHTTPHeaderField:@"x-trace-id"];
    [request setValue:@"start-span" forHTTPHeaderField:@"x-span-id"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    [interceptor interceptTask:task];
    [self waitForURLSessionInterceptorQueue];

    NSMutableURLRequest *mutatedRequest = [NSMutableURLRequest requestWithURL:url];
    [mutatedRequest setValue:@"mutated" forHTTPHeaderField:@"X-Snapshot"];
    [mutatedRequest setValue:@"mutated-trace" forHTTPHeaderField:@"x-trace-id"];
    [mutatedRequest setValue:@"mutated-span" forHTTPHeaderField:@"x-span-id"];
    [task setValue:mutatedRequest forKey:@"currentRequest"];

    __block NSURLRequest *providerRequest;
    [interceptor taskCompleted:task error:nil extraProvider:^NSDictionary * _Nullable(NSURLRequest * _Nullable request, NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error) {
        providerRequest = request;
        return @{};
    }];
    [self waitForURLSessionInterceptorQueue];

    XCTAssertEqualObjects(providerRequest.allHTTPHeaderFields[@"X-Snapshot"], @"start");
    XCTAssertEqualObjects(rumResourceHandler.content.requestHeader[@"X-Snapshot"], @"start");
    XCTAssertEqualObjects(tracer.lastUnpackedHeader[@"x-trace-id"], @"start-trace");
    XCTAssertEqualObjects(rumResourceHandler.traceID, @"start-trace");
    XCTAssertEqualObjects(rumResourceHandler.spanID, @"start-span");

    [task cancel];
    [session invalidateAndCancel];
}

- (void)assertWebSocketFinalizationWithStatus:(NSInteger)status error:(NSError *)error taskState:(NSURLSessionTaskState)taskState expectedState:(NSString *)expectedState customDelegate:(BOOL)customDelegate {
    if (@available(iOS 13.0, *)) {
        FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
        FTURLSessionSnapshotRumResourceHandler *writer = [FTURLSessionSnapshotRumResourceHandler new];
        interceptor.rumResourceHandler = writer;
        FTWebSocketLegacyForwardingDelegate *delegate = [FTWebSocketLegacyForwardingDelegate new];
        delegate.ftURLSessionDelegate = [FTURLSessionDelegate new];
        FTDURLSessionDelegate *automaticDelegate = [FTDURLSessionDelegate new];
        NSURLSession *session = [NSURLSession sharedSession];
        __block NSInteger providerCalls = 0;
        __block NSInteger filterCalls = 0;
        ResourcePropertyProvider provider = ^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *filteredError) {
            providerCalls++;
            XCTAssertNil(data);
            XCTAssertNil(filteredError);
            return @{@"resource_provider": @YES};
        };
        SessionTaskErrorFilter filter = ^BOOL(NSError *receivedError) {
            filterCalls++;
            XCTAssertEqual(receivedError, error);
            return YES;
        };
        if (customDelegate) {
            delegate.ftURLSessionDelegate.provider = provider;
            delegate.ftURLSessionDelegate.errorFilter = filter;
        } else {
            interceptor.resourcePropertyProvider = provider;
            interceptor.sessionTaskErrorFilter = filter;
        }
        FTWebSocketMetricsTestTask *snapshot = [FTWebSocketMetricsTestTask new];
        snapshot.currentRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"wss://websocket.example.com/legacy"]];
        snapshot.response = status > 0 ? [[NSHTTPURLResponse alloc] initWithURL:snapshot.currentRequest.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil] : nil;
        snapshot.error = error;
        snapshot.state = taskState;
        NSURLSessionTask *task = (id)snapshot;
        [interceptor interceptTask:task];
        [self waitForURLSessionInterceptorQueue];
        FTWebSocketTestTaskMetrics *metrics = [FTWebSocketTestTaskMetrics new];
        if (customDelegate) {
            XCTAssertFalse([delegate respondsToSelector:@selector(URLSession:webSocketTask:didOpenWithProtocol:)]);
            [delegate URLSession:session task:task didFinishCollectingMetrics:metrics];
        } else {
            [automaticDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
        }
        [self waitForURLSessionInterceptorQueue];
        // Automatic collection must retain metrics without inferring handshake success.
        // Only legacy forwarding may finish success before an open/completion callback.
        if (!customDelegate || error) {
            XCTAssertEqual(writer.addCount, 0);
            XCTAssertEqual(writer.stopCount, 0);
            XCTAssertEqual(providerCalls, 0);
            XCTAssertEqual(filterCalls, 0);
            FTSessionTaskHandler *handler = [interceptor getTraceHandler:task];
            XCTAssertNotNil(handler);
            XCTAssertEqual(handler.metricsModel.fetchEndNsTimeInterval - handler.metricsModel.fetchStartNsTimeInterval, 4000000000);
        }
        if (error) {
            if (customDelegate) {
                [delegate URLSession:session task:task didCompleteWithError:error];
            } else {
                [automaticDelegate URLSession:session task:task didCompleteWithError:error];
            }
        } else if (!customDelegate) {
            [automaticDelegate URLSession:session webSocketTask:task didOpenWithProtocol:nil];
        }
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqual(writer.addCount, 1);
        XCTAssertEqual(writer.stopCount, 1);
        XCTAssertNil([interceptor getTraceHandler:task]);
        XCTAssertEqualObjects(writer.content.webSocketHandshakeState, expectedState);
        XCTAssertEqual(writer.content.httpStatusCode, status);
        XCTAssertEqual(writer.metrics.fetchEndNsTimeInterval - writer.metrics.fetchStartNsTimeInterval, 4000000000);
        XCTAssertEqual(providerCalls, 1);
        XCTAssertEqual(filterCalls, error ? 1 : 0);
        XCTAssertEqualObjects(writer.stopProperty[@"resource_provider"], @YES);
        XCTAssertNil(writer.content.error);
        [automaticDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
        [automaticDelegate URLSession:session webSocketTask:task didOpenWithProtocol:nil];
        [automaticDelegate URLSession:session task:task didCompleteWithError:error];
        [delegate URLSession:session task:task didCompleteWithError:error];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqual(writer.addCount, 1);
        XCTAssertEqual(writer.stopCount, 1);
        XCTAssertEqual(providerCalls, 1);
        XCTAssertEqual(filterCalls, error ? 1 : 0);
    }
}
- (void)testWebSocketLegacyForwardingCompletesSuccessFromMetrics {
    [self assertWebSocketFinalizationWithStatus:101 error:nil taskState:NSURLSessionTaskStateRunning expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS customDelegate:YES];
}
- (void)testWebSocketLegacyForwardingPreservesUpgradeValidationFailure {
    [self assertWebSocketFinalizationWithStatus:101 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil] taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED customDelegate:YES];
}
- (void)testWebSocketLegacyForwardingUsesCompletionForRejection {
    [self assertWebSocketFinalizationWithStatus:403 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil] taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED customDelegate:YES];
}
- (void)testWebSocketLegacyForwardingUsesCompletionForTransportFailure {
    [self assertWebSocketFinalizationWithStatus:0 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil] taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED customDelegate:YES];
}
- (void)testWebSocketAutomaticMetricsWaitsForOpen {
    [self assertWebSocketFinalizationWithStatus:101 error:nil taskState:NSURLSessionTaskStateRunning expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS customDelegate:NO];
}
- (void)testWebSocketAutomaticMetricsUsesCompletionForUpgradeValidationFailure {
    [self assertWebSocketFinalizationWithStatus:101 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil] taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED customDelegate:NO];
}
- (void)testWebSocketAutomaticMetricsUsesCompletionForRejection {
    [self assertWebSocketFinalizationWithStatus:403 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil] taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED customDelegate:NO];
}
- (void)testWebSocketNon101HTTPResponsesAreRejectedOutsideStandardStatusRange {
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil];
    // An exposed HTTP response that did not accept the handshake is a rejection,
    // regardless of whether its status belongs to the standard HTTP status range.
    for (NSNumber *status in @[@99, @600]) {
        for (NSNumber *customDelegate in @[@NO, @YES]) {
            [self assertWebSocketFinalizationWithStatus:status.integerValue error:error taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED customDelegate:customDelegate.boolValue];
        }
    }
}
- (void)testWebSocketAutomaticMetricsUsesCompletionForTransportFailure {
    [self assertWebSocketFinalizationWithStatus:0 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil] taskState:NSURLSessionTaskStateCompleted expectedState:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED customDelegate:NO];
}

- (void)testWebSocketResourceURLRestoresSchemesForAllCreationAPIs {
    if (@available(iOS 13.0, *)) {
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        for (NSString *scheme in @[@"ws", @"wss"]) {
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://websocket.example.com:8443/socket%%2Froom?token=a%%2Bb&room=one%%20two", scheme]];
            NSArray<NSURLSessionTask *> *tasks = @[
                [session webSocketTaskWithURL:url],
                [session webSocketTaskWithURL:url protocols:@[@"chat"]],
                [session webSocketTaskWithRequest:[NSURLRequest requestWithURL:url]]
            ];
            for (NSURLSessionTask *task in tasks) {
                XCTAssertTrue(task.ft_isWebSocketTask);
                XCTAssertEqualObjects(task.ft_webSocketResourceURL.absoluteString, url.absoluteString);
                [task cancel];
            }
        }
        NSURLSessionTask *httpTask = [session dataTaskWithURL:[NSURL URLWithString:@"https://websocket.example.com/http"]];
        XCTAssertFalse(httpTask.ft_isWebSocketTask);
        XCTAssertNil(httpTask.ft_webSocketResourceURL);
        [httpTask cancel];
        [session invalidateAndCancel];
    }
}

- (void)testWebSocketHandshakeCompletesAtOpenWithOriginalURL {
    if (@available(iOS 13.0, *)) {
        FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
        FTURLSessionSnapshotRumResourceHandler *rumResourceHandler = [FTURLSessionSnapshotRumResourceHandler new];
        interceptor.rumResourceHandler = rumResourceHandler;

        NSURL *webSocketURL = [NSURL URLWithString:@"wss://websocket.example.com/socket?token=redacted"];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        NSURLSessionWebSocketTask *task = [session webSocketTaskWithURL:webSocketURL];
        XCTAssertTrue(task.ft_isWebSocketTask);
        XCTAssertEqualObjects(task.ft_webSocketResourceURL, webSocketURL);

        // Redirects or request rewriting must not replace the original Resource URL.
        [task setValue:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://redirect.example.com/changed"]] forKey:@"currentRequest"];
        XCTAssertEqualObjects(task.ft_webSocketResourceURL.absoluteString, @"wss://websocket.example.com/socket?token=redacted");

        [interceptor interceptTask:task];
        [self waitForURLSessionInterceptorQueue];
        FTSessionTaskHandler *handler = [interceptor getTraceHandler:task];
        XCTAssertNotNil(handler);
        XCTAssertTrue(handler.webSocketHandshake);
        XCTAssertEqualObjects(handler.request.URL, webSocketURL);
        XCTAssertEqual(rumResourceHandler.startCount, 1);

        [interceptor interceptTask:task];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqual(rumResourceHandler.startCount, 1);

        FTResourceMetricsModel *metrics = [FTResourceMetricsModel new];
        metrics.resourceHttpProtocol = @"http/1.1";
        handler.metricsModel = metrics;
        __block NSURLRequest *providerRequest;
        __block NSData *providerData;
        __block BOOL providerCalled = NO;
        FTURLSessionDelegate *delegate = [FTURLSessionDelegate new];
        XCTAssertTrue([delegate conformsToProtocol:@protocol(NSURLSessionWebSocketDelegate)]);
        delegate.provider = ^NSDictionary * _Nullable(NSURLRequest * _Nullable request, NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error) {
            providerCalled = YES;
            providerRequest = request;
            providerData = data;
            return @{};
        };
        // Forward through the system delegate protocol, including an absent subprotocol.
        [delegate URLSession:session webSocketTask:task didOpenWithProtocol:nil];
        [self waitForURLSessionInterceptorQueue];

        XCTAssertNil([interceptor getTraceHandler:task]);
        XCTAssertEqual(rumResourceHandler.stopCount, 1);
        XCTAssertEqual(rumResourceHandler.addCount, 1);
        XCTAssertTrue(providerCalled);
        XCTAssertEqualObjects(providerRequest.URL, webSocketURL);
        XCTAssertNil(providerData);
        XCTAssertTrue(rumResourceHandler.content.webSocketHandshake);
        XCTAssertEqualObjects(rumResourceHandler.content.resourceType, FT_RESOURCE_TYPE_WEBSOCKET);
        XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS);
        XCTAssertEqualObjects(rumResourceHandler.content.url, webSocketURL);
        XCTAssertEqualObjects(rumResourceHandler.content.httpMethod, @"GET");
        XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 101);
        XCTAssertNil(rumResourceHandler.content.error);
        XCTAssertEqual(rumResourceHandler.metrics, metrics);

        [interceptor taskCompleted:task error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqual(rumResourceHandler.addCount, 1);

        [task cancel];
        [session invalidateAndCancel];
    }
}

- (void)assertWebSocketDurationWithSuccess:(BOOL)success earlyMetrics:(BOOL)earlyMetrics {
    if (@available(iOS 13.0, *)) {
        [FTModelHelper startViewWithName:@"WebSocketDuration"];
        FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
        FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
        interceptor.rumResourceHandler = rumManager;
        NSURL *url = [NSURL URLWithString:@"wss://websocket.example.com/duration"];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        NSURLSessionTask *task = [session webSocketTaskWithURL:url];
        FTWebSocketTestClock *clock = [FTWebSocketTestClock new];
        clock.time = 1000000000;
        Method clockMethod = class_getClassMethod(FTDateUtil.class, @selector(continuousTime));
        IMP testClock = imp_implementationWithBlock(^uint64_t(id receiver) {
            return clock.time;
        });
        IMP originalClock = method_setImplementation(clockMethod, testClock);
        NSTimeInterval epoch = [[NSDate date] timeIntervalSince1970];
        Method dateMethod = class_getClassMethod(NSDate.class, @selector(date));
        IMP testDate = imp_implementationWithBlock(^NSDate *(id receiver) {
            return [NSDate dateWithTimeIntervalSince1970:epoch + clock.time / (NSTimeInterval)NSEC_PER_SEC];
        });
        IMP originalDate = method_setImplementation(dateMethod, testDate);
        @try {
            // The start must be captured at entry, before the queued work runs at t=3s.
            long long expectedStart = [[NSDate date] ft_nanosecondTimeStamp];
            dispatch_suspend(interceptor.queue);
            [interceptor interceptTask:task];
            clock.time = 3000000000;
            dispatch_resume(interceptor.queue);
            [self waitForURLSessionInterceptorQueue];
            [interceptor interceptTask:task]; // A repeated resume must keep the first start.
            [self waitForURLSessionInterceptorQueue];
            FTSessionTaskHandler *handler = [interceptor getTraceHandler:task];
            long long expectedMetricsStart = earlyMetrics ? expectedStart - NSEC_PER_SEC : expectedStart;
            long long expectedDuration = earlyMetrics ? 4500000000 : 4000000000;
            if (earlyMetrics) {
                // Foundation's interval starts at task creation (t=0), before resume
                // at t=1, and ends at t=4.5, before the open/completion callback at t=5.
                clock.time = 4500000000;
                FTResourceMetricsModel *metrics = [FTResourceMetricsModel new];
                metrics.fetchStartNsTimeInterval = expectedMetricsStart;
                metrics.fetchEndNsTimeInterval = expectedMetricsStart + expectedDuration;
                metrics.dnsStartNsTimeInterval = expectedStart;
                metrics.dnsEndNsTimeInterval = metrics.dnsStartNsTimeInterval + 100000000;
                handler.metricsModel = metrics;
            }

            __block BOOL providerCalled = NO;
            ResourcePropertyProvider provider = ^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
                providerCalled = YES;
                clock.time = 12000000000;
                return @{FT_DURATION: @99000000000};
            };
            // Both terminal callbacks arrive at t=5s, but are handled at t=9s.
            clock.time = 5000000000;
            dispatch_suspend(interceptor.queue);
            if (success) {
                [interceptor taskWebSocketDidOpen:task extraProvider:provider];
            } else {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
                [interceptor taskCompleted:task error:error extraProvider:provider errorFilter:^BOOL(NSError *error) {
                    clock.time = 10000000000;
                    return YES;
                }];
            }
            clock.time = 9000000000;
            dispatch_resume(interceptor.queue);
            [self waitForURLSessionInterceptorQueue];
            XCTAssertTrue(providerCalled);
            XCTAssertNil([interceptor getTraceHandler:task]);
            XCTAssertNotNil(handler.metricsModel);
            XCTAssertEqual(handler.metricsModel.fetchStartNsTimeInterval, expectedMetricsStart);
            XCTAssertEqual(handler.metricsModel.fetchEndNsTimeInterval - handler.metricsModel.fetchStartNsTimeInterval, expectedDuration);

            // Later duplicate/close callbacks must not replace the first terminal time.
            clock.time = 20000000000;
            [interceptor taskMetricsCollected:task metrics:nil];
            [interceptor taskWebSocketDidOpen:task extraProvider:nil];
            [interceptor taskCompleted:task error:nil];
            [self waitForURLSessionInterceptorQueue];
            [rumManager syncProcess];
            NSArray *records = [[FTTrackerEventDBTool sharedManager] getAllDatas];
            __block NSUInteger resourceCount = 0;
            [FTModelHelper resolveModelArray:records timeCallBack:^(NSString *source, NSDictionary *tags, NSDictionary *fields, long long time, BOOL *stop) {
                if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && [tags[FT_KEY_RESOURCE_URL] isEqualToString:url.absoluteString]) {
                    resourceCount += 1;
                    XCTAssertEqual(time, expectedMetricsStart);
                    XCTAssertEqualObjects(fields[FT_DURATION], @(expectedDuration), @"System taskInterval must take precedence; callback-boundary duration is only a fallback");
                    XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_WEBSOCKET_HANDSHAKE_STATE], success ? FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS : FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED);
                    XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_DNS], earlyMetrics ? @100000000 : nil);
                    NSDictionary *expectedDNSTime = earlyMetrics ? @{FT_KEY_START: @1000000000, FT_DURATION: @100000000} : nil;
                    XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_DNS_TIME], expectedDNSTime);
                }
            }];
            XCTAssertEqual(resourceCount, 1);
        } @finally {
            method_setImplementation(dateMethod, originalDate);
            imp_removeBlock(testDate);
            method_setImplementation(clockMethod, originalClock);
            imp_removeBlock(testClock);
            [task cancel];
            [session invalidateAndCancel];
        }
    }
}

- (void)testWebSocketOpenDurationPrefersTaskMetricsOverCallbackBoundaries {
    [self assertWebSocketDurationWithSuccess:YES earlyMetrics:YES];
}
- (void)testWebSocketOpenDurationUsesCallbackBoundariesWithoutMetrics {
    [self assertWebSocketDurationWithSuccess:YES earlyMetrics:NO];
}
- (void)testWebSocketFailureDurationPrefersTaskMetricsOverCallbackBoundaries {
    [self assertWebSocketDurationWithSuccess:NO earlyMetrics:YES];
}
- (void)testWebSocketFailureDurationUsesCallbackBoundariesWithoutMetrics {
    [self assertWebSocketDurationWithSuccess:NO earlyMetrics:NO];
}

- (void)testWebSocketHandshakeFailureStateMapping {
    if (@available(iOS 13.0, *)) {
        FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
        FTURLSessionSnapshotRumResourceHandler *rumResourceHandler = [FTURLSessionSnapshotRumResourceHandler new];
        interceptor.rumResourceHandler = rumResourceHandler;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];

        NSURLSessionTask *rejectedTask = [session webSocketTaskWithURL:[NSURL URLWithString:@"wss://websocket.example.com/rejected"]];
        [interceptor interceptTask:rejectedTask];
        [self waitForURLSessionInterceptorQueue];
        NSHTTPURLResponse *rejectedResponse = [[NSHTTPURLResponse alloc] initWithURL:rejectedTask.ft_webSocketResourceURL statusCode:403 HTTPVersion:@"HTTP/1.1" headerFields:nil];
        NSError *rejectedError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil];
        [interceptor handleTaskCompleted:rejectedTask response:rejectedResponse error:rejectedError extraProvider:nil errorFilter:nil endTime:[FTDateUtil continuousTime]];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED);
        XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 403);
        XCTAssertEqualObjects(rumResourceHandler.content.error, rejectedError);

        NSURLSessionTask *failedTask = [session webSocketTaskWithURL:[NSURL URLWithString:@"wss://websocket.example.com/failed"]];
        [interceptor interceptTask:failedTask];
        [self waitForURLSessionInterceptorQueue];
        NSError *failedError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
        [interceptor handleTaskCompleted:failedTask response:nil error:failedError extraProvider:nil errorFilter:nil endTime:[FTDateUtil continuousTime]];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED);
        XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 0);
        XCTAssertEqualObjects(rumResourceHandler.content.error, failedError);

        NSURLSessionTask *protocolErrorTask = [session webSocketTaskWithURL:[NSURL URLWithString:@"wss://websocket.example.com/protocol-error"]];
        [interceptor interceptTask:protocolErrorTask];
        [self waitForURLSessionInterceptorQueue];
        NSHTTPURLResponse *upgradeResponse = [[NSHTTPURLResponse alloc] initWithURL:protocolErrorTask.ft_webSocketResourceURL statusCode:101 HTTPVersion:@"HTTP/1.1" headerFields:nil];
        NSError *protocolError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil];
        [interceptor handleTaskCompleted:protocolErrorTask response:upgradeResponse error:protocolError extraProvider:nil errorFilter:nil endTime:[FTDateUtil continuousTime]];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED);
        XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 101);
        XCTAssertEqualObjects(rumResourceHandler.content.error, protocolError);

        NSURLSessionTask *filteredFailureTask = [session webSocketTaskWithURL:[NSURL URLWithString:@"wss://websocket.example.com/filtered-failure"]];
        [interceptor interceptTask:filteredFailureTask];
        [self waitForURLSessionInterceptorQueue];
        [interceptor handleTaskCompleted:filteredFailureTask response:nil error:failedError extraProvider:nil errorFilter:^BOOL(NSError *error) {
            return YES;
        } endTime:[FTDateUtil continuousTime]];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED);
        XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 0);
        XCTAssertNil(rumResourceHandler.content.error);

        NSURLSessionTask *rejectedWithoutErrorTask = [session webSocketTaskWithURL:[NSURL URLWithString:@"wss://websocket.example.com/rejected-without-error"]];
        [interceptor interceptTask:rejectedWithoutErrorTask];
        [self waitForURLSessionInterceptorQueue];
        [interceptor handleTaskCompleted:rejectedWithoutErrorTask response:rejectedResponse error:nil extraProvider:nil errorFilter:nil endTime:[FTDateUtil continuousTime]];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED);
        XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 403);
        XCTAssertNil(rumResourceHandler.content.error);

        NSArray<NSNumber *> *transportErrorCodes = @[
            @(NSURLErrorCannotFindHost),
            @(NSURLErrorSecureConnectionFailed),
            @(NSURLErrorNetworkConnectionLost),
            @(NSURLErrorCancelled),
        ];
        NSMutableArray<NSURLSessionTask *> *transportFailureTasks = [NSMutableArray array];
        for (NSNumber *errorCode in transportErrorCodes) {
            NSURLSessionTask *transportFailureTask = [session webSocketTaskWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"wss://websocket.example.com/failure/%@", errorCode]]];
            [transportFailureTasks addObject:transportFailureTask];
            [interceptor interceptTask:transportFailureTask];
            [self waitForURLSessionInterceptorQueue];
            NSError *transportError = [NSError errorWithDomain:NSURLErrorDomain code:errorCode.integerValue userInfo:nil];
            [interceptor handleTaskCompleted:transportFailureTask response:nil error:transportError extraProvider:nil errorFilter:nil endTime:[FTDateUtil continuousTime]];
            [self waitForURLSessionInterceptorQueue];
            XCTAssertEqualObjects(rumResourceHandler.content.webSocketHandshakeState, FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED, @"error %@ must remain a failed handshake", errorCode);
            XCTAssertEqual(rumResourceHandler.content.httpStatusCode, 0);
            XCTAssertEqualObjects(rumResourceHandler.content.error, transportError);
        }

        [rejectedTask cancel];
        [failedTask cancel];
        [protocolErrorTask cancel];
        [filteredFailureTask cancel];
        [rejectedWithoutErrorTask cancel];
        for (NSURLSessionTask *transportFailureTask in transportFailureTasks) {
            [transportFailureTask cancel];
        }
        [session invalidateAndCancel];
    }
}

- (void)testWebSocketHandshakeURLFilterUsesOriginalWebSocketURL {
    if (@available(iOS 13.0, *)) {
        FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
        FTURLSessionSnapshotRumResourceHandler *rumResourceHandler = [FTURLSessionSnapshotRumResourceHandler new];
        interceptor.rumResourceHandler = rumResourceHandler;
        FTResourceUrlHandler originalFilter = interceptor.resourceUrlHandler;
        __block NSURL *filteredURL;
        interceptor.resourceUrlHandler = ^BOOL(NSURL *url) {
            filteredURL = url;
            return YES;
        };

        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        NSURL *webSocketURL = [NSURL URLWithString:@"wss://websocket.example.com/filtered?token=redacted"];
        NSURLSessionTask *task = [session webSocketTaskWithURL:webSocketURL];
        [interceptor interceptTask:task];
        [self waitForURLSessionInterceptorQueue];

        XCTAssertEqualObjects(filteredURL, webSocketURL);
        XCTAssertNil([interceptor getTraceHandler:task]);
        XCTAssertEqual(rumResourceHandler.startCount, 0);

        interceptor.resourceUrlHandler = originalFilter;
        [task cancel];
        [session invalidateAndCancel];
    }
}

- (void)testHTTPResourceRemainsNonWebSocketAfterWebSocketInstrumentation {
    FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
    FTURLSessionSnapshotRumResourceHandler *rumResourceHandler = [FTURLSessionSnapshotRumResourceHandler new];
    interceptor.rumResourceHandler = rumResourceHandler;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURL *url = [NSURL URLWithString:@"https://resource.example.com/normal-http"];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url];
    [interceptor interceptTask:task];
    [self waitForURLSessionInterceptorQueue];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    [interceptor handleTaskCompleted:task response:response error:nil extraProvider:nil errorFilter:nil endTime:[FTDateUtil continuousTime]];
    [self waitForURLSessionInterceptorQueue];

    XCTAssertEqual(rumResourceHandler.addCount, 1);
    XCTAssertFalse(rumResourceHandler.content.webSocketHandshake);
    XCTAssertNil(rumResourceHandler.content.webSocketHandshakeState);
    XCTAssertNotEqualObjects(rumResourceHandler.content.resourceType, FT_RESOURCE_TYPE_WEBSOCKET);

    [task cancel];
    [session invalidateAndCancel];
}

- (void)testResourceWriterUsesSuppliedMetricsForWebSocketAndHTTP {
    [FTModelHelper startViewWithName:@"WebSocketHandshake"];
    NSString *key = [FTBaseInfoHandler randomUUID];
    NSURL *url = [NSURL URLWithString:@"wss://websocket.example.com/socket"];
    FTResourceContentModel *content = [FTResourceContentModel new];
    content.url = url;
    content.httpMethod = @"GET";
    content.httpStatusCode = 101;
    content.resourceType = FT_RESOURCE_TYPE_WEBSOCKET;
    content.webSocketHandshake = YES;
    content.webSocketHandshakeState = FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS;
    content.requestHeader = @{@"Content-Length":@"32"};
    content.responseHeader = @{@"Content-Length":@"64"};

    FTResourceMetricsModel *metrics = [FTResourceMetricsModel new];
    // Preserve the exact nanosecond timestamp without a round-trip through NSDate.
    const long long metricsStartTime = 1700000000123456789;
    metrics.fetchStartNsTimeInterval = metricsStartTime;
    metrics.fetchEndNsTimeInterval = metricsStartTime + 8000000000;
    metrics.dnsStartNsTimeInterval = metricsStartTime + 100000000;
    metrics.dnsEndNsTimeInterval = metricsStartTime + 200000000;
    metrics.connectStartNsTimeInterval = metricsStartTime + 200000000;
    metrics.connectEndNsTimeInterval = metricsStartTime + 1200000000;
    metrics.sslStartNsTimeInterval = metricsStartTime + 300000000;
    metrics.sslEndNsTimeInterval = metricsStartTime + 1100000000;
    metrics.requestStartNsTimeInterval = metricsStartTime + 1200000000;
    metrics.responseStartNsTimeInterval = metricsStartTime + 1500000000;
    metrics.resourceHttpProtocol = @"http/1.1";
    metrics.reusedConnection = NO;

    NSString *failedKey = [FTBaseInfoHandler randomUUID];
    NSURL *failedURL = [NSURL URLWithString:@"wss://websocket.example.com/failed"];
    FTResourceContentModel *failedContent = [FTResourceContentModel new];
    failedContent.url = failedURL;
    failedContent.httpMethod = @"GET";
    failedContent.httpStatusCode = 0;
    failedContent.resourceType = FT_RESOURCE_TYPE_WEBSOCKET;
    failedContent.webSocketHandshake = YES;
    failedContent.webSocketHandshakeState = FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED;

    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
    [rumManager startResourceWithKey:key];
    [rumManager stopResourceWithKey:key];
    [rumManager addResourceWithKey:key metrics:metrics content:content];
    [rumManager startResourceWithKey:failedKey];
    [rumManager stopResourceWithKey:failedKey];
    [rumManager addResourceWithKey:failedKey metrics:nil content:failedContent];
    NSString *httpKey = [FTBaseInfoHandler randomUUID];
    NSURL *httpURL = [NSURL URLWithString:@"https://resource.example.com/http"];
    FTResourceContentModel *httpContent = [FTResourceContentModel new];
    httpContent.url = httpURL;
    httpContent.httpMethod = @"GET";
    httpContent.httpStatusCode = 200;
    [rumManager startResourceWithKey:httpKey];
    [rumManager stopResourceWithKey:httpKey];
    [rumManager addResourceWithKey:httpKey metrics:metrics content:httpContent];
    [rumManager syncProcess];

    NSArray *records = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    __block BOOL foundResource = NO;
    __block BOOL foundFailedResource = NO;
    __block BOOL foundHTTPResource = NO;
    [FTModelHelper resolveModelArray:records timeCallBack:^(NSString *source, NSDictionary *tags, NSDictionary *fields, long long time, BOOL *stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && [tags[FT_KEY_RESOURCE_URL] isEqualToString:url.absoluteString]) {
            foundResource = YES;
            XCTAssertEqual(time, metricsStartTime);
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_TYPE], FT_RESOURCE_TYPE_WEBSOCKET);
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_WEBSOCKET_COLLECTION_LEVEL], FT_RESOURCE_WEBSOCKET_COLLECTION_LEVEL_HANDSHAKE);
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_WEBSOCKET_HANDSHAKE_STATE], FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS);
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_STATUS], @101);
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_STATUS_GROUP], @"1xx");
            XCTAssertNil(fields[FT_KEY_RESOURCE_SIZE]);
            XCTAssertNil(fields[FT_KEY_RESOURCE_REQUEST_SIZE]);
            XCTAssertNotNil(fields[FT_DURATION]);
            XCTAssertEqualObjects(fields[FT_DURATION], @8000000000);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_DNS], @100000000);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_DNS_TIME], (@{FT_KEY_START:@100000000, FT_DURATION:@100000000}));
            XCTAssertEqual(time + [fields[FT_KEY_RESOURCE_DNS_TIME][FT_KEY_START] longLongValue], metricsStartTime + 100000000);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_TCP], @1000000000);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_SSL], @800000000);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_TTFB], @300000000);
            XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_HTTP_PROTOCOL], @"http/1.1");
        }
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && [tags[FT_KEY_RESOURCE_URL] isEqualToString:failedURL.absoluteString]) {
            foundFailedResource = YES;
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_WEBSOCKET_HANDSHAKE_STATE], FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED);
            XCTAssertEqualObjects(tags[FT_KEY_RESOURCE_STATUS], @0);
            XCTAssertNil(tags[FT_KEY_RESOURCE_STATUS_GROUP]);
        }
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && [tags[FT_KEY_RESOURCE_URL] isEqualToString:httpURL.absoluteString]) {
            foundHTTPResource = YES;
            XCTAssertEqual(time, metricsStartTime);
            XCTAssertEqualObjects(fields[FT_DURATION], @8000000000);
            XCTAssertNil(tags[FT_KEY_RESOURCE_WEBSOCKET_COLLECTION_LEVEL]);
            XCTAssertNil(tags[FT_KEY_RESOURCE_WEBSOCKET_HANDSHAKE_STATE]);
        }
    }];
    XCTAssertTrue(foundResource);
    XCTAssertTrue(foundFailedResource);
    XCTAssertTrue(foundHTTPResource);
}

- (void)testResourceWriterTimestampFallsBackWithoutMetricsStart {
    [FTModelHelper startViewWithName:@"ResourceTimestampFallback"];
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
    FTResourceMetricsModel *emptyMetrics = [FTResourceMetricsModel new];
    FTResourceMetricsModel *invalidStartMetrics = [FTResourceMetricsModel new];
    invalidStartMetrics.fetchStartNsTimeInterval = -1;
    invalidStartMetrics.fetchEndNsTimeInterval = 9000000000;
    NSArray *inputs = @[NSNull.null, emptyMetrics, invalidStartMetrics];
    long long epochSeconds = (long long)[[NSDate date] timeIntervalSince1970] + 1;
    __block long long clockSeconds = epochSeconds;
    NSMutableDictionary<NSString *, NSNumber *> *expectedTimes = [NSMutableDictionary new];
    Method dateMethod = class_getClassMethod(NSDate.class, @selector(date));
    IMP testDate = imp_implementationWithBlock(^NSDate *(id receiver) {
        return [NSDate dateWithTimeIntervalSince1970:clockSeconds];
    });
    IMP originalDate = method_setImplementation(dateMethod, testDate);
    @try {
        for (NSUInteger index = 0; index < inputs.count; index++) {
            NSString *key = [FTBaseInfoHandler randomUUID];
            NSString *url = [NSString stringWithFormat:@"https://resource.example.com/missing-start/%lu", (unsigned long)index];
            FTResourceContentModel *content = [FTResourceContentModel new];
            content.url = [NSURL URLWithString:url];
            content.httpMethod = @"GET";
            content.httpStatusCode = 200;
            clockSeconds = epochSeconds + index * 3;
            expectedTimes[url] = @(clockSeconds * NSEC_PER_SEC);
            [rumManager startResourceWithKey:key];
            [rumManager syncProcess];
            clockSeconds += 2;
            [rumManager stopResourceWithKey:key];
            FTResourceMetricsModel *metrics = inputs[index] == NSNull.null ? nil : inputs[index];
            [rumManager addResourceWithKey:key metrics:metrics content:content];
            [rumManager syncProcess];
        }
    } @finally {
        method_setImplementation(dateMethod, originalDate);
        imp_removeBlock(testDate);
    }
    __block NSUInteger resourceCount = 0;
    NSArray *records = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    [FTModelHelper resolveModelArray:records timeCallBack:^(NSString *source, NSDictionary *tags, NSDictionary *fields, long long time, BOOL *stop) {
        NSNumber *expectedTime = expectedTimes[tags[FT_KEY_RESOURCE_URL]];
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && expectedTime) {
            resourceCount++;
            XCTAssertEqual(time, expectedTime.longLongValue);
            if ([tags[FT_KEY_RESOURCE_URL] hasSuffix:@"/0"]) {
                XCTAssertEqualObjects(fields[FT_DURATION], @2000000000);
            }
        }
    }];
    XCTAssertEqual(resourceCount, inputs.count);
}

- (NSMutableURLRequest *)adaptedURLRequestWithRequest:(id<FTRequestProtocol>)request {
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    if ([request respondsToSelector:@selector(adaptedRequest:)]) {
        urlRequest = [request adaptedRequest:urlRequest];
    }
    return urlRequest;
}

- (void)assertSDKRequestIsFiltered:(id<FTRequestProtocol>)request name:(NSString *)name {
    NSMutableURLRequest *urlRequest = [self adaptedURLRequestWithRequest:request];
    XCTAssertNotNil(urlRequest, @"%@ request should be created", name);
    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST], @"true", @"%@ request should carry SDK internal request header", name);
    XCTAssertTrue([[FTURLSessionInstrumentation sharedInstance] isFTIntakeRequest:urlRequest], @"%@ request should be filtered out", name);
}

- (id)sdkFilterTestResource {
    Class resourceClass = NSClassFromString(@"FTEnrichedResource");
    XCTAssertNotNil(resourceClass);
    id resource = [[resourceClass alloc] init];
    [resource setValue:@"resource-id" forKey:@"identifier"];
    [resource setValue:@"app-id" forKey:@"appId"];
    [resource setValue:[@"resource-data" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"data"];
    [resource setValue:@"image/png" forKey:@"mimeType"];
    return resource;
}

- (id<FTRequestProtocol>)sdkFilterRequestWithClassName:(NSString *)className events:(NSArray *)events parameters:(NSDictionary *)parameters {
    Class requestClass = NSClassFromString(className);
    XCTAssertNotNil(requestClass, @"%@ should be available in unit test target", className);
    id request = [[requestClass alloc] init];
    SEL selector = @selector(requestWithEvents:parameters:);
    XCTAssertTrue([request respondsToSelector:selector], @"%@ should build request with events", className);
    NSMethodSignature *signature = [request methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = request;
    invocation.selector = selector;
    [invocation setArgument:&events atIndex:2];
    [invocation setArgument:&parameters atIndex:3];
    [invocation invoke];
    return request;
}

- (NSData *)sdkFilterTestSegmentData {
    NSDictionary *segment = @{
        @"applicationID":@"app-id",
        @"sessionID":@"session-id",
        @"viewID":@"view-id",
        @"records":@[
            @{
                @"type":@2,
                @"timestamp":@1
            }
        ]
    };
    return [NSJSONSerialization dataWithJSONObject:segment options:kNilOptions error:nil];
}
- (void)testNetworkMockHandlerRunsOnceForMultipleMatchingRequests {
    NSURL *url = [NSURL URLWithString:@"https://network-mock.example.com/one-shot"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Mock handler should run once"];
    id<OHHTTPStubsDescriptor> stubs = [FTNetworkMock networkOHHTTPStubsWithUrl:url.absoluteString handler:^{
        [expectation fulfill];
    }];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *firstTask = [session dataTaskWithURL:url];
    NSURLSessionDataTask *secondTask = [session dataTaskWithURL:url];

    [firstTask resume];
    [secondTask resume];
    [self waitForExpectations:@[expectation] timeout:3];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];

    [session finishTasksAndInvalidate];
    [OHHTTPStubs removeStub:stubs];
}

/** Tests that creating a shared session returns a non-nil object. */
- (void)testSharedSession {
    __block NSURLSessionDataTask *dataTask;
    NSURLSession *session = [NSURLSession sharedSession];
    XCTAssertNotNil(session);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async operation timeout"];
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:self.url.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *data = [@"success" dataUsingEncoding:NSUTF8StringEncoding];
        return [[OHHTTPStubsResponse responseWithData:data statusCode:200 headers:nil] requestTime:0.2 responseTime:0];
    }];

    dataTask = [session dataTaskWithURL:self.url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation] timeout:3];
    [self waitForTraceHandlerReleasedWithTask:dataTask timeout:1];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [OHHTTPStubs removeStub:stubs];
}


/** Tests sessionWithConfiguration: with the default configuration returns a non-nil object. */
- (void)testSessionWithDefaultSessionConfiguration {
    __block NSURLSessionDataTask *dataTask;
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    __block id<OHHTTPStubsDescriptor> stubs = [FTNetworkMock networkOHHTTPStubsWithUrl:self.url.absoluteString handler:^{
        XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        [expectation fulfill];
        [OHHTTPStubs removeStub:stubs];
    }];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    XCTAssertNotNil(session);
    dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation] timeout:3];
}

/** Tests sessionWithConfiguration: with an ephemeral configuration returns a non-nil object. */
- (void)testSessionWithEphemeralSessionConfiguration {
    __block NSURLSessionDataTask *dataTask;
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    __block id<OHHTTPStubsDescriptor> stubs = [FTNetworkMock networkOHHTTPStubsWithUrl:self.url.absoluteString handler:^{
        XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        [expectation fulfill];
        [OHHTTPStubs removeStub:stubs];
    }];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    XCTAssertNotNil(session);
    dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation] timeout:3];
}

/** Tests sessionWithConfiguration: with a background configuration returns a non-nil object. */
- (void)testSessionWithBackgroundSessionConfiguration {
    [FTNetworkMock networkOHHTTPStubs];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"madeUpID"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    XCTAssertNotNil(session);
    [session finishTasksAndInvalidate];
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
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:task]);
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    method_setImplementation(method, originalImp);
}

#pragma mark - Testing delegate method wrapping

/** Tests using a nil delegate still results in tracking responses. */
- (void)testSessionWithConfigurationDelegateDelegateQueueWithNilDelegate {
    [FTNetworkMock networkOHHTTPStubs];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:nil
                                                     delegateQueue:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    @autoreleasepool {
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
        XCTAssertNotNil(dataTask);
        [dataTask resume];
        [self waitForURLSessionInterceptorQueue];
        XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        XCTAssertNotNil(session.delegate);
    }
}

//* Tests that the delegate class isn't instrumented more than once.
- (void)testDelegateClassOnlyRegisteredOnce {
    __block NSURLSessionDataTask *dataTask;
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    __block id<OHHTTPStubsDescriptor> stubs = [FTNetworkMock networkOHHTTPStubsWithUrl:self.url.absoluteString handler:^{
        XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        [expectation fulfill];
        [OHHTTPStubs removeStub:stubs];
    }];
    FTURLSessionCompleteTestDelegate *delegate =
    [[FTURLSessionCompleteTestDelegate alloc] init];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    dataTask = [session dataTaskWithRequest:request];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation] timeout:3];
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
        [self waitForURLSessionInterceptorQueue];
        XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:task]);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:task]);
    XCTAssertTrue(delegate.URLSessionTaskDidCompleteWithErrorCalledCount==1);
    [OHHTTPStubs removeStub:descriptor];
}
/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionDataTaskDidReceiveData {
    [FTNetworkMock networkOHHTTPStubs];
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
        [self waitForURLSessionInterceptorQueue];
        XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        [session invalidateAndCancel];
    }
}
/** Tests that even if a delegate doesn't implement a method, we add it to the delegate class. */
- (void)testDelegateUnimplementedURLSessionTaskDidCompleteWithError {
    __block NSURLSessionDataTask *dataTask;
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    __block id<OHHTTPStubsDescriptor> stubs = [FTNetworkMock networkOHHTTPStubsWithUrl:self.url.absoluteString handler:^{
        XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        [expectation fulfill];
        [OHHTTPStubs removeStub:stubs];
    }];
    FTURLSessionNoCompleteTestDelegate *delegate = [[FTURLSessionNoCompleteTestDelegate alloc] init];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    XCTAssertFalse([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:delegate
                                                     delegateQueue:nil];
    XCTAssertTrue([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]);
    dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation] timeout:3];
    [session invalidateAndCancel];
}
/** Tests that even if a delegate doesn't implement a method, we add it to the delegate class. */
- (void)testDelegateUnimplementedURLSessionTaskDidFinishCollectingMetrics {
    __block NSURLSessionDataTask *dataTask;
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    __block id<OHHTTPStubsDescriptor> stubs = [FTNetworkMock networkOHHTTPStubsWithUrl:self.url.absoluteString handler:^{
        XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
        [expectation fulfill];
        [OHHTTPStubs removeStub:stubs];
    }];
    FTURLSessionNoDidFinishCollectingMetrics *delegate = [[FTURLSessionNoDidFinishCollectingMetrics alloc] init];
    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    XCTAssertFalse([delegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:delegate
                                                     delegateQueue:nil];
    XCTAssertTrue([delegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]);
    dataTask = [session dataTaskWithURL:self.url];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectations:@[expectation] timeout:3];
    [session invalidateAndCancel];
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
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [dataTask cancel];
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
    [dataTask cancel];
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
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    [self waitForTraceHandlerReleasedWithTask:dataTask timeout:1];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [dataTask cancel];
}

/** Validate that it works with NSMutableURLRequest URLs across data, upload, and download. */
- (void)testMutableRequestURLs{
    [FTNetworkMock networkOHHTTPStubs];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:self.url];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNotNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [session invalidateAndCancel];
}

- (void)testSDKUploadLoggingRequest{
    [FTNetworkMock networkOHHTTPStubs];
    FTRequest *loggingRequest = [FTRequest createRequestWithEvents:@[[FTModelHelper createLogModel]] type:FT_DATA_TYPE_LOGGING];
    NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc]initWithURL:loggingRequest.absoluteURL];
    URLRequest = [loggingRequest adaptedRequest:URLRequest];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [session invalidateAndCancel];
}
- (void)testSDKUploadRumRequest{
    __block NSURLSessionDataTask *dataTask;
    [FTNetworkMock networkOHHTTPStubs];
    FTRequest *rumRequest = [FTRequest createRequestWithEvents:@[[FTModelHelper createRumModel]] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc]initWithURL:rumRequest.absoluteURL];
    URLRequest = [rumRequest adaptedRequest:URLRequest];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [session invalidateAndCancel];
}
- (void)testSDKRemoteConfigRequest{
    [FTNetworkMock networkOHHTTPStubs];
    FTRemoteConfigurationRequest *remoteConfigRequest = [[FTRemoteConfigurationRequest alloc]init];
    NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc]initWithURL:remoteConfigRequest.absoluteURL];
    URLRequest = [remoteConfigRequest adaptedRequest:URLRequest];
    NSURLSession *session = [NSURLSession
                             sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:URLRequest];
    [dataTask resume];
    [self waitForURLSessionInterceptorQueue];
    XCTAssertNil([[FTURLSessionInterceptor shared] getTraceHandler:dataTask]);
    [session invalidateAndCancel];
}

#pragma mark - SDK Internal Request Filtering Tests

/** Tests that SDK internal RUM upload requests are filtered out. */
- (void)testIsFTIntakeRequest_RUMRequest{
    FTRequest *rumRequest = [FTRequest createRequestWithEvents:@[[FTModelHelper createRumModel]] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc]initWithURL:rumRequest.absoluteURL];
    URLRequest = [rumRequest adaptedRequest:URLRequest];
    
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
        
    XCTAssertTrue([instrumentation isFTIntakeRequest:URLRequest], @"RUM package request should be filtered out");
}
/** Tests that SDK internal Log upload requests are filtered out. */
- (void)testIsFTIntakeRequest_LogRequest{
    FTRequest *loggingRequest = [FTRequest createRequestWithEvents:@[[FTModelHelper createLogModel]] type:FT_DATA_TYPE_LOGGING];
    NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc]initWithURL:loggingRequest.absoluteURL];
    URLRequest = [loggingRequest adaptedRequest:URLRequest];
    
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
        
    XCTAssertTrue([instrumentation isFTIntakeRequest:URLRequest], @"RUM package request should be filtered out");
}
/** Tests that SDK internal RemoteConfig requests are filtered out. */
- (void)testIsFTIntakeRequest_RemoteConfigRequest{
    FTRemoteConfigurationRequest *remoteConfigRequest = [[FTRemoteConfigurationRequest alloc]init];
    NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc]initWithURL:remoteConfigRequest.absoluteURL];
    URLRequest = [remoteConfigRequest adaptedRequest:URLRequest];

    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];

    XCTAssertTrue([instrumentation isFTIntakeRequest:URLRequest], @"RemoteConfig request should be filtered out");
}
- (void)testIsFTIntakeRequest_AllFTRequestSubclasses{
    [self assertSDKRequestIsFiltered:[FTRequest createRequestWithEvents:@[[FTModelHelper createRumModel]] type:FT_DATA_TYPE_RUM] name:@"FTRumRequest"];
    [self assertSDKRequestIsFiltered:[FTRequest createRequestWithEvents:@[[FTModelHelper createLogModel]] type:FT_DATA_TYPE_LOGGING] name:@"FTLoggingRequest"];

    id<FTRequestProtocol> segmentRequest = [self sdkFilterRequestWithClassName:@"FTSegmentRequest"
                                                                         events:@[[self sdkFilterTestSegmentData]]
                                                                     parameters:@{}];
    [self assertSDKRequestIsFiltered:segmentRequest name:@"FTSegmentRequest"];

    id<FTRequestProtocol> resourceRequest = [self sdkFilterRequestWithClassName:@"FTResourceRequest"
                                                                          events:@[[self sdkFilterTestResource]]
                                                                      parameters:@{}];
    [self assertSDKRequestIsFiltered:resourceRequest name:@"FTResourceRequest"];

    id<FTRequestProtocol> resourceCheckRequest = [self sdkFilterRequestWithClassName:@"FTResourceCheckRequest"
                                                                               events:@[@"resource-id"]
                                                                           parameters:@{FT_APP_ID:@"app-id"}];
    [self assertSDKRequestIsFiltered:resourceCheckRequest name:@"FTResourceCheckRequest"];

    [self assertSDKRequestIsFiltered:[[FTRemoteConfigurationRequest alloc] init] name:@"FTRemoteConfigurationRequest"];
    [self assertSDKRequestIsFiltered:[[FTDataFilterPullRequest alloc] init] name:@"FTDataFilterPullRequest"];
}
- (void)testIsFTIntakeRequest_InternalRequestHeader{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    [request setValue:@"true" forHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST];
    
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
    
    XCTAssertTrue([instrumentation isFTIntakeRequest:request], @"Request with SDK internal request header should be filtered out");
}

/** Tests that X-Pkg-Id alone no longer marks a request as internal. */
- (void)testIsFTIntakeRequest_PackageIdHeaderOnly {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    [request setValue:@"rumm-" forHTTPHeaderField:FT_HTTP_HEADER_X_PKG_ID];
    
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
    
    XCTAssertFalse([instrumentation isFTIntakeRequest:request], @"X-Pkg-Id alone should NOT be filtered out");
}

/** Tests that requests without SDK internal request header are not filtered. */
- (void)testIsFTIntakeRequest_NoInternalRequestHeader {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
  
    XCTAssertFalse([instrumentation isFTIntakeRequest:request], @"Request without SDK internal request header should NOT be filtered out");
}

/** Tests that nil request returns NO. */
- (void)testIsFTIntakeRequest_NilRequest {
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
    XCTAssertFalse([instrumentation isFTIntakeRequest:nil], @"Nil request should return NO");
}

/** Tests that user requests with custom headers are not filtered. */
- (void)testUserRequestsWithCustomHeaders {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    [request setValue:@"custom-value" forHTTPHeaderField:@"X-Custom-Header"];
    [request setValue:@"user-token" forHTTPHeaderField:@"Authorization"];
    
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
    
    XCTAssertFalse([instrumentation isFTIntakeRequest:request], @"User request with custom headers should NOT be filtered out");
}
#pragma mark ======= isSupportedForInstrumentation =======

- (void)testIsSupportedForInstrumentation_dataTask{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:[NSURL URLWithString:@"https://httpbin.org/status/200"]];
    XCTAssertTrue([dataTask ft_isSupportedForInstrumentation]);
    [dataTask cancel];
    [session invalidateAndCancel];
}
- (void)testIsSupportedForInstrumentation_uploadTask{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURL *url = [NSURL URLWithString:@"https://httpbin.org/post"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    NSError *jsonError;
    NSDictionary *parameters = @{@"test":@"uploadTask"};
    NSData *uploadData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&jsonError];
    NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromData:uploadData];
    XCTAssertTrue([uploadTask ft_isSupportedForInstrumentation]);
    [uploadTask cancel];
    [session invalidateAndCancel];
}
- (void)testIsSupportedForInstrumentation_downloadTask{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:[NSURL URLWithString:@"https://httpbin.org/bytes/1024"]];
    XCTAssertTrue([downloadTask ft_isSupportedForInstrumentation]);
    [downloadTask cancel];
    [session invalidateAndCancel];
}

- (void)testIsSupportedForInstrumentation_webSocketTask API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0)){
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURL *url = [NSURL URLWithString:@"wss://httpbin.org/ws"];

    NSURLSessionWebSocketTask *webSocketTask = [session webSocketTaskWithURL:url];
   
    XCTAssertTrue([webSocketTask ft_isSupportedForInstrumentation]);
    [webSocketTask cancel];
    [session invalidateAndCancel];
    
}

- (void)testIsSupportedForInstrumentation_streamTask{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionStreamTask *streamTask = [session streamTaskWithHostName:@"tcpbin.org" port:4242];
    XCTAssertTrue([streamTask ft_isSupportedForInstrumentation]);
    [streamTask cancel];
    [session invalidateAndCancel];
}

- (void)testIsSupportedForInstrumentation_unsupportedAVTaskTypes {
    NSArray *unsupportedClassNames = @[
        @"AVAssetDownloadTask",
        @"NSURLSessionAVAssetDownloadTask",
        @"AVAggregateAssetDownloadTask",
        @"NSURLSessionAVAggregateAssetDownloadTask",
        @"__NSCFBackgroundAVAssetDownloadTask"
    ];
    
    for (NSString *className in unsupportedClassNames) {
        Class taskClass = NSClassFromString(className);
        if (!taskClass) {
            continue;
        }
        
        NSURLSessionTask *task = [taskClass alloc];
        if (!task) {
            continue;
        }
        
        XCTAssertFalse([task ft_isSupportedForInstrumentation],
                       @"%@ should not be instrumented", className);
    }
}
@end
