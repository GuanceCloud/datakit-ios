//
//  FTResourceAutoTrace.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/24.
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
#import "XCTestCase+Utils.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager+Private.h"
#import "FTTrackerEventDBTool.h"
#import "FTConstants.h"
#import "FTRUMManager.h"
#import "TestSessionDelegate.h"
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "FTSessionConfiguration.h"
#import "FTURLSessionInstrumentation.h"
#import "OHHTTPStubs.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLConnectionInstrumentation.h"
#import "FTTraceContext.h"
#import <objc/runtime.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>
@interface FTURLSessionInterceptor()
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@interface FTResourceAutoTrace : XCTestCase

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface FTURLConnectionGapDelegate : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong) XCTestExpectation *completionExpectation;
@property (nonatomic, strong, nullable) NSError *error;
@property (nonatomic, strong, nullable) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, assign) NSUInteger responseCalls;
@property (nonatomic, assign) NSUInteger dataCalls;
@property (nonatomic, assign) NSUInteger finishCalls;
@property (nonatomic, assign) NSUInteger failureCalls;
@property (nonatomic, strong, nullable) NSThread *lastCallbackThread;
@property (nonatomic, copy, nullable) void (^dataCallback)(void);
@property (nonatomic, copy, nullable) void (^finishCallback)(void);
@end

@implementation FTURLConnectionGapDelegate
- (instancetype)init {
    self = [super init];
    if (self) {
        _data = [NSMutableData data];
    }
    return self;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.lastCallbackThread = NSThread.currentThread;
    self.response = response;
    self.responseCalls += 1;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    self.lastCallbackThread = NSThread.currentThread;
    self.dataCalls += 1;
    [self.data appendData:data];
    if (self.dataCallback) self.dataCallback();
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.lastCallbackThread = NSThread.currentThread;
    self.finishCalls += 1;
    if (self.finishCallback) self.finishCallback();
    [self.completionExpectation fulfill];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.lastCallbackThread = NSThread.currentThread;
    self.error = error;
    self.failureCalls += 1;
    [self.completionExpectation fulfill];
}
@end

@interface FTURLConnectionIntegrationClock : NSObject <FTURLConnectionClock>
@property (atomic, strong) NSDate *currentDate;
@property (atomic, assign) uint64_t currentContinuousTime;
@end

@implementation FTURLConnectionIntegrationClock
- (NSDate *)date { return self.currentDate; }
- (uint64_t)continuousTime { return self.currentContinuousTime; }
@end

// Creator 2.x's HttpAsynConnection implements these four observations and
// authentication, but no redirect or upload-progress method. Keep this separate
// from the general fixture so other tests cannot pre-install its missing methods.
@interface FTURLConnectionCocosHTTPDelegate : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSThread *expectedThread;
@property (nonatomic, assign) NSUInteger responseCalls;
@property (nonatomic, assign) NSUInteger finishCalls;
@property (nonatomic, assign) NSUInteger failureCalls;
@property (nonatomic, copy) void (^onTerminal)(void);
@end
@implementation FTURLConnectionCocosHTTPDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    XCTAssertEqual(NSThread.currentThread, self.expectedThread);
    self.responseCalls++;
    self.response = response;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    XCTAssertEqual(NSThread.currentThread, self.expectedThread);
    [self.data appendData:data];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    XCTAssertEqual(NSThread.currentThread, self.expectedThread);
    self.finishCalls++;
    self.onTerminal();
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    XCTAssertEqual(NSThread.currentThread, self.expectedThread);
    self.error = error;
    self.failureCalls++;
    self.onTerminal();
}
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
}
@end

@interface FTURLConnectionLoopbackHTTPServer : NSObject
@property (atomic, assign) BOOL running;
@property (nonatomic, assign) int listener;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *requests;
@property (nonatomic, copy, nullable) void (^beforeResponse)(NSString *path);
- (BOOL)start;
- (void)stop;
- (NSURL *)URLForPath:(NSString *)path;
- (nullable NSDictionary *)requestForPath:(NSString *)path;
- (void)handleClient:(int)client;
@end

@implementation FTURLConnectionLoopbackHTTPServer
- (instancetype)init {
    self = [super init];
    if (self) {
        _listener = -1;
        _serverQueue = dispatch_queue_create("com.ft.urlconnection.loopback-http", DISPATCH_QUEUE_SERIAL);
        _lock = [NSLock new];
        _requests = [NSMutableDictionary dictionary];
    }
    return self;
}
- (BOOL)start {
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) {
        return NO;
    }
    int enabled = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));
#ifdef SO_NOSIGPIPE
    setsockopt(listener, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled));
