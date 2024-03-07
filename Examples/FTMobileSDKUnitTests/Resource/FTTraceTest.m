//
//  NetworkTraceTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTGlobalRumManager.h"
#import "FTConstants.h"
#import "NSString+FTAdd.h"
#import "OHHTTPStubs.h"
#import "FTMonitorUtils.h"
#import "FTTrackerEventDBTool+Test.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "FTJSONUtil.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTTracer.h"
#import <objc/runtime.h>
#import "FTURLSessionInstrumentation.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTURLSessionInterceptor.h"
#import "FTSessionTaskHandler.h"
#import "FTTracer.h"
#define FT_SDK_COMPILED_FOR_TESTING
@interface FTTraceTest : XCTestCase<NSURLSessionDelegate,NSCacheDelegate>
@property (nonatomic, strong) id<FTTracerProtocol> tracer;
@end

@implementation FTTraceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
}

- (void)tearDown {
    [[FTMobileAgent sharedInstance] shutDown];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)setNetworkTraceType:(FTNetworkTraceType)type{
    [self setNetworkTraceType:type serviceName:FT_DEFAULT_SERVICE_NAME];
}
- (void)setNetworkTraceType:(FTNetworkTraceType)type serviceName:(NSString *)serviceName{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.service = serviceName;
    config.autoSync = NO;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = type;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    self.tracer = [[FTURLSessionInstrumentation sharedInstance] valueForKey:@"tracer"];
    XCTAssertNotNil(self.tracer);
}
// traceID: uuid lowercaseString
// spanID: uuid-16位 lowercaseString
- (void)testFTNetworkTrackTypeZipkinMultiHeader{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinMultiHeader];
    __block NSString *testTrace,*testSpan;
    NSDictionary *dict = [self.tracer networkTraceHeaderWithUrl:[NSURL URLWithString:@"http://www.test.com/some/url/string"] handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        testTrace = traceId;
        testSpan = spanID;
    }];
    [self.tracer unpackTraceHeader:dict handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        XCTAssertTrue([testTrace isEqualToString:traceId]);
        XCTAssertTrue([testSpan isEqualToString:spanID]);
        XCTAssertTrue(testSpan.length == 16);
    }];
    [self networkUpload:@"ZipkinMultiHeader" handler:^(NSDictionary *header) {
        NSString *traceId = [header valueForKey:FT_NETWORK_ZIPKIN_TRACEID];
        NSString *spanID = [header valueForKey:FT_NETWORK_ZIPKIN_SPANID];
        NSString *sampled = [header valueForKey:FT_NETWORK_ZIPKIN_SAMPLED];
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SAMPLED]);
        XCTAssertEqualObjects(sampled, @"1");
        XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
        XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);
        [self.tracer unpackTraceHeader:header handler:^(NSString * _Nullable atraceId, NSString * _Nullable aspanID) {
            XCTAssertTrue([traceId isEqualToString:atraceId]);
            XCTAssertTrue([spanID isEqualToString:aspanID]);
        }];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
