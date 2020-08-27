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

#define WAIT                                                                \
do {                                                                        \
[self expectationForNotification:@"LCUnitTest" object:nil handler:nil]; \
[self waitForExpectationsWithTimeout:10 handler:nil];                   \
} while(0);
#define NOTIFY                                                                            \
do {                                                                                      \
[[NSNotificationCenter defaultCenter] postNotificationName:@"LCUnitTest" object:nil]; \
} while(0);
@interface NetworkTraceTest : XCTestCase<NSURLSessionDelegate>
@property (nonatomic, assign) FTNetworkTrackType type;
@end

@implementation NetworkTraceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)setNetworkTraceType:(FTNetworkTrackType)type{
    self.type = type;
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"TACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"TACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"TACCESS_SERVER_URL"];
    NSString *token = [processInfo environment][@"TACCESS_DATAWAY_TOKEN"];
   
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    config.networkTrace = YES;
    config.monitorInfoType = FTMonitorInfoTypeNetwork;
    config.networkTraceType = type;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [self networkUpload];
    WAIT
}

- (void)testFTNetworkTrackTypeZipkin{
    [self setNetworkTraceType:FTNetworkTrackTypeZipkin];
}
- (void)testFTNetworkTrackTypeJaeger{
    [self setNetworkTraceType:FTNetworkTrackTypeJaeger];
}
- (void)testFTNetworkTrackTypeSKYWALKING_V2{
    [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V2];
}
- (void)testFTNetworkTrackTypeSKYWALKING_V3{
   [self setNetworkTraceType:FTNetworkTrackTypeSKYWALKING_V3];
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
    switch (self.type) {
        case FTNetworkTrackTypeZipkin:
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SAMPLED]);
            break;
        case FTNetworkTrackTypeJaeger:
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_JAEGER_TRACEID]);
            break;
        case FTNetworkTrackTypeSKYWALKING_V2:
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V2]);
            break;
        case FTNetworkTrackTypeSKYWALKING_V3:
            XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]);
            break;
    }
    NOTIFY

}
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
