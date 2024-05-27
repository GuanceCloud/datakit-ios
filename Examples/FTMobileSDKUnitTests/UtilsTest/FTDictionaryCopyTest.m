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
- (void)testDictionaryCopy_setValue{
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
- (void)testDictionaryCopyProperties_multithreading{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    for (int i = 0; i<1000; i++) {
        [dict setValue:@(i) forKey:[NSString stringWithFormat:@"%d",i]];
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i<1000; i++) {
            [dict removeObjectForKey:[NSString stringWithFormat:@"%d",i]];
        }
    });
    XCTAssertNoThrow([dict ft_deepCopy]);
}
@end
