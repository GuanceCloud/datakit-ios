//
//  FTDictionaryCopyTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/5/21.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSDictionary+FTCopyProperties.h"
#import "FTJSONUtil.h"

@interface FTDictionaryCopyTest : XCTestCase

@end

@implementation FTDictionaryCopyTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDictionaryCopy_stringValue{
    NSDictionary *dict = @{@"key_1":@"value_1",
                           @"key_2":@"value_2",
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 2);
    XCTAssertTrue([copyDict[@"key_1"] isEqualToString:@"value_1"]);
    XCTAssertTrue([copyDict[@"key_2"] isEqualToString:@"value_2"]);
}
- (void)testDictionaryCopy_NSCFStringValue{
    NSString *str = [NSString stringWithFormat:@"1234567890"];
    NSDictionary *dict = @{@"key_1":@"value_1",
                           @"key_2":str,
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 2);
    XCTAssertTrue([copyDict[@"key_1"] isEqualToString:@"value_1"]);
    XCTAssertTrue([copyDict[@"key_2"] isEqualToString:@"1234567890"]);
    XCTAssertTrue(copyDict[@"key_2"] == str);
}

- (void)testDictionaryCopy_arrayValue{
    NSArray *array = @[@1,@2,@3];
    NSDictionary *dict = @{@"key_1":array,
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    XCTAssertTrue([copyDict[@"key_1"] isKindOfClass:NSArray.class]);
    XCTAssertTrue([copyDict[@"key_1"] isEqualToArray:array]);
}
- (void)testDictionaryCopy_dictValue{
    NSDictionary *dictValue = @{@"value_key":@"value"};
    NSDictionary *dict = @{@"key_1":dictValue,
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    XCTAssertTrue([copyDict[@"key_1"] isKindOfClass:NSDictionary.class]);
    XCTAssertTrue([copyDict[@"key_1"] isEqualToDictionary:dictValue]);
}
- (void)testDictionaryCopy_NSSetValue{
    NSSet *setValue = [NSSet setWithArray:@[@1,@2,@3]];
    NSDictionary *dict = @{@"key_1":setValue,
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    XCTAssertTrue([copyDict[@"key_1"] isKindOfClass:NSArray.class]);
}
- (void)testDictionaryCopyProperties_mutableValue{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{@"key_1":@"value_1",
                                                                                @"key_2":@"value_2"}];
    NSDictionary *copyDict = [dict ft_deepCopy];
    [dict setValue:@"key_3" forKey:@"value_3"];
    [dict setValue:@"value_4" forKey:@"key_1"];
    
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 2);
    XCTAssertTrue([copyDict[@"key_1"] isEqualToString:@"value_1"]);
    XCTAssertTrue(dict.allKeys.count == 3);
}

- (void)testDictionaryCopyProperties_NSDate{
    NSDate *date = [NSDate date];
    NSDictionary *dict = @{@"date":date};
    NSDictionary *copyDict = [dict ft_deepCopy];
    
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    XCTAssertTrue([copyDict[@"date"] isEqualToString:[date description]]);
}

- (void)testDictionaryCopyProperties_Object{
    NSDictionary *dict = @{@"object":self};
    NSDictionary *copyDict = [dict ft_deepCopy];
    
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    XCTAssertTrue([copyDict[@"object"] isEqualToString:[self description]]);
}

- (void)testDictionaryCopyProperties_NaN_Infinity_Number{
    NSDictionary *dict = @{@"NaN":NSDecimalNumber.notANumber,
                           @"Infinity":@(INFINITY),
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 0);
}
- (void)testDictionaryCopyProperties_ArrayValue_Null{
    NSDate *date = [NSDate date];
    NSDictionary *dict = @{@"array":@[[NSNull null],date,NSDecimalNumber.notANumber,@(INFINITY),self]};
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    NSArray *array = copyDict[@"array"];
    XCTAssertTrue(array.count == 3);
    XCTAssertTrue([array containsObject:[[NSNull null] description]]);
    XCTAssertTrue([array containsObject:[date description]]);
    XCTAssertTrue([array containsObject:[self description]]);
}
- (void)testDictionaryCopyProperties_DictValue_Null{
    NSDate *date = [NSDate date];
    NSDictionary *dict = @{@"dictValue":@{@"date":date,
                                     @"null":[NSNull null],
                                     @"object":self,
                                     @"NAN":NSDecimalNumber.notANumber,
                                     @"INFINITY":@(INFINITY)
    }};
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue(copyDict.allKeys.count == 1);
    NSDictionary *dictValue = copyDict[@"dictValue"];
    XCTAssertTrue(dictValue.count == 3);
    XCTAssertTrue([dictValue[@"null"] isEqualToString:[[NSNull null] description]]);
    XCTAssertTrue([dictValue[@"date"] isEqualToString:[date description]]);
    XCTAssertTrue([dictValue[@"object"] isEqualToString:[self description]]);
}
- (void)testDictionaryCopyProperties_Number{
    float a = 1.00005;
    double b = 1.00000000005;

    NSDictionary *dict = @{@"test_float":@(a),
                           @"test_double":@(b),
                           @"test_bool":@(YES),
                           @"test_int":@(2),
    };
    NSDictionary *copyDict = [dict ft_deepCopy];
    XCTAssertFalse(copyDict == dict);
    XCTAssertTrue([copyDict[@"test_float"] isKindOfClass:NSString.class]);
    XCTAssertTrue([copyDict[@"test_float"] isEqualToString:@"1.00005"]);
    XCTAssertTrue([copyDict[@"test_double"] isKindOfClass:NSString.class]);
    XCTAssertTrue([copyDict[@"test_double"] isEqualToString:@"1.00000000005"]);
    XCTAssertTrue([copyDict[@"test_bool"] isKindOfClass:NSNumber.class]);
    XCTAssertTrue([copyDict[@"test_int"] isKindOfClass:NSNumber.class]);
    XCTAssertTrue([copyDict[@"test_bool"] isEqualToNumber:@(YES)]);
    XCTAssertTrue([copyDict[@"test_int"] isEqualToNumber:@(2)]);
}
@end
