//
//  FTViewTimingMetricsTests.m
//  FTMobileAgent
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTAutoTrackHandler.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTRUMContext.h"
#import "FTResourceMetricsModel.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTRUMViewMetrics.h"
#import "FTRUMNetworkSettledMetric.h"
#import "FTRUMDependencies.h"
#import "FTRUMManager.h"
#import "FTRumConfig.h"
#import "FTGlobalRumManager+Private.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTDataWriterWorker.h"
#import "FTDataFilterManager.h"
#import "FTURLConnectionHandler.h"
#import "FTURLSessionInstrumentation.h"
#import "FTReadWriteHelper.h"
#if __has_include("OHHTTPStubs.h")
#import "OHHTTPStubs.h"
#endif
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>

@interface UIViewController (AppearanceReentryTesting)
+ (BOOL)ft_installViewControllerLifecycleSwizzlesForClass:(Class)controllerClass;
@end
@interface FTAppearanceOrderBase : UIViewController
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end
@implementation FTAppearanceOrderBase
- (void)viewDidAppear:(BOOL)animated {
    [self.events addObject:@"base-before"];
    [super viewDidAppear:animated];
    [self.events addObject:@"base-after"];
}
@end
@interface FTAppearanceOrderChild : FTAppearanceOrderBase
@end
@implementation FTAppearanceOrderChild
- (void)viewDidAppear:(BOOL)animated {
    [self.events addObject:@"child-before"];
    [super viewDidAppear:animated];
    [self.events addObject:@"child-after"];
}
@end
@interface FTAppearanceOrderNoSuper : FTAppearanceOrderBase
@end
@implementation FTAppearanceOrderNoSuper
- (void)viewDidAppear:(BOOL)animated { [self.events addObject:@"no-super"]; }
@end
@interface FTAppearanceOrderThrowing : FTAppearanceOrderBase
@property (nonatomic, assign) BOOL throwsOnAppearance;
@end
@implementation FTAppearanceOrderThrowing
- (void)viewDidAppear:(BOOL)animated {
    [self.events addObject:@"business"];
    if (self.throwsOnAppearance) [NSException raise:@"appearance-test" format:@"test exception"];
}
@end
@interface FTAppearanceOrderSpy : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end
@implementation FTAppearanceOrderSpy
- (void)notify_viewDidAppear:(UIViewController *)controller animated:(BOOL)animated { [self.events addObject:@"sdk"]; }
@end

static long long const FTMetricEpoch = 1800000000000000000LL;

@interface FTMetricPredicate : NSObject <FTRUMNetworkSettledResourcePredicate>
@property (nonatomic, copy) BOOL (^evaluate)(FTRUMNetworkSettledResourceParams *params);
@property (nonatomic, assign) NSUInteger calls;
@end
@implementation FTMetricPredicate
- (BOOL)isInitialResource:(FTRUMNetworkSettledResourceParams *)params {
    self.calls += 1;
    return self.evaluate(params);
}
@end

@interface FTINVPredicate : NSObject <FTRUMNextViewActionPredicate>
@property (nonatomic, copy) BOOL (^evaluate)(FTRUMNextViewActionParams *params);
@end
@implementation FTINVPredicate
- (BOOL)isLastAction:(FTRUMNextViewActionParams *)params { return self.evaluate(params); }
@end

@interface FTGlobalRumManager (PredicateConfigTests)
- (FTRUMDependencies *)dependenciesWithRumConfig:(FTRumConfig *)config writer:(id)writer monitor:(id)monitor errorInfoWrapper:(id)wrapper;
@end

@interface FTMetricWriter : NSObject <FTRUMDataWriteProtocol>
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *events;
@property (nonatomic, copy) NSString *discardAction;
@property (nonatomic, copy) NSString *discardResource;
@property (nonatomic, strong) FTDataWriterWorker *admissionWriter;
@end
@implementation FTMetricWriter
- (instancetype)init { if ((self = [super init])) _events = [NSMutableArray new]; return self; }
- (BOOL)rumWriteAccepted:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)context time:(long long)time {
    if (([source isEqual:@"action"] && [tags[@"action_name"] isEqual:self.discardAction]) ||
        ([source isEqual:@"resource"] && [tags[@"resource_id"] isEqual:self.discardResource])) return NO;
    if (self.admissionWriter && ![self.admissionWriter rumWriteAccepted:source tags:tags fields:fields dynamicContext:context time:time]) return NO;
    [self rumWrite:source tags:tags fields:fields dynamicContext:context time:time];
    return YES;
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)context time:(long long)time {
    [self.events addObject:@{@"source":source, @"tags":tags ?: @{}, @"fields":[fields copy], @"time":@(time)}];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)context time:(long long)time updateTime:(long long)updateTime {
    [self rumWrite:source tags:tags fields:fields dynamicContext:context time:time];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)context time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache {
    [self rumWrite:source tags:tags fields:fields dynamicContext:context time:time];
}
- (void)rumWriteAssembledData:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time {}
@end

@interface FTURLSessionInterceptor (MetricTestClock)
- (NSDate *)resourceBoundaryDate;
- (uint64_t)resourceBoundaryContinuousTime;
@end
@interface FTMetricInterceptor : FTURLSessionInterceptor
@property (nonatomic, strong) NSDate *boundaryDate;
@property (nonatomic, assign) uint64_t boundaryTime;
@end
@implementation FTMetricInterceptor
- (NSDate *)resourceBoundaryDate { return self.boundaryDate; }
- (uint64_t)resourceBoundaryContinuousTime { return self.boundaryTime; }
@end
@interface FTMetricTask : NSURLSessionTask
@end
@implementation FTMetricTask
- (NSURLRequest *)currentRequest { return [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.test/resource"]]; }
- (NSURLResponse *)response { return [[NSHTTPURLResponse alloc] initWithURL:self.currentRequest.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}]; }
@end

@interface FTMetricImageServer : NSObject
@property int listener;
@property uint16_t port;
- (BOOL)start;
- (void)stop;
@end
@implementation FTMetricImageServer
- (BOOL)start {
    self.listener = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address = {0};
    address.sin_len = sizeof(address); address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(self.listener, (struct sockaddr *)&address, sizeof(address)) || listen(self.listener, 4)) return NO;
    socklen_t length = sizeof(address);
    getsockname(self.listener, (struct sockaddr *)&address, &length);
    self.port = ntohs(address.sin_port);
    int listener = self.listener;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (NSUInteger i = 0; i < 2; i++) {
            int client = accept(listener, NULL, NULL);
            if (client < 0) break;
            int enabled = 1; setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled));
            char buffer[4096]; recv(client, buffer, sizeof(buffer), 0);
            NSData *body = [[NSData alloc] initWithBase64EncodedString:@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9XkAAAAASUVORK5CYII=" options:0];
            NSString *header = i == 0 ? @"HTTP/1.1 302 Found\r\nLocation: /final.png\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" : [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", (unsigned long)body.length];
            NSMutableData *response = [[header dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
            if (i != 0) [response appendData:body];
            NSUInteger sent = 0;
            while (sent < response.length) { ssize_t count = send(client, (char *)response.bytes + sent, response.length - sent, 0); if (count <= 0) break; sent += count; }
            close(client);
        }
    });
    return YES;
}
- (void)stop { shutdown(self.listener, SHUT_RDWR); close(self.listener); }
@end