#endif
    struct sockaddr_in address = {0};
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_port = 0;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(listener, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(listener, 8) != 0) {
        close(listener);
        return NO;
    }
    socklen_t addressLength = sizeof(address);
    if (getsockname(listener, (struct sockaddr *)&address, &addressLength) != 0) {
        close(listener);
        return NO;
    }
    self.listener = listener;
    self.port = ntohs(address.sin_port);
    self.running = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.serverQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        while (self.running) {
            int client = accept(self.listener, NULL, NULL);
            if (client < 0) {
                continue;
            }
            [self handleClient:client];
            close(client);
        }
    });
    return YES;
}
- (void)handleClient:(int)client {
    NSMutableData *received = [NSMutableData data];
    NSUInteger expectedLength = NSNotFound;
    while (received.length < 1024 * 1024) {
        uint8_t buffer[4096];
        ssize_t count = recv(client, buffer, sizeof(buffer), 0);
        if (count <= 0) {
            break;
        }
        [received appendBytes:buffer length:(NSUInteger)count];
        NSData *separator = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        NSRange separatorRange = [received rangeOfData:separator options:0 range:NSMakeRange(0, received.length)];
        if (separatorRange.location == NSNotFound) {
            continue;
        }
        if (expectedLength == NSNotFound) {
            NSData *headerData = [received subdataWithRange:NSMakeRange(0, separatorRange.location)];
            NSString *headerText = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
            expectedLength = separatorRange.location + separatorRange.length;
            for (NSString *line in [headerText componentsSeparatedByString:@"\r\n"]) {
                if ([line.lowercaseString hasPrefix:@"content-length:"]) {
                    expectedLength += [[[line componentsSeparatedByString:@":"] lastObject] integerValue];
                }
            }
        }
        if (received.length >= expectedLength) {
            break;
        }
    }
    NSData *separator = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSRange separatorRange = [received rangeOfData:separator options:0 range:NSMakeRange(0, received.length)];
    if (separatorRange.location == NSNotFound) {
        return;
    }
    NSString *headerText = [[NSString alloc] initWithData:[received subdataWithRange:NSMakeRange(0, separatorRange.location)]
                                                  encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [headerText componentsSeparatedByString:@"\r\n"];
    NSArray<NSString *> *requestLine = [lines.firstObject componentsSeparatedByString:@" "];
    NSString *method = requestLine.count > 0 ? requestLine[0] : @"";
    NSString *path = requestLine.count > 1 ? requestLine[1] : @"/";
    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    for (NSUInteger index = 1; index < lines.count; index++) {
        NSRange colon = [lines[index] rangeOfString:@":"];
        if (colon.location != NSNotFound) {
            NSString *key = [[lines[index] substringToIndex:colon.location] lowercaseString];
            NSString *value = [[lines[index] substringFromIndex:colon.location + 1]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            headers[key] = value;
        }
    }
    NSUInteger bodyOffset = NSMaxRange(separatorRange);
    NSData *body = received.length > bodyOffset ? [received subdataWithRange:NSMakeRange(bodyOffset, received.length - bodyOffset)] : NSData.data;
    [self.lock lock];
    self.requests[path] = @{@"method": method, @"headers": headers, @"body": body};
    [self.lock unlock];

    BOOL redirect = [path isEqualToString:@"/cocos-redirect"];
    NSInteger status = redirect ? 302 : ([path isEqualToString:@"/post"] ? 201 : 200);
    NSData *responseBody = redirect ? NSData.data : [[NSString stringWithFormat:@"real%@", path] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *statusText = redirect ? @"Found" : (status == 201 ? @"Created" : @"OK");
    NSString *location = redirect ? @"Location: /cocos-final\r\n" : @"";
    NSString *responseHeader = [NSString stringWithFormat:@"HTTP/1.1 %ld %@\r\nContent-Type: text/plain\r\nContent-Length: %lu\r\n%@Connection: close\r\n\r\n",
                                (long)status, statusText, (unsigned long)responseBody.length, location];
    NSMutableData *response = [[responseHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [response appendData:responseBody];
    if (self.beforeResponse) self.beforeResponse(path);
    const uint8_t *bytes = response.bytes;
    NSUInteger sent = 0;
    while (sent < response.length) {
        ssize_t count = send(client, bytes + sent, response.length - sent, 0);
        if (count <= 0) {
            break;
        }
        sent += (NSUInteger)count;
    }
}
- (NSURL *)URLForPath:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu%@", self.port, path]];
}
- (NSDictionary *)requestForPath:(NSString *)path {
    [self.lock lock];
    NSDictionary *request = self.requests[path];
    [self.lock unlock];
    return request;
}
- (void)stop {
    self.running = NO;
    int listener = self.listener;
    self.listener = -1;
    if (listener >= 0) {
        shutdown(listener, SHUT_RDWR);
        close(listener);
    }
}
- (void)dealloc {
    [self stop];
}
@end
#pragma clang diagnostic pop

@implementation FTResourceAutoTrace

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTSessionConfiguration defaultConfiguration] load];

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [FTMobileAgent clearAllData];
    [[FTSessionConfiguration defaultConfiguration] unload];

}
- (void)initSDKWithEnableAutoTraceResource:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.autoSync = NO;
    config.enableDataFilter = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = enable;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
}

- (void)initSDKWithURLConnectionResource:(BOOL)resourceEnabled
                                    trace:(BOOL)traceEnabled
                                     link:(BOOL)linkEnabled
                                 provider:(FTResourcePropertyProvider)provider
                              errorFilter:(FTSessionTaskErrorFilter)errorFilter
                              interceptor:(FTTraceInterceptor)interceptor {
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:processInfo.environment[@"ACCESS_SERVER_URL"]];
    config.autoSync = NO;
    config.enableDataFilter = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc] initWithAppid:processInfo.environment[@"APP_ID"]];
    rumConfig.enableTraceUserResource = NO;
    rumConfig.enableTraceURLConnectionResource = resourceEnabled;
    rumConfig.resourcePropertyProvider = provider;
    rumConfig.sessionTaskErrorFilter = errorFilter;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc] init];
    traceConfig.enableAutoTrace = NO;
    traceConfig.enableAutoTraceURLConnection = traceEnabled;
    traceConfig.enableLinkRumData = linkEnabled;
    traceConfig.traceInterceptor = interceptor;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}

- (void)initSDKWithBothNativeResourceCollectorsWithProvider:(FTResourcePropertyProvider)provider {
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:processInfo.environment[@"ACCESS_SERVER_URL"]];
    config.autoSync = NO;
    config.enableDataFilter = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc] initWithAppid:processInfo.environment[@"APP_ID"]];
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTraceURLConnectionResource = YES;
    rumConfig.resourcePropertyProvider = provider;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc] init];
    traceConfig.enableAutoTrace = YES;
    traceConfig.enableAutoTraceURLConnection = YES;
    traceConfig.enableLinkRumData = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}

- (void)syncURLConnectionResources {
    [[FTURLConnectionInstrumentation existingInstance] syncProcess];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
}

- (NSArray<NSDictionary *> *)urlConnectionResourcesForURL:(NSURL *)URL {
    NSMutableArray<NSDictionary *> *matches = [NSMutableArray array];
    [FTModelHelper resolveModelArray:[[FTTrackerEventDBTool sharedManager] getAllDatas]
                         timeCallBack:^(NSString *source, NSDictionary *tags, NSDictionary *fields, long long time, BOOL *stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] && [tags[FT_KEY_RESOURCE_URL] isEqualToString:URL.absoluteString]) {
            [matches addObject:@{@"tags": tags, @"fields": fields, @"time": @(time)}];
        }
    }];
    return matches;
}

- (void)testNSURLConnectionCreatesAutomaticResource {
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:nil errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startView];
    [FTModelHelper startAction];

    NSURL *URL = [NSURL URLWithString:@"https://urlconnection-gap.example.test/resource"];
    NSData *responseData = [@"urlconnection-response" dataUsingEncoding:NSUTF8StringEncoding];
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL isEqual:URL];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:responseData
                                          statusCode:200
                                             headers:@{@"Content-Type": @"application/json"}];
    }];

    FTURLConnectionGapDelegate *delegate = [FTURLConnectionGapDelegate new];
    delegate.completionExpectation = [self expectationWithDescription:@"NSURLConnection completion"];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                   delegate:delegate
                                                           startImmediately:NO];
    [connection start];
#pragma clang diagnostic pop

    [self waitForExpectations:@[delegate.completionExpectation] timeout:5];
    XCTAssertNil(delegate.error);

    [self syncURLConnectionResources];

    __block NSUInteger matchingResourceCount = 0;
    NSArray *records = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    [FTModelHelper resolveModelArray:records callBack:^(NSString *source, NSDictionary *tags, NSDictionary *fields, BOOL *stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE] &&
            [tags[FT_KEY_RESOURCE_URL] isEqualToString:URL.absoluteString]) {
            matchingResourceCount += 1;
        }
    }];
    XCTAssertEqual(matchingResourceCount, 1u);
    [OHHTTPStubs removeStub:stub];
}

