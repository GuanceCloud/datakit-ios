//
//  FTUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTRecordModel.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTConstants.h>
@interface FTUtilsTest : XCTestCase

@end

@implementation FTUtilsTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {

}
- (void)testMd5Base64{
    NSString *str = [FTBaseInfoHander ft_md5base64EncryptStr:@"iosTest"];
    XCTAssertEqualObjects(str, @"YODdoqDoIU+kZc597EPHXQ==");
}
- (void)testSignature{
    NSString *date =@"Wed, 02 Sep 2020 09:41:24 GMT";
    NSString *signature = [FTBaseInfoHander ft_getSignatureWithHTTPMethod:@"POST" contentType:@"application/json" dateStr:date akSecret:@"screct" data:@"testSignature"];
    
    XCTAssertEqualObjects(signature, @"kdmAYSUlyDEVS/J5Dlnm33ecDxY=");
}
- (void)testLineProtocol{
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"testLineProtocol"},
        FT_AGENT_TAGS:@{@"name":@"testLineProtocol"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeLogging,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeLogging;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    FTUploadTool *tool =  [FTUploadTool new];
    NSString *line = [tool getRequestDataWithEventArray:@[model]];
    NSArray *array = [line componentsSeparatedByString:@" "];
    XCTAssertTrue(array.count == 3);
    
    XCTAssertEqualObjects([array firstObject], @"iOSTest,name=testLineProtocol");
    XCTAssertEqualObjects(array[1], @"event=\"testLineProtocol\"");
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm*1000];
    XCTAssertEqualObjects([array lastObject],tm);
}
- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
