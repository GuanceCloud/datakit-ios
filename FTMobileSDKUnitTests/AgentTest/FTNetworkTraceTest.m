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
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSString+FTAdd.h>
#import "OHHTTPStubs.h"
#import "UploadDataTest.h"
#define WAIT                                                                \
do {                                                                        \
[self expectationForNotification:@"LCUnitTest" object:nil handler:nil]; \
[self waitForExpectationsWithTimeout:60 handler:nil];                   \
} while(0);
#define NOTIFY                                                                            \
do {                                                                                      \
[[NSNotificationCenter defaultCenter] postNotificationName:@"LCUnitTest" object:nil]; \
} while(0);
@interface FTNetworkTraceTest : XCTestCase<NSURLSessionDelegate>
@property (nonatomic, assign) FTNetworkTrackType type;
@end

@implementation FTNetworkTraceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)setNetworkTraceType:(FTNetworkTrackType)type{
    self.type = type;
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    config.source = @"iOSTest";
    config.networkTrace = YES;
    config.networkTraceType = type;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
}

- (void)testFTNetworkTrackTypeZipkin{
    [self setNetworkTraceType:FTNetworkTrackTypeZipkin];
    [self networkUpload];
    WAIT
}
- (void)testFTNetworkTrackTypeJaeger{
    [self setNetworkTraceType:FTNetworkTrackTypeJaeger];
    [self networkUpload];
    WAIT
}
- (void)testFTNetworkTrackTypeSKYWALKING_V2{
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V2];
    [self networkUpload];
    WAIT
}
- (void)testFTNetworkTrackTypeSKYWALKING_V3{
   [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V3];
   [self networkUpload];
    WAIT
}
- (void)networkUpload{
     NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
     NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
     NSString *uuid = [NSUUID UUID].UUIDString;
     NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
     NSString *urlStr = @"http://api.qingyunke.com/api.php";
     NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];

     request.HTTPMethod = @"POST";

     request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
     NSURLSessionTask *task = [session dataTaskWithRequest:request];
     
     [task resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{

    NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
    NSString *traceId,*spanID,*sampled;
    switch (self.type) {
        case FTNetworkTrackTypeZipkin:
            traceId = [header valueForKey:FT_NETWORK_ZIPKIN_TRACEID];
            spanID = [header valueForKey:FT_NETWORK_ZIPKIN_SPANID];
            sampled = [header valueForKey:FT_NETWORK_ZIPKIN_SAMPLED];
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SAMPLED]);
    
            XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
            XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);

            break;
        case FTNetworkTrackTypeJaeger:{
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_JAEGER_TRACEID]);
            NSString *trace =header[FT_NETWORK_JAEGER_TRACEID];
            NSArray *traceAry = [trace componentsSeparatedByString:@":"];
            traceId = [traceAry firstObject];
            spanID =traceAry[1];
            sampled = [traceAry lastObject];
            XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
            XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);
        }
            break;
        case FTNetworkTrackTypeSKYWALKING_V2:{
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V2]);
            NSString *traceStr =header[FT_NETWORK_SKYWALKING_V2];
            NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
            sampled = [traceAry firstObject];
            traceId = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            spanID = [parentTraceID stringByAppendingString:@"0"];
            XCTAssertTrue([[traceAry[7] ft_base64Decode] isEqualToString:@"-1"] && [[traceAry[8] ft_base64Decode] isEqualToString:@"-1"]);
        }
            break;
        case FTNetworkTrackTypeSKYWALKING_V3:{
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]);
            NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
            NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
            sampled = [traceAry firstObject];
            traceId = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            spanID = [parentTraceID stringByAppendingString:@"0"];
            
        }
            break;
    }
    
    XCTAssertTrue([sampled isEqualToString:@"0"] || [sampled isEqualToString:@"1"]);
    XCTAssertTrue(sampled && traceId && spanID);
    NOTIFY
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
    
}
- (void)testRightRequest{
    [self setNetworkTraceType:FTNetworkTrackTypeJaeger];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    NSString *uuid = [NSUUID UUID].UUIDString;
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
    NSString *urlStr = @"http://api.qingyunke.com/api.php";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    request.HTTPMethod = @"POST";
    
    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    
    [task resume];
    WAIT
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    [FTMobileAgent sharedInstance].upTool.isUploading = NO;
    [[FTMobileAgent sharedInstance].upTool upload];
    [NSThread sleepForTimeInterval:30];
    UploadDataTest *upload = [UploadDataTest new];
    NSString *content = [upload testLogging];
    
    XCTAssertTrue([content containsString:uuid]);
}
- (void)testNewThread{
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V2];
    NSString *uuid = [NSUUID UUID].UUIDString;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
        NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
        NSString *urlStr = @"http://api.qingyunke.com/api.php";
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        
        request.HTTPMethod = @"POST";
        
        request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
        
        [task resume];
        
    });
    WAIT
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    [FTMobileAgent sharedInstance].upTool.isUploading = NO;
    [[FTMobileAgent sharedInstance].upTool upload];
    [NSThread sleepForTimeInterval:30];
    UploadDataTest *upload = [UploadDataTest new];
    NSString *content = [upload testLogging];
    XCTAssertTrue([content containsString:uuid]);
}

- (void)testBadResponse{
    [self setNetworkTraceType:FTNetworkTrackTypeZipkin];
    NSString *uuid = [NSUUID UUID].UUIDString;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
    NSString *urlStr = @"http://api.qingyunke.com/api.php1";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    request.HTTPMethod = @"POST";
    
    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    
    [task resume];
    
    WAIT
    [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
    [FTMobileAgent sharedInstance].upTool.isUploading = NO;
    [[FTMobileAgent sharedInstance].upTool upload];
    [NSThread sleepForTimeInterval:30];
    UploadDataTest *upload = [UploadDataTest new];
    NSString *content = [upload testLogging];
    XCTAssertTrue([content containsString:uuid]);
}


@end
