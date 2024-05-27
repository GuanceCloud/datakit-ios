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
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "NSString+FTAdd.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTRequestBody.h"
#import "FTModelHelper.h"
#import "FTReadWriteHelper.h"
#import "NSNumber+FTAdd.h"

@interface FTUtilsTest : XCTestCase

@end

@implementation FTUtilsTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
}
#pragma mark NSString+FTAdd
- (void)testStringRemoveFrontBackBlank{
    NSString *string = @"    a  ";
    XCTAssertTrue([[string ft_removeFrontBackBlank] isEqualToString:@"a"]);
}
/// 字符串的编码格式为 NSUTF8StringEncoding ，英文字符占一字节，中文占三字节
- (void)testCharacterNumber{
    NSString *letterStr = @"abcde";
    XCTAssertTrue([letterStr ft_characterNumber] == 5);
    NSString *Chinese = @"一二三";
    XCTAssertTrue([Chinese ft_characterNumber] == 9);
}
- (void)testSubStringWithCharacterLength{
    NSString *letterStr = @"abcde一二三";
    NSString *subStr = [letterStr ft_subStringWithCharacterLength:4];
    XCTAssertTrue([subStr isEqualToString:@"abcd"]);
    NSString *subStr2 = [letterStr ft_subStringWithCharacterLength:15];
    XCTAssertTrue([subStr2 isEqualToString:letterStr]);
    NSString *subStr3 = [letterStr ft_subStringWithCharacterLength:6];
    XCTAssertTrue([subStr3 isEqualToString:@"abcde"]);
}
#pragma mark FTJSONUtil
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
    NSString *str = [FTJSONUtil convertToJsonDataWithObject:@[@"A",@"B",@"C"]];
    XCTAssertTrue([str isEqualToString:@"[\"A\",\"B\",\"C\"]"]);
}
- (void)testConvertToJsonDataWithNilArray{
    XCTAssertNil([FTJSONUtil convertToJsonDataWithObject:nil]);
}
- (void)testConvertToJsonDataWithObjectDict{
    UIView *view = [[UIView alloc]init];
    view.backgroundColor = [UIColor redColor];
    NSDictionary *dict = @{@"view":view};
    XCTAssertNil([FTJSONUtil convertToJsonData:dict]);
}
#pragma mark FTBaseInfoHandler
- (void)testReplaceUrlGroupNumberChar{
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSString *replace = [FTBaseInfoHandler replaceNumberCharByUrl:[NSURL URLWithString:urlStr]];
    XCTAssertTrue([replace isEqualToString:@"/data/sk/?"]);
    NSString *baidu = @"https://www.baidu.com";
    XCTAssertTrue([[FTBaseInfoHandler replaceNumberCharByUrl:[NSURL URLWithString:baidu]] isEqualToString:@""]);
}
- (void)testRandomSampling{
    XCTAssertTrue([FTBaseInfoHandler randomSampling:100]);
    XCTAssertFalse([FTBaseInfoHandler randomSampling:0]);
    NSMutableArray *ary = [[NSMutableArray alloc]init];
    for (int i= 0; i<10; i++) {
        [ary addObject:@([FTBaseInfoHandler randomSampling:50])];
    }
    XCTAssertTrue([ary containsObject:@(1)]);
    XCTAssertTrue([ary containsObject:@(0)]);
}
- (void)testRandomUUID{
    NSString *uuid = [FTBaseInfoHandler randomUUID];
    XCTAssertFalse([uuid containsString:@"-"]);
    XCTAssertTrue([[uuid lowercaseString] isEqualToString:uuid]);
}
#pragma mark FTReadWriteHelper
- (void)testReadWriteHelper{
    NSMutableArray *array = @[@"a",@"b",@"c",@"d"].mutableCopy;
    FTReadWriteHelper *helper = [[FTReadWriteHelper alloc]initWithValue:array];
    [helper concurrentRead:^(NSMutableArray *value) {
        XCTAssertTrue(value.count == 4);
    }];
    [helper concurrentRead:^(NSMutableArray *value) {
        XCTAssertTrue(value.count == 4);
    }];
    [helper concurrentWrite:^(id  _Nonnull value) {
        sleep(0.5);
        [value addObject:@"e"];
    }];
    
    [helper concurrentRead:^(NSMutableArray *value) {
        XCTAssertTrue(value.count == 5);
    }];
    [helper concurrentRead:^(NSMutableArray *value) {
        XCTAssertTrue([value.lastObject isEqualToString:@"e"]);
    }];    
}
#pragma mark ==========  NSNumber ==========
- (void)testLineProtocolDealNumber{
    NSNumber *trueNum = [NSNumber numberWithBool:YES];
    XCTAssertEqualObjects([trueNum ft_toFiledString], @"true");
    
    NSNumber *falseNum = [NSNumber numberWithBool:NO];
    XCTAssertEqualObjects([falseNum ft_toFiledString], @"false");
    
    NSNumber *floatNum = [NSNumber numberWithFloat:1234567.12];
    XCTAssertEqualObjects([floatNum ft_toFiledString], @"1234567.1");
   
    NSNumber *doubleNum = [NSNumber numberWithDouble:123456789012345.12345];
    XCTAssertEqualObjects([doubleNum ft_toFiledString], @"123456789012345.1");
    
    NSNumber *intNum = [NSNumber numberWithInt:2147483647];
    XCTAssertEqualObjects([intNum ft_toFiledString], @"2147483647i");
    
    NSNumber *longNum = [NSNumber numberWithLong:9223372036854775807];
    XCTAssertEqualObjects([longNum ft_toFiledString], @"9223372036854775807i");
    
    NSNumber *unsignedLongNum = [NSNumber numberWithUnsignedLong:9223372036854775807];
    XCTAssertEqualObjects([unsignedLongNum ft_toFiledString], @"9223372036854775807i");
   
    NSNumber *longlongNum = [NSNumber numberWithLongLong:9223372036854775807];
    XCTAssertEqualObjects([longlongNum ft_toFiledString], @"9223372036854775807i");
    
    NSNumber *unsignedLongLongNum = [NSNumber numberWithUnsignedLongLong:9223372036854775807];
    XCTAssertEqualObjects([unsignedLongLongNum ft_toFiledString], @"9223372036854775807i");

}
@end
