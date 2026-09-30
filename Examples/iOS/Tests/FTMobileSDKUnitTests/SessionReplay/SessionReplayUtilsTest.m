//
//  SessionReplayUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/2/2.
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
#import "FTSRBaseFrame.h"
#import "FTConstants.h"
#import "FTHTTPClient.h"
#import "FTJSONUtil.h"
#import "FTFeatureUpload.h"
#import "FTPerformancePreset.h"
#import "FTResourceCheckRequest.h"
#import "FTResourceProcessor.h"
#import "FTResourceRequest.h"
#import "FTSessionReplayConfig.h"
#import "FTSessionReplayFeature.h"
#import "FTRecordingCoordinator.h"
#import "FTSegmentJSON.h"
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRRecord.h"
#import "FTViewAttributes.h"
#import "FTResourcesWriter.h"
#import "FTFeatureScope.h"
#import "FTFeatureStorage.h"
#import "FTFeatureDirectories.h"
#import "FTDirectory.h"
#import "FTDataStore.h"
#import "FTFileWriter.h"
#import "FTFilesOrchestrator.h"
#import "FTTLV.h"
#import "FTUploadConditions.h"
#import "FTNetworkInfoManager.h"
#import "FTUploadStatus.h"
#import "FTUIImageResource.h"
#import "UIImage+FTSRIdentifier.h"
#import "UIColor+FTSRIdentifier.h"
#import "FTSRWireframe.h"
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#endif

BOOL isNull(id value)
{
    if (!value) return YES;
    if ([value isKindOfClass:[NSNull class]]) return YES;

    return NO;
}
BOOL isNAN(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *num = (NSNumber *)value;
        return num.doubleValue != num.doubleValue;
    }
    
    if ([value isKindOfClass:[NSValue class]]) {
        const char *type = [value objCType];
        if (strcmp(type, @encode(double)) == 0) {
            return isnan([value doubleValue]);
        } else if (strcmp(type, @encode(float)) == 0) {
            return isnan([value floatValue]);
        }
    }
    return NO;
}

@interface FTTestSRFrame : FTSRBaseFrame
@property (nonatomic, copy) NSString *testName;
@property (nonatomic, strong,nullable) NSDictionary *property;

@end
@implementation FTTestSRFrame


@end

@interface FTResourceRequest (Testing)
- (void)requestWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters;
@end

@interface FTResourceCheckRequest (Testing)
- (void)requestWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters;
@end

@interface FTSessionReplayFeature (Testing)
- (void)addCssTextToHrefWithFileScheme:(NSMutableDictionary *)rootNodeDict slotID:(NSString *)slotID;
@end

@interface FTImageFeatureUpload (Testing)
- (FTUploadStatus *)flushWithEvent:(id)event parameters:(NSDictionary *)parameters;
- (void)cancelSynchronously;
@end

@interface FTMockSRResource : NSObject<FTSRResource>
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSData *data;
@end

@implementation FTMockSRResource
- (NSString *)calculateIdentifier{
    return self.identifier;
}
- (NSData *)calculateData{
    return self.data;
}
@end

@interface FTMockResourcesWriter : NSObject<FTResourcesWriting>
@property (nonatomic, strong) NSMutableArray<FTEnrichedResource *> *writtenResources;
@end

@implementation FTMockResourcesWriter
- (instancetype)init{
    self = [super init];
    if (self) {
        _writtenResources = [NSMutableArray new];
    }
    return self;
}
- (void)write:(NSArray<FTEnrichedResource *> *)resources{
    [self.writtenResources addObjectsFromArray:resources];
}
- (void)writeExternalResourcesToNormalDirectory:(NSArray<FTEnrichedResource *> *)resources{
    [self write:resources];
}
@end

static void *FTExternalImageProcessorQueueKey = &FTExternalImageProcessorQueueKey;

@interface FTMockExternalImageResourceWriter : NSObject<FTResourcesWriting>
@property (nonatomic, strong) NSMutableArray<FTEnrichedResource *> *writtenResources;
@property (nonatomic, assign) BOOL allWritesOnProcessorQueue;
@property (nonatomic, assign) NSUInteger normalDirectoryCallCount;
@end

@implementation FTMockExternalImageResourceWriter
- (instancetype)init{
    self = [super init];
    if (self) {
        _writtenResources = [NSMutableArray new];
        _allWritesOnProcessorQueue = YES;
    }
    return self;
}
- (void)write:(NSArray<FTEnrichedResource *> *)resources{
    self.allWritesOnProcessorQueue = self.allWritesOnProcessorQueue && dispatch_get_specific(FTExternalImageProcessorQueueKey) != NULL;
    [self.writtenResources addObjectsFromArray:resources];
}
- (void)writeExternalResourcesToNormalDirectory:(NSArray<FTEnrichedResource *> *)resources{
    self.normalDirectoryCallCount += 1;
    [self write:resources];
}
@end

@interface FTMockDataStore : NSObject<FTDataStore>
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *values;
@property (nonatomic, strong) NSMutableArray<NSString *> *setKeys;
@end

@implementation FTMockDataStore
- (instancetype)init{
    self = [super init];
    if (self) {
        _values = [NSMutableDictionary new];
        _setKeys = [NSMutableArray new];
    }
    return self;
}
- (void)setValue:(NSData *)value forKey:(NSString *)key version:(FTDataStoreKeyVersion)version{
    self.values[key] = value;
    [self.setKeys addObject:key];
}
- (void)removeValueForKey:(NSString *)key{
    [self.values removeObjectForKey:key];
}
- (void)valueForKey:(NSString *)key callback:(DataStoreValueResult)callback{
    NSData *data = self.values[key];
    callback(nil, data, data ? DataStoreDefaultKeyVersion : (FTDataStoreKeyVersion)-1);
}
@end

@interface FTMockFilesOrchestrator : NSObject<FTFilesOrchestratorType>
@property (nonatomic, strong) id<FTStoragePerformancePreset> performance;
@property (nonatomic, assign) BOOL ignoreFilesAgeWhenReading;
@property (nonatomic, assign) NSInteger writableFileRequestCount;
@end

@implementation FTMockFilesOrchestrator
- (id<FTWritableFile>)getWritableFile:(long long)writeSize{
    return [self getWritableFile:writeSize forceNewFile:NO];
}
- (id<FTWritableFile>)getWritableFile:(long long)writeSize forceNewFile:(BOOL)force{
    self.writableFileRequestCount += 1;
    return nil;
}
- (NSArray<FTFile *> *)getReadableFiles:(NSSet *)excludedFileNames limit:(int)limit{
    return @[];
}
- (void)deleteReadableFile:(id<FTReadableFile>)readableFile{
}
@end

static void *FTExternalSegmentProcessorQueueKey = &FTExternalSegmentProcessorQueueKey;

@interface FTMockExternalSegmentWriter : NSObject<FTWriter>
@property (nonatomic, strong) NSMutableArray<NSData *> *writtenData;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *forceNewFileValues;
@property (nonatomic, assign) BOOL allWritesOnProcessorQueue;
@end

@implementation FTMockExternalSegmentWriter
- (instancetype)init{
    self = [super init];
    if (self) {
        _writtenData = [NSMutableArray new];
        _forceNewFileValues = [NSMutableArray new];
        _allWritesOnProcessorQueue = YES;
    }
    return self;
}
- (void)write:(NSData *)datas{
    [self write:datas forceNewFile:NO];
}
- (void)write:(NSData *)datas forceNewFile:(BOOL)force{
    @synchronized (self) {
        self.allWritesOnProcessorQueue = self.allWritesOnProcessorQueue && dispatch_get_specific(FTExternalSegmentProcessorQueueKey) != NULL;
        [self.writtenData addObject:datas];
        [self.forceNewFileValues addObject:@(force)];
    }
}
@end

