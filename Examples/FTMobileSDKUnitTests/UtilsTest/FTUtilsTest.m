//
//  FTUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2020/9/2.
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
#import "FTHTTPClient.h"
#import "FTRequestBody.h"
#import "FTModelHelper.h"
#import "FTReadWriteHelper.h"
#import "NSNumber+FTAdd.h"
#import "NSError+FTDescription.h"
@interface FTUtilsTest : XCTestCase

@end

@implementation FTUtilsTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
#pragma mark NSString+FTAdd
- (void)testStringRemoveFrontBackBlank{
    NSString *string = @"    a  ";
    XCTAssertTrue([[string ft_removeFrontBackBlank] isEqualToString:@"a"]);
}
/// String encoding format is NSUTF8StringEncoding, English characters occupy 1 byte, complex characters occupy 3 bytes
- (void)testCharacterNumber{
    NSString *letterStr = @"abcde";
    XCTAssertTrue([letterStr ft_characterNumber] == 5);
    NSString *complexString = [NSString stringWithFormat:@"%C%C%C", 0x4E00, 0x4E8C, 0x4E09];
    XCTAssertTrue([complexString ft_characterNumber] == 9);
}
- (void)testSubStringWithCharacterLength{
    NSString *letterStr = [NSString stringWithFormat:@"abcde%C%C%C", 0x4E00, 0x4E8C, 0x4E09];
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
                          @"key6":@"test",
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
#pragma mark ==========  NSNumber ==========
- (void)testLineProtocolDealNumber{
    NSNumber *trueNum = [NSNumber numberWithBool:YES];
    XCTAssertEqualObjects([trueNum ft_toFieldFormat], @"true");
    XCTAssertEqualObjects([trueNum ft_toFieldIntegerCompatibleFormat], @"true");

    NSNumber *falseNum = [NSNumber numberWithBool:NO];
    XCTAssertEqualObjects([falseNum ft_toFieldFormat], @"false");
    XCTAssertEqualObjects([falseNum ft_toFieldIntegerCompatibleFormat], @"false");

    NSNumber *floatNum = [NSNumber numberWithFloat:1234567.123];
    XCTAssertEqualObjects([floatNum ft_toFieldFormat], @"1234567.12");
    XCTAssertEqualObjects([floatNum ft_toFieldIntegerCompatibleFormat], @"1234567.12");
    XCTAssertEqualObjects([floatNum ft_toTagFormat], @"1234567.12");

    
    NSNumber *doubleNum = [NSNumber numberWithDouble:123456789012345.12345];
    XCTAssertEqualObjects([doubleNum ft_toFieldFormat], @"123456789012345.12");
    XCTAssertEqualObjects([doubleNum ft_toFieldIntegerCompatibleFormat], @"123456789012345.12");
    XCTAssertEqualObjects([doubleNum ft_toTagFormat], @"123456789012345.12");

    
    NSNumber *intNum = [NSNumber numberWithInt:2147483647];
    XCTAssertEqualObjects([intNum ft_toFieldFormat], @"2147483647i");
    XCTAssertEqualObjects([[intNum ft_toFieldIntegerCompatibleFormat] stringValue], @"2147483647");

    NSNumber *longNum = [NSNumber numberWithLong:9223372036854775807];
    XCTAssertEqualObjects([longNum ft_toFieldFormat], @"9223372036854775807i");
    XCTAssertEqualObjects([[longNum ft_toFieldIntegerCompatibleFormat] stringValue], @"9223372036854775807");

    NSNumber *unsignedLongNum = [NSNumber numberWithUnsignedLong:9223372036854775807];
    XCTAssertEqualObjects([unsignedLongNum ft_toFieldFormat], @"9223372036854775807i");
    XCTAssertEqualObjects([[unsignedLongNum ft_toFieldIntegerCompatibleFormat] stringValue], @"9223372036854775807");

    NSNumber *longlongNum = [NSNumber numberWithLongLong:9223372036854775807];
    XCTAssertEqualObjects([longlongNum ft_toFieldFormat], @"9223372036854775807i");
    XCTAssertEqualObjects([[longlongNum ft_toFieldIntegerCompatibleFormat] stringValue], @"9223372036854775807");

    NSNumber *unsignedLongLongNum = [NSNumber numberWithUnsignedLongLong:9223372036854775807];
    XCTAssertEqualObjects([unsignedLongLongNum ft_toFieldFormat], @"9223372036854775807i");
    XCTAssertEqualObjects([[unsignedLongLongNum ft_toFieldIntegerCompatibleFormat] stringValue], @"9223372036854775807");

}
#if TARGET_OS_IOS
- (void)testErrorDescription{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"errors" ofType:@"json"];
     // Convert file to data
     NSData *data = [[NSData alloc] initWithContentsOfFile:path];
     // Format data as JSON and return as dictionary
     NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    for (NSDictionary *domain in array) {
        if([domain[@"key"] isEqualToString:@"NSURLErrorDomain"]){
            NSArray *errors = domain[@"errors"];
            for (NSDictionary *error in errors) {
                NSInteger code =  [error[@"code"] integerValue];
                NSString *description = error[@"description"];
                NSDictionary* errorMessage = [NSDictionary dictionaryWithObject:@"testErrorDescription" forKey:NSLocalizedDescriptionKey];
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:code userInfo:errorMessage];
                NSString *ftError = [error ft_description];
                XCTAssertTrue([ftError isEqualToString:description]);
            }
        }
    }
}
#endif
@end
