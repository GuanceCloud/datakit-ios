//
//  FTTrackDataManagerTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/29.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTNetworkInfoManager.h"
#import "FTTrackDataManager.h"
#import "FTTrackerEventDBTool+Test.h"
#import "OHHTTPStubs.h"
#import "FTJSONUtil.h"
#import "FTModelHelper.h"
#import "FTTestUtils.h"
@interface FTTrackDataManagerTest : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;

@end

@implementation FTTrackDataManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testTrackDataManagerShutDown{
    [self mockHttp];
    [FTTrackDataManager sharedInstance];
    [FTModelHelper createRumModel];
    [[FTTrackDataManager sharedInstance] addTrackData:[FTModelHelper createRumModel] type:FTAddDataRUM];
    self.expectation = [self expectationWithDescription:@"异步操作timeout"];
    [[FTTrackDataManager sharedInstance] addObserver:self forKeyPath:@"isUploading" options:NSKeyValueObservingOptionNew context:nil];
    [[FTTrackDataManager sharedInstance] uploadTrackData];
    [self waitForExpectations:@[self.expectation] timeout:2];
    CFTimeInterval interval = [FTTestUtils functionElapsedTime:^{
        [[FTTrackDataManager sharedInstance] shutDown];
    }];
    XCTAssertTrue(interval<0.1);
    XCTAssertTrue([[[FTTrackDataManager sharedInstance] valueForKey:@"isUploading"] isEqual:@YES]);
    [[FTTrackDataManager sharedInstance] removeObserver:self forKeyPath:@"isUploading"];
}

- (void)mockHttp{
    __block id<OHHTTPStubsDescriptor> stub = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        sleep(1);
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        [OHHTTPStubs removeStub:stub];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
    NSString *urlStr = @"http://www.test.com/some/url/string";
    FTNetworkInfoManager *manager = [FTNetworkInfoManager sharedInstance];
    manager.setDatakitUrl(urlStr)
        .setSdkVersion(@"RequestTest");
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"isUploading"]){
        FTTrackDataManager *manager = object;
        NSNumber *isUploading = [manager valueForKey:@"isUploading"];
        if(isUploading.boolValue){
            [self.expectation fulfill];
            self.expectation = nil;
        }
    }
}
@end