@interface FTMockExternalSegmentScope : FTFeatureScope
@property (nonatomic, strong) id<FTWriter> writer;
@property (nonatomic, copy, nullable) FTTrackingConsent (^samplingConsentProvider)(void);
- (instancetype)initWithWriter:(id<FTWriter>)writer;
@end

@implementation FTMockExternalSegmentScope
- (instancetype)initWithWriter:(id<FTWriter>)writer{
    self = [super initWithStorage:nil trackingConsentProvider:nil];
    if (self) {
        _writer = writer;
    }
    return self;
}
- (FTTrackingConsent)trackingConsent{
    return self.samplingConsentProvider ? self.samplingConsentProvider() : FTTrackingConsentGranted;
}
- (void)eventWriteContext:(FTFeatureWriteContext)block{
    block([[FTFeatureContext alloc]initWithTrackingConsent:self.trackingConsent], self.writer);
}
@end

@interface FTMockHTTPClient : FTHTTPClient
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *checkBodies;
@property (nonatomic, strong) NSMutableArray<NSString *> *writeBodies;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *contentMap;
@property (nonatomic, assign) NSInteger checkStatusCode;
@property (nonatomic, strong, nullable) NSData *checkResponseData;
@property (nonatomic, assign) NSInteger writeStatusCode;
@end

@implementation FTMockHTTPClient
- (instancetype)init{
    self = [super initWithTimeoutIntervalForRequest:1];
    if (self) {
        _checkBodies = [NSMutableArray new];
        _writeBodies = [NSMutableArray new];
        _checkStatusCode = 200;
        _writeStatusCode = 200;
    }
    return self;
}

- (void)sendRequest:(id<FTRequestProtocol>)request completion:(void (^)(NSHTTPURLResponse * _Nullable, NSData * _Nullable, NSError * _Nullable))callback{
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    if ([request respondsToSelector:@selector(adaptedRequest:)]) {
        urlRequest = [request adaptedRequest:urlRequest];
    }
    if ([request isKindOfClass:[FTResourceCheckRequest class]]) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:urlRequest.URL
                                                                 statusCode:self.checkStatusCode
                                                                HTTPVersion:nil
                                                               headerFields:@{@"Content-Type": self.checkResponseData ? @"text/html" : @"application/json"}];
        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:urlRequest.HTTPBody options:kNilOptions error:nil];
        [self.checkBodies addObject:body];
        NSMutableDictionary *content = [NSMutableDictionary dictionary];
        for (NSString *identifier in body[@"files"]) {
            content[identifier] = self.contentMap[identifier] ?: @NO;
        }
        NSData *responseData = self.checkResponseData ?: [NSJSONSerialization dataWithJSONObject:@{@"content":content} options:kNilOptions error:nil];
        callback(response, responseData, nil);
        return;
    }
    NSString *body = [[NSString alloc] initWithData:urlRequest.HTTPBody encoding:NSUTF8StringEncoding];
    [self.writeBodies addObject:body ?: @""];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:urlRequest.URL statusCode:self.writeStatusCode HTTPVersion:nil headerFields:nil];
    callback(response, [NSData data], nil);
}
@end

@interface SessionReplayUtil : XCTestCase

@end

@implementation SessionReplayUtil

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTNetworkInfoManager sharedInstance] clearUploadInfo];
}

- (void)testFileWriterDropsPayloadExceedingMaximumLengthBeforeRequestingFile {
    dispatch_queue_t queue = dispatch_queue_create("com.ft.test.session-replay-file-writer", DISPATCH_QUEUE_SERIAL);
    FTMockFilesOrchestrator *orchestrator = [FTMockFilesOrchestrator new];
    FTFileWriter *writer = [[FTFileWriter alloc]initWithOrchestrator:orchestrator queue:queue];
    NSData *payload = [NSMutableData dataWithLength:FT_MAX_DATA_LENGTH + 1];

    [writer write:payload];
    dispatch_sync(queue, ^{});

    XCTAssertEqual(orchestrator.writableFileRequestCount, 0);
}

- (void)testTLVAcceptsPayloadAtMaximumLength {
    NSData *payload = [NSMutableData dataWithLength:FT_MAX_DATA_LENGTH];
    FTTLV *tlv = [[FTTLV alloc]initWithType:1 value:payload];

    XCTAssertNotNil([tlv serialize]);
}

- (void)testExternalSegmentsAreProcessedSeriallyOnProcessorsQueue {
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc]initWithConfig:[FTSessionReplayConfig new]];
    FTMockExternalSegmentWriter *writer = [FTMockExternalSegmentWriter new];
    FTMockExternalSegmentScope *scope = [[FTMockExternalSegmentScope alloc]initWithWriter:writer];
    [feature setValue:scope forKey:@"recordScope"];
    dispatch_queue_t processorsQueue = [feature valueForKey:@"processorsQueue"];
    dispatch_queue_set_specific(processorsQueue, FTExternalSegmentProcessorQueueKey, FTExternalSegmentProcessorQueueKey, NULL);

    dispatch_apply(50, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        [feature writeExternalSegment:[NSString stringWithFormat:@"segment-%zu", index] viewID:@"view-1"];
    });
    XCTestExpectation *processed = [self expectationWithDescription:@"External segments processed"];
    dispatch_async(processorsQueue, ^{
        [processed fulfill];
    });
    [self waitForExpectations:@[processed] timeout:2];

    XCTAssertEqual(writer.writtenData.count, 50);
    XCTAssertTrue(writer.allWritesOnProcessorQueue);
    NSUInteger forceNewFileCount = [writer.forceNewFileValues indexesOfObjectsPassingTest:^BOOL(NSNumber *value, NSUInteger idx, BOOL *stop) {
        return value.boolValue;
    }].count;
    XCTAssertEqual(forceNewFileCount, 1);
}

- (void)testExternalSegmentFollowsCoordinatorSamplingState {
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:[FTSessionReplayConfig new]];
    FTMockExternalSegmentWriter *writer = [FTMockExternalSegmentWriter new];
    FTRecordingCoordinator *coordinator = [feature valueForKey:@"recordingCoordinator"];
    FTMockExternalSegmentScope *scope = [[FTMockExternalSegmentScope alloc] initWithWriter:writer];
    scope.samplingConsentProvider = ^FTTrackingConsent { return coordinator.trackingConsent; };
    [feature setValue:scope forKey:@"recordScope"];
    dispatch_queue_t queue = [feature valueForKey:@"processorsQueue"];
    NSString *segment = @"segment";

    [feature writeExternalSegment:segment viewID:@"view-1"];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(writer.writtenData.count, 0);

    [coordinator setSampleState:FTRecordingSampleStateNormal];
    [feature writeExternalSegment:segment viewID:@"view-1"];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(writer.writtenData.count, 1);
    XCTAssertEqualObjects(writer.writtenData.firstObject, [segment dataUsingEncoding:NSUTF8StringEncoding]);

    [coordinator setSampleState:FTRecordingSampleStateError];
    [feature writeExternalSegment:segment viewID:@"view-1"];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(writer.writtenData.count, 2);

    [coordinator setSampleState:FTRecordingSampleStateNone];
    [feature writeExternalSegment:segment viewID:@"view-1"];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(writer.writtenData.count, 2);
}

