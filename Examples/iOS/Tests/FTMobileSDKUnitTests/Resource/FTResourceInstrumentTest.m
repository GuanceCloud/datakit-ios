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

@interface FTURLSessionInstrumentation()
- (BOOL)isFTIntakeRequest:(NSURLRequest *)request;
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
@end

@implementation FTURLSessionSnapshotRumResourceHandler
- (void)startResourceWithKey:(NSString *)key {
    self.startCount += 1;
}
- (void)startResourceWithKey:(NSString *)key property:(NSDictionary *)property {
    self.startCount += 1;
}
- (void)stopResourceWithKey:(NSString *)key {
    self.stopCount += 1;
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property {
    self.stopCount += 1;
    self.stopProperty = property;
}
- (void)addResourceWithKey:(NSString *)key metrics:(FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content {
    self.content = content;
    self.metrics = metrics;
    self.addCount += 1;
}
- (void)addResourceWithKey:(NSString *)key metrics:(FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(NSString *)spanID traceID:(NSString *)traceID {
    self.content = content;
    self.metrics = metrics;
    self.spanID = spanID;
    self.traceID = traceID;
    self.addCount += 1;
}
@end

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