@interface FTViewTimingMetricsTests : XCTestCase
@property (nonatomic, strong) FTMetricWriter *writer;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTRUMSessionHandler *session;
@end
@implementation FTViewTimingMetricsTests
- (void)testResourceStartDoesNotWaitForTraceHandlerStorage {
    FTMetricInterceptor *interceptor = [FTMetricInterceptor new];
    interceptor.boundaryDate = [NSDate date];
    interceptor.boundaryTime = 20000000;
    FTReadWriteHelper *storage = [interceptor valueForKey:@"traceHandlers"];
    dispatch_queue_t storageQueue = [storage valueForKey:@"concurrentQueue"];
    dispatch_queue_t collectorQueue = [interceptor valueForKey:@"queue"];
    FTMetricTask *task = [FTMetricTask new];
    XCTestExpectation *returned = [self expectationWithDescription:@"request start does not depend on storage queue progress"];
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    dispatch_suspend(storageQueue);
    [storage concurrentWrite:^(id value) {}];
    XCTWaiterResult result;
    @try {
        [NSThread detachNewThreadWithBlock:^{
            [interceptor interceptTask:task];
            [returned fulfill];
            dispatch_semaphore_signal(finished);
        }];
        result = [XCTWaiter waitForExpectations:@[returned] timeout:1];
    } @finally {
        dispatch_resume(storageQueue);
    }
    XCTAssertEqual(result, XCTWaiterResultCompleted);
    XCTAssertEqual(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0L);
    dispatch_sync(collectorQueue, ^{});
    [interceptor shutDown];
}

- (void)testSessionStateOmitsRemovedProcessStartTime {
    FTRUMContext *context = [[FTRUMContext alloc] initWithSampleRate:100 sessionOnErrorSampleRate:0 appId:@"test-app"];
    FTRUMSessionState *state = context.sessionState;
    state.session_start_reason = FT_RUM_SESSION_START_REASON_SDK_INIT;
    XCTAssertNil(state.sessionFields[@"process_start_time_ns"]);
    XCTAssertNil([state toDictionary][@"process_start_time_ns"]);
    XCTAssertNil([[state copy] sessionFields][@"process_start_time_ns"]);

    NSMutableDictionary *legacy = [[state toDictionary] mutableCopy];
    legacy[@"process_start_time_ns"] = @1800000000000000000LL;
    FTRUMSessionState *restored = [[FTRUMSessionState alloc] initWithDict:legacy];
    XCTAssertNil(restored.sessionFields[@"process_start_time_ns"]);
    XCTAssertNil([restored toDictionary][@"process_start_time_ns"]);
    XCTAssertEqualObjects(restored, state);
    XCTAssertEqualObjects(restored.session_start_reason, FT_RUM_SESSION_START_REASON_SDK_INIT);
}

