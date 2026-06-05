//
//  SessionReplayUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/2/2.
//  Copyright © 2026 GuanceCloud. All rights reserved.
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
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRRecord.h"
#import "FTViewAttributes.h"
#import "FTResourcesWriter.h"
#import "FTFeatureScope.h"
#import "FTFeatureStorage.h"
#import "FTFeatureDirectories.h"
#import "FTDirectory.h"
#import "FTDataStore.h"
#import "FTUploadConditions.h"
#import "FTNetworkInfoManager.h"
#import "FTUploadStatus.h"
#import "FTUIImageResource.h"
#import "FTSRWireframe.h"

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
@property (nonatomic, strong) NSArray<FTEnrichedResource *> *writtenResources;
@end

@implementation FTMockResourcesWriter
- (void)write:(NSArray<FTEnrichedResource *> *)resources{
    self.writtenResources = resources;
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

@interface FTMockHTTPClient : FTHTTPClient
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *checkBodies;
@property (nonatomic, strong) NSMutableArray<NSString *> *writeBodies;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *contentMap;
@property (nonatomic, assign) NSInteger writeStatusCode;
@end

@implementation FTMockHTTPClient
- (instancetype)init{
    self = [super initWithTimeoutIntervalForRequest:1];
    if (self) {
        _checkBodies = [NSMutableArray new];
        _writeBodies = [NSMutableArray new];
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
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:urlRequest.URL statusCode:200 HTTPVersion:nil headerFields:nil];
        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:urlRequest.HTTPBody options:kNilOptions error:nil];
        [self.checkBodies addObject:body];
        NSMutableDictionary *content = [NSMutableDictionary dictionary];
        for (NSString *identifier in body[@"files"]) {
            content[identifier] = self.contentMap[identifier] ?: @NO;
        }
        NSData *responseData = [NSJSONSerialization dataWithJSONObject:@{@"content":content} options:kNilOptions error:nil];
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

- (void)testResourceRequestContainsBindInfoFields{
    FTEnrichedResource *resource = [[FTEnrichedResource alloc] init];
    resource.identifier = @"resource-id";
    resource.appId = @"app-id";
    resource.data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";
    resource.bindInfo = @{@"user_id":@"123"};
    
    FTResourceRequest *request = [[FTResourceRequest alloc] init];
    [request requestWithEvents:@[resource] parameters:@{@"service":@"demo-service"}];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    NSMutableURLRequest *adaptedRequest = [request adaptedRequest:urlRequest];
    NSString *body = [[NSString alloc] initWithData:adaptedRequest.HTTPBody encoding:NSUTF8StringEncoding];
    
    XCTAssertTrue([body containsString:@"name=\"app_id\""]);
    XCTAssertTrue([body containsString:@"app-id"]);
    XCTAssertTrue([body containsString:@"name=\"service\""]);
    XCTAssertTrue([body containsString:@"demo-service"]);
    XCTAssertTrue([body containsString:@"name=\"user_id\""]);
    XCTAssertTrue([body containsString:@"123"]);
}

- (void)testResourceCheckRequestContainsBindInfoFields{
    FTResourceCheckRequest *request = [[FTResourceCheckRequest alloc] init];
    [request requestWithEvents:@[@"resource-id"] parameters:@{
        FT_APP_ID:@"app-id",
        @"service":@"demo-service",
        @"user_id":@"123"
    }];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    NSMutableURLRequest *adaptedRequest = [request adaptedRequest:urlRequest];
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:adaptedRequest.HTTPBody options:kNilOptions error:nil];
    
    XCTAssertEqualObjects(body[FT_APP_ID], @"app-id");
    XCTAssertEqualObjects(body[@"service"], @"demo-service");
    XCTAssertEqualObjects(body[@"user_id"], @"123");
    XCTAssertEqualObjects(body[@"files"], (@[@"resource-id"]));
}

- (void)testImageFeatureUploadGroupsByBindInfoBeforeCheckAndWrite{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.contentMap = @{
        @"resource-a":@NO,
        @"resource-b":@NO,
        @"resource-c":@NO
    };
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"user_id":@"user-1"}],
        [self resourceDataWithIdentifier:@"resource-b" bindInfo:@{@"user_id":@"user-2"}],
        [self resourceDataWithIdentifier:@"resource-c" bindInfo:@{@"user_id":@"user-1"}]
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
    
    XCTAssertEqualObjects(firstCheck[@"user_id"], @"user-1");
    XCTAssertTrue(firstFiles.count == 2);
    XCTAssertTrue([firstFiles containsObject:@"resource-a"]);
    XCTAssertTrue([firstFiles containsObject:@"resource-c"]);
    XCTAssertEqualObjects(secondCheck[@"user_id"], @"user-2");
    XCTAssertEqualObjects(secondFiles, (@[@"resource-b"]));
    
    NSString *firstWrite = httpClient.writeBodies[0];
    NSString *secondWrite = httpClient.writeBodies[1];
    XCTAssertTrue([firstWrite containsString:@"user-1"]);
    XCTAssertTrue([firstWrite containsString:@"resource-a"]);
    XCTAssertTrue([firstWrite containsString:@"resource-c"]);
    XCTAssertFalse([firstWrite containsString:@"resource-b"]);
    XCTAssertTrue([secondWrite containsString:@"user-2"]);
    XCTAssertTrue([secondWrite containsString:@"resource-b"]);
    XCTAssertFalse([secondWrite containsString:@"resource-a"]);
}

- (void)testImageFeatureUploadTreats403And429AsFailure{
    [self verifyImageFeatureUploadFailsWithStatusCode:403];
    [self verifyImageFeatureUploadFailsWithStatusCode:429];
}

- (void)testImageFeatureUploadMergesSameBindInfoIntoSingleBatch{
    FTMockHTTPClient *httpClient = [[FTMockHTTPClient alloc] init];
    httpClient.contentMap = @{
        @"resource-a":@NO,
        @"resource-b":@NO
    };
    FTImageFeatureUpload *upload = [self createImageUploadWithHTTPClient:httpClient];
    NSArray *event = @[
        [self resourceDataWithIdentifier:@"resource-a" bindInfo:@{@"user_id":@"user-1"}],
        [self resourceDataWithIdentifier:@"resource-b" bindInfo:@{@"user_id":@"user-1"}]
    ];
    
    FTUploadStatus *status = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];
    
    XCTAssertTrue(status.success);
    XCTAssertEqual(httpClient.checkBodies.count, 1);
    XCTAssertEqual(httpClient.writeBodies.count, 1);
    NSDictionary *checkBody = httpClient.checkBodies.firstObject;
    NSArray *files = checkBody[@"files"];
    XCTAssertEqualObjects(checkBody[@"user_id"], @"user-1");
    XCTAssertTrue(files.count == 2);
    XCTAssertTrue([files containsObject:@"resource-a"]);
    XCTAssertTrue([files containsObject:@"resource-b"]);
    
    NSString *writeBody = httpClient.writeBodies.firstObject;
    XCTAssertTrue([writeBody containsString:@"user-1"]);
    XCTAssertTrue([writeBody containsString:@"resource-a"]);
    XCTAssertTrue([writeBody containsString:@"resource-b"]);
}
@end