- (void)testNSURLConnectionDelayedStartUsesActualNetworkBoundaries {
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:nil errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionDelayedStart"];
    NSURL *URL = [NSURL URLWithString:@"https://urlconnection.example.test/delayed-start"];
    NSData *body = [@"12345678" dataUsingEncoding:NSUTF8StringEncoding];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL isEqual:URL];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:body statusCode:200 headers:@{@"Content-Length": @"999"}];
    }];

    FTURLConnectionIntegrationClock *clock = [FTURLConnectionIntegrationClock new];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1600000000];
    clock.currentContinuousTime = 10;
    [[FTURLConnectionInstrumentation existingInstance] setValue:clock forKey:@"clock"];
    FTURLConnectionGapDelegate *delegate = [FTURLConnectionGapDelegate new];
    delegate.completionExpectation = [self expectationWithDescription:@"delayed connection finished"];
    delegate.dataCallback = ^{
        clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000004];
        clock.currentContinuousTime = 5000000000;
    };
    delegate.finishCallback = ^{
        clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000099];
        clock.currentContinuousTime = 100000000000;
    };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URL]
                                                                   delegate:delegate
                                                           startImmediately:NO];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
    clock.currentContinuousTime = 1000000000;
    [connection start];
#pragma clang diagnostic pop
    [self waitForExpectations:@[delegate.completionExpectation] timeout:5];
    [self syncURLConnectionResources];

    XCTAssertEqual(delegate.responseCalls, 1u);
    XCTAssertEqual(delegate.dataCalls, 1u);
    XCTAssertEqual(delegate.finishCalls, 1u);
    XCTAssertEqual(delegate.failureCalls, 0u);
    XCTAssertEqualObjects(delegate.data, body);
    NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:URL];
    XCTAssertEqual(resources.count, 1u);
    NSDictionary *resource = resources.firstObject;
    XCTAssertEqualObjects(resource[@"time"], @1700000000000000000LL);
    XCTAssertEqualObjects(resource[@"fields"][FT_DURATION], @4000000000LL);
    XCTAssertEqualObjects(resource[@"fields"][FT_KEY_RESOURCE_SIZE], @8);
    XCTAssertEqualObjects(resource[@"fields"][FT_KEY_RESOURCE_REQUEST_SIZE], @0);
    XCTAssertNil(resource[@"fields"][FT_KEY_RESOURCE_CONNECTION_REUSE]);
    XCTAssertNil(resource[@"fields"][FT_KEY_RESOURCE_DNS]);
    XCTAssertNil(resource[@"fields"][FT_KEY_RESOURCE_TCP]);
    XCTAssertNil(resource[@"fields"][FT_KEY_RESOURCE_SSL]);
    XCTAssertNil(resource[@"fields"][FT_KEY_RESOURCE_TTFB]);
}

- (void)testNSURLConnectionResourceAndTraceFourSwitchCombinations {
    for (NSNumber *resourceValue in @[@NO, @YES]) {
        for (NSNumber *traceValue in @[@NO, @YES]) {
            BOOL resourceEnabled = resourceValue.boolValue;
            BOOL traceEnabled = traceValue.boolValue;
            [self initSDKWithURLConnectionResource:resourceEnabled trace:traceEnabled link:YES provider:nil errorFilter:nil interceptor:nil];
            [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
            [FTModelHelper startViewWithName:@"URLConnectionSwitches"];
            NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://urlconnection.example.test/switch-%d-%d", resourceEnabled, traceEnabled]];
            __block NSURLRequest *observedRequest;
            [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
                return [request.URL isEqual:URL];
            } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
                observedRequest = request;
                return [OHHTTPStubsResponse responseWithData:[@"switch" dataUsingEncoding:NSUTF8StringEncoding]
                                                  statusCode:200
                                                     headers:nil];
            }];
            XCTestExpectation *completion = [self expectationWithDescription:@"async completion"];
            __block NSUInteger completionCalls = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:URL]
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                completionCalls += 1;
                XCTAssertNil(connectionError);
                XCTAssertEqualObjects(data, [@"switch" dataUsingEncoding:NSUTF8StringEncoding]);
                [completion fulfill];
            }];
#pragma clang diagnostic pop
            [self waitForExpectations:@[completion] timeout:5];
            [self syncURLConnectionResources];
            XCTAssertEqual(completionCalls, 1u);
            NSString *traceID = [observedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID];
            NSString *spanID = [observedRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID];
            XCTAssertEqual(traceID.length > 0, traceEnabled);
            XCTAssertEqual(spanID.length > 0, traceEnabled);
            NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:URL];
            XCTAssertEqual(resources.count, resourceEnabled ? 1u : 0u);
            if (resourceEnabled) {
                NSDictionary *tags = resources.firstObject[@"tags"];
                XCTAssertEqualObjects(tags[FT_KEY_TRACEID], traceEnabled ? traceID : nil);
                XCTAssertEqualObjects(tags[FT_KEY_SPANID], traceEnabled ? spanID : nil);
            }
            [FTMobileAgent shutDown];
            [FTMobileAgent clearAllData];
            [OHHTTPStubs removeAllStubs];
        }
    }
}

- (void)testNSURLConnectionAsyncCompletionQueueWaitIsExcludedFromDuration {
    XCTestExpectation *providerExpectation = [self expectationWithDescription:@"provider reached network terminal"];
    __block NSUInteger providerCalls = 0;
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        providerCalls += 1;
        XCTAssertNil(error);
        XCTAssertEqualObjects(data, [@"async-body" dataUsingEncoding:NSUTF8StringEncoding]);
        [providerExpectation fulfill];
        return @{@"async_provider": @YES};
    } errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionAsyncQueue"];
    NSURL *URL = [NSURL URLWithString:@"https://urlconnection.example.test/async-queue"];
    FTURLConnectionIntegrationClock *clock = [FTURLConnectionIntegrationClock new];
    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
    clock.currentContinuousTime = 1000000000;
    [[FTURLConnectionInstrumentation existingInstance] setValue:clock forKey:@"clock"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL isEqual:URL];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000003];
        clock.currentContinuousTime = 4000000000;
        return [OHHTTPStubsResponse responseWithData:[@"async-body" dataUsingEncoding:NSUTF8StringEncoding]
                                          statusCode:200
                                             headers:nil];
    }];
    NSOperationQueue *userQueue = [[NSOperationQueue alloc] init];
    userQueue.name = @"com.ft.urlconnection.user-completion";
    userQueue.suspended = YES;
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"user completion"];
    __block NSUInteger completionCalls = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:URL]
                                       queue:userQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        completionCalls += 1;
        [completionExpectation fulfill];
    }];