- (void)testExternalRUMContextUsesCopiedStableKeysOnlyWhileSampled {
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:[FTSessionReplayConfig new]];
    FTRecordingCoordinator *coordinator = [feature valueForKey:@"recordingCoordinator"];
    FTMockExternalSegmentScope *scope = [[FTMockExternalSegmentScope alloc] initWithWriter:[FTMockExternalSegmentWriter new]];
    scope.samplingConsentProvider = ^FTTrackingConsent { return coordinator.trackingConsent; };
    [feature setValue:scope forKey:@"recordScope"];
    NSMutableDictionary *globalContext = [@{@"team": @"ios"} mutableCopy];
    NSMutableDictionary *rumContext = [@{
        FT_APP_ID: @"app-1",
        FT_RUM_KEY_SESSION_ID: @"session-1",
        FT_KEY_VIEW_ID: @"view-1",
        FT_LINK_RUM_KEYS: globalContext,
        FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION: @YES,
    } mutableCopy];
    [coordinator setValue:rumContext forKey:@"currentRUMContext"];

    XCTAssertNil([feature currentExternalRUMContext]);
    [coordinator setSampleState:FTRecordingSampleStateNormal];
    NSDictionary *context = [feature currentExternalRUMContext];
    XCTAssertEqualObjects(context[FTSessionReplayRUMContextApplicationIDKey], @"app-1");
    XCTAssertEqualObjects(context[FTSessionReplayRUMContextViewIDKey], @"view-1");
    XCTAssertEqualObjects(context[FTSessionReplayRUMContextGlobalContextKey], (@{@"team": @"ios"}));
    XCTAssertEqualObjects(context[FTSessionReplayRUMContextSampledForErrorSessionKey], @YES);

    globalContext[@"team"] = @"changed";
    rumContext[FT_KEY_VIEW_ID] = @"view-2";
    XCTAssertEqualObjects(context[FTSessionReplayRUMContextViewIDKey], @"view-1");
    XCTAssertEqualObjects(context[FTSessionReplayRUMContextGlobalContextKey], (@{@"team": @"ios"}));
}

- (void)testExternalImageResourceUsesConfigWhitelistAndStableIdentifier {
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.enableLinkRUMKeys = @[@"team"];
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:config];
    FTMockExternalImageResourceWriter *writer = [FTMockExternalImageResourceWriter new];
    [feature setValue:writer forKey:@"externalResourceWriter"];
    FTRecordingCoordinator *coordinator = [feature valueForKey:@"recordingCoordinator"];
    FTMockExternalSegmentScope *scope = [[FTMockExternalSegmentScope alloc] initWithWriter:[FTMockExternalSegmentWriter new]];
    scope.samplingConsentProvider = ^FTTrackingConsent { return coordinator.trackingConsent; };
    [feature setValue:scope forKey:@"resourceScope"];
    dispatch_queue_t queue = [feature valueForKey:@"processorsQueue"];
    NSData *pngData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    [coordinator setValue:@{
        FT_APP_ID: @"app-1",
        FT_LINK_RUM_KEYS: @{@"team": @"ios", @"secret": @"excluded"},
    } forKey:@"currentRUMContext"];

    XCTAssertNil([feature saveExternalImageResourceData:pngData mimeType:@"image/png"]);
    [coordinator setSampleState:FTRecordingSampleStateNormal];
    NSString *identifier = [feature saveExternalImageResourceData:pngData mimeType:@"image/png"];
    dispatch_sync(queue, ^{});

    XCTAssertEqualObjects(identifier, @"900150983cd24fb0d6963f7d28e17f72");
    XCTAssertEqual(writer.writtenResources.count, 1);
    XCTAssertEqual(writer.normalDirectoryCallCount, 1);
    XCTAssertEqualObjects(writer.writtenResources.firstObject.appId, @"app-1");
    XCTAssertEqualObjects(writer.writtenResources.firstObject.bindInfo, (@{@"team": @"ios"}));

    [coordinator setSampleState:FTRecordingSampleStateError];
    XCTAssertEqualObjects([feature saveExternalImageResourceData:pngData mimeType:@"image/png"], identifier);
    dispatch_sync(queue, ^{});
    XCTAssertEqual(writer.normalDirectoryCallCount, 2);

    [coordinator setSampleState:FTRecordingSampleStateNone];
    XCTAssertNil([feature saveExternalImageResourceData:pngData mimeType:@"image/png"]);
    dispatch_sync(queue, ^{});
    XCTAssertEqual(writer.normalDirectoryCallCount, 2);
}

- (void)testExternalSegmentsForceNewFileWhenViewChangesInSubmissionOrder {
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc]initWithConfig:[FTSessionReplayConfig new]];
    FTMockExternalSegmentWriter *writer = [FTMockExternalSegmentWriter new];
    FTMockExternalSegmentScope *scope = [[FTMockExternalSegmentScope alloc]initWithWriter:writer];
    [feature setValue:scope forKey:@"recordScope"];
    dispatch_queue_t processorsQueue = [feature valueForKey:@"processorsQueue"];
    dispatch_queue_set_specific(processorsQueue, FTExternalSegmentProcessorQueueKey, FTExternalSegmentProcessorQueueKey, NULL);

    [feature writeExternalSegment:@"segment-1" viewID:@"view-1"];
    [feature writeExternalSegment:@"segment-2" viewID:@"view-1"];
    [feature writeExternalSegment:@"segment-3" viewID:@"view-2"];
    XCTestExpectation *processed = [self expectationWithDescription:@"External segments processed in order"];
    dispatch_async(processorsQueue, ^{
        [processed fulfill];
    });
    [self waitForExpectations:@[processed] timeout:2];

    XCTAssertEqualObjects(writer.forceNewFileValues, (@[@YES, @NO, @YES]));
    XCTAssertTrue(writer.allWritesOnProcessorQueue);
}

