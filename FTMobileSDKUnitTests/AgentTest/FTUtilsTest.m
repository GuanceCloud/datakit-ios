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
#import <FTMobileAgent/FTJSONUtil.h>
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
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    FTUploadTool *tool =  [FTUploadTool new];
    NSString *line = [tool getRequestDataWithEventArray:@[model]];
    NSArray *array = [line componentsSeparatedByString:@" "];
    XCTAssertTrue(array.count == 3);
    
    XCTAssertEqualObjects([array firstObject], @"iOSTest,name=testLineProtocol");
    XCTAssertEqualObjects(array[1], @"event=\"testLineProtocol\"");
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm*1000];
    XCTAssertEqualObjects([array lastObject],tm);
}
- (void)testJSONSerializeDictObject{
    NSDictionary *dict =@{@"key1":@"value1",
                          @"key2":@{@"key11":@1,
                                    @"key12":@[@"1",@"2"],
                          },
                          @"key3":@1,
                          @"key4":@[@1,@2,[NSNumber numberWithFloat:2.0]],
                          @"key5":[NSNumber numberWithFloat:0],
                          @"key6":@"测试",
    };
    
    FTJSONUtil *util = [FTJSONUtil new];
    NSData *data = [util JSONSerializeDictObject:dict];
    NSString *jsonString = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    XCTAssertTrue([dic isEqual:dict]);
    NSNumber *number = [dict valueForKey:@"key5"];
    XCTAssertTrue(strcmp([number objCType], @encode(float)) == 0||strcmp([number objCType], @encode(double)) == 0);
}


@end
