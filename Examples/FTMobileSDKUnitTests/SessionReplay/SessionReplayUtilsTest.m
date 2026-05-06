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
#import "FTResourceWriter.h"

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
- (BOOL)flushWithEvent:(id)event parameters:(NSDictionary *)parameters;
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

@interface FTMockHTTPClient : FTHTTPClient
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *checkBodies;
@property (nonatomic, strong) NSMutableArray<NSString *> *writeBodies;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *contentMap;
@end

@implementation FTMockHTTPClient
- (instancetype)init{
    self = [super initWithTimeoutIntervalForRequest:1];
    if (self) {
        _checkBodies = [NSMutableArray new];
        _writeBodies = [NSMutableArray new];
    }
    return self;
}

- (void)sendRequest:(id<FTRequestProtocol>)request completion:(void (^)(NSHTTPURLResponse * _Nonnull, NSData * _Nullable, NSError * _Nullable))callback{
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]];
    if ([request respondsToSelector:@selector(adaptedRequest:)]) {
        urlRequest = [request adaptedRequest:urlRequest];
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:urlRequest.URL statusCode:200 HTTPVersion:nil headerFields:nil];
    if ([request isKindOfClass:[FTResourceCheckRequest class]]) {
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
    
    BOOL success = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];
    
    XCTAssertTrue(success);
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
    
    BOOL success = [upload flushWithEvent:event parameters:@{@"service":@"demo-service"}];
    [upload cancelSynchronously];
    
    XCTAssertTrue(success);
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