- (void)testExternalImageResourceWriterCapturesInputBeforeAsynchronousProcessing {
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.enableLinkRUMKeys = @[@"env"];
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc]initWithConfig:config];
    FTMockExternalImageResourceWriter *writer = [FTMockExternalImageResourceWriter new];
    FTMockExternalSegmentScope *resourceScope = [[FTMockExternalSegmentScope alloc]initWithWriter:[FTMockExternalSegmentWriter new]];
    [feature setValue:writer forKey:@"externalResourceWriter"];
    [feature setValue:resourceScope forKey:@"resourceScope"];
    NSDictionary *bindInfo = @{@"env": @"test"};
    id recordingCoordinator = [feature valueForKey:@"recordingCoordinator"];
    [recordingCoordinator setValue:@{
        FT_APP_ID: @"app-id",
        FT_LINK_RUM_KEYS: bindInfo,
    } forKey:@"currentRUMContext"];
    dispatch_queue_t processorsQueue = [feature valueForKey:@"processorsQueue"];
    dispatch_queue_set_specific(processorsQueue, FTExternalImageProcessorQueueKey, FTExternalImageProcessorQueueKey, NULL);
    dispatch_suspend(processorsQueue);

    NSMutableData *data = [[@"image-data" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    NSData *expectedData = [data copy];
    NSString *identifier = [feature saveExternalImageResourceData:data mimeType:@"image/png"];
    [data appendData:[@"-mutated" dataUsingEncoding:NSUTF8StringEncoding]];

    XCTAssertNotNil(identifier);
    XCTAssertEqual(writer.writtenResources.count, 0);
    dispatch_resume(processorsQueue);
    XCTestExpectation *processed = [self expectationWithDescription:@"External image resource processed"];
    dispatch_async(processorsQueue, ^{
        [processed fulfill];
    });
    [self waitForExpectations:@[processed] timeout:2];

    XCTAssertEqual(writer.writtenResources.count, 1);
    XCTAssertTrue(writer.allWritesOnProcessorQueue);
    XCTAssertEqual(writer.normalDirectoryCallCount, 1);
    FTEnrichedResource *resource = writer.writtenResources.firstObject;
    XCTAssertEqualObjects(resource.identifier, identifier);
    XCTAssertEqualObjects(resource.data, expectedData);
    XCTAssertEqualObjects(resource.appId, @"app-id");
    XCTAssertEqualObjects(resource.mimeType, @"image/png");
    XCTAssertEqualObjects(resource.bindInfo, bindInfo);
}

- (void)testSegmentJSONUsesIOSSourceByDefault {
    NSDictionary *record = @{
        @"applicationID": @"app-ios",
        @"sessionID": @"session-ios",
        @"viewID": @"view-ios",
        @"records": @[
            @{
                @"type": @2,
                @"timestamp": @1000,
            },
        ],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:0 error:nil];

    FTSegmentJSON *segment = [[FTSegmentJSON alloc] initWithData:data];

    XCTAssertEqualObjects(segment.source, @"ios");
}

- (NSData *)resourceDataWithIdentifier:(NSString *)identifier bindInfo:(NSDictionary *)bindInfo{
    FTEnrichedResource *resource = [[FTEnrichedResource alloc] init];
    resource.identifier = identifier;
    resource.appId = @"app-id";
    resource.data = [[NSString stringWithFormat:@"data-%@",identifier] dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";
    resource.bindInfo = bindInfo;
    return [resource toJSONData];
}

- (FTImageFeatureUpload *)createImageUploadWithHTTPClient:(FTMockHTTPClient *)httpClient{
    FTImageFeatureUpload *upload = [[FTImageFeatureUpload alloc] initWithFeatureName:@"session-replay-resources"
                                                                          fileReader:nil
                                                                         cacheWriter:nil
                                                                      requestBuilder:[[FTResourceRequest alloc] init]
                                                                 maxBatchesPerUpload:10
                                                                         performance:[[FTPerformancePreset alloc] init]
                                                                             context:@{}];
    [upload setValue:httpClient forKey:@"httpClient"];
    [upload cancelSynchronously];
    return upload;
}

- (void)runOnMainThreadAndWait:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
        return;
    }
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Run on main thread"];
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (UIImage *)sessionReplayTestImage{
    CGSize size = CGSizeMake(1, 1);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [[UIColor blackColor] setFill];
        UIRectFill((CGRect){CGPointZero, size});
    }];
}

- (void)testImageSrIdentifierCopiesMutableString{
    UIImage *image = [self sessionReplayTestImage];
    NSMutableString *identifier = [NSMutableString stringWithString:@"image-id"];
    image.srIdentifier = identifier;

    [identifier appendString:@"-mutated"];

    XCTAssertEqualObjects(image.srIdentifier, @"image-id");
}

- (void)testColorSrIdentifierCopiesMutableString{
    UIColor *color = [UIColor redColor];
    NSMutableString *identifier = [NSMutableString stringWithString:@"color-id"];
    color.srIdentifier = identifier;

    [identifier appendString:@"-mutated"];

    XCTAssertEqualObjects(color.srIdentifier, @"color-id");
}

#if !TARGET_OS_TV
- (void)testWebViewLinkRumKeysInfoCopiesMutableDictionary{
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    NSMutableDictionary *linkRumKeysInfo = [@{@"view_id": @"view-1"} mutableCopy];
    webView.ft_linkRumKeysInfo = linkRumKeysInfo;

    linkRumKeysInfo[@"view_id"] = @"view-2";
    linkRumKeysInfo[@"extra"] = @"value";

    XCTAssertEqualObjects(webView.ft_linkRumKeysInfo[@"view_id"], @"view-1");
    XCTAssertNil(webView.ft_linkRumKeysInfo[@"extra"]);
    XCTAssertFalse([webView.ft_linkRumKeysInfo isKindOfClass:[NSMutableDictionary class]]);
}
#endif

- (void)testImageResourceResolvesDynamicTintColorBeforeBackgroundProcessing API_AVAILABLE(ios(13.0)){
    __block NSInteger providerCallCount = 0;
    __block NSInteger backgroundProviderCallCount = 0;
    UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        providerCallCount += 1;
        if (![NSThread isMainThread]) {
            backgroundProviderCallCount += 1;
        }
        return [UIColor colorWithRed:0.1 green:0.2 blue:0.3 alpha:0.4];
    }];
    UITraitCollection *traitCollection = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
    
    __block FTUIImageResource *resource = nil;
    [self runOnMainThreadAndWait:^{
        resource = [[FTUIImageResource alloc] initWithImage:[self sessionReplayTestImage]
                                                  tintColor:dynamicColor
                                            traitCollection:traitCollection];
    }];
    NSInteger providerCallsAfterSnapshot = providerCallCount;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Background resource processing"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [resource calculateIdentifier];
        [resource calculateData];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(backgroundProviderCallCount, 0);
    XCTAssertEqual(providerCallCount, providerCallsAfterSnapshot);
}

- (void)testViewAttributesResolveDynamicColorsBeforeBackgroundProcessing API_AVAILABLE(ios(13.0)){
    __block NSInteger providerCallCount = 0;
    __block NSInteger backgroundProviderCallCount = 0;
    UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        providerCallCount += 1;
        if (![NSThread isMainThread]) {
            backgroundProviderCallCount += 1;
        }
        return [UIColor colorWithRed:0.4 green:0.3 blue:0.2 alpha:0.8];
    }];
    
    __block FTViewAttributes *attributes = nil;
    [self runOnMainThreadAndWait:^{
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        view.backgroundColor = dynamicColor;
        attributes = [[FTViewAttributes alloc] initWithView:view
                                            frameInRootView:view.frame
                                                       clip:view.frame
                                                  overrides:[PrivacyOverrides new]];
    }];
    NSInteger providerCallsAfterSnapshot = providerCallCount;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Background wireframe processing"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        __unused FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc] initWithIdentifier:1 attributes:attributes];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(backgroundProviderCallCount, 0);
    XCTAssertEqual(providerCallCount, providerCallsAfterSnapshot);
}

- (void)verifyImageFeatureUploadFailsWithStatusCode:(NSInteger)statusCode{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.contentMap = @{@"resource-a":@NO};
    httpClient.writeStatusCode = statusCode;
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"user_id":@"user-1"}]
    ];
    
    FTUploadStatus *status = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];
    
    XCTAssertFalse(status.success);
    XCTAssertTrue(status.needsRetry);
    XCTAssertEqualObjects(status.responseCode, @(statusCode));
    XCTAssertEqual(httpClient.checkBodies.count, 1);
    XCTAssertEqual(httpClient.writeBodies.count, 1);
}

- (void)testUploadStatusTreatsCurrentSuccessfulCodesAsSuccess{
    NSArray<NSNumber *> *successCodes = @[@200, @202, @204, @400, @401, @404, @413];
    for (NSNumber *statusCode in successCodes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"] statusCode:statusCode.integerValue HTTPVersion:nil headerFields:nil];
        FTUploadStatus *status = [FTUploadStatus statusWithHTTPResponse:response error:nil previousStatus:nil];
        
        XCTAssertTrue(status.success, @"statusCode:%@", statusCode);
        XCTAssertFalse(status.needsRetry, @"statusCode:%@", statusCode);
        XCTAssertEqualObjects(status.responseCode, statusCode);
    }
}