#pragma clang diagnostic pop
    [self waitForExpectations:@[providerExpectation] timeout:5];
    [self syncURLConnectionResources];
    XCTAssertEqual(providerCalls, 1u);
    XCTAssertEqual(completionCalls, 0u);
    NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:URL];
    XCTAssertEqual(resources.count, 1u);
    XCTAssertEqualObjects(resources.firstObject[@"fields"][FT_DURATION], @3000000000LL);
    XCTAssertEqualObjects(resources.firstObject[@"fields"][@"async_provider"], @YES);

    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000100];
    clock.currentContinuousTime = 101000000000;
    userQueue.suspended = NO;
    [self waitForExpectations:@[completionExpectation] timeout:5];
    XCTAssertEqual(completionCalls, 1u);
    [self syncURLConnectionResources];
    XCTAssertEqualObjects([self urlConnectionResourcesForURL:URL].firstObject[@"fields"][FT_DURATION], @3000000000LL);
}

- (void)testNSURLConnectionNilDelegateAndNilCompletionStillCollect {
    NSArray<NSURL *> *delegateURLs = @[
        [NSURL URLWithString:@"https://urlconnection.example.test/nil-delegate-init"],
        [NSURL URLWithString:@"https://urlconnection.example.test/nil-delegate-immediate"],
        [NSURL URLWithString:@"https://urlconnection.example.test/nil-delegate-delayed"],
        [NSURL URLWithString:@"https://urlconnection.example.test/nil-delegate-factory"],
    ];
    NSURL *completionURL = [NSURL URLWithString:@"https://urlconnection.example.test/nil-completion"];
    NSArray<NSURL *> *URLs = [delegateURLs arrayByAddingObject:completionURL];
    NSData *expectedData = [@"nil" dataUsingEncoding:NSUTF8StringEncoding];
    XCTestExpectation *providerExpectation = [self expectationWithDescription:@"one provider call per request"];
    providerExpectation.expectedFulfillmentCount = URLs.count;
    __block NSUInteger providerCalls = 0;
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        providerCalls += 1;
        XCTAssertTrue([URLs containsObject:request.URL]);
        XCTAssertEqual([(NSHTTPURLResponse *)response statusCode], 200);
        XCTAssertEqualObjects(data, expectedData);
        XCTAssertNil(error);
        [providerExpectation fulfill];
        return nil;
    } errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionNilCallbacks"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [URLs containsObject:request.URL];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:expectedData statusCode:200 headers:nil];
    }];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    __unused NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:delegateURLs[0]]
                                                                            delegate:nil];
    __unused NSURLConnection *immediateConnection = [[NSURLConnection alloc]
        initWithRequest:[NSURLRequest requestWithURL:delegateURLs[1]] delegate:nil startImmediately:YES];
    NSURLConnection *delayedConnection = [[NSURLConnection alloc]
        initWithRequest:[NSURLRequest requestWithURL:delegateURLs[2]] delegate:nil startImmediately:NO];
    [delayedConnection start];
    __unused NSURLConnection *factoryConnection = [NSURLConnection
        connectionWithRequest:[NSURLRequest requestWithURL:delegateURLs[3]] delegate:nil];
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:completionURL]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:nil];
#pragma clang diagnostic pop
    [self waitForExpectations:@[providerExpectation] timeout:5];
    [self syncURLConnectionResources];
    XCTAssertEqual(providerCalls, 5u);
    for (NSURL *URL in URLs) {
        NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:URL];
        XCTAssertEqual(resources.count, 1u);
        XCTAssertEqualObjects(resources.firstObject[@"fields"][FT_KEY_RESOURCE_SIZE], @3);
    }
}

- (void)testNSURLConnectionNeverStartedDoesNotCollectAndCancelTerminatesOnce {
    XCTestExpectation *cancelProvider = [self expectationWithDescription:@"cancel provider"];
    __block NSUInteger providerCalls = 0;
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        providerCalls += 1;
        XCTAssertEqual(error.code, NSURLErrorCancelled);
        [cancelProvider fulfill];
        return nil;
    } errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionCancel"];
    NSURL *unstartedURL = [NSURL URLWithString:@"https://urlconnection.example.test/unstarted"];
    NSURL *cancelURL = [NSURL URLWithString:@"https://urlconnection.example.test/cancel"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL isEqual:cancelURL];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[@"should-not-win" dataUsingEncoding:NSUTF8StringEncoding]
                                          statusCode:200
                                             headers:nil];
    }];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    @autoreleasepool {
        __unused NSURLConnection *unstarted = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:unstartedURL]
                                                                                delegate:nil
                                                                        startImmediately:NO];
    }
    NSURLConnection *cancelled = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:cancelURL]
                                                                   delegate:nil
                                                           startImmediately:NO];
    [cancelled start];
    [cancelled cancel];
    [cancelled cancel];
#pragma clang diagnostic pop
    [self waitForExpectations:@[cancelProvider] timeout:5];
    [self syncURLConnectionResources];
    XCTAssertEqual(providerCalls, 1u);
    XCTAssertEqual([self urlConnectionResourcesForURL:unstartedURL].count, 0u);
    XCTAssertEqual([self urlConnectionResourcesForURL:cancelURL].count, 1u);
}

- (void)testNSURLConnectionGETPOSTHTTPAndNetworkFailures {
    NSArray<NSString *> *paths = @[@"get", @"post", @"http-500", @"offline", @"timeout"];
    XCTestExpectation *providerExpectation = [self expectationWithDescription:@"all terminal providers"];
    providerExpectation.expectedFulfillmentCount = paths.count;
    NSMutableDictionary<NSString *, NSDictionary *> *observed = [NSMutableDictionary dictionary];
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        @synchronized (observed) {
            observed[request.URL.lastPathComponent] = @{
                @"method": request.HTTPMethod ?: @"",
                @"status": @([(NSHTTPURLResponse *)response statusCode]),
                @"bytes": @(data.length),
                @"error": error ? @(error.code) : NSNull.null,
            };
        }
        [providerExpectation fulfill];
        return nil;
    } errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionOutcomes"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"urlconnection-outcomes.example.test"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSString *path = request.URL.lastPathComponent;
        if ([path isEqualToString:@"offline"]) {
            return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
        }
        if ([path isEqualToString:@"timeout"]) {
            return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
        }
        NSInteger status = [path isEqualToString:@"http-500"] ? 500 : 200;
        NSData *data = [[NSString stringWithFormat:@"body-%@", path] dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:data statusCode:(int)status headers:nil];
    }];
    FTURLConnectionGapDelegate *delegate = [FTURLConnectionGapDelegate new];
    delegate.completionExpectation = [self expectationWithDescription:@"all delegate terminals"];
    delegate.completionExpectation.expectedFulfillmentCount = paths.count;
    NSMutableArray<NSURLConnection *> *connections = [NSMutableArray array];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (NSString *path in paths) {
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://urlconnection-outcomes.example.test/%@", path]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        if ([path isEqualToString:@"post"]) {
            request.HTTPMethod = @"POST";
            request.HTTPBody = [@"post-body" dataUsingEncoding:NSUTF8StringEncoding];
        }
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
        [connections addObject:connection];
    }