- (NSDate *)date:(NSInteger)ms { return [NSDate dateWithTimeIntervalSince1970:(FTMetricEpoch + ms * 1000000LL) / 1e9]; }
- (void)setUp {
    self.writer = [FTMetricWriter new];
    self.dependencies = [FTRUMDependencies new];
    self.dependencies.sampleRate = 100;
    self.dependencies.writer = self.writer;
    self.dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"foreground" timeNs:FTMetricEpoch - 1000000000];
    FTRUMDataModel *initial = [[FTRUMDataModel alloc] initWithType:FTRUMViewPlaceholder time:[self date:0]];
    self.session = [[FTRUMSessionHandler alloc] initWithModel:initial dependencies:self.dependencies];
}
- (void)send:(FTRUMDataModel *)model at:(NSInteger)ms {
    model.time = [self date:ms];
    model.tm = FTMetricEpoch + ms * 1000000LL;
    [self.session.assistant process:model context:@{}];
}
- (void)view:(NSString *)identifier at:(NSInteger)ms stop:(BOOL)stop {
    FTRUMViewModel *model = [[FTRUMViewModel alloc] initWithViewID:identifier viewName:@"same-name" viewReferrer:@""];
    model.type = stop ? FTRUMDataViewStop : FTRUMDataViewStart;
    [self send:model at:ms];
}
- (void)click:(NSString *)name at:(NSInteger)ms type:(NSString *)type {
    FTRUMActionModel *model = [[FTRUMActionModel alloc] initWithActionName:name actionType:type];
    model.type = FTRUMDataAddAction;
    [self send:model at:ms];
}
- (void)resource:(NSString *)key type:(FTRUMDataType)type at:(NSInteger)ms metrics:(FTResourceMetricsModel *)metrics {
    FTRUMResourceDataModel *model = [[FTRUMResourceDataModel alloc] initWithType:type identifier:key];
    model.metrics = metrics;
    [self send:model at:ms];
}
- (NSDictionary *)fields:(NSString *)view {
    for (NSDictionary *event in self.writer.events.reverseObjectEnumerator) {
        if ([event[@"source"] isEqual:@"view"] && [event[@"tags"][@"view_id"] isEqual:view]) return event[@"fields"];
    }
    return @{};
}
- (FTResourceMetricsModel *)metricsFrom:(NSInteger)start to:(NSInteger)end {
    FTResourceMetricsModel *metrics = [FTResourceMetricsModel new];
    metrics.fetchStartNsTimeInterval = FTMetricEpoch + start * 1000000LL;
    metrics.fetchEndNsTimeInterval = FTMetricEpoch + end * 1000000LL;
    return metrics;
}
- (void)testAppearanceReportsBeforeBusinessCallbackAndDeduplicatesSuperclassHooks {
    XCTAssertTrue([UIViewController ft_installViewControllerLifecycleSwizzlesForClass:FTAppearanceOrderBase.class]);
    XCTAssertTrue([UIViewController ft_installViewControllerLifecycleSwizzlesForClass:FTAppearanceOrderChild.class]);
    FTAutoTrackHandler *handler = [FTAutoTrackHandler sharedInstance];
    id previous = [handler valueForKey:@"viewControllerHandler"];
    FTAppearanceOrderSpy *spy = [FTAppearanceOrderSpy new];
    spy.events = [NSMutableArray new];
    [handler setValue:spy forKey:@"viewControllerHandler"];
    @try {
        FTAppearanceOrderChild *controller = [FTAppearanceOrderChild new];
        controller.events = spy.events;
        [controller viewDidAppear:NO];
        XCTAssertEqualObjects(spy.events, (@[@"sdk", @"child-before", @"base-before", @"base-after", @"child-after"]));
        [spy.events removeAllObjects];
        [controller viewDidAppear:NO];
        XCTAssertEqualObjects(spy.events, (@[@"sdk", @"child-before", @"base-before", @"base-after", @"child-after"]));
    } @finally { [handler setValue:previous forKey:@"viewControllerHandler"]; }
}
- (void)testAppearanceWithoutSuperStillReportsBeforeBusinessCallback {
    XCTAssertTrue([UIViewController ft_installViewControllerLifecycleSwizzlesForClass:FTAppearanceOrderNoSuper.class]);
    FTAutoTrackHandler *handler = [FTAutoTrackHandler sharedInstance];
    id previous = [handler valueForKey:@"viewControllerHandler"];
    FTAppearanceOrderSpy *spy = [FTAppearanceOrderSpy new];
    spy.events = [NSMutableArray new];
    [handler setValue:spy forKey:@"viewControllerHandler"];
    @try {
        FTAppearanceOrderNoSuper *controller = [FTAppearanceOrderNoSuper new];
        controller.events = spy.events;
        [controller viewDidAppear:NO];
        XCTAssertEqualObjects(spy.events, (@[@"sdk", @"no-super"]));
    } @finally { [handler setValue:previous forKey:@"viewControllerHandler"]; }
}
- (void)testAppearanceExceptionRestoresDepthForTheNextAppearance {
    XCTAssertTrue([UIViewController ft_installViewControllerLifecycleSwizzlesForClass:FTAppearanceOrderThrowing.class]);
    FTAutoTrackHandler *handler = [FTAutoTrackHandler sharedInstance];
    id previous = [handler valueForKey:@"viewControllerHandler"];
    FTAppearanceOrderSpy *spy = [FTAppearanceOrderSpy new];
    spy.events = [NSMutableArray new];
    [handler setValue:spy forKey:@"viewControllerHandler"];
    @try {
        FTAppearanceOrderThrowing *controller = [FTAppearanceOrderThrowing new];
        controller.events = spy.events;
        controller.throwsOnAppearance = YES;
        XCTAssertThrowsSpecificNamed([controller viewDidAppear:NO], NSException, @"appearance-test");
        XCTAssertEqualObjects(spy.events, (@[@"sdk", @"business"]));
        [spy.events removeAllObjects];
        controller.throwsOnAppearance = NO;
        [controller viewDidAppear:NO];
        XCTAssertEqualObjects(spy.events, (@[@"sdk", @"business"]));
    } @finally { [handler setValue:previous forKey:@"viewControllerHandler"]; }
}
- (void)testINVFirstStartedActionNavigatesWithoutOtherEvents {
    for (NSNumber *delay in @[@50, @200]) {
        [self setUp];
        [self view:@"first-page" at:0 stop:NO];
        FTRUMActionModel *click = [[FTRUMActionModel alloc] initWithActionName:@"first-click" actionType:@"click"];
        click.type = FTRUMDataStartAction;
        [self send:click at:800];
        [self view:@"second-page" at:800 + delay.integerValue stop:NO];
        XCTAssertEqualObjects([self fields:@"second-page"][@"interaction_to_next_view_time"], @(delay.longLongValue * 1000000LL));
    }
}
- (void)testINVFirstStartedActionSurvivesExplicitViewStop {
    [self view:@"first-page" at:0 stop:NO];
    FTRUMActionModel *click = [[FTRUMActionModel alloc] initWithActionName:@"first-click" actionType:@"click"];
    click.type = FTRUMDataStartAction;
    [self send:click at:800];
    [self view:@"first-page" at:850 stop:YES];
    [self view:@"second-page" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"second-page"][@"interaction_to_next_view_time"], @200000000);
}
- (void)testINVFirstNavigationAfterColdLaunchReport {
    [self view:@"home" at:0 stop:NO];
    FTRUMLaunchDataModel *launch = [[FTRUMLaunchDataModel alloc] initWithDuration:@500000000];
    launch.action_name = @"app_cold_start";
    launch.action_type = FT_LAUNCH_COLD;
    [self send:launch at:0];
    FTRUMActionModel *click = [[FTRUMActionModel alloc] initWithActionName:@"first-navigation" actionType:@"click"];
    click.type = FTRUMDataStartAction;
    [self send:click at:800];
    [self view:@"destination" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"destination"][@"interaction_to_next_view_time"], @200000000);
}
- (void)testINVExampleFirstNavigationLogReplay {
    void (^sendAt)(FTRUMDataModel *, long long) = ^(FTRUMDataModel *model, long long ns) {
        model.time = [NSDate dateWithTimeIntervalSince1970:ns / 1e9];
        model.tm = ns;
        [self.session.assistant process:model context:@{}];
    };
    FTRUMViewModel *(^view)(NSString *, BOOL) = ^FTRUMViewModel *(NSString *identifier, BOOL stop) {
        FTRUMViewModel *model = [[FTRUMViewModel alloc] initWithViewID:identifier viewName:@"UITestVC" viewReferrer:@""];
        model.type = stop ? FTRUMDataViewStop : FTRUMDataViewStart;
        return model;
    };
    // Exact event timestamps from the reported example navigation.
    sendAt(view(@"home", NO), 1792152202551974912LL);
    FTRUMLaunchDataModel *launch = [[FTRUMLaunchDataModel alloc] initWithDuration:@68587731122LL];
    launch.action_name = @"app_cold_start"; launch.action_type = FT_LAUNCH_COLD;
    sendAt(launch, 1792152134474966016LL);
    FTRUMActionModel *click = [[FTRUMActionModel alloc] initWithActionName:@"EventFlowLog" actionType:@"click"];
    click.type = FTRUMDataStartAction;
    sendAt(click, 1792152208923889152LL);
    sendAt(view(@"home", YES), 1792152211454923264LL);
    sendAt(view(@"first-UITestVC", NO), 1792152211454923264LL);
    XCTAssertEqualObjects([self fields:@"first-UITestVC"][@"interaction_to_next_view_time"], @2531034112LL);
    sendAt(view(@"first-UITestVC", YES), 1792152212332869120LL);
    sendAt(view(@"restarted-UITestVC", NO), 1792152212332869120LL);
    XCTAssertNil([self fields:@"restarted-UITestVC"][@"interaction_to_next_view_time"]);
}
- (void)testResourceIncompleteFetchUsesOneCapturedIntervalForEventAndTNS {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"r" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"r" type:FTRUMDataResourceStop at:300 metrics:nil];
    FTResourceMetricsModel *partial = [FTResourceMetricsModel new];
    partial.fetchStartNsTimeInterval = FTMetricEpoch + 80000000;
    [self resource:@"r" type:FTRUMDataResourceComplete at:2000 metrics:partial];
    NSDictionary *event = nil;
    for (NSDictionary *candidate in self.writer.events) if ([candidate[@"source"] isEqual:@"resource"]) event = candidate;
    XCTAssertEqualObjects(event[@"time"], @(FTMetricEpoch + 20000000));
    XCTAssertEqualObjects(event[@"fields"][@"duration"], @280000000);
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
}
- (void)testLegacyDurationWithoutEndpointDoesNotInventNetworkSettledTime {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"r" type:FTRUMDataResourceStart at:20 metrics:nil];
    FTResourceMetricsModel *legacy = [FTResourceMetricsModel new];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    legacy.duration = @500000000;
