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
#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTRUMContext.h"
#import "FTResourceMetricsModel.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTRUMViewMetrics.h"
#import "FTRUMManager.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTDataWriterWorker.h"
#import "FTDataFilterManager.h"
#import "FTURLConnectionHandler.h"
#import "FTURLSessionInstrumentation.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>

static long long const FTMetricEpoch = 1800000000000000000LL;

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
- (void)testTNSWaitsForStopAndAllResourcesAndUsesMaximumEnd {
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
    [previous.metrics recordClickStart:FTMetricEpoch + 800000000];
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
- (void)testTNSShortViewWaitsForWindowClosureAndPreservesZero {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceStart at:0 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:0 metrics:[self metricsFrom:0 to:0]];
    [self view:@"A" at:50 stop:YES];
    XCTAssertNil([self fields:@"A"][@"network_settled_time"]);
    NSNumber *timeSpentBeforeWindow = [self fields:@"A"][@"time_spent"];
    FTRUMViewModel *window = [[FTRUMViewModel alloc] initWithViewID:@"A" viewName:@"" viewReferrer:@""];
    window.type = FTRUMDataViewMetricsUpdate;
    [self send:window at:100];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @0);
    XCTAssertEqualObjects([self fields:@"A"][@"time_spent"], timeSpentBeforeWindow);
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
- (void)testReservationRetainsOriginalViewAcrossDelayedAdmission {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceReserve at:20 metrics:nil];
    [self view:@"B" at:1000 stop:NO];
    FTRUMResourceDataModel *admit = [[FTRUMResourceDataModel alloc] initWithType:FTRUMDataResourceStart identifier:@"a"];
    admit.requiresReservation = YES;
    [self send:admit at:20];
    [self resource:@"a" type:FTRUMDataResourceStop at:500 metrics:nil];
    [self resource:@"a" type:FTRUMDataResourceComplete at:2000 metrics:nil];
    XCTAssertEqualObjects([self fields:@"A"][@"network_settled_time"], @500000000);
    XCTAssertNil([self fields:@"B"][@"network_settled_time"]);
}
- (void)testOldSessionReservationCannotBeAdmittedIntoNewSession {
    [self view:@"A" at:0 stop:NO];
    [self resource:@"a" type:FTRUMDataResourceReserve at:20 metrics:nil];
    self.session = [[FTRUMSessionHandler alloc] initWithExpiredSession:self.session time:[self date:1000]];
    [self view:@"B" at:1100 stop:NO];
    FTRUMResourceDataModel *admit = [[FTRUMResourceDataModel alloc] initWithType:FTRUMDataResourceStart identifier:@"a"];
    admit.requiresReservation = YES;
    [self send:admit at:20];
    [self resource:@"a" type:FTRUMDataResourceComplete at:2000 metrics:[self metricsFrom:20 to:500]];
    [self view:@"B" at:2500 stop:YES];
    XCTAssertEqualObjects([self fields:@"B"][@"view_resource_count"], @0);
    XCTAssertNil([self fields:@"B"][@"network_settled_time"]);
}
- (void)testImageRedirectWithCompletionAndDefaultSessionIsCollected {
    FTRUMManager *manager = [[FTRUMManager alloc] initWithRumDependencies:self.dependencies];
    [manager startViewWithName:@"image-page"];
    [manager syncProcess];
    FTURLSessionInstrumentation *instrumentation = [FTURLSessionInstrumentation sharedInstance];
    [instrumentation setEnableAutoRumTrace:YES resourceUrlHandler:nil resourcePropertyProvider:nil sessionTaskErrorFilter:nil];
    [instrumentation setRumResourceHandler:manager];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.URLCache = nil;
    FTMetricImageServer *server = [FTMetricImageServer new];
    XCTAssertTrue([server start]);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    XCTestExpectation *completed = [self expectationWithDescription:@"image completed"];
    [[session dataTaskWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/image.png", server.port]] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 200);
        XCTAssertEqual(data.length, 68u);
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

- (void)testCollectorQueueAndProviderDelayDoNotChangeBoundariesOrView {
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
    [interceptor taskCompleted:task error:nil endTime:500000000];
    dispatch_sync(networkQueue, ^{});
    [manager syncProcess];
    XCTAssertEqualObjects([self fields:@"collectorA"][@"network_settled_time"], @500000000);
    XCTAssertNil([self fields:@"collectorB"][@"network_settled_time"]);
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
- (void)testRejectedURLReservationDoesNotCreateAViewOrHideClick {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"A" at:900 stop:YES];
    NSUInteger viewsBefore = self.writer.events.count;
    [self resource:@"filtered" type:FTRUMDataResourceReserve at:950 metrics:nil];
    [self resource:@"filtered" type:FTRUMDataResourceAbandon at:950 metrics:nil];
    XCTAssertEqual(self.writer.events.count, viewsBefore);
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @200000000);
}
- (void)testURLReservationDecisionAfterNextViewCorrectsPredecessor {
    [self view:@"A" at:0 stop:NO];
    [self click:@"click" at:800 type:@"click"];
    [self view:@"A" at:900 stop:YES];
    [self resource:@"pending" type:FTRUMDataResourceReserve at:950 metrics:nil];
    [self view:@"B" at:1000 stop:NO];
    XCTAssertEqualObjects([self fields:@"B"][@"interaction_to_next_view_time"], @200000000);
    FTRUMResourceDataModel *admit = [[FTRUMResourceDataModel alloc] initWithType:FTRUMDataResourceStart identifier:@"pending"];
    admit.requiresReservation = YES;
    [self send:admit at:950];
    // An admitted fallback View now lies between A and B and has no click.
    XCTAssertNil([self fields:@"B"][@"interaction_to_next_view_time"]);
}
- (void)testURLConnectionStartReservationPrecedesActivationAndProvider {
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
    XCTAssertEqualObjects([self fields:@"connectionA"][@"network_settled_time"], @500000000);
    XCTAssertNil([self fields:@"connectionB"][@"network_settled_time"]);
}
- (void)testMetricsFollowEarlierViewOriginAndReclassifyExistingIntervals {
    FTRUMViewMetrics *metrics = [[FTRUMViewMetrics alloc] initWithStartNs:FTMetricEpoch + 100000000];
    [metrics recordResourceStart:FTMetricEpoch + 80000000 end:FTMetricEpoch + 400000000];
    [metrics recordResourceStart:FTMetricEpoch + 120000000 end:FTMetricEpoch + 900000000];
    [metrics moveStartEarlierTo:FTMetricEpoch];
    XCTAssertEqualObjects([metrics networkSettledTimeWithHistory:self.dependencies.appStateHistory], @400000000);
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
