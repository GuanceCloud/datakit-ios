//
//  FTNetworkTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/24.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTUploadTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTRecordModel.h>
#import "OHHTTPStubs.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/FTJSONUtil.h>
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
    long  tm =[[NSDate now] ft_dateTimestamp];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
}
- (FTUploadTool *)setRightConfigWithTestType:(FTNetworkTestsType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
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
    NSString *newUrl = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        NSString *str =  request.URL.absoluteString;
        return [str isEqualToString:newUrl];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        switch (type) {
            case FTNetworkTest:{
                NSString *data  =[FTJSONUtil ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
                NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
                return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
            }
                break;
                
            case FTNetworkTestBad:{
                NSString *data  =[FTJSONUtil ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
                
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
                NSString *data  =[FTJSONUtil ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
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
                NSString *data  =[FTJSONUtil ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@500}];
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
    if (akId && akSecret && urlStr) {
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:urlStr datawayToken:nil akId:akId akSecret:akSecret enableRequestSigning:YES];
        config.enableLog = YES;
        return  [[FTUploadTool alloc]initWithConfig:config];
    }
    return nil;
}
-(FTUploadTool *)setBadMetricsUrl{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"https://162.215.252.78" datawayToken:nil akId:akId akSecret:akSecret enableRequestSigning:YES];
    
    
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    return  [[FTUploadTool alloc]initWithConfig:config];
}
/**
 测试上传过程是否正确
 */
-(void)testNetwork{
    FTUploadTool *tool = [self setRightConfigWithTestType:FTNetworkTest];
    [NSThread sleepForTimeInterval:2];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
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
    FTUploadTool *tool = [self setRightConfigWithTestType:FTNetworkTestBad];
    
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
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
    FTUploadTool *tool = [self setRightConfigWithTestType:FTNetworkTestNoJsonResponse];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        NSError *errors;
        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&errors];
        NSString *result =[[ NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        XCTAssertTrue(errors != nil && [result isEqualToString:@"Hello World!"]);
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
    FTUploadTool *tool = [self setRightConfigWithTestType:FTNetworkTestWrongJsonResponse];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        NSError *errors;
        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&errors];
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
    FTUploadTool *tool =  [self setRightConfigWithTestType:FTNetworkTestEmptyResponseData];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(response.bytes == 0);
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
    FTUploadTool *tool = [self setRightConfigWithTestType:FTNetworkTestErrorResponse];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
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
    FTUploadTool *tool = [self setBadMetricsUrl];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
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
    FTUploadTool *tool = [self setRightConfigWithTestType:FTNetworkTestErrorNet];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