#pragma clang diagnostic pop
    [self waitForExpectations:@[delegate.completionExpectation, providerExpectation] timeout:5];
    [self syncURLConnectionResources];

    XCTAssertEqual(delegate.responseCalls, 3u);
    XCTAssertEqual(delegate.dataCalls, 3u);
    XCTAssertEqual(delegate.finishCalls, 3u);
    XCTAssertEqual(delegate.failureCalls, 2u);
    XCTAssertEqualObjects(observed[@"get"][@"method"], @"GET");
    XCTAssertEqualObjects(observed[@"post"][@"method"], @"POST");
    XCTAssertEqualObjects(observed[@"http-500"][@"status"], @500);
    XCTAssertEqualObjects(observed[@"offline"][@"error"], @(NSURLErrorNotConnectedToInternet));
    XCTAssertEqualObjects(observed[@"timeout"][@"error"], @(NSURLErrorTimedOut));
    for (NSString *path in paths) {
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://urlconnection-outcomes.example.test/%@", path]];
        NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:URL];
        XCTAssertEqual(resources.count, 1u, @"%@", path);
        if ([path isEqualToString:@"post"]) {
            XCTAssertEqualObjects(resources.firstObject[@"tags"][FT_KEY_RESOURCE_METHOD], @"POST");
            XCTAssertEqualObjects(resources.firstObject[@"fields"][FT_KEY_RESOURCE_REQUEST_SIZE], @9);
        }
    }
}

- (void)testNSURLConnectionInitializerAndFactoryEntriesHaveOneOwnerEach {
    XCTestExpectation *providerExpectation = [self expectationWithDescription:@"three resources"];
    providerExpectation.expectedFulfillmentCount = 3;
    [self initSDKWithURLConnectionResource:YES trace:NO link:NO provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        [providerExpectation fulfill];
        return nil;
    } errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionEntries"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"urlconnection-entries.example.test"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[@"entry" dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    FTURLConnectionGapDelegate *delegate = [FTURLConnectionGapDelegate new];
    delegate.completionExpectation = [self expectationWithDescription:@"three delegate terminals"];
    delegate.completionExpectation.expectedFulfillmentCount = 3;
    NSArray<NSURL *> *URLs = @[
        [NSURL URLWithString:@"https://urlconnection-entries.example.test/default-init"],
        [NSURL URLWithString:@"https://urlconnection-entries.example.test/immediate-init"],
        [NSURL URLWithString:@"https://urlconnection-entries.example.test/factory"],
    ];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    __unused NSURLConnection *defaultInit = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URLs[0]] delegate:delegate];
    __unused NSURLConnection *immediateInit = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URLs[1]] delegate:delegate startImmediately:YES];
    __unused NSURLConnection *factory = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:URLs[2]] delegate:delegate];
#pragma clang diagnostic pop
    [self waitForExpectations:@[delegate.completionExpectation, providerExpectation] timeout:5];
    [self syncURLConnectionResources];
    XCTAssertEqual(delegate.finishCalls, 3u);
    XCTAssertEqual(delegate.failureCalls, 0u);
    for (NSURL *URL in URLs) {
        XCTAssertEqual([self urlConnectionResourcesForURL:URL].count, 1u);
    }
}

- (void)testNSURLConnectionCrossOriginRedirectDoesNotLeakInjectedTraceHeaders {
    [self initSDKWithURLConnectionResource:YES trace:YES link:YES provider:nil errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionRedirect"];
    NSURL *startURL = [NSURL URLWithString:@"https://redirect-source.example.test/start"];
    NSURL *finalURL = [NSURL URLWithString:@"https://redirect-target.example.test/final"];
    __block NSURLRequest *sourceRequest;
    __block NSURLRequest *targetRequest;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host hasSuffix:@"example.test"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL isEqual:startURL]) {
            sourceRequest = request;
            return [OHHTTPStubsResponse responseWithData:NSData.data
                                              statusCode:302
                                                 headers:@{@"Location": finalURL.absoluteString}];
        }
        if ([request.URL isEqual:finalURL]) {
            targetRequest = request;
            return [OHHTTPStubsResponse responseWithData:[@"redirected" dataUsingEncoding:NSUTF8StringEncoding]
                                              statusCode:200
                                                 headers:nil];
        }
        return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil]];
    }];
    FTURLConnectionGapDelegate *delegate = [FTURLConnectionGapDelegate new];
    delegate.completionExpectation = [self expectationWithDescription:@"redirect finished"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    __unused NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:startURL]
                                                                            delegate:delegate];
#pragma clang diagnostic pop
    [self waitForExpectations:@[delegate.completionExpectation] timeout:5];
    [self syncURLConnectionResources];
    XCTAssertGreaterThan([sourceRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID].length, 0u);
    XCTAssertNil([targetRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID]);
    XCTAssertNil([targetRequest valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID]);
    NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:finalURL];
    XCTAssertEqual(resources.count, 1u);
    XCTAssertNil(resources.firstObject[@"tags"][FT_KEY_TRACEID]);
    XCTAssertNil(resources.firstObject[@"tags"][FT_KEY_SPANID]);
    XCTAssertEqual([self urlConnectionResourcesForURL:startURL].count, 0u);
}