#pragma clang diagnostic pop
    [self resource:@"r" type:FTRUMDataResourceComplete at:9000 metrics:legacy];
    NSDictionary *event = nil;
    for (NSDictionary *candidate in self.writer.events) if ([candidate[@"source"] isEqual:@"resource"]) event = candidate;
    XCTAssertEqualObjects(event[@"time"], @(FTMetricEpoch + 20000000));
    XCTAssertEqualObjects(event[@"fields"][@"duration"], @500000000);
    XCTAssertNil([self fields:@"A"][@"network_settled_time"]);
}
- (void)testNetworkMetricPersistsInLaterWholeViewSnapshot {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"r" type:FTRUMDataResourceStart at:10 metrics:nil];
    [self resource:@"r" type:FTRUMDataResourceComplete at:40 metrics:[self metricsFrom:10 to:40]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @40000000);
    [self click:@"later-event" at:500 type:@"custom"];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @40000000);
    XCTAssertEqualObjects([self fields:@"A"][@"view_action_count"], @1);
}
- (void)testResourceFetchIntervalSharedByEventAndTNS {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"r" type:FTRUMDataResourceStart at:120 metrics:nil];
    [self resource:@"r" type:FTRUMDataResourceStop at:500 metrics:nil];
    [self resource:@"r" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:80 to:400]];
    NSDictionary *event = nil;
    for (NSDictionary *candidate in self.writer.events) if ([candidate[@"source"] isEqual:@"resource"]) event = candidate;
    XCTAssertEqualObjects(event[@"time"], @(FTMetricEpoch + 80000000));
    XCTAssertEqualObjects(event[@"fields"][@"duration"], @320000000);
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @400000000);
}
- (void)testTNSPublishesCompletedBatchesWhileViewIsActive {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:10 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:40 metrics:[self metricsFrom:10 to:40]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @40000000);
    [self resource:@"b" type:FTRUMDataResourceStart at:80 metrics:nil];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @40000000);
    [self resource:@"b" type:FTRUMDataResourceComplete at:300 metrics:[self metricsFrom:80 to:300]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
    XCTAssertEqualObjects([self fields:@"A"][@"is_active"], @YES);
}
- (void)testTNSNoninitialPendingResourceDoesNotDelayInitialBatch {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"initial" type:FTRUMDataResourceStart at:10 metrics:nil];
    [self resource:@"later" type:FTRUMDataResourceStart at:101 metrics:nil];
    [self resource:@"initial" type:FTRUMDataResourceComplete at:300 metrics:[self metricsFrom:10 to:300]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
    [self resource:@"later" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:101 to:2000]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
}
- (void)testTNSLaterMetricsReclassifyResourceAndUpdateCompletedBatch {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:10 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:40 metrics:[self metricsFrom:10 to:40]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @40000000);
    [self resource:@"b" type:FTRUMDataResourceStart at:120 metrics:nil];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @40000000);
    [self resource:@"b" type:FTRUMDataResourceComplete at:500 metrics:[self metricsFrom:80 to:400]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @400000000);
}
- (void)testRumPredicateDefaultsAndExplicitNilCopySemantics {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"app"];
    XCTAssertTrue([config.nextViewActionPredicate isKindOfClass:FTRUMTimeBasedNextViewActionPredicate.class]);
    XCTAssertTrue([config.networkSettledResourcePredicate isKindOfClass:FTRUMTimeBasedNetworkSettledPredicate.class]);
    config.nextViewActionPredicate = nil;
    config.networkSettledResourcePredicate = nil;
    FTRumConfig *copy = [config copy];
    XCTAssertNil(copy.nextViewActionPredicate);
    XCTAssertTrue([copy.networkSettledResourcePredicate isKindOfClass:FTRUMTimeBasedNetworkSettledPredicate.class]);
    FTRUMDependencies *dependencies = [[FTGlobalRumManager sharedInstance] dependenciesWithRumConfig:copy writer:self.writer monitor:nil errorInfoWrapper:nil];
    XCTAssertNil(dependencies.nextViewActionPredicate);
    XCTAssertEqual(dependencies.networkSettledResourcePredicate, copy.networkSettledResourcePredicate);
    self.dependencies = dependencies;
    dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"foreground" timeNs:FTMetricEpoch - 1000000000];
    FTRUMDataModel *initial = [[FTRUMDataModel alloc] initWithType:FTRUMViewPlaceholder time:[self date:0]];
    self.session = [[FTRUMSessionHandler alloc] initWithModel:initial dependencies:dependencies];
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertNil([self fields:@"B"][@"interaction_to_next_view_time"]);
    [self resource:@"r" type:FTRUMDataResourceStart at:1020 metrics:nil];
    [self resource:@"r" type:FTRUMDataResourceComplete at:1300 metrics:[self metricsFrom:1020 to:1300]];
    XCTAssertEqualObjects([self fields:@"B"][@"network_settled_time"], @300000000);
}
- (void)testRumCustomPredicatesSurviveConfigCopyAndDependencyConstruction {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"app"];
    config.nextViewActionPredicate = [[FTRUMTimeBasedNextViewActionPredicate alloc] initWithMaxTimeNs:5000000000LL];
    config.networkSettledResourcePredicate = [[FTRUMTimeBasedNetworkSettledPredicate alloc] initWithThresholdNs:200000000];
    FTRumConfig *copy = [config copy];
    FTRUMDependencies *dependencies = [[FTGlobalRumManager sharedInstance] dependenciesWithRumConfig:copy writer:self.writer monitor:nil errorInfoWrapper:nil];
    XCTAssertEqual(dependencies.nextViewActionPredicate, config.nextViewActionPredicate);
    XCTAssertEqual(dependencies.networkSettledResourcePredicate, config.networkSettledResourcePredicate);
}
- (void)testINVInternalRuleCanSelectCustomActionByNameAndNextView {
    FTINVPredicate *predicate = [FTINVPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNextViewActionParams *params) {
        return [params.actionType isEqual:@"custom"] && [params.actionName isEqual:@"navigate"] &&
            [params.nextViewName isEqual:@"same-name"] && params.timeToNextViewNs <= 5000000000LL;
    };
    self.dependencies.nextViewActionPredicate = predicate;
    [self view:@"A" at:0 stop:NO];
    [self click:@"navigate" at:500 type:@"custom"];
    [self click:@"unrelated" at:900 type:@"click"];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @500000000);
}
- (void)testINVInternalThresholdCanExceedThreeSecondsAndSurvivesDependencyCopy {
    self.dependencies.nextViewActionPredicate = [[FTRUMTimeBasedNextViewActionPredicate alloc] initWithMaxTimeNs:5000000000LL];
    FTRUMDependencies *copy = [self.dependencies copy];
    XCTAssertEqual(copy.nextViewActionPredicate, self.dependencies.nextViewActionPredicate);
    [self view:@"A" at:0 stop:NO];
    [self click:@"navigate" at:0 type:@"click"];
    [self view:@"B" at:4000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @4000000000LL);
}
- (void)testINVRuleQueriesKeepRejectedCandidatesForOtherDestinations {
    FTINVPredicate *predicate = [FTINVPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNextViewActionParams *params) {
        return [params.nextViewName isEqual:@"destination"] && [params.actionName isEqual:@"navigate"];
    };
    FTRUMViewMetrics *metric = [[FTRUMViewMetrics alloc] initWithStartNs:FTMetricEpoch predicate:predicate];
    [metric recordActionStart:FTMetricEpoch + 900000000 name:@"unrelated" type:@"custom"];
    [metric recordActionStart:FTMetricEpoch + 800000000 name:@"navigate" type:@"custom"];
    XCTAssertNil([metric interactionToViewAt:FTMetricEpoch + 1000000000 name:@"other"]);
    XCTAssertEqualObjects([metric interactionToViewAt:FTMetricEpoch + 1000000000 name:@"destination"], @200000000);
    XCTAssertEqualObjects([metric interactionToViewAt:FTMetricEpoch + 1000000000 name:@"destination"], @200000000);
}
- (void)testINVCustomRuleCannotSelectInvalidActionButCanReevaluateEarlierOrigin {
    FTINVPredicate *predicate = [FTINVPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNextViewActionParams *params) { return YES; };
    FTRUMViewMetrics *metric = [[FTRUMViewMetrics alloc] initWithStartNs:FTMetricEpoch + 100000000 predicate:predicate];
    [metric recordActionStart:FTMetricEpoch + 80000000 name:@"before-origin" type:@"custom"];
    [metric recordActionStart:FTMetricEpoch + 1100000000 name:@"future" type:@"custom"];
    XCTAssertNil([metric interactionToViewAt:FTMetricEpoch + 1000000000 name:@"B"]);
    [metric moveStartEarlierTo:FTMetricEpoch];
    XCTAssertEqualObjects([metric interactionToViewAt:FTMetricEpoch + 1000000000 name:@"B"], @920000000);
}
- (void)testINVCustomRuleHonorsFilteringAndUpdatesForLateAcceptedAction {
    FTINVPredicate *predicate = [FTINVPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNextViewActionParams *params) { return [params.actionType isEqual:@"custom"]; };
    self.dependencies.nextViewActionPredicate = predicate;
    self.writer.discardAction = @"discard";
    [self view:@"A" at:0 stop:NO];
    [self click:@"keep" at:700 type:@"custom"];
    [self click:@"discard" at:900 type:@"custom"];
    FTRUMViewHandler *previous = [[self.session valueForKey:@"viewHandlers"] lastObject];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @300000000);
    [previous.metrics recordActionStart:FTMetricEpoch + 800000000 name:@"late" type:@"custom"];
    FTRUMDataModel *refresh = [[FTRUMDataModel alloc] initWithType:FTRUMViewPlaceholder time:[self date:1200]];
    [self send:refresh at:1200];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @200000000);
}
- (void)testINVUsesLatestClickEventTimeAndSkipsOtherTypes {
    [self view:@"A" at:0 stop:NO];
    [self click:@"new" at:900 type:@"click"];
    [self click:@"old" at:700 type:@"click"];
    [self click:@"custom" at:950 type:@"custom"];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @100000000);
}
- (void)testINVThresholdZeroAndSessionIsolation {
    for (NSNumber *gap in @[@0, @3000, @3001]) {
        [self setUp];
        [self view:@"A" at:0 stop:NO];
        [self click:@"click" at:800 type:@"click"];
        [self view:@"A" at:800 stop:YES];
        [self view:@"B" at:800 + gap.integerValue stop:NO];
        NSNumber *expected = gap.integerValue > 3000 ? nil : @(gap.longLongValue * 1000000);
        XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], expected);
    }
    FTRUMSessionHandler *renewed = [[FTRUMSessionHandler alloc] initWithExpiredSession:self.session time:[self date:4000]];
    self.session = renewed;
    [self view:@"C" at:4100 stop:NO];
    XCTAssertNil([self fields:@"C"][@"interaction_to_next_view_time"]);
}
- (void)testINVFilteredClickDoesNotHideEarlierClick {
    self.writer.discardAction = @"discard";
    [self view:@"A" at:0 stop:NO];
    [self click:@"keep" at:700 type:@"click"];
    [self click:@"discard" at:900 type:@"click"];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @300000000);
}
- (void)testTNSWaitsForAllResourcesAfterStopAndUsesMaximumEnd {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"b" type:FTRUMDataResourceStart at:80 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceStop at:300 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:1500 metrics:nil];
    XCTAssertNil([self fields:@"A"][@"network_settled_time"]);
    [self view:@"B" at:1600 stop:NO];
    [self resource:@"b" type:FTRUMDataResourceStop at:500 metrics:nil];
    [self resource:@"b" type:FTRUMDataResourceError at:2000 metrics:nil];
    [self resource:@"b" type:FTRUMDataResourceComplete at:2500 metrics:nil];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
    XCTAssertNil([self fields:@"B"][@"network_settled_time"]);
    NSUInteger count = self.writer.events.count;
    [self resource:@"b" type:FTRUMDataResourceComplete at:3000 metrics:nil];
    XCTAssertEqual(self.writer.events.count, count);
}
- (void)testTNSMetricsReclassifiesMembershipAndNoninitialEndDoesNotContribute {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"include" type:FTRUMDataResourceStart at:120 metrics:nil];
    [self resource:@"exclude" type:FTRUMDataResourceStart at:80 metrics:nil];
    [self resource:@"include" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:80 to:400]];
    [self resource:@"exclude" type:FTRUMDataResourceComplete at:3000 metrics:[self metricsFrom:120 to:2500]];
    [self view:@"A" at:3100 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @400000000);
}
- (void)testTNSInclusiveWindowAndInvalidIntervals {
    [self view:@"A" at:0 stop:NO];
    NSArray<NSNumber *> *starts = @[@(-1), @0, @100, @101];
    NSArray<NSNumber *> *ends = @[@900, @300, @500, @2000];
    for (NSUInteger i = 0; i < starts.count; i++) {
        NSString *key = [NSString stringWithFormat:@"r%lu", (unsigned long)i];
        [self resource:key type:FTRUMDataResourceStart at:starts[i].integerValue metrics:nil];
        [self resource:key type:FTRUMDataResourceComplete at:4000 metrics:[self metricsFrom:starts[i].integerValue to:ends[i].integerValue]];
    }
    [self view:@"A" at:4500 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
}
- (void)testTNSDiscardAndAbandonDoNotContribute {
    self.writer.discardResource = @"discard";
    [self view:@"A" at:0 stop:NO];
    for (NSString *key in @[@"keep", @"discard", @"abandon"]) [self resource:key type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"keep" type:FTRUMDataResourceComplete at:300 metrics:[self metricsFrom:20 to:300]];
    [self resource:@"discard" type:FTRUMDataResourceComplete at:500 metrics:[self metricsFrom:20 to:500]];
    [self resource:@"abandon" type:FTRUMDataResourceAbandon at:700 metrics:nil];
    [self view:@"A" at:1000 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
}
- (void)testTNSBackgroundSuppressionAndMissingData {
    [self view:@"empty" at:0 stop:NO];
    [self view:@"A" at:1000 stop:NO];
    XCTAssertNil([self fields:@"empty"][@"network_settled_time"]);
    [self.dependencies.appStateHistory recordState:@"background" timeNs:FTMetricEpoch + 1100000000];
    [self resource:@"a" type:FTRUMDataResourceStart at:1020 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:1300 metrics:[self metricsFrom:1020 to:1300]];
    [self view:@"A" at:1500 stop:YES];
    XCTAssertNil([self fields:@"A"][@"network_settled_time"]);
}
- (void)testViewMetricSerializationPreservesIntegerNanoseconds {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"B" at:1000 stop:NO];
    FTRecordModel *record = [[FTRecordModel alloc] initWithSource:@"view" op:FT_DATA_TYPE_RUM tags:@{} fields:[self fields:@"B"] tm:FTMetricEpoch];
    NSDictionary *payload = [FTJSONUtil dictionaryWithJsonString:record.data];
    XCTAssertEqualObjects(payload[@"opdata"][@"fields"][@"interaction_to_next_view_time"], @200000000);
}
- (void)testINVDelayedAcceptanceUpdatesCurrentView {
    [self view:@"A" at:0 stop:NO];
    FTRUMViewHandler *previous = [[self.session valueForKey:@"viewHandlers"] lastObject];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertNil([self fields:@"B"][@"interaction_to_next_view_time"]);
    [previous.metrics recordActionStart:FTMetricEpoch + 800000000 name:@"late" type:@"click"];
    FTRUMDataModel *update = [[FTRUMDataModel alloc] initWithType:FTRUMViewPlaceholder time:[self date:1200]];
    [self send:update at:1200];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @200000000);
}
- (void)testINVCandidateMustBelongToImmediatelyPrecedingView {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"B" at:1000 stop:NO];
    [self view:@"C" at:1100 stop:NO];
    XCTAssertNil([self fields:@"C"][@"interaction_to_next_view_time"]);
}
- (void)testTNSShortViewClosesWithoutTimerAndPreservesZero {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:0 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:0 metrics:[self metricsFrom:0 to:0]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @0);
    [self view:@"A" at:50 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @0);
    NSArray *remainingViews = [self.session valueForKey:@"viewHandlers"];
    XCTAssertEqual(remainingViews.count, 0);
}
- (void)testTNSMissingEndAndNegativeDurationAreExcluded {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"missing" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"negative" type:FTRUMDataResourceStart at:30 metrics:nil];
    [self resource:@"missing" type:FTRUMDataResourceComplete at:500 metrics:nil];
    [self resource:@"negative" type:FTRUMDataResourceStop at:10 metrics:nil];
    [self resource:@"negative" type:FTRUMDataResourceComplete at:600 metrics:[self metricsFrom:30 to:10]];
    [self view:@"A" at:1000 stop:YES];
    XCTAssertNil([self fields:@"A"][@"network_settled_time"]);
}
- (void)testTNSIncompleteMetricsFallBackAsAPairAndDuplicateStopIsIgnored {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceStop at:300 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceStop at:900 metrics:nil];
    FTResourceMetricsModel *incomplete = [self metricsFrom:120 to:400];
    incomplete.fetchEndNsTimeInterval = 0;
    [self resource:@"a" type:FTRUMDataResourceComplete at:1200 metrics:incomplete];
    [self view:@"A" at:1500 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
}
- (void)testTNSReversedTerminalProcessingUsesMaximumEventEnd {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"b" type:FTRUMDataResourceStart at:80 metrics:nil];
    [self resource:@"b" type:FTRUMDataResourceComplete at:1000 metrics:[self metricsFrom:80 to:500]];
    [self resource:@"a" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:20 to:300]];
    [self view:@"A" at:2500 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
}
- (void)testTNSAllDiscardedResourcesOmitTheField {
    self.writer.discardResource = @"discard";
    [self view:@"A" at:0 stop:NO];
    [self resource:@"discard" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"discard" type:FTRUMDataResourceComplete at:500 metrics:[self metricsFrom:20 to:500]];
    [self view:@"A" at:1000 stop:YES];
    XCTAssertNil([self fields:@"A"][@"network_settled_time"]);
}
- (void)testActualWriterFilterDecisionControlsBothMetrics {
    [[FTDataFilterManager sharedInstance] enable:YES localFilters:@{@"rum":@[@"{ source = 'action' and action_name = 'discard' }", @"{ source = 'resource' and resource_id = 'discard' }"]}];
    self.writer.admissionWriter = [[FTDataWriterWorker alloc] initWithCacheInvalidTimeInterval:60];
    @try {
        [self view:@"A" at:0 stop:NO];
        [self resource:@"keep" type:FTRUMDataResourceStart at:20 metrics:nil];
        [self resource:@"discard" type:FTRUMDataResourceStart at:80 metrics:nil];
        [self resource:@"keep" type:FTRUMDataResourceComplete at:300 metrics:[self metricsFrom:20 to:300]];
        [self resource:@"discard" type:FTRUMDataResourceComplete at:500 metrics:[self metricsFrom:80 to:500]];
        [self click:@"keep" at:700 type:@"click"];
        [self click:@"discard" at:900 type:@"click"];
        [self view:@"B" at:1000 stop:NO];
        XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @300000000);
        XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @300000000);
    } @finally {
        [[FTDataFilterManager sharedInstance] shutDown];
    }
}
- (void)testStartedResourceRetainsOriginalViewAfterViewStop {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self view:@"B" at:1000 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStop at:500 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:2000 metrics:nil];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
    XCTAssertNil([self fields:@"B"][@"network_settled_time"]);
}
- (void)testOldSessionResourceCannotCompleteIntoNewSession {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    self.session = [[FTRUMSessionHandler alloc] initWithExpiredSession:self.session time:[self date:1000]];
    [self view:@"B" at:1100 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:20 to:500]];
    [self view:@"B" at:2500 stop:YES];
    XCTAssertEqualObjects([self fields:@"B"][@"view_resource_count"], @0);
    XCTAssertNil([self fields:@"B"][@"network_settled_time"]);
}
#if __has_include("OHHTTPStubs.h")
- (void)testImageRedirectWithUnrelatedHTTPStubIsCollected {
    id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *body = [@"{\"data\":\"Hello World!\",\"code\":200}" dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:body statusCode:200 headers:nil];
    }];
    @try {
        [self assertImageRedirectIsCollected];
    } @finally {
        [OHHTTPStubs removeStub:stub];
    }
}
#endif

