//
//  NetworkTraceTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTGlobalRumManager.h>
#import <FTConstants.h>
#import <NSString+FTAdd.h>
#import "OHHTTPStubs.h"
#import <NSURLRequest+FTMonitor.h>
#import <FTMobileAgent/FTMonitorUtils.h>
#import "FTTrackerEventDBTool+Test.h"
#import <FTRecordModel.h>
#import <FTBaseInfoHandler.h>
#import <FTDateUtil.h>
#import "FTSessionConfiguration+Test.h"
#import <FTJSONUtil.h>
#import "FTTrackDataManger+Test.h"
#import <FTRequest.h>
#import <FTNetworkManager.h>
@interface FTNetworkTraceTest : XCTestCase<NSURLSessionDelegate>
@end

@implementation FTNetworkTraceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}

- (void)tearDown {
    [[FTMobileAgent sharedInstance] resetInstance];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)setNetworkTraceType:(FTNetworkTraceType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = type;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}

- (void)testFTNetworkTrackTypeZipkinMultiHeader{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinMultiHeader];
    [self networkUpload:@"ZipkinMultiHeader" handler:^(NSDictionary *header) {
        NSString *traceId = [header valueForKey:FT_NETWORK_ZIPKIN_TRACEID];
        NSString *spanID = [header valueForKey:FT_NETWORK_ZIPKIN_SPANID];
        NSString *sampled = [header valueForKey:FT_NETWORK_ZIPKIN_SAMPLED];
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SAMPLED]);
        XCTAssertEqualObjects(sampled, @"1");
        XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
        XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeZipkinSingleHeader{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinSingleHeader];
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
- (void)testFTNetworkTrackTypeJaeger{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    [self networkUpload:@"Jaeger" handler:^(NSDictionary *header) {
        NSString *trace =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [trace componentsSeparatedByString:@":"];
        NSString *traceId = [traceAry firstObject];
        NSString *spanID =traceAry[1];
        NSString *sampled = [traceAry lastObject];
        XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
        XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);
        XCTAssertEqualObjects(sampled, @"1");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeDDtrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    [self networkUpload:@"DDtrace" handler:^(NSDictionary *header) {
       
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertTrue([header[FT_NETWORK_DDTRACE_SAMPLING_PRIORITY] isEqualToString:@"1"]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);

        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeSkywalking_v3{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeSkywalking];
    [self networkUpload:@"Skywalking_v3" handler:^(NSDictionary *header) {
        XCTAssertTrue(([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]));
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        XCTAssertTrue(traceAry.count == 8);
        
        NSString *sampling = [traceAry firstObject];
        NSString *trace = [traceAry[1] ft_base64Decode];
        NSString *parentTraceID=[traceAry[2] ft_base64Decode];
        NSString *span = [parentTraceID stringByAppendingString:@"0"];
        XCTAssertTrue(trace && span && sampling);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeTraceparent{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeTraceparent];
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 0;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];

    [self networkUpload:@"SampleRate0" handler:^(NSDictionary *header) {
        XCTAssertTrue([[header valueForKey:FT_NETWORK_DDTRACE_SAMPLED] isEqualToString:@"0"]);
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
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 100;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];

    [self networkUpload:@"SampleRate100" handler:^(NSDictionary *header) {
        XCTAssertTrue([[header valueForKey:FT_NETWORK_DDTRACE_SAMPLED] isEqualToString:@"1"]);

        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];

}
- (void)testDisableAutoTrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
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
- (void)networkUpload:(NSString *)str handler:(void (^)(NSDictionary *header))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
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
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
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
    NSString *uuid = [NSUUID UUID].UUIDString;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
    NSString *urlStr = @"http://api.qingyunke.com/api.php1";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];

    request.HTTPMethod = @"POST";

    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
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
