//
//  FTNetworkTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/24.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "OHHTTPStubs.h"
#import "FTConstants.h"
#import "FTDateUtil.h"
#import "FTJSONUtil.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTModelHelper.h"
#import "FTTrackDataManager+Test.h"
#import "FTModelHelper.h"
#import "FTMobileAgent+Private.h"
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
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation FTNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    long  tm =[FTDateUtil currentTimeNanosecond];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
}
- (void)tearDown{
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)setRightConfigWithTestType:(FTNetworkTestsType)type{
    NSString *urlStr = @"http://www.test.com/some/url/string";
    NSString *logUrl = [urlStr stringByAppendingString:@"/v1/write/logging"];
    NSString *rumUrl = [urlStr stringByAppendingString:@"/v1/write/rum"];
    NSString *traceUrl = [urlStr stringByAppendingString:@"/v1/write/tracing"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        NSString *str =  request.URL.absoluteString;
        return [str isEqualToString:logUrl] || [str isEqualToString:rumUrl] || [str isEqualToString:traceUrl];
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
        [FTMobileAgent startWithConfigOptions:config];
        FTTraceConfig *trace = [[FTTraceConfig alloc]init];
        trace.enableAutoTrace = YES;
        [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:trace];
    }
}
/**
 测试上传过程是否正确
 */
-(void)testNetwork{
    
    [self setRightConfigWithTestType:FTNetworkTest];

    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    FTRecordModel *model = [FTModelHelper createLogModel:@"FTNetworkTests"];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
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
    
    FTRecordModel *model = [FTModelHelper createLogModel:@"testBadNetwork"];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
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
    FTRecordModel *model = [FTModelHelper createLogModel:@"testNoJsonResponseNetWork"];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
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
    FTRecordModel *model = [FTModelHelper createLogModel:@"testWrongJsonResponseNetWork"];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
    
        NSError *errors;
        [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
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
    FTRecordModel *model = [FTModelHelper createLogModel:@"testEmptyResponseDataNetWork"];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
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
    FTRecordModel *model = [FTModelHelper createLogModel:@"testErrorResponse"];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
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
    FTRecordModel *model = [FTModelHelper createLogModel:@"testErrorNet"];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        NSInteger statusCode = httpResponse.statusCode;
        XCTAssertFalse(statusCode == 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testUploadAll{
    [self setRightConfigWithTestType:FTNetworkTest];
    for (int i = 0 ; i<10; i++) {
       FTRecordModel *logModel = [FTModelHelper createLogModel:[NSString stringWithFormat:@"%d",i]];
        FTRecordModel *rumModel = [FTModelHelper createRumModel];

        [[FTTrackDataManager sharedInstance] addTrackData:logModel type:FTAddDataNormal];
        [[FTTrackDataManager sharedInstance] addTrackData:rumModel type:FTAddDataNormal];
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(count == 20);
    self.expectation = [self expectationWithDescription:@"异步操作timeout"];
       
    [[FTTrackDataManager sharedInstance] addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    [[FTTrackDataManager sharedInstance] performSelector:@selector(privateUpload)];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 0);
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"isUploading"]){
        FTTrackDataManager *manager = object;
        NSNumber *isUploading = [manager valueForKey:@"isUploading"];
        if(!isUploading.boolValue){
            [self.expectation fulfill];
            self.expectation = nil;
        }
    }
}
@end
