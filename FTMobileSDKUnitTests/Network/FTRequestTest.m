//
//  FTRequestTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/24.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTRecordModel.h>
#import "OHHTTPStubs.h"
#import <FTConstants.h>
#import <FTDateUtil.h>
#import <FTJSONUtil.h>
#import "FTConfigManager.h"
#import <FTRequest.h>
#import <FTNetworkManager.h>
#import "FTNetworkInfoManager.h"
#import "FTEnumConstant.h"
#import "FTModelHelper.h"
@interface FTRequestTest : XCTestCase

@end

@implementation FTRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self mockHttp];
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *urlStr = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setMetricsUrl(urlStr)
        .setSdkVersion(@"RequestTest")
        .setXDataKitUUID([NSUUID UUID].UUIDString);
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)mockHttp{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
- (void)testLogRequest{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

   
    FTRecordModel *model = [FTModelHelper createLogModel:@"testLogRequest"];
    
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        if (!error) {
            NSInteger statusCode = httpResponse.statusCode;
            BOOL success = (statusCode >=200 && statusCode < 500);
            XCTAssertTrue(success);
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:35 handler:^(NSError *error) {
    }];
}
- (void)testRumRequest{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    FTRecordModel *model = [FTModelHelper createRumModel];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        if (!error) {
        NSInteger statusCode = httpResponse.statusCode;
        BOOL success = (statusCode >=200 && statusCode < 500);
        XCTAssertTrue(success);
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:35 handler:^(NSError *error) {
    }];
}
@end
