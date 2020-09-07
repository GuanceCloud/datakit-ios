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
#import <FTMobileAgent/FTMonitorManager.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSString+FTAdd.h>
#import "OHHTTPStubs.h"
#import <FTMobileAgent/Network/NSURLRequest+FTMonitor.h>
#import "FTMonitorManager+Test.h"
#import <FTMobileAgent/FTMonitorUtils.h>
#import "FTTrackerEventDBTool+Test.h"
#import <FTRecordModel.h>
#import <FTBaseInfoHander.h>
#import <NSDate+FTAdd.h>
#import "FTSessionConfiguration+Test.h"
@interface FTNetworkTraceTest : XCTestCase<NSURLSessionDelegate>
@end

@implementation FTNetworkTraceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)setNetworkTraceType:(FTNetworkTrackType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    config.source = @"iOSTest";
    config.networkTrace = YES;
    config.networkTraceType = type;
    config.traceServiceName = @"iOSTestService";
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
}

- (void)testFTNetworkTrackTypeZipkin{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTrackTypeZipkin];
    [self networkUpload:@"Zipkin" handler:^(NSDictionary *header) {
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
- (void)testFTNetworkTrackTypeJaeger{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTrackTypeJaeger];
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
- (void)testFTNetworkTrackTypeSKYWALKING_V2{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V2];
    [self networkUpload:@"SKYWALKING_V2" handler:^(NSDictionary *header) {
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V2]);
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V2];
        NSArray *array = [traceStr componentsSeparatedByString:@"-"];
        NSString *sampled = [array firstObject];
        NSString *traceId = [array[1] ft_base64Decode];
        NSString *parentTraceID=[array[2] ft_base64Decode];
        NSString *urlStr = [@"#api.qingyunke.com" ft_base64Encode];
        NSArray *traceIdAry = [traceId componentsSeparatedByString:@"."];
        NSInteger seq =  [[traceId  substringFromIndex:traceId.length-4] integerValue];
        NSInteger parentSeq = [[parentTraceID  substringFromIndex:parentTraceID.length-4] integerValue];
        XCTAssertEqualObjects(array[0], @"1");
        XCTAssertEqualObjects([traceId  substringToIndex:traceId.length-4], [parentTraceID  substringToIndex:traceId.length-4]);
        XCTAssertTrue(seq - parentSeq == 1);
        XCTAssertEqualObjects(array[3], @"0");
        XCTAssertTrue([array[4] isEqualToString:array[5]] && [traceIdAry[0] isEqualToString:array[4]]);
        XCTAssertEqualObjects(array[6], urlStr);
        XCTAssertTrue([[array[7] ft_base64Decode] isEqualToString:@"-1"] && [[array[8] ft_base64Decode] isEqualToString:@"-1"]);
        XCTAssertEqualObjects(sampled, @"1");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeSKYWALKING_V3{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V3];
    [self networkUpload:@"SKYWALKING_V3" handler:^(NSDictionary *header) {
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray  *traceAry = [traceStr componentsSeparatedByString:@"-"];
        NSString *sampled = [traceAry firstObject];
        NSString *traceId = [traceAry[1] ft_base64Decode];
        NSString *parentTraceID=[traceAry[2] ft_base64Decode];
        NSInteger seq =  [[traceId  substringFromIndex:traceId.length-4] integerValue];
        NSInteger parentSeq = [[parentTraceID  substringFromIndex:parentTraceID.length-4] integerValue];
        NSString *parentServiceInstance = [NSString stringWithFormat:@"%@@%@",[FTMonitorManager sharedInstance].parentInstance,[FTMonitorUtils getCELLULARIPAddress:YES]];
        XCTAssertEqualObjects(sampled, @"1");
        XCTAssertTrue(seq-parentSeq == 1);
        XCTAssertEqualObjects(traceAry[3], @"0");
        XCTAssertEqualObjects([traceAry[4] ft_base64Decode], @"iOSTestService");
        XCTAssertEqualObjects([traceAry[5] ft_base64Decode], parentServiceInstance);
        XCTAssertEqualObjects([traceAry[6] ft_base64Decode], @"/api.php");
        XCTAssertEqualObjects([traceAry[7] ft_base64Decode], @"api.qingyunke.com");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)networkUpload:(NSString *)str handler:(void (^)(NSDictionary *header))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",str];
    NSString *urlStr = @"http://api.qingyunke.com/api.php";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    request.HTTPMethod = @"POST";
    
    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
        completionHandler?completionHandler(header):nil;
    }];
    
    [task resume];
}
-(void)setBadNetOHHTTPStubs{
    NSString *urlStr = @"http://api.qingyunke.com/api.php";
    NSURL *url = [NSURL URLWithString:urlStr];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorTimedOut userInfo:@{NSLocalizedDescriptionKey:@"time out"}];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
}
- (void)testTimeOut{
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V3];
    [self setBadNetOHHTTPStubs];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUpload:@"SKYWALKING_V3" handler:^(NSDictionary *header) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSDictionary *tags = opdata[@"tags"];
    BOOL isError = [tags[@"__isError"] boolValue];
    XCTAssertTrue(isError == YES);
    NSDictionary *content = [FTBaseInfoHander ft_dictionaryWithJsonString:field[@"__content"]];
    NSDictionary *responseContent = content[@"responseContent"];
    NSDictionary *error = responseContent[@"error"];
    NSNumber *errorCode = error[@"errorCode"];
    XCTAssertTrue([errorCode isEqualToNumber:@-1001]);
}
- (void)testRightRequest{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTrackTypeJaeger];
    [self networkUpload:@"testRightRequest" handler:^(NSDictionary *header) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSDictionary *tags = opdata[@"tags"];
    BOOL isError = [tags[@"__isError"] boolValue];
    XCTAssertTrue(isError == NO);
    NSDictionary *content = [FTBaseInfoHander ft_dictionaryWithJsonString:field[@"__content"]];
    NSDictionary *requestContent = content[@"requestContent"];
    NSString *body = requestContent[@"body"];
    XCTAssertTrue([body containsString:@"testRightRequest"]);
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
    }];
}
- (void)testNewThread{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V2];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self networkUpload:@"testNewThread" handler:^(NSDictionary *header) {
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSDictionary *tags = opdata[@"tags"];
    BOOL isError = [tags[@"__isError"] boolValue];
    XCTAssertTrue(isError == NO);
    NSDictionary *content = [FTBaseInfoHander ft_dictionaryWithJsonString:field[@"__content"]];
    NSDictionary *requestContent = content[@"requestContent"];
    NSString *body = requestContent[@"body"];
    XCTAssertTrue([body containsString:@"testNewThread"]);
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
    }];
}

- (void)testBadResponse{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTrackTypeZipkin];
    NSString *uuid = [NSUUID UUID].UUIDString;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
    NSString *urlStr = @"http://api.qingyunke.com/api.php1";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    request.HTTPMethod = @"POST";
    
    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    
    [task resume];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSDictionary *tags = opdata[@"tags"];
    NSDictionary *content = [FTBaseInfoHander ft_dictionaryWithJsonString:field[@"__content"]];
    NSDictionary *requestContent = content[@"requestContent"];
    NSString *body = requestContent[@"body"];
    XCTAssertTrue([body containsString:uuid]);
    BOOL isError = [tags[@"__isError"] boolValue];
    XCTAssertTrue(isError == YES);
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
    }];
}


@end