- (void)testNSURLConnectionCocosStyleRunLoopAgainstRealHTTPServer {
    FTURLConnectionLoopbackHTTPServer *server = [FTURLConnectionLoopbackHTTPServer new];
    XCTAssertTrue([server start]);
    FTURLConnectionIntegrationClock *clock = [FTURLConnectionIntegrationClock new];
    FTTraceContext *context = [FTTraceContext new];
    context.traceHeader = @{FT_NETWORK_DDTRACE_TRACEID: @"123", FT_NETWORK_DDTRACE_SPANID: @"456"};
    [self initSDKWithURLConnectionResource:YES trace:YES link:YES provider:nil errorFilter:nil
                              interceptor:^FTTraceContext *(NSURLRequest *request) { return context; }];
    [[FTURLConnectionInstrumentation existingInstance] setValue:clock forKey:@"clock"];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"CocosNativeRunLoop"];
    SEL redirectSelector = @selector(connection:willSendRequest:redirectResponse:);
    SEL uploadSelector = @selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:);
    SEL authentication = @selector(connection:willSendRequestForAuthenticationChallenge:);
    Class delegateClass = FTURLConnectionCocosHTTPDelegate.class;
    IMP authenticationIMP = class_getMethodImplementation(delegateClass, authentication);
    IMP classIMP = class_getMethodImplementation(delegateClass, @selector(class));
    IMP respondsIMP = class_getMethodImplementation(delegateClass, @selector(respondsToSelector:));
    NSArray<NSDictionary *> *cases = @[
        @{@"start": @"/get", @"final": @"/get", @"method": @"GET", @"body": @"real/get", @"size": @8, @"status": @200},
        @{@"start": @"/post", @"final": @"/post", @"method": @"POST", @"body": @"real/post", @"size": @9, @"status": @201},
        @{@"start": @"/cocos-redirect", @"final": @"/cocos-final", @"method": @"GET", @"body": @"real/cocos-final", @"size": @16, @"status": @200},
    ];
    @try {
        for (NSDictionary *testCase in cases) {
            NSURL *startURL = [server URLForPath:testCase[@"start"]];
            NSURL *finalURL = [server URLForPath:testCase[@"final"]];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:startURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:3];
            request.HTTPMethod = testCase[@"method"];
            if ([request.HTTPMethod isEqualToString:@"POST"]) {
                request.HTTPBody = [@"native-post-body" dataUsingEncoding:NSUTF8StringEncoding];
                XCTAssertEqual(request.HTTPBody.length, 16u);
            }
            FTURLConnectionCocosHTTPDelegate *delegate = [FTURLConnectionCocosHTTPDelegate new];
            delegate.data = [NSMutableData data];
            XCTestExpectation *finished = [self expectationWithDescription:testCase[@"start"]];
            clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000000];
            clock.currentContinuousTime = 1000000000;
            // A controlled server event advances the fake clock before the final
            // response can arrive; no sleep or wall-clock duration assertion.
            server.beforeResponse = ^(NSString *path) {
                if ([path isEqualToString:testCase[@"final"]]) {
                    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000103];
                    clock.currentContinuousTime = 104000000000;
                }
            };
            delegate.onTerminal = ^{
                clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000200];
                clock.currentContinuousTime = 201000000000;
                CFRunLoopStop(CFRunLoopGetCurrent());
            };
            NSThread *thread = [[NSThread alloc] initWithBlock:^{
                @autoreleasepool {
                    delegate.expectedThread = NSThread.currentThread;
                    // This is the Creator 2.x native entry sequence, with the
                    // exact business object passed to Foundation throughout.
                    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate startImmediately:NO];
                    XCTAssertNotNil(connection);
                    XCTAssertEqual(object_getClass(delegate), delegateClass);
                    XCTAssertEqual(delegate.class, delegateClass);
                    XCTAssertTrue([delegate respondsToSelector:redirectSelector]);
                    XCTAssertTrue([delegate respondsToSelector:uploadSelector]);
                    XCTAssertEqual(class_getMethodImplementation(delegateClass, authentication), authenticationIMP);
                    XCTAssertEqual(class_getMethodImplementation(delegateClass, @selector(class)), classIMP);
                    XCTAssertEqual(class_getMethodImplementation(delegateClass, @selector(respondsToSelector:)), respondsIMP);
                    XCTAssertNil([server requestForPath:testCase[@"start"]]);
                    clock.currentDate = [NSDate dateWithTimeIntervalSince1970:1700000100];
                    clock.currentContinuousTime = 101000000000;
                    [connection scheduleInRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
                    [connection start];
                    if (delegate.finishCalls + delegate.failureCalls == 0) CFRunLoopRun();
                    [finished fulfill];
                }
            }];
            [thread start];
            [self waitForExpectations:@[finished] timeout:5];
            [self syncURLConnectionResources];
            XCTAssertNil(delegate.error);
            XCTAssertEqual(delegate.responseCalls, 1u);
            XCTAssertEqual(delegate.finishCalls, 1u);
            XCTAssertEqual(delegate.failureCalls, 0u);
            XCTAssertEqualObjects(delegate.data, [testCase[@"body"] dataUsingEncoding:NSUTF8StringEncoding]);
            XCTAssertEqualObjects(@(delegate.data.length), testCase[@"size"]);
            NSDictionary *received = [server requestForPath:testCase[@"final"]];
            XCTAssertEqualObjects(received[@"method"], testCase[@"method"]);
            XCTAssertEqualObjects(received[@"headers"][[FT_NETWORK_DDTRACE_TRACEID lowercaseString]], @"123");
            XCTAssertEqualObjects(received[@"headers"][[FT_NETWORK_DDTRACE_SPANID lowercaseString]], @"456");
            NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:finalURL];
            XCTAssertEqual(resources.count, 1u);
            NSDictionary *resource = resources.firstObject;
            XCTAssertEqualObjects(resource[@"tags"][FT_KEY_TRACEID], @"123");
            XCTAssertEqualObjects(resource[@"tags"][FT_KEY_SPANID], @"456");
            XCTAssertEqualObjects(resource[@"tags"][FT_KEY_RESOURCE_STATUS], testCase[@"status"]);
            XCTAssertEqualObjects(resource[@"fields"][FT_KEY_RESOURCE_SIZE], testCase[@"size"]);
            XCTAssertEqualObjects(resource[@"fields"][FT_DURATION], @3000000000LL);
            XCTAssertEqualObjects(resource[@"time"], @1700000100000000000LL);
            if ([request.HTTPMethod isEqualToString:@"POST"]) {
                XCTAssertEqualObjects(received[@"body"], request.HTTPBody);
                XCTAssertEqualObjects(resource[@"fields"][FT_KEY_RESOURCE_REQUEST_SIZE], @16);
            }
            if (![startURL isEqual:finalURL]) {
                XCTAssertEqual([self urlConnectionResourcesForURL:startURL].count, 0u);
            }
        }
    } @finally {
        [server stop];
    }
}

- (void)testNSURLConnectionAgainstRealLoopbackHTTPServer {
    FTURLConnectionLoopbackHTTPServer *server = [FTURLConnectionLoopbackHTTPServer new];
    XCTAssertTrue([server start]);
    XCTestExpectation *providerExpectation = [self expectationWithDescription:@"real HTTP resources"];
    providerExpectation.expectedFulfillmentCount = 2;
    [self initSDKWithURLConnectionResource:YES trace:YES link:YES provider:^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        XCTAssertNil(error);
        [providerExpectation fulfill];
        return nil;
    } errorFilter:nil interceptor:nil];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"URLConnectionRealHTTP"];
    NSURL *GETURL = [server URLForPath:@"/get"];
    NSURL *POSTURL = [server URLForPath:@"/post"];
    NSData *POSTBody = [@"native-post-body" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:@{
        NSHTTPCookieName: @"ft_urlconnection_cookie",
        NSHTTPCookieValue: @"preserved",
        NSHTTPCookieDomain: @"127.0.0.1",
        NSHTTPCookiePath: @"/",
    }];
    [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:cookie];
    FTURLConnectionGapDelegate *delegate = [FTURLConnectionGapDelegate new];
    delegate.completionExpectation = [self expectationWithDescription:@"real HTTP delegate completions"];
    delegate.completionExpectation.expectedFulfillmentCount = 2;
    NSMutableURLRequest *POSTRequest = [NSMutableURLRequest requestWithURL:POSTURL];
    POSTRequest.HTTPMethod = @"POST";
    POSTRequest.HTTPBody = POSTBody;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    __unused NSURLConnection *GETConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:GETURL]
                                                                                delegate:delegate];
    __unused NSURLConnection *POSTConnection = [[NSURLConnection alloc] initWithRequest:POSTRequest
                                                                                 delegate:delegate];
