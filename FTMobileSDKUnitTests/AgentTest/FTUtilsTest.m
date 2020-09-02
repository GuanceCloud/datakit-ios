//
//  FTUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
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
