//
//  FTUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHandler.h"
#import "FTDateUtil.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "NSString+FTAdd.h"
#import "FTTrackDataManger+Test.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTRequestBody.h"
#import "FTModelHelper.h"
#import "FTReadWriteHelper.h"
@interface FTUtilsTest : XCTestCase

@end

@implementation FTUtilsTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)testMd5Base64{
    NSString *str = [@"iosTest" ft_md5base64Encrypt];
    XCTAssertEqualObjects(str, @"YODdoqDoIU+kZc597EPHXQ==");
}
- (void)testSignature{
    NSString *date =@"Wed, 02 Sep 2020 09:41:24 GMT";
    NSString *signature = [FTBaseInfoHandler signatureWithHTTPMethod:@"POST" contentType:@"application/json" dateStr:date akSecret:@"screct" data:@"testSignature"];
    
    XCTAssertEqualObjects(signature, @"kdmAYSUlyDEVS/J5Dlnm33ecDxY=");
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
- (void)testAnalyticJsonString{
    XCTAssertNotNil([FTJSONUtil dictionaryWithJsonString:@"{\"a\":\"b\"}"]);
}
- (void)testAnalyticWrongJsonString{
    XCTAssertNil([FTJSONUtil dictionaryWithJsonString:@"a:b"]);
}
- (void)testConvertToJsonDataWithArray{
    NSString *str = [FTJSONUtil convertToJsonDataWithArray:@[@"A",@"B",@"C"]];
    XCTAssertTrue([str isEqualToString:@"[\"A\",\"B\",\"C\"]"]);
}
- (void)testConvertToJsonDataWithNilArray{
    XCTAssertNil([FTJSONUtil convertToJsonDataWithArray:nil]);
}
- (void)testReplaceUrlGroupNumberChar{
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSString *replace = [FTBaseInfoHandler replaceNumberCharByUrl:[NSURL URLWithString:urlStr]];
    XCTAssertTrue([replace isEqualToString:@"/data/sk/?"]);
}
- (void)testReadWriteHelper{
    NSMutableArray *array = @[@"a",@"b",@"c",@"d"].mutableCopy;
    FTReadWriteHelper *helper = [[FTReadWriteHelper alloc]initWithValue:array];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [helper concurrentWrite:^(id  _Nonnull value) {
            sleep(0.5);
            [value addObject:@"e"];
        }];
    });
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [helper concurrentWrite:^(id  _Nonnull value) {
            [value addObject:@"f"];
        }];
    });
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [helper concurrentRead:^(NSMutableArray *value) {
            XCTAssertTrue(value.count == 6);
            XCTAssertTrue([value.lastObject isEqualToString:@"f"]);
        }];
    });
}
@end
