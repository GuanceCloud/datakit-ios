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

@interface FTRequestTest : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation FTRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
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
- (void)testRumSdkDataIDIncrease{
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
    [self mockHttp];
    for (int i = 0 ; i<8; i++) {
        FTRecordModel *rumModel = [FTModelHelper createRumModel];
        [[FTTrackDataManager sharedInstance] addTrackData:rumModel type:FTAddDataNormal];
    }
    NSString *serialNumber = [FTBaseInfoHandler rumRequestSerialNumber];
    self.expectation = [self expectationWithDescription:@"异步操作timeout"];
       
    [[FTTrackDataManager sharedInstance] addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    [[FTTrackDataManager sharedInstance] uploadTrackData];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSString *newSerialNumber = [FTBaseInfoHandler rumRequestSerialNumber];
    XCTAssertTrue([self  base36ToDecimal:newSerialNumber] - [self base36ToDecimal:serialNumber] == 1);
    [[FTTrackDataManager sharedInstance] removeObserver:self forKeyPath:@"isUploading"];
}
- (void)testLogSdkDataIDIncrease{
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
    [self mockHttp];
    self.expectation= [self expectationWithDescription:@"异步操作timeout"];
    for (int i = 0 ; i<8; i++) {
        FTRecordModel *logModel = [FTModelHelper createLogModel:[NSString stringWithFormat:@"%d",i]];
        [[FTTrackDataManager sharedInstance] addTrackData:logModel type:FTAddDataNormal];
    }
    
    NSString *serialNumber = [FTBaseInfoHandler logRequestSerialNumber];
    [[FTTrackDataManager sharedInstance] addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    [[FTTrackDataManager sharedInstance] uploadTrackData];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSString *newSerialNumber = [FTBaseInfoHandler logRequestSerialNumber];
    XCTAssertTrue([self  base36ToDecimal:newSerialNumber] - [self base36ToDecimal:serialNumber] == 1);
    [[FTTrackDataManager sharedInstance] removeObserver:self forKeyPath:@"isUploading"];
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
- (unsigned long long)base36ToDecimal:(NSString *)str {
    NSString *str36 = str.copy;
    NSString *param = @"0123456789abcdefghijklmnopqrstuvwxyz";
    unsigned long long num = 0;
    for (unsigned long long i = 0; i < str36.length; i++) {
        for (NSInteger j = 0; j < param.length; j++) {
            char iChar = [str36 characterAtIndex:i];
            char jChar = [param characterAtIndex:j];
            if (iChar == jChar) {
                unsigned long long n = j * pow(36, str36.length - i - 1);
                num += n;
                break;
            }
        }
    }
    return num;
}
- (void)testWrongFormat{
    [self mockHttp];
    FTRecordModel *model = [FTModelHelper createWrongFormatRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:request.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    NSMutableURLRequest *mRequest = [request adaptedRequest:urlRequest];
    XCTAssertTrue([mRequest.HTTPBody isEqual: [@"" dataUsingEncoding:NSUTF8StringEncoding]]);
}
- (void)testDatakitUrl{
    NSString *datakitUrlStr = @"http://www.test.com/some/url/string";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrlStr];
    [FTMobileAgent startWithConfigOptions:config];
    FTRecordModel *model = [FTModelHelper createWrongFormatRumModel];
    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_RUM];
    XCTAssertTrue([request.absoluteURL.host isEqualToString:[NSURL URLWithString:datakitUrlStr].host]);
    [[FTMobileAgent sharedInstance] shutDown];
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
    [[FTMobileAgent sharedInstance] shutDown];
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
    [[FTMobileAgent sharedInstance] shutDown];
}
@end