#pragma clang diagnostic pop
    [self waitForExpectations:@[delegate.completionExpectation, providerExpectation] timeout:5];
    [self syncURLConnectionResources];

    NSDictionary *GETRequest = [server requestForPath:@"/get"];
    NSDictionary *observedPOSTRequest = [server requestForPath:@"/post"];
    XCTAssertEqualObjects(GETRequest[@"method"], @"GET");
    XCTAssertEqualObjects(observedPOSTRequest[@"method"], @"POST");
    XCTAssertEqualObjects(observedPOSTRequest[@"body"], POSTBody);
    XCTAssertTrue([GETRequest[@"headers"][@"cookie"] containsString:@"ft_urlconnection_cookie=preserved"]);
    NSString *GETTraceID = GETRequest[@"headers"][[FT_NETWORK_DDTRACE_TRACEID lowercaseString]];
    NSString *GETSpanID = GETRequest[@"headers"][[FT_NETWORK_DDTRACE_SPANID lowercaseString]];
    XCTAssertGreaterThan(GETTraceID.length, 0u);
    XCTAssertGreaterThan(GETSpanID.length, 0u);
    NSArray<NSDictionary *> *GETResources = [self urlConnectionResourcesForURL:GETURL];
    NSArray<NSDictionary *> *POSTResources = [self urlConnectionResourcesForURL:POSTURL];
    XCTAssertEqual(GETResources.count, 1u);
    XCTAssertEqual(POSTResources.count, 1u);
    XCTAssertEqualObjects(GETResources.firstObject[@"tags"][FT_KEY_TRACEID], GETTraceID);
    XCTAssertEqualObjects(GETResources.firstObject[@"tags"][FT_KEY_SPANID], GETSpanID);
    XCTAssertEqualObjects(GETResources.firstObject[@"fields"][FT_KEY_RESOURCE_SIZE], @8);
    XCTAssertEqualObjects(POSTResources.firstObject[@"tags"][FT_KEY_RESOURCE_STATUS], @201);
    XCTAssertEqualObjects(POSTResources.firstObject[@"fields"][FT_KEY_RESOURCE_REQUEST_SIZE], @(POSTBody.length));
    XCTAssertEqual(delegate.finishCalls, 2u);
    XCTAssertEqual(delegate.failureCalls, 0u);
    XCTAssertTrue(delegate.lastCallbackThread.isMainThread);

    [NSHTTPCookieStorage.sharedHTTPCookieStorage deleteCookie:cookie];
    [server stop];
}

- (void)testNSURLConnectionAndNSURLSessionCollectExactlyOneResourceEachWhenConcurrent {
    XCTestExpectation *resourceProviderExpectation = [self expectationWithDescription:@"both collectors reached Resource provider"];
    resourceProviderExpectation.expectedFulfillmentCount = 2;
    [self initSDKWithBothNativeResourceCollectorsWithProvider:^NSDictionary *(NSURLRequest *request,
                                                                               NSURLResponse *response,
                                                                               NSData *data,
                                                                               NSError *error) {
        XCTAssertNil(error);
        [resourceProviderExpectation fulfill];
        return @{@"test_native_collector": [request valueForHTTPHeaderField:@"X-FT-Test-Collector"] ?: @"",
                 @"test_trace_id": [request valueForHTTPHeaderField:FT_NETWORK_DDTRACE_TRACEID] ?: @"",
                 @"test_span_id": [request valueForHTTPHeaderField:FT_NETWORK_DDTRACE_SPANID] ?: @""};
    }];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTModelHelper startViewWithName:@"ConcurrentNativeCollectors"];
    FTURLConnectionLoopbackHTTPServer *server = [FTURLConnectionLoopbackHTTPServer new];
    XCTAssertTrue([server start]);
    NSURL *URL = [server URLForPath:@"/concurrent"];
    NSData *body = [@"real/concurrent" dataUsingEncoding:NSUTF8StringEncoding];

    FTURLConnectionGapDelegate *connectionDelegate = [FTURLConnectionGapDelegate new];
    connectionDelegate.completionExpectation = [self expectationWithDescription:@"URLConnection completion"];
    XCTestExpectation *sessionExpectation = [self expectationWithDescription:@"URLSession completion"];
    NSMutableURLRequest *connectionRequest = [NSMutableURLRequest requestWithURL:URL];
    [connectionRequest setValue:@"urlconnection" forHTTPHeaderField:@"X-FT-Test-Collector"];
    NSMutableURLRequest *sessionRequest = [NSMutableURLRequest requestWithURL:URL];
    [sessionRequest setValue:@"urlsession" forHTTPHeaderField:@"X-FT-Test-Collector"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    __unused NSURLConnection *connection = [[NSURLConnection alloc]
        initWithRequest:connectionRequest
               delegate:connectionDelegate];
#pragma clang diagnostic pop
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:sessionRequest
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(data, body);
        [sessionExpectation fulfill];
    }];
    [task resume];

    [self waitForExpectations:@[connectionDelegate.completionExpectation,
                                sessionExpectation,
                                resourceProviderExpectation]
                         timeout:5];
    dispatch_sync([FTURLSessionInterceptor shared].queue, ^{});
    [self syncURLConnectionResources];
    NSArray<NSDictionary *> *resources = [self urlConnectionResourcesForURL:URL];
    XCTAssertEqual(resources.count, 2u);
    // URLConnection reports body bytes. URLSession keeps its existing
    // header-inclusive metric; derive that expectation from this HTTP fixture.
    NSData *expectedSessionHeader = [@"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 15\r\nConnection: close\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqual(body.length, 15u);
    XCTAssertEqual(expectedSessionHeader.length, 84u);
    NSMutableSet<NSString *> *collectors = [NSMutableSet set];
    for (NSDictionary *resource in resources) {
        NSDictionary *fields = resource[@"fields"];
        NSString *collector = fields[@"test_native_collector"];
        XCTAssertTrue(([@[@"urlconnection", @"urlsession"] containsObject:collector]));
        if (collector) [collectors addObject:collector];
        NSNumber *expectedBytes = [collector isEqualToString:@"urlconnection"] ? @15 : @(84 + 15);
        XCTAssertEqualObjects(fields[FT_KEY_RESOURCE_SIZE], expectedBytes);
        XCTAssertGreaterThan([fields[@"test_trace_id"] length], 0u);
        XCTAssertGreaterThan([fields[@"test_span_id"] length], 0u);
        XCTAssertEqualObjects(resource[@"tags"][FT_KEY_TRACEID], fields[@"test_trace_id"]);
        XCTAssertEqualObjects(resource[@"tags"][FT_KEY_SPANID], fields[@"test_span_id"]);
    }
    XCTAssertEqualObjects(collectors, ([NSSet setWithArray:@[@"urlconnection", @"urlsession"]]));
    XCTAssertEqual(connectionDelegate.finishCalls, 1u);
    [session finishTasksAndInvalidate];
    [server stop];
}