- (void)testImageRedirectWithCompletionAndDefaultSessionIsCollected {
    [self assertImageRedirectIsCollected];
}

- (void)assertImageRedirectIsCollected {
    FTRUMManager *manager = [[FTRUMManager alloc] initWithRumDependencies:self.dependencies];
    [manager startViewWithName:@"image-page"];
    [manager syncProcess];
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
    [instrumentation setEnableAutoRumTrace:YES resourceUrlHandler:nil resourcePropertyProvider:nil sessionTaskErrorFilter:nil];
    [instrumentation setRumResourceHandler:manager];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.URLCache = nil;
#if __has_include("OHHTTPStubs.h")
    // Exercise the real local redirect without changing other sessions' stubs.
    [OHHTTPStubs setEnabled:NO forSessionConfiguration:config];
#endif
    FTMetricImageServer *server = [FTMetricImageServer new];
    XCTAssertTrue([server start]);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    XCTestExpectation *completed = [self expectationWithDescription:@"image completed"];
    [[session dataTaskWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/image.png", server.port]] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 200);
        XCTAssertEqual(data.length, 68u);
        XCTAssertEqualObjects(response.URL.path, @"/final.png");
        XCTAssertEqualObjects(response.MIMEType, @"image/png");
        [completed fulfill];
    }] resume];
    [self waitForExpectations:@[completed] timeout:5];
    XCTestExpectation *settled = [self expectationWithDescription:@"collector drained after completion"];
    [session.delegateQueue addBarrierBlock:^{
        dispatch_sync([(NSObject *)instrumentation.interceptor valueForKey:@"queue"], ^{});
        [manager syncProcess];
        [settled fulfill];
    }];
    [self waitForExpectations:@[settled] timeout:5];
    NSUInteger count = 0;
    for (NSDictionary *event in self.writer.events) {
        if ([event[@"source"] isEqualToString:@"resource"]) count++;
    }
    XCTAssertEqual(count, 1u);
    [session invalidateAndCancel];
    [server stop];
    [instrumentation shutDown];
}

