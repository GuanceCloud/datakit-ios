//
//  FTLineProtocol.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/5/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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
//#import "FTBaseInfoHander.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTRequestBody.h"
#import "FTModelHelper.h"
#import "FTEnumConstant.h"
@interface FTLineProtocol : XCTestCase

@end

@implementation FTLineProtocol

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
/**
    tag： "=" —> "\\="
    field: "=" -> "="
 */
- (void)testLineProtocol_EqualsSign{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_FIELDS:@{@"event":@"test=lineProtocol"},
        FT_TAGS:@{@"name":@"test=lineProtocol"},
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };

    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@" "];
    XCTAssertTrue(array.count == 3);
    NSArray *tags = [[array firstObject] componentsSeparatedByString:@","];
    NSString *field = array[1];
    XCTAssertTrue(tags.count == 3);
    XCTAssertEqualObjects([tags firstObject], @"iOSTest");
    XCTAssertTrue([tags[1] isEqualToString:@"name=test\\=lineProtocol"]||[tags[2] isEqualToString:@"name=test\\=lineProtocol"]);
    XCTAssertTrue([tags[1] isEqualToString:@"name=test\\=lineProtocol"]||[tags[2] isEqualToString:@"name=test\\=lineProtocol"]);
    XCTAssertTrue([field isEqualToString:@"event=\"test=lineProtocol\""]);
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm];
    XCTAssertEqualObjects([array lastObject],tm);
}
/**
    tag： " " —> "\\ "
    field: " " -> " "
 */
- (void)testLineProtocol_Blank{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_FIELDS:@{@"event":@"test lineProtocol"},
        FT_TAGS:@{@"name":@"test lineProtocol"},
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };

    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@"event"];
    NSArray *tags = [[[array firstObject] ft_removeFrontBackBlank]componentsSeparatedByString:@","];
    NSString *field = [lineStr stringByReplacingOccurrencesOfString:[array firstObject] withString:@""];
    XCTAssertTrue(tags.count == 3);
    XCTAssertEqualObjects([tags firstObject], @"iOSTest");
    XCTAssertTrue([tags[1] isEqualToString:@"name=test\\ lineProtocol"]||[tags[2] isEqualToString:@"name=test\\ lineProtocol"]);
    XCTAssertTrue([field containsString:@"event=\"test lineProtocol\""]);
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm];
    XCTAssertTrue([field containsString:tm]);
}
/**
    tag： "," —> "\\,"
    field: "," -> ","
 */
- (void)testLineProtocol_Comma{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_FIELDS:@{@"event":@"test,lineProtocol"},
        FT_TAGS:@{@"name":@"test,lineProtocol"},
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };

    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@"event"];
    NSString *str = [array firstObject];
    NSString *tagsStr = [str stringByReplacingOccurrencesOfString:[[str componentsSeparatedByString:@"name"] firstObject] withString:@""];
    NSString *field = [lineStr stringByReplacingOccurrencesOfString:[array firstObject] withString:@""];
    XCTAssertTrue([tagsStr containsString:@"name=test\\,lineProtocol"]);
    XCTAssertTrue([field containsString:@"event=\"test,lineProtocol\""]);
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm];
    XCTAssertTrue([field containsString:tm]);
}
/**
    tag： "\"" —> "\""
    field: "\"" -> "\\\""
 */