- (void)testAutoTraceResource_NoDelegate{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    [self networkUploadHandler:nil trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testDisableAutoTraceResource_NoDelegate{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    [self networkUploadHandler:nil trace:NO completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testURLSessionCreateBeforeSDKInit_NoDelegate{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session autoTrace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testAutoTraceResource_DelegateNoneMethod{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_None *delegate = [[TestSessionDelegate_None alloc]init];
    [self networkUploadHandler:delegate trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testDisableAutoTraceResource_DelegateNoneMethod{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_None *delegate = [[TestSessionDelegate_None alloc]init];
    [self networkUploadHandler:delegate trace:NO completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateNoneMethod{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_None *delegate = [[TestSessionDelegate_None alloc]init];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session autoTrace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testAutoTraceResource_DelegateAllMethod{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithCompletionHandler:^{
        [expectation fulfill];
    }];
    [self networkUploadHandler:delegate trace:YES completionHandler:nil];
}
- (void)testDisableAutoTraceResource_DelegateAllMethod{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithCompletionHandler:^{
        [expectation fulfill];
    }];
    [self networkUploadHandler:delegate trace:NO completionHandler:nil];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateAllMethod{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate *delegate = [[TestSessionDelegate alloc]initWithCompletionHandler:^{
        [expectation fulfill];
    }];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session autoTrace:YES completionHandler:nil];
}
- (void)testAutoTraceResource_DelegateNoCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_NoCollectingMetrics *delegate = [[TestSessionDelegate_NoCollectingMetrics alloc]initWithCompletionHandler:^{
        [expectation fulfill];
    }];
    [self networkUploadHandler:delegate trace:YES completionHandler:nil];
}
- (void)testDisableAutoTraceResource_DelegateNoCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_NoCollectingMetrics *delegate = [[TestSessionDelegate_NoCollectingMetrics alloc]initWithCompletionHandler:^{
        [expectation fulfill];
    }];
    [self networkUploadHandler:delegate trace:NO completionHandler:nil];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateNoCollectingMetrics{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_NoCollectingMetrics *delegate = [[TestSessionDelegate_NoCollectingMetrics alloc]initWithCompletionHandler:^{
        [expectation fulfill];
    }];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session autoTrace:YES completionHandler:nil];
}
- (void)testAutoTraceResource_DelegateOnlyCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:YES];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_OnlyCollectingMetrics *delegate = [[TestSessionDelegate_OnlyCollectingMetrics alloc]init];
    [self networkUploadHandler:delegate trace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
   
}
- (void)testDisableAutoTraceResource_DelegateOnlyCollectingMetrics{
    [self initSDKWithEnableAutoTraceResource:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_OnlyCollectingMetrics *delegate = [[TestSessionDelegate_OnlyCollectingMetrics alloc]init];
    [self networkUploadHandler:delegate trace:NO completionHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
}
- (void)testURLSessionCreateBeforeSDKInit_DelegateOnlyCollectingMetrics{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    TestSessionDelegate_OnlyCollectingMetrics *delegate = [[TestSessionDelegate_OnlyCollectingMetrics alloc]init];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    [self initSDKWithEnableAutoTraceResource:YES];
    [self networkUploadHandlerSession:session autoTrace:YES completionHandler:^(NSURLResponse *response, NSError *error) {
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
    [self networkUploadHandlerSession:session autoTrace:trace completionHandler:completionHandler];
}
- (void)networkUploadHandlerSession:(NSURLSession *)session autoTrace:(BOOL)trace completionHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    [FTModelHelper startView];
    [FTModelHelper startAction];
    
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
    [session finishTasksAndInvalidate];
    dispatch_sync([FTURLSessionInterceptor shared].queue, ^{});
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    __block NSInteger hasResCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResCount ++;
            XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_TCP]);
            
            NSNumber *dnsStart = @0;
            if([fields.allKeys containsObject:FT_KEY_RESOURCE_DNS]){
                XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_DNS_TIME]);
                dnsStart = fields[FT_KEY_RESOURCE_DNS_TIME][FT_KEY_START];
            }
            XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_CONNECT_TIME]);
            NSNumber *connectStart = fields[FT_KEY_RESOURCE_CONNECT_TIME][FT_KEY_START];
            XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_FIRST_BYTE_TIME]);
            NSNumber *firstByteStart = fields[FT_KEY_RESOURCE_FIRST_BYTE_TIME][FT_KEY_START];
            XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_DOWNLOAD_TIME]);
            NSNumber *downloadStart = fields[FT_KEY_RESOURCE_DOWNLOAD_TIME][FT_KEY_START];
            XCTAssertTrue(downloadStart.longValue>firstByteStart.longValue);
            XCTAssertTrue(firstByteStart.longValue>=connectStart.longValue);
            XCTAssertTrue(connectStart.longValue>=dnsStart.longValue);
            if ([tags[FT_KEY_RESOURCE_URL] hasPrefix:@"https:"]) {
                XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_SSL]);
                XCTAssertTrue([fields.allKeys containsObject:FT_KEY_RESOURCE_SSL_TIME]);
                NSNumber *sslStart = fields[FT_KEY_RESOURCE_SSL_TIME][FT_KEY_START];
                XCTAssertTrue(firstByteStart.longValue>=sslStart.longValue);
                XCTAssertTrue(sslStart.longValue>=connectStart.longValue);
            }
        }
    }];
    if(trace){
        XCTAssertTrue(hasResCount==1);
    }else{
        XCTAssertTrue(hasResCount==0);
    }
}
/**
 * verify: No crashes occur when calling network request during SDK shutdown.
 */
- (void)testSDKShutdown{
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[@"success" dataUsingEncoding:NSUTF8StringEncoding] statusCode:200 headers:nil];
    }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDK shutdown test"];
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t lifecycleQueue = dispatch_queue_create("com.ft.resource_auto_trace.lifecycle", DISPATCH_QUEUE_SERIAL);
    for (int i = 0; i<100; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self network:^{
                dispatch_group_leave(group);
            }];
        });
        dispatch_group_enter(group);
        dispatch_async(lifecycleQueue, ^{
            [FTMobileAgent shutDown];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self initSDK];
            });
            dispatch_group_leave(group);
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:nil];
    [OHHTTPStubs removeStub:stubs];
    [FTMobileAgent shutDown];
}
- (void)initSDK{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.autoSync = NO;
    config.enableDataFilter = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = YES;
    traceConfig.enableLinkRumData = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}
- (void)network:(void (^)(void))callback{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSString * urlStr = @"https://httpbin.org/status/200";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(callback) callback();
    }];
    [task resume];
    [session finishTasksAndInvalidate];
}
@end