- (void)testCollectorDelayPreservesBoundariesButUsesCurrentView {
    FTRUMManager *manager = [[FTRUMManager alloc] initWithRumDependencies:self.dependencies];
    [manager syncProcess];
    [self.dependencies.appStateHistory stopMonitoring];
    self.dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"foreground" timeNs:FTMetricEpoch - 1000000000];
    dispatch_queue_t rumQueue = [manager valueForKey:@"rumQueue"];
    FTRUMViewModel *first = [[FTRUMViewModel alloc] initWithViewID:@"collectorA" viewName:@"A" viewReferrer:@""];
    first.type = FTRUMDataViewStart;
    first.time = [self date:0]; first.tm = FTMetricEpoch;
    dispatch_sync(rumQueue, ^{ [manager.assistant process:first context:@{}]; });
    FTMetricInterceptor *interceptor = [FTMetricInterceptor new];
    interceptor.rumResourceHandler = manager;
    interceptor.boundaryDate = [self date:20];
    interceptor.boundaryTime = 20000000;
    FTMetricTask *task = [FTMetricTask new];
    dispatch_queue_t networkQueue = [interceptor valueForKey:@"queue"];
    dispatch_suspend(networkQueue);
    [interceptor interceptTask:task];
    [manager syncProcess];
    FTRUMViewModel *next = [[FTRUMViewModel alloc] initWithViewID:@"collectorB" viewName:@"B" viewReferrer:@""];
    next.type = FTRUMDataViewStart;
    next.time = [self date:1000]; next.tm = FTMetricEpoch + 1000000000;
    dispatch_sync(rumQueue, ^{ [manager.assistant process:next context:@{}]; });
    dispatch_resume(networkQueue);
    dispatch_sync(networkQueue, ^{});
    [manager syncProcess];
    interceptor.resourcePropertyProvider = ^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        // Advance processing time by seconds without waiting or changing event time.
        interceptor.boundaryDate = [self date:9000];
        interceptor.boundaryTime = 9000000000;
        return @{};
    };
    [interceptor taskCompleted:task error:nil endTime:520000000];
    dispatch_sync(networkQueue, ^{});
    [manager syncProcess];
    XCTAssertNil([self fields:@"collectorA"][@"network_settled_time"]);
    XCTAssertNil([self fields:@"collectorB"][@"network_settled_time"]);
    NSUInteger resources = 0;
    for (NSDictionary *event in self.writer.events) {
        if (![event[@"source"] isEqualToString:@"resource"]) continue;
        resources++;
        XCTAssertEqualObjects(event[@"tags"][@"view_id"], @"collectorB");
        XCTAssertEqualObjects(event[@"time"], @(FTMetricEpoch + 20000000));
        XCTAssertEqualObjects(event[@"fields"][@"duration"], @500000000);
    }
    XCTAssertEqual(resources, 1u);
    interceptor.resourcePropertyProvider = nil;
    [interceptor shutDown];
}
- (void)testInactiveIsAllowedAndInitialBackgroundIsSuppressed {
    self.dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"unknown" timeNs:FTMetricEpoch background:NO];
    [self view:@"inactive" at:1000 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:1020 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:1500 metrics:[self metricsFrom:1020 to:1300]];
    [self view:@"inactive" at:2000 stop:YES];
    XCTAssertEqualObjects([self fields:@"inactive"][@"network_settled_time"], @300000000);
    self.dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"unknown" timeNs:FTMetricEpoch background:YES];
    [self view:@"background" at:3000 stop:NO];
    [self resource:@"b" type:FTRUMDataResourceStart at:3020 metrics:nil];
    [self resource:@"b" type:FTRUMDataResourceComplete at:3500 metrics:[self metricsFrom:3020 to:3300]];
    [self view:@"background" at:4000 stop:YES];
    XCTAssertNil([self fields:@"background"][@"network_settled_time"]);
}
- (void)testRejectedURLDoesNotCreateAViewOrHideClick {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"A" at:900 stop:YES];
    FTRUMManager *manager = [[FTRUMManager alloc] initWithRumDependencies:self.dependencies];
    [manager syncProcess];
    [manager setValue:self.session forKey:@"sessionHandler"];
    FTMetricInterceptor *interceptor = [FTMetricInterceptor new];
    interceptor.rumResourceHandler = manager;
    interceptor.boundaryDate = [self date:950];
    interceptor.resourceUrlHandler = ^BOOL(NSURL *url) { return YES; };
    NSUInteger before = self.writer.events.count;
    [interceptor interceptTask:[FTMetricTask new]];
    dispatch_sync([interceptor valueForKey:@"queue"], ^{});
    [manager syncProcess];
    XCTAssertEqual(self.writer.events.count, before);
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @200000000);
    [interceptor shutDown];
}

