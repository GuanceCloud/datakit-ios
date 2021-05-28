//
//  FTUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTRecordModel.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTJSONUtil.h>
#import <NSString+FTAdd.h>
@interface FTUtilsTest : XCTestCase

@end

@implementation FTUtilsTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {

}
- (void)testMd5Base64{
    NSString *str = [@"iosTest" ft_md5base64Encrypt];
    XCTAssertEqualObjects(str, @"YODdoqDoIU+kZc597EPHXQ==");
}
- (void)testSignature{
    NSString *date =@"Wed, 02 Sep 2020 09:41:24 GMT";
    NSString *signature = [FTBaseInfoHander signatureWithHTTPMethod:@"POST" contentType:@"application/json" dateStr:date akSecret:@"screct" data:@"testSignature"];
    
    XCTAssertEqualObjects(signature, @"kdmAYSUlyDEVS/J5Dlnm33ecDxY=");
}
- (void)testLineProtocol{
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"testLineProtocol"},
        FT_AGENT_TAGS:@{@"name":@"testLineProtocol"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FT_DATA_TYPE_INFLUXDB,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_INFLUXDB;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTUploadTool *tool =  [FTUploadTool new];
    NSString *line = [tool getRequestDataWithEventArray:@[model] type:FT_AGENT_MEASUREMENT];
    NSArray *array = [line componentsSeparatedByString:@" "];
    XCTAssertTrue(array.count == 3);
    
    XCTAssertEqualObjects([array firstObject], @"iOSTest,name=testLineProtocol");
    XCTAssertEqualObjects(array[1], @"event=\"testLineProtocol\"");
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm];
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

- (void)testFieldValueHasTransliteration1{
    [self transliteration:@"\\"];
}
- (void)testFieldValueHasTransliteration2{
    [self transliteration:@"\\\\"];
}
- (void)testFieldValueHasTransliteration3{
    [self transliteration:@"\\\\\\"];
}
- (void)testFieldValueJsonStr{
    NSDictionary *json = @{@"json":@"1",
                           @"json2":@"2"
    };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&error];
    if (!error) {
        NSString *str  = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [self transliteration:str];
    }
    
}
- (void)transliteration:(NSString *)str{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.appid = appid;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
     
    [[FTMobileAgent sharedInstance] logging:str status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode == 200);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