- (void)testUploadStatusCreatesSuccessWithoutHTTPResponse{
    FTUploadStatus *status = [FTUploadStatus successStatus];

    XCTAssertTrue(status.success);
    XCTAssertFalse(status.needsRetry);
    XCTAssertNil(status.responseCode);
    XCTAssertNil(status.error);
    XCTAssertEqual(status.attempt, 0);
}

- (void)testUploadStatusTreatsCurrentFailureCodesAsRetryable{
    NSArray<NSNumber *> *failureCodes = @[@403, @429, @500, @502, @503, @504];
    for (NSNumber *statusCode in failureCodes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"] statusCode:statusCode.integerValue HTTPVersion:nil headerFields:nil];
        FTUploadStatus *status = [FTUploadStatus statusWithHTTPResponse:response error:nil previousStatus:nil];
        
        XCTAssertFalse(status.success, @"statusCode:%@", statusCode);
        XCTAssertTrue(status.needsRetry, @"statusCode:%@", statusCode);
        XCTAssertEqualObjects(status.responseCode, statusCode);
    }
}

- (void)testUploadStatusTreatsNetworkErrorAndNilResponseAsRetryable{
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    FTUploadStatus *errorStatus = [FTUploadStatus statusWithHTTPResponse:nil error:error previousStatus:nil];
    FTUploadStatus *nilResponseStatus = [FTUploadStatus statusWithHTTPResponse:nil error:nil previousStatus:nil];
    
    XCTAssertFalse(errorStatus.success);
    XCTAssertTrue(errorStatus.needsRetry);
    XCTAssertNil(errorStatus.responseCode);
    XCTAssertEqualObjects(errorStatus.error, error);
    
    XCTAssertFalse(nilResponseStatus.success);
    XCTAssertTrue(nilResponseStatus.needsRetry);
    XCTAssertNil(nilResponseStatus.responseCode);
}

- (void)testUploadStatusIncreasesAttemptFromPreviousStatus{
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"] statusCode:500 HTTPVersion:nil headerFields:nil];
    
    FTUploadStatus *first = [FTUploadStatus statusWithHTTPResponse:response error:nil previousStatus:nil];
    FTUploadStatus *second = [FTUploadStatus statusWithHTTPResponse:response error:nil previousStatus:first];
    
    XCTAssertEqual(first.attempt, 0);
    XCTAssertEqual(second.attempt, 1);
}

- (void)testFuncConflict{
    FTTestSRFrame *test = [[FTTestSRFrame alloc]init];
    test.testName = @"testFuncConflict";
    
    NSDictionary *dict = [test toDictionary];
    XCTAssertEqual(dict[@"testName"] , @"testFuncConflict");
    XCTAssertNil(dict[@"property"]);
}

- (void)testWebCssTextInjectionHandlesImmutableNestedNodes{
    NSString *cssPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ft-session-replay-test.css"];
    NSString *cssText = @"body { color: red; }";
    XCTAssertTrue([cssText writeToFile:cssPath atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    
    NSDictionary *linkNode = @{
        @"tagName":@"link",
        @"attributes":@{@"href":[@"file://" stringByAppendingString:cssPath]}
    };
    NSMutableDictionary *rootNode = [@{
        @"tagName":@"div",
        @"childNodes":@[linkNode]
    } mutableCopy];
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:[[FTSessionReplayConfig alloc] init]];
    
    [feature addCssTextToHrefWithFileScheme:rootNode slotID:@"slot-id"];
    
    NSArray *childNodes = rootNode[@"childNodes"];
    NSDictionary *processedLinkNode = childNodes.firstObject;
    NSDictionary *attributes = processedLinkNode[@"attributes"];
    XCTAssertEqualObjects(attributes[@"_cssText"], cssText);
    XCTAssertTrue([childNodes isKindOfClass:NSMutableArray.class]);
    XCTAssertTrue([processedLinkNode isKindOfClass:NSMutableDictionary.class]);
    XCTAssertTrue([attributes isKindOfClass:NSMutableDictionary.class]);
    
    [[NSFileManager defaultManager] removeItemAtPath:cssPath error:nil];
}

- (void)testEnrichedResourceArchivePreservesBindInfo{
    FTEnrichedResource *resource = [[FTEnrichedResource alloc] init];
    resource.identifier = @"resource-id";
    resource.appId = @"app-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";
    resource.bindInfo = @{@"user_id":@"123"};
    
    NSData *encoded = [resource toJSONData];
    FTEnrichedResource *decoded = [[FTEnrichedResource alloc] initWithData:encoded];
    
    XCTAssertEqualObjects(decoded.bindInfo, resource.bindInfo);
}

- (void)testResourceProcessorWritesBindInfo{
    dispatch_queue_t queue = dispatch_queue_create("com.ft.sr.resource-processor.test", DISPATCH_QUEUE_SERIAL);
    FTMockResourcesWriter *writer = [[FTMockResourcesWriter alloc] init];
    FTResourceProcessor *processor = [[FTResourceProcessor alloc] initWithQueue:queue resourceWriter:writer];
    FTMockSRResource *resource = [[FTMockSRResource alloc] init];
    resource.identifier = @"resource-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";
    
    FTSRContext *context = [[FTSRContext alloc] init];
    context.applicationID = @"app-id";
    context.bindInfo = @{@"user_id":@"123"};
    
    [processor process:@[resource] context:context];
    dispatch_sync(queue, ^{
    });
    
    XCTAssertEqual(writer.writtenResources.count, 1);
    XCTAssertEqualObjects(writer.writtenResources.firstObject.bindInfo, context.bindInfo);
}

- (void)testResourceDeduplicationIdentifierUsesBindInfoValues{
    FTEnrichedResource *first = [[FTEnrichedResource alloc] init];
    first.identifier = @"resource-id";
    first.bindInfo = @{@"wgtid": @"widget-1", @"tenant": @"tenant-1"};

    FTEnrichedResource *sameContext = [[FTEnrichedResource alloc] init];
    sameContext.identifier = @"resource-id";
    sameContext.bindInfo = @{@"tenant": @"tenant-1", @"wgtid": @"widget-1"};

    FTEnrichedResource *differentContext = [[FTEnrichedResource alloc] init];
    differentContext.identifier = @"resource-id";
    differentContext.bindInfo = @{@"wgtid": @"widget-2", @"tenant": @"tenant-1"};

    FTEnrichedResource *withoutBindInfo = [[FTEnrichedResource alloc] init];
    withoutBindInfo.identifier = @"resource-id";

    XCTAssertEqualObjects(first.deduplicationIdentifier, sameContext.deduplicationIdentifier);
    XCTAssertNotEqualObjects(first.deduplicationIdentifier, differentContext.deduplicationIdentifier);
    XCTAssertEqualObjects(withoutBindInfo.deduplicationIdentifier, withoutBindInfo.identifier);
}

- (void)testResourceProcessorWritesSameIdentifierForDifferentBindInfo{
    dispatch_queue_t queue = dispatch_queue_create("com.ft.sr.resource-processor.deduplication.test", DISPATCH_QUEUE_SERIAL);
    FTMockResourcesWriter *writer = [[FTMockResourcesWriter alloc] init];
    FTResourceProcessor *processor = [[FTResourceProcessor alloc] initWithQueue:queue resourceWriter:writer];
    FTMockSRResource *resource = [[FTMockSRResource alloc] init];
    resource.identifier = @"resource-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";

    FTSRContext *firstContext = [[FTSRContext alloc] init];
    firstContext.applicationID = @"app-id";
    firstContext.bindInfo = @{@"wgtid": @"widget-1"};
    FTSRContext *secondContext = [[FTSRContext alloc] init];
    secondContext.applicationID = @"app-id";
    secondContext.bindInfo = @{@"wgtid": @"widget-2"};

    [processor process:@[resource] context:firstContext];
    [processor process:@[resource] context:secondContext];
    [processor process:@[resource] context:firstContext];
    dispatch_sync(queue, ^{
    });

    XCTAssertEqual(writer.writtenResources.count, 2);
    XCTAssertEqualObjects(writer.writtenResources[0].bindInfo, firstContext.bindInfo);
    XCTAssertEqualObjects(writer.writtenResources[1].bindInfo, secondContext.bindInfo);
}

- (void)testResourcesWriterPersistsSameIdentifierForDifferentBindInfo{
    dispatch_queue_t queue = dispatch_queue_create("com.ft.sr.resources-writer.deduplication.test", DISPATCH_QUEUE_SERIAL);
    NSString *basePath = [NSString stringWithFormat:@"ft-session-replay-resource-writer-test/%@", NSUUID.UUID.UUIDString];
    FTDirectory *grantedDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:basePath];
    FTFeatureDirectories *directories = [[FTFeatureDirectories alloc] initWithGranted:grantedDirectory
                                                                              pending:nil
                                                                         errorSampled:nil];
    FTFeatureStorage *storage = [[FTFeatureStorage alloc] initWithFeatureName:@"session-replay-resources"
                                                                        queue:queue
                                                                  directories:directories
                                                                  performance:[[FTPerformancePreset alloc] init]];
    FTFeatureScope *scope = [[FTFeatureScope alloc] initWithStorage:storage trackingConsentProvider:^FTTrackingConsent{
        return FTTrackingConsentGranted;
    }];
    FTMockDataStore *dataStore = [[FTMockDataStore alloc] init];
    FTResourcesWriter *writer = [[FTResourcesWriter alloc] initWithFeatureScope:scope dataStore:dataStore];
    FTEnrichedResource *first = [[FTEnrichedResource alloc] init];
    first.identifier = @"resource-id";
    first.appId = @"app-id";
    first.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    first.mimeType = @"image/png";
    first.bindInfo = @{@"wgtid": @"widget-1"};
    FTEnrichedResource *second = [[FTEnrichedResource alloc] init];
    second.identifier = @"resource-id";
    second.appId = @"app-id";
    second.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    second.mimeType = @"image/png";
    second.bindInfo = @{@"wgtid": @"widget-2"};

    [writer write:@[first]];
    [writer write:@[second, first]];
    dispatch_sync(queue, ^{
    });

    NSSet *knownIdentifiers = [writer valueForKey:@"knownIdentifiers"];
    XCTAssertEqual(knownIdentifiers.count, 2);
    XCTAssertTrue([knownIdentifiers containsObject:first.deduplicationIdentifier]);
    XCTAssertTrue([knownIdentifiers containsObject:second.deduplicationIdentifier]);
    XCTAssertTrue([dataStore.setKeys containsObject:@"ft-known-resources"]);

    FTResourcesWriter *reloadedWriter = [[FTResourcesWriter alloc] initWithFeatureScope:scope dataStore:dataStore];
    NSSet *reloadedKnownIdentifiers = [reloadedWriter valueForKey:@"knownIdentifiers"];
    XCTAssertEqual(reloadedKnownIdentifiers.count, 2);
    XCTAssertTrue([reloadedKnownIdentifiers containsObject:first.deduplicationIdentifier]);
    XCTAssertTrue([reloadedKnownIdentifiers containsObject:second.deduplicationIdentifier]);

    [reloadedWriter write:@[first, second]];
    dispatch_sync(queue, ^{
    });
    XCTAssertEqual([[reloadedWriter valueForKey:@"knownIdentifiers"] count], 2);

    FTEnrichedResource *third = [[FTEnrichedResource alloc] init];
    third.identifier = @"resource-id";
    third.appId = @"app-id";
    third.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    third.mimeType = @"image/png";
    third.bindInfo = @{@"wgtid": @"widget-3"};
    [reloadedWriter write:@[third]];
    dispatch_sync(queue, ^{
    });
    NSSet *updatedKnownIdentifiers = [reloadedWriter valueForKey:@"knownIdentifiers"];
    XCTAssertEqual(updatedKnownIdentifiers.count, 3);
    XCTAssertTrue([updatedKnownIdentifiers containsObject:third.deduplicationIdentifier]);
}

