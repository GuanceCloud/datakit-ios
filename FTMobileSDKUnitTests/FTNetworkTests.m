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
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import "OHHTTPStubs.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>

@interface FTNetworkTests : XCTestCase
@end

@implementation FTNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    long  tm =[[NSDate now] ft_dateTimestamp];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
}
- (void)tearDown {
}
- (FTUploadTool *)setRightConfig:(NSString *)urlStr{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    if (!urlStr) {
        urlStr = url;
    }
    if (akId && akSecret && url) {
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
- (void)setOHHTTPStubs:(NSString *)urlStr{
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        NSString *str =  request.URL.absoluteString;
        return [str isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        
        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
-(void)setBadNetOHHTTPStubs:(NSString *)urlStr{
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        
        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [[OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil]
                requestTime:1.0 responseTime:3.0];
    }];
}

-(void)setErrorNetOHHTTPStubs:(NSString *)urlStr{
    
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
    
}
-(void)setErrorResponseOHHTTPStubs:(NSString *)urlStr{
    
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@500}];
        
        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:500 headers:nil];
    }];
}
-(void)setNoJsonResponseOHHTTPStubs:(NSString *)urlStr{
   
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        NSString *str =request.URL.absoluteString;
        return [str isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =@"Hello World!";
        
        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
-(void)setWrongJsonResponseOHHTTPStubs:(NSString *)urlStr{
    
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        data = [data stringByAppendingString:@"/n/t"];
        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
-(void)setEmptyResponseOHHTTPStubs:(NSString *)urlStr{
   
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:urlStr];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
    }];
}
/**
 测试上传过程是否正确
 */
-(void)testNetwork{
    FTUploadTool *tool = [self setRightConfig:nil];
    [NSThread sleepForTimeInterval:2];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
    urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setOHHTTPStubs:urlStr];
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
     model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
    urlStr = [urlStr stringByAppendingString:@"badNet"];
    FTUploadTool *tool = [self setRightConfig:urlStr];
    urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setBadNetOHHTTPStubs:urlStr];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
       urlStr = [urlStr stringByAppendingString:@"noJson"];
    FTUploadTool *tool = [self setRightConfig:urlStr];
       urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setNoJsonResponseOHHTTPStubs:urlStr];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
    urlStr = [urlStr stringByAppendingString:@"wrongJson"];
    FTUploadTool *tool = [self setRightConfig:urlStr];
    urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setWrongJsonResponseOHHTTPStubs:urlStr];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
    urlStr = [urlStr stringByAppendingString:@"emptyResponse"];
    FTUploadTool *tool =  [self setRightConfig:urlStr];
    urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setEmptyResponseOHHTTPStubs:urlStr];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
    
    urlStr = [urlStr stringByAppendingString:@"errorResponse"];
   FTUploadTool *tool = [self setRightConfig:urlStr];
    urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setErrorResponseOHHTTPStubs:urlStr];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"ACCESS_SERVER_URL"];
    urlStr = [urlStr stringByAppendingString:@"errorNet"];
    FTUploadTool *tool = [self setRightConfig:urlStr];
    urlStr = [urlStr stringByAppendingString:FT_NETWORKING_API_METRICS];
    [self setErrorNetOHHTTPStubs:urlStr];
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [tool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