// traceID: uuid lowercaseString
// spanID: uuid-16位 lowercaseString
- (void)testFTNetworkTrackTypeZipkinSingleHeader{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinSingleHeader];
    __block NSString *testTrace,*testSpan;
    NSDictionary *dict = [self.tracer networkTraceHeaderWithUrl:[NSURL URLWithString:@"http://www.test.com/some/url/string"] handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        testTrace = traceId;
        testSpan = spanID;
    }];
    [self.tracer unpackTraceHeader:dict handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        XCTAssertTrue([testTrace isEqualToString:traceId]);
        XCTAssertTrue([testSpan isEqualToString:spanID]);
        XCTAssertTrue(testSpan.length == 16);
    }];
    [self networkUpload:@"ZipkinSingleHeader" handler:^(NSDictionary *header) {
        NSString *key = [header valueForKey:FT_NETWORK_ZIPKIN_SINGLE_KEY];
        NSArray *traceAry = [key componentsSeparatedByString:@"-"];
        XCTAssertTrue(traceAry.count == 3);
        NSString *trace = [traceAry firstObject];
        NSString *span = traceAry[1];
        NSString *sampling=traceAry[2];
        XCTAssertEqualObjects(sampling, @"1");
        XCTAssertTrue(trace.length == 32 && span.length == 16);
        XCTAssertTrue([trace.lowercaseString isEqualToString:trace] && [span.lowercaseString isEqualToString:span]);
        
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
// traceID: uuid lowercaseString
// spanID: uuid-16位 lowercaseString
- (void)testFTNetworkTrackTypeJaeger{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    __block NSString *testTrace,*testSpan;
    NSDictionary *dict = [self.tracer networkTraceHeaderWithUrl:[NSURL URLWithString:@"http://www.test.com/some/url/string"] handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        testTrace = traceId;
        testSpan = spanID;
    }];
    [self.tracer unpackTraceHeader:dict handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        XCTAssertTrue([testTrace isEqualToString:traceId]);
        XCTAssertTrue([testSpan isEqualToString:spanID]);
        XCTAssertTrue(testSpan.length == 16);
    }];
    [self networkUpload:@"Jaeger" handler:^(NSDictionary *header) {
        NSString *traceStr =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@":"];
        NSString *trace = [traceAry firstObject];
        NSString *span =traceAry[1];
        NSString *sampled = [traceAry lastObject];
        XCTAssertTrue(trace.length == 32 && span.length == 16);
        XCTAssertTrue([trace.lowercaseString isEqualToString:trace] && [span.lowercaseString isEqualToString:span]);
        XCTAssertEqualObjects(sampled, @"1");
        [self.tracer unpackTraceHeader:header handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            XCTAssertTrue([trace isEqualToString:traceId]);
            XCTAssertTrue([span isEqualToString:spanID]);
        }];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
// traceID: 64位数字
// spanID: 64位数字
- (void)testFTNetworkTrackTypeDDtrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    __block NSString *testTrace,*testSpan;
    NSDictionary *dict = [self.tracer networkTraceHeaderWithUrl:[NSURL URLWithString:@"http://www.test.com/some/url/string"] handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        testTrace = traceId;
        testSpan = spanID;
    }];
    [self.tracer unpackTraceHeader:dict handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        XCTAssertTrue([testTrace isEqualToString:traceId]);
        XCTAssertTrue([testSpan isEqualToString:spanID]);
    }];
    [self networkUpload:@"DDtrace" handler:^(NSDictionary *header) {
        
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertTrue([header[FT_NETWORK_DDTRACE_SAMPLING_PRIORITY] isEqualToString:@"2"]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        [self.tracer unpackTraceHeader:header handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            XCTAssertTrue([header[FT_NETWORK_DDTRACE_TRACEID] isEqualToString:traceId]);
            XCTAssertTrue([header[FT_NETWORK_DDTRACE_SPANID] isEqualToString:spanID]);
        }];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
// 
- (void)testFTNetworkTrackTypeSkywalking_v3{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeSkywalking];
    __block NSString *testTrace,*testSpan;
    NSDictionary *dict = [self.tracer networkTraceHeaderWithUrl:[NSURL URLWithString:@"http://www.test.com/some/url/string"] handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        testTrace = traceId;
        testSpan = spanID;
    }];
    [self.tracer unpackTraceHeader:dict handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        XCTAssertTrue([testTrace isEqualToString:traceId]);
        XCTAssertTrue([testSpan isEqualToString:spanID]);
    }];
    [self networkUpload:@"Skywalking_v3" handler:^(NSDictionary *header) {
        XCTAssertTrue(([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]));
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        XCTAssertTrue(traceAry.count == 8);
        
        NSString *sampling = [traceAry firstObject];
        NSString *trace = [traceAry[1] ft_base64Decode];
        NSString *parentTraceID=[traceAry[2] ft_base64Decode];
        NSString *span = [parentTraceID stringByAppendingString:@"0"];
        NSString *serviceName = [traceAry[4] ft_base64Decode];
        XCTAssertEqualObjects(serviceName, FT_DEFAULT_SERVICE_NAME);
        XCTAssertTrue(trace && span && sampling);
        [self.tracer unpackTraceHeader:header handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            XCTAssertTrue([trace isEqualToString:traceId]);
            XCTAssertTrue([span isEqualToString:spanID]);
        }];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeSkywalking_v3_ServiceName{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    NSString *testServiceName = @"TestServiceName";
    [self setNetworkTraceType:FTNetworkTraceTypeSkywalking serviceName:testServiceName];
    [self networkUpload:@"Skywalking_v3" handler:^(NSDictionary *header) {
        XCTAssertTrue(([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]));
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        XCTAssertTrue(traceAry.count == 8);
    
        NSString *serviceName = [traceAry[4] ft_base64Decode];
        XCTAssertEqualObjects(serviceName, testServiceName);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeSkywalking_v3SeqOver9999{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTraceTypeSkywalking];
    if ([self.tracer isKindOfClass:FTTracer.class]) {
        FTTracer *tracerInstance = (FTTracer *)self.tracer;
        for (int i = 0; i<5000; i++) {
            if( [tracerInstance getSkyWalkingSequence] == 9998){
                break;;
            }
        }
    }
    [self networkUpload:@"Skywalking_v3_2" handler:^(NSDictionary *header) {
        XCTAssertTrue(([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]));
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        XCTAssertTrue(traceAry.count == 8);
        
        NSString *sampling = [traceAry firstObject];
        NSString *trace = [traceAry[1] ft_base64Decode];
        NSString *parentTraceID=[traceAry[2] ft_base64Decode];
        NSString *span = [parentTraceID stringByAppendingString:@"0"];
        NSRange range = NSMakeRange(span.length-5, 5);
        XCTAssertTrue([[span substringWithRange:range] isEqualToString:@"00000"]);
        XCTAssertTrue(trace && span && sampling);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
    
}
// traceID: uuid lowercaseString
// spanID: uuid-16位 lowercaseString
- (void)testFTNetworkTrackTypeTraceparent{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeTraceparent];
    __block NSString *testTrace,*testSpan;
    NSDictionary *dict = [self.tracer networkTraceHeaderWithUrl:[NSURL URLWithString:@"http://www.test.com/some/url/string"] handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        testTrace = traceId;
        testSpan = spanID;
    }];
    [self.tracer unpackTraceHeader:dict handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
        XCTAssertTrue([testTrace isEqualToString:traceId]);
        XCTAssertTrue([testSpan isEqualToString:spanID]);
        XCTAssertTrue(testSpan.length == 16);
    }];
    [self networkUpload:@"Traceparent" handler:^(NSDictionary *header) {
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_TRACEPARENT_KEY]);
        NSString *traceStr =header[FT_NETWORK_TRACEPARENT_KEY];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        XCTAssertTrue(traceAry.count == 4);
        NSString *trace = traceAry[1];
        NSString *span=traceAry[2];
        NSString *sampling = [traceAry lastObject];
        XCTAssertTrue(trace.length == 32 && span.length == 16);
        XCTAssertTrue([sampling isEqualToString:@"01"]);
        [self.tracer unpackTraceHeader:header handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            XCTAssertTrue([trace isEqualToString:traceId]);
            XCTAssertTrue([span isEqualToString:spanID]);
        }];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testSampleRate0{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 0;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    
    [self networkUpload:@"SampleRate0" handler:^(NSDictionary *header) {
        XCTAssertTrue([[header valueForKey:FT_NETWORK_DDTRACE_SAMPLING_PRIORITY] isEqualToString:@"-1"]);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testSampleRate100{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 100;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    
    [self networkUpload:@"SampleRate100" handler:^(NSDictionary *header) {
        XCTAssertTrue([[header valueForKey:FT_NETWORK_DDTRACE_SAMPLING_PRIORITY] isEqualToString:@"2"]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
}
- (void)testDisableAutoTrace_enableLinkRumData{
    
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *murl = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:murl];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 100;
    traceConfig.enableAutoTrace = NO;
    traceConfig.enableLinkRumData = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [FTModelHelper startView];
    
    NSString *key = [FTBaseInfoHandler randomUUID];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    
    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = url;
    model.httpStatusCode = 200;
    model.httpMethod = @"GET";
    model.requestHeader = traceHeader;
    model.responseHeader = @{ @"Accept-Ranges": @"bytes",
                              @"Cache-Control": @"max-age=86400", @"Content-Encoding": @"gzip",
                              @"Content-Length": @"11328",
                              @"Content-Type": @"text/html",
                              @"Server": @"Apache",
                              @"Vary": @"Accept-Encoding,User-Agent"
                              
    };
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    FTResourceMetricsModel *metrics = [FTResourceMetricsModel new];
    metrics.duration = @1000;
    metrics.resource_dns = @0;
    metrics.resource_ssl = @12;
    metrics.resource_tcp = @100;
    metrics.resource_ttfb = @101;
    metrics.resource_trans = @102;
    metrics.resource_first_byte = @103;
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:metrics content:model];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[FT_OPDATA];
        NSString *measurement = opdata[FT_KEY_SOURCE];
        if ([measurement isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceData = YES;
            NSDictionary *tags = opdata[FT_TAGS];
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
- (void)testDisableAutoTrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [self networkUpload:@"DisableAutoTrace" handler:^(NSDictionary *header) {
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testDisableAutoTrace_enableRumAutoTraceResource{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"test"];
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [FTModelHelper startView];
    [self networkUpload:@"DisableAutoTrace" handler:^(NSDictionary *header) {
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertFalse([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testDisabledInitTraceConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    [FTMobileAgent startWithConfigOptions:config];
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    
    NSDictionary *header = [[FTExternalDataManager sharedManager] getTraceHeaderWithUrl:[NSURL URLWithString:urlStr]];
    XCTAssertNil(header);
}
- (void)testCustomTrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableAutoTrace = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    
    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[FTBaseInfoHandler randomUUID] url:[NSURL URLWithString:urlStr]];
    
    [self networkUpload:@"DisableAutoTrace" traceHeader:traceHeader handler:^(NSDictionary *header) {
        XCTAssertTrue([header[FT_NETWORK_DDTRACE_TRACEID] isEqualToString:traceHeader[FT_NETWORK_DDTRACE_TRACEID]]);
        XCTAssertTrue([header[FT_NETWORK_DDTRACE_SPANID] isEqualToString:traceHeader[FT_NETWORK_DDTRACE_SPANID]]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        XCTAssertTrue([header[FT_NETWORK_DDTRACE_SAMPLING_PRIORITY] isEqualToString:traceHeader[FT_NETWORK_DDTRACE_SAMPLING_PRIORITY]]);
        
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)networkUpload:(NSString *)str handler:(void (^)(NSDictionary *header))completionHandler{
    [self networkUpload:str traceHeader:nil handler:completionHandler];
}
- (void)networkUpload:(NSString *)str traceHeader:(nullable NSDictionary *)traceHeader handler:(void (^)(NSDictionary *header))completionHandler{
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    if(traceHeader){
        [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [request setValue:value forHTTPHeaderField:field];
        }];
    }
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
        completionHandler?completionHandler(header):nil;
    }];
    
    [task resume];
}
-(void)setBadNetOHHTTPStubs{
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSURL *url = [NSURL URLWithString:urlStr];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorTimedOut userInfo:@{NSLocalizedDescriptionKey:@"time out"}];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
}
- (void)testNewThread{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self networkUpload:@"testNewThread" handler:^(NSDictionary *header) {
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}

- (void)testBadResponse{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    [self setBadNetOHHTTPStubs];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLING_PRIORITY]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);
        [expectation fulfill];
    }];
    
    [task resume];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