- (void)testResourcesWriterDoesNotPersistKnownIdentifierWhenNotGranted{
    dispatch_queue_t queue = dispatch_queue_create("com.ft.sr.resources-writer.not-granted.test", DISPATCH_QUEUE_SERIAL);
    NSString *basePath = [NSString stringWithFormat:@"ft-session-replay-resource-writer-test/%@", NSUUID.UUID.UUIDString];
    FTDirectory *grantedDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:basePath];
    FTFeatureDirectories *directories = [[FTFeatureDirectories alloc] initWithGranted:grantedDirectory
                                                                              pending:nil
                                                                         errorSampled:nil];
    FTFeatureStorage *storage = [[FTFeatureStorage alloc] initWithFeatureName:@"session-replay-resources"
                                                                        queue:queue
                                                                  directories:directories
                                                                  performance:[[FTPerformancePreset alloc] init]];
    __block FTTrackingConsent trackingConsent = FTTrackingConsentNotGranted;
    FTFeatureScope *scope = [[FTFeatureScope alloc] initWithStorage:storage trackingConsentProvider:^FTTrackingConsent{
        return trackingConsent;
    }];
    FTMockDataStore *dataStore = [[FTMockDataStore alloc] init];
    FTResourcesWriter *writer = [[FTResourcesWriter alloc] initWithFeatureScope:scope dataStore:dataStore];
    FTEnrichedResource *resource = [[FTEnrichedResource alloc] init];
    resource.identifier = @"resource-id";
    resource.appId = @"app-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";

    [writer write:@[resource]];
    dispatch_sync(queue, ^{
    });

    NSSet *knownIdentifiers = [writer valueForKey:@"knownIdentifiers"];
    XCTAssertFalse([knownIdentifiers containsObject:resource.identifier]);
    XCTAssertFalse([dataStore.setKeys containsObject:@"ft-known-resources"]);
    XCTAssertEqual(grantedDirectory.files.count, 0);
}