- (void)testLineProtocol_QuotationMarks{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_FIELDS:@{@"event":@"test\"lineProtocol"},
        FT_TAGS:@{@"name":@"test\"lineProtocol"},
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@"event"];
    NSString *str = [array firstObject];
    NSString *tagsStr = [str stringByReplacingOccurrencesOfString:[[str componentsSeparatedByString:@"name"] firstObject] withString:@""];
    NSString *field = [lineStr stringByReplacingOccurrencesOfString:[array firstObject] withString:@""];
    XCTAssertTrue([tagsStr containsString:@"name=test\"lineProtocol"]);
    XCTAssertTrue([field containsString:@"event=\"test\\\"lineProtocol\""]);
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm];
    XCTAssertTrue([field containsString:tm]);
}
- (void)testStringReplacingBlank{
    NSString *str = @"a b c";
    str = [str ft_replacingSpecialCharacters];
    XCTAssertTrue([str isEqualToString:@"a\\ b\\ c"]);
    NSString *str2 = @"⍣ ₂₈.₂₃ᴀͤꜱᷟ ⷨꜱᷛᴮᴀᷟꜱͤı ⷨɴ";
    str2 = [str2 ft_replacingMeasurementSpecialCharacters];
    XCTAssertTrue([str2 isEqualToString:@"⍣\\ ₂₈.₂₃ᴀͤꜱᷟ\\ ⷨꜱᷛᴮᴀᷟꜱͤı\\ ⷨɴ"]);
}
- (void)testDataUUID{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_FIELDS:@{@"event":@"testLineProtocol"},
        FT_TAGS:@{@"name":@"testLineProtocol"},
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };

    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSString *lineStr2 = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    XCTAssertFalse([lineStr isEqualToString:lineStr2]);
    XCTAssertTrue([lineStr containsString:@"sdk_data_id=1.1."]);
    XCTAssertTrue([lineStr2 containsString:@"sdk_data_id=1.1."]);
}
- (void)testNullValue{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_FIELDS:@{@"event":@"testLineProtocol",@"emptyString":@"",@"null":[NSNull null]},
        FT_TAGS:@{@"name":@"testLineProtocol",@"emptyString":@"",@"null":[NSNull null]},
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };

    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@" "];
    XCTAssertTrue(array.count == 3);
    NSArray *tags = [[array firstObject] componentsSeparatedByString:@","];
    XCTAssertTrue(tags.count == 3);
    XCTAssertEqualObjects([tags firstObject], @"iOSTest");
    XCTAssertTrue([tags[1] isEqualToString:@"name=testLineProtocol"]||[tags[2] isEqualToString:@"name=testLineProtocol"]);
    XCTAssertEqualObjects(array[1], @"event=\"testLineProtocol\",null=\"\",emptyString=\"\"");
    NSString *tm =[NSString stringWithFormat:@"%lld",model.tm];
    XCTAssertEqualObjects([array lastObject],tm);
}
- (void)testLogLineProtocol{
    FTRecordModel *model = [FTModelHelper createLogModel:@"testLogLineProtocol"];
    
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    //df_rum_ios_log,status=info message="testLogLineProtocol" 1651916317042660096
    NSArray *array = [lineStr componentsSeparatedByString:@" "];
    NSArray *sourceAndTagsArray = [[array firstObject] componentsSeparatedByString:@","];
    XCTAssertTrue([[sourceAndTagsArray firstObject] isEqualToString:FT_LOGGER_SOURCE]);
    XCTAssertTrue([sourceAndTagsArray containsObject:@"status=info"]);
    NSArray *fieldsArray = [array[1] componentsSeparatedByString:@","];
    XCTAssertTrue([fieldsArray containsObject:@"message=\"testLogLineProtocol\""]);
    NSString *times = [array lastObject];
    XCTAssertTrue([self isNum:times]);
}
- (void)testRumLineProtocol{
    NSDictionary *field = @{ FT_KEY_ERROR_MESSAGE:@"rum_model_create",
                             FT_KEY_ERROR_STACK:@"rum_model_create",
    };
    NSDictionary *tags = @{
        FT_KEY_ERROR_TYPE:@"ios_crash",
        FT_KEY_ERROR_SOURCE:@"logger",
        FT_KEY_ERROR_SITUATION:AppStateStringMap[FTAppStateRun],
        FT_RUM_KEY_SESSION_ID:[FTBaseInfoHandler randomUUID],
        FT_RUM_KEY_SESSION_TYPE:@"user",
    };
    long long time = [NSDate ft_currentNanosecondTimeStamp];
    FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_RUM_SOURCE_ERROR op:FT_DATA_TYPE_RUM tags:tags fields:field tm:time];
    
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@" "];
    NSArray *sourceAndTagsArray = [[array firstObject] componentsSeparatedByString:@","];
    XCTAssertTrue([[sourceAndTagsArray firstObject] isEqualToString:FT_RUM_SOURCE_ERROR]);
    NSString *errorType = [NSString stringWithFormat:@"%@=%@",FT_KEY_ERROR_TYPE,@"ios_crash"];
    XCTAssertTrue([sourceAndTagsArray containsObject:errorType]);
    NSArray *fieldsArray = [array[1] componentsSeparatedByString:@","];
    NSString *errorMessage = [NSString stringWithFormat:@"%@=\"%@\"",FT_KEY_ERROR_MESSAGE,@"rum_model_create"];
    XCTAssertTrue([fieldsArray containsObject:errorMessage]);
    NSString *timeStr = [array lastObject];
    XCTAssertTrue([self isNum:timeStr] && [timeStr longLongValue] == time);
}
// message 实际为 "\"
- (void)testFieldValueHasTransliteration1{
    [self transliteration:@"\\" expect:@"\\\\"];
}
// message 实际为 "\\"
- (void)testFieldValueHasTransliteration2{
    [self transliteration:@"\\\\" expect:@"\\\\\\\\"];
}
// message 实际为 "\\\"
- (void)testFieldValueHasTransliteration3{
    [self transliteration:@"\\\\\\" expect:@"\\\\\\\\\\\\"];
}
- (void)testFieldValueJsonStr{
    NSDictionary *json = @{@"json":@"1",
                           @"json2":@"2"
    };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&error];
    if (!error) {
        NSString *str  = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [self transliteration:str expect:@""];
    }
    
}
- (void)testLineProtocolValueFormat{
    NSDictionary *dict = @{
        FT_MEASUREMENT:@"iOSTest",
        FT_TAGS:@{@"string":@"stringValue",
                  @"boolNumber":@(YES),
                  @"null":[NSNull null],
                  @"array":@[@"1",@"2"],
                  @"dict":@{@"key1":@"value1"}
        },
        FT_FIELDS:@{@"string":@"stringValue",
                  @"intNumber":@(1),
                  @"floatNumber":@(1.23456789),
                  @"boolNumber":@(NO),
                  @"array":@[@"1",@"2"],
                  @"null":[NSNull null],
                  @"dict":@{@"key1":@"value1"}
        },
    };
    NSDictionary *data =@{FT_OP:FT_DATA_TYPE_RUM,
                          FT_OPDATA:dict,
    };

    FTRecordModel *model = [FTRecordModel new];
    model.op =FT_DATA_TYPE_RUM;
    model.data =[FTJSONUtil convertToJsonData:data];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    
    NSRange range = [lineStr rangeOfString:@" "];
    NSString *tagStr = [lineStr substringToIndex:range.location];
    NSString *fieldStr = [lineStr substringFromIndex:range.location+1];
    
    XCTAssertTrue([tagStr containsString:@"string=stringValue"]);
    XCTAssertTrue([tagStr containsString:@"boolNumber=true"]);
    XCTAssertTrue([tagStr containsString:@"array=[\"1\"\\,\"2\"]"]);
    XCTAssertTrue([tagStr containsString:@"dict={\"key1\":\"value1\"}"]);

    XCTAssertTrue([fieldStr containsString:@"string=\"stringValue\""]);
    XCTAssertTrue([fieldStr containsString:@"floatNumber=1.2"]);
    XCTAssertTrue([fieldStr containsString:@"intNumber=1i"]);
    XCTAssertTrue([fieldStr containsString:@"boolNumber=false"]);
    XCTAssertTrue([fieldStr containsString:@"array=\"[\\\"1\\\",\\\"2\\\"]\""]);
    XCTAssertTrue([fieldStr containsString:@"dict=\"{\\\"key1\\\":\\\"value1\\\"}\""]);

    
}
- (void)transliteration:(NSString *)str expect:(NSString *)expect{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.autoSync = NO;
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

//    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    FTRecordModel *model = [FTModelHelper createLogModel:str];
    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] requestNumber:@"1"];
    NSArray *array = [lineStr componentsSeparatedByString:@" "];
    if(array.count == 3){
        NSString *message = [NSString stringWithFormat:@"message=\"%@\"",expect];
        XCTAssertTrue([array[1] isEqualToString:message]);
    }
//    FTRequest *request = [FTRequest createRequestWithEvents:@[model] type:FT_DATA_TYPE_LOGGING];
//    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
//        if(!error){
//        NSInteger statusCode = httpResponse.statusCode;
//        BOOL success = (statusCode >=200 && statusCode < 500);
//        XCTAssertTrue(success);
//        }
//        [expectation fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:32 handler:^(NSError *error) {
//    }];
}

- (BOOL)isNum:(NSString *)checkedNumString {
    checkedNumString = [checkedNumString stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]];
    if(checkedNumString.length > 0) {
        return NO;
    }
    return YES;
}
@end