- (void)testFallbackSkipsCustomRulesButKeepsResourceAndActionReporting {
    __block NSUInteger interactionCalls = 0;
    FTINVPredicate *inv = [FTINVPredicate new];
    inv.evaluate = ^BOOL(FTRUMNextViewActionParams *params) { interactionCalls += 1; return YES; };
    FTMetricPredicate *network = [FTMetricPredicate new];
    network.evaluate = ^BOOL(FTRUMNetworkSettledResourceParams *params) { return YES; };
    self.dependencies.nextViewActionPredicate = inv;
    self.dependencies.networkSettledResourcePredicate = network;
    [self resource:@"fallback" type:FTRUMDataResourceStart at:20 metrics:nil];
    FTRUMViewHandler *fallback = [[self.session valueForKey:@"viewHandlers"] lastObject];
    [self resource:@"fallback" type:FTRUMDataResourceComplete at:300 metrics:[self metricsFrom:20 to:300]];
    [self click:@"fallback-click" at:400 type:@"click"];
    XCTAssertEqualObjects([self fields:fallback.view_id][@"view_resource_count"], @1);
    XCTAssertEqualObjects([self fields:fallback.view_id][@"view_action_count"], @1);
    [self view:@"normal" at:1000 stop:NO];
    XCTAssertEqual(interactionCalls, 0u);
    XCTAssertEqual(network.calls, 0u);
    XCTAssertNil([self fields:@"normal"][@"interaction_to_next_view_time"]);
}
- (void)testFallbackDoesNotEmitTimingMetricsOrProvideNextInteraction {
    [self resource:@"fallback-request" type:FTRUMDataResourceStart at:20 metrics:nil];
    FTRUMViewHandler *fallback = [[self.session valueForKey:@"viewHandlers"] lastObject];
    XCTAssertTrue(fallback.fallbackView);
    [self resource:@"fallback-request" type:FTRUMDataResourceComplete at:300 metrics:[self metricsFrom:20 to:300]];
    [self click:@"fallback-click" at:400 type:@"click"];
    XCTAssertNil([self fields:fallback.view_id][@"network_settled_time"]);
    XCTAssertNil([self fields:fallback.view_id][@"interaction_to_next_view_time"]);
    [self view:@"normal" at:1000 stop:NO];
    XCTAssertNil([self fields:@"normal"][@"interaction_to_next_view_time"]);
    [self resource:@"normal-request" type:FTRUMDataResourceStart at:1020 metrics:nil];
    [self resource:@"normal-request" type:FTRUMDataResourceComplete at:1300 metrics:[self metricsFrom:1020 to:1300]];
    XCTAssertEqualObjects([self fields:@"normal"][@"network_settled_time"], @300000000);
}
- (void)testFallbackDoesNotInheritPreviousNormalInteraction {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"A" at:900 stop:YES];
    [self resource:@"fallback-request" type:FTRUMDataResourceStart at:1000 metrics:nil];
    FTRUMViewHandler *fallback = [[self.session valueForKey:@"viewHandlers"] lastObject];
    [self resource:@"fallback-request" type:FTRUMDataResourceComplete at:1300 metrics:[self metricsFrom:1000 to:1300]];
    XCTAssertTrue(fallback.fallbackView);
    XCTAssertNil([self fields:fallback.view_id][@"interaction_to_next_view_time"]);
    XCTAssertNil([self fields:fallback.view_id][@"network_settled_time"]);
    [self view:@"B" at:1400 stop:NO];
    XCTAssertNil([self fields:@"B"][@"interaction_to_next_view_time"]);
}
- (void)testStartedResourceFallbackIsTheImmediatePredecessor {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"A" at:900 stop:YES];
    [self resource:@"pending" type:FTRUMDataResourceStart at:950 metrics:nil];
    [self view:@"B" at:1000 stop:NO];
    // A Resource fallback View now lies between A and B and has no click.
    XCTAssertNil([self fields:@"B"][@"interaction_to_next_view_time"]);
}
- (void)testURLConnectionActivationPreservesStartTimeAndUsesCurrentView {
    FTRUMManager *manager = [[FTRUMManager alloc] initWithRumDependencies:self.dependencies];
    [manager syncProcess];
    [self.dependencies.appStateHistory stopMonitoring];
    self.dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:@"foreground" timeNs:FTMetricEpoch - 1000000000];
    dispatch_queue_t queue = [manager valueForKey:@"rumQueue"];
    FTRUMViewModel *view = [[FTRUMViewModel alloc] initWithViewID:@"connectionA" viewName:@"A" viewReferrer:@""];
    view.type = FTRUMDataViewStart; view.time = [self date:0]; view.tm = FTMetricEpoch;
    dispatch_sync(queue, ^{ [manager.assistant process:view context:@{}]; });
    FTURLConnectionHandler *handler = [[FTURLConnectionHandler alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.test"]] resourceEnabled:YES provider:nil errorFilter:nil rumResourceHandler:manager];
    XCTAssertTrue([handler recordStartWithDate:[self date:20] continuousTime:20000000]);
    XCTAssertFalse([handler recordStartWithDate:[self date:2000] continuousTime:2000000000]);
    [manager syncProcess];
    FTRUMViewModel *next = [[FTRUMViewModel alloc] initWithViewID:@"connectionB" viewName:@"B" viewReferrer:@""];
    next.type = FTRUMDataViewStart; next.time = [self date:1000]; next.tm = FTMetricEpoch + 1000000000;
    dispatch_sync(queue, ^{ [manager.assistant process:next context:@{}]; });
    [handler activate];
    [handler reportStartIfNeeded];
    [handler recordTerminalWithResponse:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil] date:[self date:500] continuousTime:500000000];
    [handler reportTerminalIfNeeded];
    [manager syncProcess];
    XCTAssertNil([self fields:@"connectionA"][@"network_settled_time"]);
    XCTAssertNil([self fields:@"connectionB"][@"network_settled_time"]);
}
- (void)testMetricsFollowEarlierViewOriginAndReclassifyExistingIntervals {
    FTRUMNetworkSettledMetric *metric = [[FTRUMNetworkSettledMetric alloc] initWithStartNs:FTMetricEpoch + 100000000 viewName:@"page" predicate:nil];
    [metric startResourceWithKey:@"early" startNs:FTMetricEpoch + 80000000 URL:nil];
    [metric completeResourceWithKey:@"early" endNs:FTMetricEpoch + 400000000];
    [metric startResourceWithKey:@"later" startNs:FTMetricEpoch + 120000000 URL:nil];
    [metric completeResourceWithKey:@"later" endNs:FTMetricEpoch + 900000000];
    [metric moveStartEarlierTo:FTMetricEpoch];
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @400000000);
}
- (void)testInternalNetworkRuleCanUse200msWithoutChangingViewOrResource {
    self.dependencies.networkSettledResourcePredicate = [[FTRUMTimeBasedNetworkSettledPredicate alloc] initWithThresholdNs:200000000];
    [self view:@"A" at:0 stop:NO];
    [self resource:@"r" type:FTRUMDataResourceStart at:120 metrics:nil];
    [self resource:@"r" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:120 to:500]];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
    FTRUMDependencies *copy = [self.dependencies copy];
    XCTAssertEqual(copy.networkSettledResourcePredicate, self.dependencies.networkSettledResourcePredicate);
}
- (void)testURLRuleUsesFinalOriginalInformationAndIgnoresExcludedSlowRequest {
    FTMetricPredicate *predicate = [FTMetricPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNetworkSettledResourceParams *params) {
        return [params.resourceURL hasSuffix:@"/include"] && [params.viewName isEqual:@"same-name"];
    };
    self.dependencies.networkSettledResourcePredicate = predicate;
    [self view:@"A" at:0 stop:NO];
    [self resource:@"include" type:FTRUMDataResourceStart at:120 metrics:nil];
    [self resource:@"exclude" type:FTRUMDataResourceStart at:20 metrics:nil];
    FTRUMResourceDataModel *complete = [[FTRUMResourceDataModel alloc] initWithType:FTRUMDataResourceComplete identifier:@"include"];
    complete.tags = @{FT_KEY_RESOURCE_URL:@"https://example.test/include"};
    complete.metrics = [self metricsFrom:120 to:500];
    [self send:complete at:2000];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
    complete = [[FTRUMResourceDataModel alloc] initWithType:FTRUMDataResourceComplete identifier:@"exclude"];
    complete.tags = @{FT_KEY_RESOURCE_URL:@"https://example.test/exclude"};
    complete.metrics = [self metricsFrom:20 to:9000];
    [self send:complete at:10000];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
}
- (void)testNetworkValueReadsArePureAndRetainCompletedBatchWhilePending {
    FTMetricPredicate *predicate = [FTMetricPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNetworkSettledResourceParams *params) { return YES; };
    FTRUMNetworkSettledMetric *metric = [[FTRUMNetworkSettledMetric alloc] initWithStartNs:FTMetricEpoch viewName:@"A" predicate:predicate];
    [metric startResourceWithKey:@"a" startNs:FTMetricEpoch + 10000000 URL:nil];
    [metric completeResourceWithKey:@"a" endNs:FTMetricEpoch + 40000000];
    [metric startResourceWithKey:@"b" startNs:FTMetricEpoch + 80000000 URL:nil];
    NSUInteger calls = predicate.calls;
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @40000000);
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @40000000);
    XCTAssertEqual(predicate.calls, calls);
    [metric completeResourceWithKey:@"b" endNs:FTMetricEpoch + 300000000];
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @300000000);
    [metric completeResourceWithKey:@"b" endNs:FTMetricEpoch + 900000000];
    [metric updateResourceWithKey:@"b" startNs:FTMetricEpoch URL:@"late"];
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @300000000);
}
- (void)testNetworkRuleReevaluatesPreviouslyExcludedCompletedIntervalsAfterOriginChange {
    FTMetricPredicate *predicate = [FTMetricPredicate new];
    predicate.evaluate = ^BOOL(FTRUMNetworkSettledResourceParams *params) {
        return params.timeSinceViewStartNs >= 150000000 && params.timeSinceViewStartNs <= 250000000;
    };
    FTRUMNetworkSettledMetric *metric = [[FTRUMNetworkSettledMetric alloc] initWithStartNs:FTMetricEpoch + 100000000 viewName:@"A" predicate:predicate];
    [metric startResourceWithKey:@"r" startNs:FTMetricEpoch + 200000000 URL:nil];
    [metric completeResourceWithKey:@"r" endNs:FTMetricEpoch + 500000000];
    XCTAssertNil([metric valueWithHistory:self.dependencies.appStateHistory]);
    [metric moveStartEarlierTo:FTMetricEpoch];
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @500000000);
}
- (void)testNetworkReclassifiedPendingResourceWaitsWithoutLosingPreviousBatch {
    FTRUMNetworkSettledMetric *metric = [[FTRUMNetworkSettledMetric alloc] initWithStartNs:FTMetricEpoch viewName:@"A" predicate:nil];
    [metric startResourceWithKey:@"a" startNs:FTMetricEpoch + 10000000 URL:nil];
    [metric completeResourceWithKey:@"a" endNs:FTMetricEpoch + 40000000];
    [metric startResourceWithKey:@"b" startNs:FTMetricEpoch + 120000000 URL:nil];
    [metric updateResourceWithKey:@"b" startNs:FTMetricEpoch + 80000000 URL:@"https://example.test"];
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @40000000);
    [metric completeResourceWithKey:@"b" endNs:FTMetricEpoch + 400000000];
    XCTAssertEqualObjects([metric valueWithHistory:self.dependencies.appStateHistory], @400000000);
}
- (void)testDuplicateTerminalsDoNotAffectTheNextViewsAction {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:500 metrics:[self metricsFrom:20 to:500]];
    [self view:@"B" at:1000 stop:NO];
    FTRUMActionModel *action = [[FTRUMActionModel alloc] initWithActionName:@"B-action" actionType:@"click"];
    action.type = FTRUMDataStartAction;
    [self send:action at:1010];
    [self resource:@"b" type:FTRUMDataResourceStart at:1020 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:1100 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceError at:1150 metrics:nil];
    [self view:@"B" at:1200 stop:YES];
    NSDictionary *fields;
    for (NSDictionary *event in self.writer.events) {
        if ([event[@"tags"][@"action_name"] isEqual:@"B-action"]) fields = event[@"fields"];
    }
    XCTAssertEqualObjects(fields[@"action_resource_count"], @0);
    XCTAssertEqualObjects(fields[@"action_error_count"], @0);
}
- (void)testTNSNanosecondsAbove32BitsSurviveSerialization {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:20 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:6000 metrics:[self metricsFrom:20 to:5000]];
    [self view:@"A" at:7000 stop:YES];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @5000000000LL);
    FTRecordModel *record = [[FTRecordModel alloc] initWithSource:@"view" op:FT_DATA_TYPE_RUM tags:@{} fields:[self fields:@"A"] tm:FTMetricEpoch];
    NSDictionary *payload = [FTJSONUtil dictionaryWithJsonString:record.data];
    XCTAssertEqualObjects(payload[@"opdata"][@"fields"][@"network_settled_time"], @5000000000LL);
}
@end