- (void)testExternalErrorSampledImageUsesNormalDirectoryWithoutGrantingUnsampledWrites{
    dispatch_queue_t queue = dispatch_queue_create("com.ft.sr.external-resource-consent.test", DISPATCH_QUEUE_SERIAL);
    NSString *basePath = [NSString stringWithFormat:@"ft-session-replay-external-resource-test/%@", NSUUID.UUID.UUIDString];
    FTDirectory *normalDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:[basePath stringByAppendingPathComponent:@"normal"]];
    FTDirectory *errorDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:[basePath stringByAppendingPathComponent:@"error"]];
    FTFeatureDirectories *directories = [[FTFeatureDirectories alloc] initWithGranted:normalDirectory
                                                                             pending:nil
                                                                        errorSampled:errorDirectory];
    FTFeatureStorage *storage = [[FTFeatureStorage alloc] initWithFeatureName:@"session-replay-resources"
                                                                        queue:queue
                                                                  directories:directories
                                                                  performance:[[FTPerformancePreset alloc] init]];
    __block FTTrackingConsent consent = FTTrackingConsentErrorSampled;
    FTFeatureScope *scope = [[FTFeatureScope alloc] initWithStorage:storage trackingConsentProvider:^FTTrackingConsent{
        return consent;
    }];
    FTMockDataStore *dataStore = [FTMockDataStore new];
    FTResourcesWriter *writer = [[FTResourcesWriter alloc] initWithFeatureScope:scope dataStore:dataStore];
    FTEnrichedResource *sampled = [FTEnrichedResource new];
    sampled.identifier = @"sampled-image";
    sampled.appId = @"app-id";
    sampled.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    sampled.mimeType = @"image/png";
    sampled.bindInfo = @{@"view": @"one"};

    [writer writeExternalResourcesToNormalDirectory:@[sampled]];
    [writer writeExternalResourcesToNormalDirectory:@[sampled]];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(normalDirectory.files.count, 1);
    XCTAssertEqual(errorDirectory.files.count, 0);
    XCTAssertTrue([[writer valueForKey:@"knownIdentifiers"] containsObject:sampled.deduplicationIdentifier]);

    FTEnrichedResource *blocked = [FTEnrichedResource new];
    blocked.identifier = @"blocked-image";
    blocked.appId = @"app-id";
    blocked.data = [@"def" dataUsingEncoding:NSUTF8StringEncoding];
    blocked.mimeType = @"image/png";
    consent = FTTrackingConsentNotGranted;
    [writer writeExternalResourcesToNormalDirectory:@[blocked]];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(normalDirectory.files.count, 1);
    XCTAssertEqual(errorDirectory.files.count, 0);
    XCTAssertFalse([[writer valueForKey:@"knownIdentifiers"] containsObject:blocked.deduplicationIdentifier]);

    consent = FTTrackingConsentPending;
    [writer writeExternalResourcesToNormalDirectory:@[blocked]];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(normalDirectory.files.count, 1);
    XCTAssertEqual(errorDirectory.files.count, 0);
    XCTAssertFalse([[writer valueForKey:@"knownIdentifiers"] containsObject:blocked.deduplicationIdentifier]);
}

- (void)testUploadConditionsIncludesUploadURLNotConfigured{
    [[FTNetworkInfoManager sharedInstance] clearUploadInfo];
    
    FTUploadConditions *conditions = [[FTUploadConditions alloc] init];
    NSArray *result = [conditions checkForUpload];
    
    XCTAssertEqualObjects(result, @[@"Upload URL Not Configured"]);
}

- (void)testUploadConditionsAllowsConfiguredUploadURL{
    [FTNetworkInfoManager sharedInstance].setUploadURL(@"https://example.com", nil, nil);
    
    FTUploadConditions *conditions = [[FTUploadConditions alloc] init];
    NSArray *result = [conditions checkForUpload];
    
    XCTAssertFalse([result containsObject:@"Upload URL Not Configured"]);
}

- (void)testUploadConditionsUsesUnknownForInvalidBatteryState{
    [FTNetworkInfoManager sharedInstance].setUploadURL(@"https://example.com", nil, nil);
    FTUploadConditions *conditions = [[FTUploadConditions alloc] init];
    [conditions setValue:@0 forKey:@"batteryLevel"];

    NSArray<NSArray *> *blockingCases = @[
        @[@(UIDeviceBatteryStateUnplugged), @"Unplugged"],
        @[@((UIDeviceBatteryState)-1), @"Unknown"],
        @[@(UIDeviceBatteryStateFull + 1), @"Unknown"],
        @[@(NSUIntegerMax), @"Unknown"],
    ];
    for (NSArray *testCase in blockingCases) {
        [conditions setValue:testCase[0] forKey:@"batteryState"];
        NSString *expected = [@"Battery State: " stringByAppendingString:testCase[1]];
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *condition, NSDictionary *bindings) {
            return [condition containsString:expected];
        }];
        XCTAssertEqual([[conditions checkForUpload] filteredArrayUsingPredicate:predicate].count, 1);
    }

    [conditions setValue:@(UIDeviceBatteryStateUnknown) forKey:@"batteryState"];
    XCTAssertNotNil([conditions checkForUpload]);

    NSPredicate *batteryPredicate = [NSPredicate predicateWithBlock:^BOOL(NSString *condition, NSDictionary *bindings) {
        return [condition containsString:@"Battery Level"];
    }];
    [conditions setValue:@(UIDeviceBatteryStateCharging) forKey:@"batteryState"];
    XCTAssertEqual([[conditions checkForUpload] filteredArrayUsingPredicate:batteryPredicate].count, 0);
    [conditions setValue:@(UIDeviceBatteryStateFull) forKey:@"batteryState"];
    XCTAssertEqual([[conditions checkForUpload] filteredArrayUsingPredicate:batteryPredicate].count, 0);
}

- (void)testResourceRequestContainsReplayAssetTagsField{
    FTEnrichedResource *resource = [[FTEnrichedResource alloc] init];
    resource.identifier = @"resource-id";
    resource.appId = @"app-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";
    resource.bindInfo = @{@"wgtid":@"123"};
    
    FTResourceRequest *request = [[FTResourceRequest alloc] init];
    [request requestWithEvents:@[resource] parameters:@{
        FT_APP_ID:@"app-id",
        @"tags":@{@"wgtid":@"123"},
        @"service":@"demo-service"
    }];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    NSMutableURLRequest *adaptedRequest = [request adaptedRequest:urlRequest];
    NSString *body = [[NSString alloc] initWithData:adaptedRequest.HTTPBody encoding:NSUTF8StringEncoding];
    
    XCTAssertTrue([body containsString:@"name=\"app_id\""]);
    XCTAssertTrue([body containsString:@"app-id"]);
    XCTAssertTrue([body containsString:@"name=\"tags\""]);
    XCTAssertTrue([body containsString:@"wgtid"]);
    XCTAssertTrue([body containsString:@"123"]);
    XCTAssertFalse([body containsString:@"name=\"appid\""]);
    XCTAssertFalse([body containsString:@"name=\"wgtid\""]);
    XCTAssertFalse([body containsString:@"name=\"service\""]);
    XCTAssertFalse([body containsString:@"demo-service"]);
}

- (void)testResourceCheckRequestContainsReplayAssetTagsObject{
    FTResourceCheckRequest *request = [[FTResourceCheckRequest alloc] init];
    [request requestWithEvents:@[@"resource-id"] parameters:@{
        FT_APP_ID:@"app-id",
        @"tags":@{@"wgtid":@"123"},
        @"service":@"demo-service",
        @"wgtid":@"flattened-value"
    }];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    NSMutableURLRequest *adaptedRequest = [request adaptedRequest:urlRequest];
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:adaptedRequest.HTTPBody options:kNilOptions error:nil];
    
    XCTAssertEqualObjects(body[FT_APP_ID], @"app-id");
    XCTAssertEqualObjects(body[@"tags"][@"wgtid"], @"123");
    XCTAssertEqualObjects(body[@"files"], (@[@"resource-id"]));
    XCTAssertNil(body[@"appid"]);
    XCTAssertNil(body[@"service"]);
    XCTAssertNil(body[@"wgtid"]);
}

- (void)testResourceRequestOmitsReplayAssetTagsWhenEmpty{
    FTEnrichedResource *resource = [[FTEnrichedResource alloc] init];
    resource.identifier = @"resource-id";
    resource.appId = @"app-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";

    FTResourceRequest *request = [[FTResourceRequest alloc] init];
    [request requestWithEvents:@[resource] parameters:@{FT_APP_ID:@"app-id"}];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    NSMutableURLRequest *adaptedRequest = [request adaptedRequest:urlRequest];
    NSString *body = [[NSString alloc] initWithData:adaptedRequest.HTTPBody encoding:NSUTF8StringEncoding];

    XCTAssertTrue([body containsString:@"name=\"app_id\""]);
    XCTAssertFalse([body containsString:@"name=\"tags\""]);
}

