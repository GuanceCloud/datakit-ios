//
//  FTRequestTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/24.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "OHHTTPStubs.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTNetworkInfoManager.h"
#import "FTEnumConstant.h"
#import "FTModelHelper.h"
#import "FTTrackDataManager.h"
#import "NSDate+FTUtil.h"
#import "FTBaseInfoHandler.h"
#import "FTTestUtils.h"
@interface FTRequestTest : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation FTRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTNetworkInfoManager shutDown];
    [OHHTTPStubs removeAllStubs];
}
- (void)mockHttp{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
    NSString *urlStr = @"http://www.test.com/some/url/string";
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setDatakitUrl(urlStr)
        .setSdkVersion(@"RequestTest");
}
- (void)testLogRequest{
    [self mockHttp];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

   
    FTRecordModel *model = [FTModelHelper createLogModel:@"testLogRequest"];
    
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
    [[FTNetworkManager new] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
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
    [self mockHttp];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    FTRecordModel *model = [FTModelHelper createRumModel];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    [[FTNetworkManager new] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
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
- (void)testRequestSerialNumIncrease{
    FTRequest *rumRequest = [FTRequest createRequestWithEvents:@[[FTModelHelper createRumModel]] type:FT_DATA_TYPE_RUM];
    FTRequest *logRequest = [FTRequest createRequestWithEvents:@[[FTModelHelper createLogModel]] type:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue([rumRequest.classSerialGenerator.prefix isEqualToString:@"FTRumRequest"]);
    XCTAssertTrue([logRequest.classSerialGenerator.prefix isEqualToString:@"FTLoggingRequest"]);
    NSString *currentRumSerialNum = [rumRequest.classSerialGenerator getCurrentSerialNumber];
    NSString *currentLogSerialNum = [logRequest.classSerialGenerator getCurrentSerialNumber];
    [rumRequest.classSerialGenerator increaseRequestSerialNumber];
    [logRequest.classSerialGenerator increaseRequestSerialNumber];
    
    NSString *newRumSerialNum = [rumRequest.classSerialGenerator getCurrentSerialNumber];
    NSString *newtLogSerialNum = [logRequest.classSerialGenerator getCurrentSerialNumber];
    
    XCTAssertFalse([currentRumSerialNum isEqualToString:newRumSerialNum]);
    XCTAssertFalse([currentLogSerialNum isEqualToString:newtLogSerialNum]);
    XCTAssertTrue([FTTestUtils base36ToDecimal:newRumSerialNum] - [FTTestUtils base36ToDecimal:currentRumSerialNum] == 1);
    XCTAssertTrue([FTTestUtils base36ToDecimal:newtLogSerialNum] - [FTTestUtils base36ToDecimal:currentLogSerialNum] == 1);
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

- (void)testWrongFormat{
    [self mockHttp];
    FTRecordModel *model = [FTModelHelper createWrongFormatRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    NSMutableURLRequest *mRequest = [request adaptedRequest:urlRequest];
    XCTAssertTrue([mRequest.HTTPBody isEqual: [@"" dataUsingEncoding:NSUTF8StringEncoding]]);
}
- (void)testSdkDataID_RUM{
    [self sdkDataIDTest:YES];
}
- (void)testSdkDataID_LOG{
    [self sdkDataIDTest:NO];
}
- (void)sdkDataIDTest:(BOOL)rum{
    FTRecordModel *model = rum?[FTModelHelper createRumModel]:[FTModelHelper createLogModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:rum?FT_DATA_TYPE_RUM:FT_DATA_TYPE_LOGGING];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    NSMutableURLRequest *urlRequest2 = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];

    NSMutableURLRequest *mRequest = [request adaptedRequest:urlRequest];
    [request.classSerialGenerator increaseRequestSerialNumber];
    NSMutableURLRequest *mRequest2 = [request adaptedRequest:urlRequest2];
    NSString *bodyStr = [[NSString alloc]initWithData:mRequest.HTTPBody encoding:NSUTF8StringEncoding];
    NSString *bodyStr2 = [[NSString alloc]initWithData:mRequest2.HTTPBody encoding:NSUTF8StringEncoding];
    XCTAssertFalse([bodyStr isEqualToString:bodyStr2]);
    NSArray *array1 = [bodyStr componentsSeparatedByString:@","];
    NSArray *array2 = [bodyStr2 componentsSeparatedByString:@","];
    __block NSString *sdk_data_id1;
    __block NSString *sdk_data_id2;
    [array1 enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj containsString:@"sdk_data_id"]) {
            sdk_data_id1 = obj;
            *stop = YES;
        }
    }];
    [array2 enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj containsString:@"sdk_data_id"]) {
            sdk_data_id2 = obj;
            *stop = YES;
        }
    }];
    array1 = [[sdk_data_id1 substringFromIndex:12] componentsSeparatedByString:@"."];
    array2 = [[sdk_data_id2 substringFromIndex:12] componentsSeparatedByString:@"."];
    // packageId +1
    XCTAssertTrue([FTTestUtils base36ToDecimal:array2[0]] - [FTTestUtils base36ToDecimal:array1[0]] == 1);
    // 进程 id 一致
    XCTAssertTrue([array1[1] isEqualToString:array2[1]]);
    // 数据个数
    XCTAssertTrue([array2[2] intValue] == [array1[2] intValue] == 1);
    // packageId 末尾随机数
    NSString *random12 = array2[3];
    XCTAssertTrue(random12.length == 12);
    XCTAssertFalse([array2[3] isEqualToString:array1[3]]);
    // 数据 id 不一致
    XCTAssertFalse([[array1 lastObject] isEqualToString:[array2 lastObject]]);

}
- (void)testDatakitUrl{
    NSString *datakitUrlStr = @"http://www.test.com/some/url/string";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrlStr];
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTModelHelper createWrongFormatRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    XCTAssertTrue([request.absoluteURL.host isEqualToString:[NSURL URLWithString:datakitUrlStr].host]);
    [FTMobileAgent shutDown];
}
- (void)testDatawayUrl{
    NSString *datawayUrlStr = @"http://www.test.com/some/url/string";
    NSString *clientToken = @"clientToken";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatawayUrl:datawayUrlStr clientToken:clientToken];
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTModelHelper createWrongFormatRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    NSURL *datawayUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?token=%@&to_headless=true",datawayUrlStr,request.path,clientToken]];
    XCTAssertTrue([request.absoluteURL.host isEqualToString:[NSURL URLWithString:datawayUrlStr].host]);
    XCTAssertTrue([request.absoluteURL isEqual:datawayUrl]);
    [FTMobileAgent shutDown];
}
- (void)testSetDatakitAndDatawayUrl{
    NSString *datakitUrlStr = @"http://www.test.com/datakit/url/string";
    NSString *datawayUrlStr = @"http://www.test.com/dataway/url/string";
    NSString *clientToken = @"clientToken";

    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrlStr];
    config.datawayUrl = datawayUrlStr;
    config.clientToken = clientToken;
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTModelHelper createWrongFormatRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    XCTAssertTrue([request.absoluteURL.host isEqualToString:[NSURL URLWithString:datakitUrlStr].host]);
    [FTMobileAgent shutDown];
}
- (void)testCompressIntakeRequests_NO{
    NSString *datakitUrlStr = @"http://www.test.com/datakit/url/string";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrlStr];
    config.enableSDKDebugLog = YES;
    config.compressIntakeRequests = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTModelHelper createRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];

    NSMutableURLRequest *newRequest = [request adaptedRequest:urlRequest];
    
    XCTAssertNil([newRequest.allHTTPHeaderFields valueForKey:@"Content-Encoding"]);
    [FTMobileAgent shutDown];
}
//- (void)testCompressionForUpload_Gzip_HTTPHeader{
//    FTRecordModel *model = [FTModelHelper createRumModel];
//    FTRequest *referenceRequest = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
//    NSMutableURLRequest *rUrlRequest = [[NSMutableURLRequest alloc]initWithURL:referenceRequest.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
//    NSMutableURLRequest *normalRequest = [referenceRequest adaptedRequest:rUrlRequest];
//    
//    NSString *datakitUrlStr = @"http://www.test.com/datakit/url/string";
//    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrlStr];
//    config.enableSDKDebugLog = YES;
//    config.compressionForUpload = FTHttpRequestCompressionGzip;
//    [FTMobileAgent startWithConfigOptions:config];
//
//    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
//    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
//
//    NSMutableURLRequest *compressRequest = [request adaptedRequest:urlRequest];
//
//    NSString *contentEncoding = [compressRequest.allHTTPHeaderFields valueForKey:@"Content-Encoding"];
//
//    XCTAssertTrue([contentEncoding isEqualToString:@"gzip"]);
//    
//    NSUInteger rLength = normalRequest.HTTPBody.length;
//    NSUInteger cLength = compressRequest.HTTPBody.length;
//    XCTAssertTrue(rLength>cLength);
//    [FTMobileAgent shutDown];
//}
- (void)testCompressIntakeRequests_YES{
    FTRecordModel *model = [FTModelHelper createRumModel];
    FTRequest *referenceRequest = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *rUrlRequest = [[NSMutableURLRequest alloc]initWithURL:referenceRequest.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    NSMutableURLRequest *normalRequest = [referenceRequest adaptedRequest:rUrlRequest];
    
    NSString *datakitUrlStr = @"http://www.test.com/datakit/url/string";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrlStr];
    config.enableSDKDebugLog = YES;
    config.compressIntakeRequests = YES;
    [FTMobileAgent startWithConfigOptions:config];

    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];

    NSMutableURLRequest *compressRequest = [request adaptedRequest:urlRequest];

    NSString *contentEncoding = [compressRequest.allHTTPHeaderFields valueForKey:@"Content-Encoding"];

    XCTAssertTrue([contentEncoding isEqualToString:@"deflate"]);
    
    NSUInteger rLength = normalRequest.HTTPBody.length;
    NSUInteger cLength = compressRequest.HTTPBody.length;
    XCTAssertTrue(rLength>cLength);
   
    [FTMobileAgent shutDown];
}
@end
