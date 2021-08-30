//
//  FTNetworkTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/24.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTRecordModel.h>
#import "OHHTTPStubs.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTDateUtil.h>
#import <FTJSONUtil.h>
#import "FTConfigManager.h"
#import <FTRequest.h>
#import <FTNetworkManager.h>
typedef NS_ENUM(NSInteger, FTNetworkTestsType) {
    FTNetworkTest          = 0,
    FTNetworkTestBad          = 1,
    FTNetworkTestNoJsonResponse  = 2,
    FTNetworkTestWrongJsonResponse  = 3,
    FTNetworkTestEmptyResponseData,
    FTNetworkTestErrorResponse,
    FTNetworkTestErrorNet,
};
@interface FTNetworkTests : XCTestCase
@end

@implementation FTNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    long  tm =[FTDateUtil currentTimeNanosecond];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
}
- (void)setRightConfigWithTestType:(FTNetworkTestsType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *urlStr = [processInfo environment][@"ACCESS_SERVER_URL"];
    switch (type) {
        case FTNetworkTest:
            break;
        case FTNetworkTestBad:
            urlStr = [urlStr stringByAppendingString:@"TestBad"];
            break;
        case FTNetworkTestNoJsonResponse:
            urlStr = [urlStr stringByAppendingString:@"TestNoJsonResponse"];
            break;
        case FTNetworkTestWrongJsonResponse:
            urlStr = [urlStr stringByAppendingString:@"TestWrongJsonResponse"];
            break;
        case FTNetworkTestEmptyResponseData:
            urlStr = [urlStr stringByAppendingString:@"TestEmptyResponseData"];
            break;
        case FTNetworkTestErrorResponse:
            urlStr = [urlStr stringByAppendingString:@"TestErrorResponse"];
            break;
        case FTNetworkTestErrorNet:
            urlStr = [urlStr stringByAppendingString:@"TestErrorNet"];
            break;
    }
    NSString *newUrl = [urlStr stringByAppendingString:@"/v1/write/logging"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        NSString *str =  request.URL.absoluteString;
        return [str isEqualToString:newUrl];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        switch (type) {
            case FTNetworkTest:{
                NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
                NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
                return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
            }
                break;
                
            case FTNetworkTestBad:{
                NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
                
                NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
                return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
            }
                break;
            case FTNetworkTestNoJsonResponse:{
                NSString *data  =@"Hello World!";
                
                NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
                return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
            }
                break;
            case FTNetworkTestWrongJsonResponse:{
                NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
                data = [data stringByAppendingString:@"/n/t"];
                NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
                return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
            }
                break;
            case FTNetworkTestEmptyResponseData:{
                return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
            }
                break;
            case FTNetworkTestErrorResponse:{
                NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@500}];
                NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
                return [OHHTTPStubsResponse responseWithData:requestData statusCode:500 headers:nil];
            }
                break;
            case FTNetworkTestErrorNet:{
                NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
                return [OHHTTPStubsResponse responseWithError:notConnectedError];
            }
                break;
        }
        
    }];
    if (urlStr) {
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:urlStr];
        config.enableSDKDebugLog = YES;
        [[FTConfigManager sharedInstance] setTrackConfig:config];
    }
}
-(void)setBadMetricsUrl{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"https://162.215.252.78"];
    config.enableSDKDebugLog = YES;
    [[FTConfigManager sharedInstance] setTrackConfig:config];

}
/**
 测试上传过程是否正确
 */
-(void)testNetwork{
    
    [self setRightConfigWithTestType:FTNetworkTest];
    [NSThread sleepForTimeInterval:2];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
    
        NSInteger statusCode = httpResponse.statusCode;
        BOOL success = (statusCode >=200 && statusCode < 500);
        XCTAssertTrue(success);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
}
/**
 测试网络状态较差时上传过程是否正确
 */
-(void)testBadNetwork{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setRightConfigWithTestType:FTNetworkTestBad];
    
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
    
        NSInteger statusCode = httpResponse.statusCode;
        BOOL success = (statusCode >=200 && statusCode < 500);
        XCTAssertTrue(success);
        [expectation fulfill];
        
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
}

/**
 测试请求成功 返回结果为非json数据格式
 */
-(void)testNoJsonResponseNetWork{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
     [self setRightConfigWithTestType:FTNetworkTestNoJsonResponse];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
    
        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        NSString *result =[[ NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssertTrue(error != nil && [result isEqualToString:@"Hello World!"]);
        [expectation fulfill];
        
    }];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 测试请求成功 返回结果为错误json数据格式
 */
- (void)testWrongJsonResponseNetWork{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setRightConfigWithTestType:FTNetworkTestWrongJsonResponse];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
    
        NSError *errors;
        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
        XCTAssertTrue(errors != nil);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 测试请求成功 返回结果为空数据
 */
- (void)testEmptyResponseDataNetWork{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setRightConfigWithTestType:FTNetworkTestEmptyResponseData];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        XCTAssertTrue(data.bytes == 0);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 测试请求成功 返回结果code 非200
 */
- (void)testErrorResponse{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
     [self setRightConfigWithTestType:FTNetworkTestErrorResponse];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        NSInteger statusCode = httpResponse.statusCode;
        XCTAssertFalse(statusCode == 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 测试无效地址
 */
-(void)testBadMetricsUrl{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
     [self setBadMetricsUrl];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        NSInteger statusCode = httpResponse.statusCode;
        XCTAssertFalse(statusCode == 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 测试网络错误
 */
- (void)testErrorNet{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setRightConfigWithTestType:FTNetworkTestErrorNet];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_LOGGING,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_LOGGING;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        NSInteger statusCode = httpResponse.statusCode;
        XCTAssertFalse(statusCode == 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