- (void)testResourceCheckRequestOmitsReplayAssetTagsWhenEmpty{
    FTResourceCheckRequest *request = [[FTResourceCheckRequest alloc] init];
    [request requestWithEvents:@[@"resource-id"] parameters:@{FT_APP_ID:@"app-id"}];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    NSMutableURLRequest *adaptedRequest = [request adaptedRequest:urlRequest];
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:adaptedRequest.HTTPBody options:kNilOptions error:nil];

    XCTAssertEqualObjects(body[FT_APP_ID], @"app-id");
    XCTAssertEqualObjects(body[@"files"], (@[@"resource-id"]));
    XCTAssertNil(body[@"tags"]);
}

- (void)testImageFeatureUploadGroupsByLinkedTagsBeforeCheckAndWrite{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.contentMap = @{
        @"resource-a":@NO,
        @"resource-b":@NO,
        @"resource-c":@NO
    };
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"wgtid":@"widget-1"}],
        [self resourceDataWithIdentifier:@"resource-b" bindInfo:@{@"wgtid":@"widget-2"}],
        [self resourceDataWithIdentifier:@"resource-c" bindInfo:@{@"wgtid":@"widget-1"}]
    ];
    
    FTUploadStatus *status = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];
    
    XCTAssertTrue(status.success);
    XCTAssertEqual(httpClient.checkBodies.count, 2);
    XCTAssertEqual(httpClient.writeBodies.count, 2);
    
    NSDictionary *firstCheck = httpClient.checkBodies[0];
    NSDictionary *secondCheck = httpClient.checkBodies[1];
    NSArray *firstFiles = firstCheck[@"files"];
    NSArray *secondFiles = secondCheck[@"files"];
    
    XCTAssertEqualObjects(firstCheck[FT_APP_ID], @"app-id");
    XCTAssertEqualObjects(firstCheck[@"tags"][@"wgtid"], @"widget-1");
    XCTAssertNil(firstCheck[@"wgtid"]);
    XCTAssertNil(firstCheck[@"service"]);
    XCTAssertTrue(firstFiles.count == 2);
    XCTAssertTrue([firstFiles containsObject:@"resource-a"]);
    XCTAssertTrue([firstFiles containsObject:@"resource-c"]);
    XCTAssertEqualObjects(secondCheck[FT_APP_ID], @"app-id");
    XCTAssertEqualObjects(secondCheck[@"tags"][@"wgtid"], @"widget-2");
    XCTAssertNil(secondCheck[@"wgtid"]);
    XCTAssertNil(secondCheck[@"service"]);
    XCTAssertEqualObjects(secondFiles, (@[@"resource-b"]));
    
    NSString *firstWrite = httpClient.writeBodies[0];
    NSString *secondWrite = httpClient.writeBodies[1];
    XCTAssertTrue([firstWrite containsString:@"name=\"app_id\""]);
    XCTAssertTrue([firstWrite containsString:@"name=\"tags\""]);
    XCTAssertTrue([firstWrite containsString:@"widget-1"]);
    XCTAssertTrue([firstWrite containsString:@"resource-a"]);
    XCTAssertTrue([firstWrite containsString:@"resource-c"]);
    XCTAssertFalse([firstWrite containsString:@"resource-b"]);
    XCTAssertFalse([firstWrite containsString:@"name=\"appid\""]);
    XCTAssertFalse([firstWrite containsString:@"name=\"wgtid\""]);
    XCTAssertFalse([firstWrite containsString:@"name=\"service\""]);
    XCTAssertTrue([secondWrite containsString:@"name=\"app_id\""]);
    XCTAssertTrue([secondWrite containsString:@"name=\"tags\""]);
    XCTAssertTrue([secondWrite containsString:@"widget-2"]);
    XCTAssertTrue([secondWrite containsString:@"resource-b"]);
    XCTAssertFalse([secondWrite containsString:@"resource-a"]);
    XCTAssertFalse([secondWrite containsString:@"name=\"appid\""]);
    XCTAssertFalse([secondWrite containsString:@"name=\"wgtid\""]);
    XCTAssertFalse([secondWrite containsString:@"name=\"service\""]);
}

- (void)testImageFeatureUploadTreats403And429AsFailure{
    [self verifyImageFeatureUploadFailsWithStatusCode:403];
    [self verifyImageFeatureUploadFailsWithStatusCode:429];
}

- (void)testImageFeatureUploadDoesNotRetry404HTMLResourceCheckResponse{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.checkStatusCode = 404;
    httpClient.checkResponseData = [@"\n<!doctype html><html><body>Not Found</body></html>" dataUsingEncoding:NSUTF8StringEncoding];
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"user_id":@"user-1"}]
    ];

    FTUploadStatus *status = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];

    XCTAssertTrue(status.success);
    XCTAssertFalse(status.needsRetry);
    XCTAssertEqualObjects(status.responseCode, @404);
    XCTAssertEqual(httpClient.checkBodies.count, 1);
    XCTAssertEqual(httpClient.writeBodies.count, 0);
}

- (void)testImageFeatureUploadRetriesMalformedSuccessfulResourceCheckResponse{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.checkResponseData = [@"\n<!doctype html><html><body>Unexpected response</body></html>" dataUsingEncoding:NSUTF8StringEncoding];
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"user_id":@"user-1"}]
    ];

    FTUploadStatus *status = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];

    XCTAssertFalse(status.success);
    XCTAssertTrue(status.needsRetry);
    XCTAssertEqualObjects(status.responseCode, @200);
    XCTAssertEqual(httpClient.checkBodies.count, 1);
    XCTAssertEqual(httpClient.writeBodies.count, 0);
}

- (void)testImageFeatureUploadMergesSameBindInfoIntoSingleBatch{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.contentMap = @{
        @"resource-a":@NO,
        @"resource-b":@NO
    };
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"wgtid":@"widget-1"}],
        [self resourceDataWithIdentifier:@"resource-b" bindInfo:@{@"wgtid":@"widget-1"}]
    ];
    
    FTUploadStatus *status = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];
    
    XCTAssertTrue(status.success);
    XCTAssertEqual(httpClient.checkBodies.count, 1);
    XCTAssertEqual(httpClient.writeBodies.count, 1);
    NSDictionary *checkBody = httpClient.checkBodies.firstObject;
    NSArray *files = checkBody[@"files"];
    XCTAssertEqualObjects(checkBody[FT_APP_ID], @"app-id");
    XCTAssertEqualObjects(checkBody[@"tags"][@"wgtid"], @"widget-1");
    XCTAssertNil(checkBody[@"wgtid"]);
    XCTAssertNil(checkBody[@"service"]);
    XCTAssertTrue(files.count == 2);
    XCTAssertTrue([files containsObject:@"resource-a"]);
    XCTAssertTrue([files containsObject:@"resource-b"]);
    
    NSString *writeBody = httpClient.writeBodies.firstObject;
    XCTAssertTrue([writeBody containsString:@"name=\"app_id\""]);
    XCTAssertTrue([writeBody containsString:@"name=\"tags\""]);
    XCTAssertTrue([writeBody containsString:@"widget-1"]);
    XCTAssertTrue([writeBody containsString:@"resource-a"]);
    XCTAssertTrue([writeBody containsString:@"resource-b"]);
    XCTAssertFalse([writeBody containsString:@"name=\"appid\""]);
    XCTAssertFalse([writeBody containsString:@"name=\"wgtid\""]);
    XCTAssertFalse([writeBody containsString:@"name=\"service\""]);
}
@end
