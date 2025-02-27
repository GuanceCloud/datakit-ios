//
//  FTReadWriteHelperTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/1/19.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
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
#import "NSError+FTDescription.h"
#import "FTUserInfo.h"
#import "FTMonitorValue.h"
@interface FTTestObject : NSObject
@end
@implementation FTTestObject


@end
@interface FTReadWriteHelperTest : XCTestCase

@end

@implementation FTReadWriteHelperTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

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
- (void)testReadWriteHelperCurrentValue{
    NSMutableDictionary *dict = @{@"a":@"a",@"b":@"b",@"c":@"c"}.mutableCopy;
    FTReadWriteHelper *helper = [[FTReadWriteHelper alloc]initWithValue:dict];
    dispatch_group_t group = dispatch_group_create();
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_async(dispatch_queue_create(0, 0), ^{
        for (int i = 0; i<10000; i++) {
            [helper concurrentWrite:^(id  _Nonnull value) {
                [value addEntriesFromDictionary:@{[NSString stringWithFormat:@"%d",i]:@"val"}];
            }];
        }
    });
    dispatch_group_enter(group);
    dispatch_async(dispatch_queue_create(0, 0), ^{
        for (int j = 0; j<10000; j++) {
            NSMutableDictionary *newDict = [NSMutableDictionary new];
            [newDict addEntriesFromDictionary:helper.currentValue];
            if(j == 9999){
                dispatch_group_leave(group);
            }
        }
        
    });
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
}
- (void)testReadWriteHelperValueTypeCopy{
    FTTestObject *object = [[FTTestObject alloc]init];
    XCTAssertThrows([[FTReadWriteHelper alloc]initWithValue:object]);
}
- (void)testFTUserInfoCopy{
    FTUserInfo *info = [[FTUserInfo alloc]init];
    int a = arc4random_uniform(100)+1;
    NSString *name = [NSString stringWithFormat:@"test_%d",a];
    [info updateUser:[NSString stringWithFormat:@"%d",a] name:name email:@"test@123.com" extra:@{@"test_a":@"test_b"}];
    FTReadWriteHelper *helper = [[FTReadWriteHelper alloc]initWithValue:info];
    FTUserInfo *copyInfo = helper.currentValue;
    XCTAssertTrue(copyInfo != info);
    XCTAssertTrue([copyInfo.name isEqualToString: info.name]);
    XCTAssertTrue([copyInfo.userId isEqualToString: info.userId]);
    XCTAssertTrue([copyInfo.email isEqualToString: info.email]);
    XCTAssertTrue(copyInfo.isSignIn == info.isSignIn);
    XCTAssertTrue([copyInfo.extra[@"test_a"] isEqualToString:info.extra[@"test_a"]]);
}
- (void)testFTMonitorValueCopy{
    FTMonitorValue *value = [[FTMonitorValue alloc]init];
    [value addSample:1234];
    [value addSample:2345];
    FTReadWriteHelper *helper = [[FTReadWriteHelper alloc]initWithValue:value];
    FTMonitorValue *copy = helper.currentValue;
    XCTAssertTrue(copy != value);
    XCTAssertTrue(copy.sampleValueCount == value.sampleValueCount);
    XCTAssertTrue(copy.maxValue == value.maxValue);
    XCTAssertTrue(copy.minValue == value.minValue);
    XCTAssertTrue(copy.meanValue == value.meanValue);
    XCTAssertTrue(copy.greatestDiff == value.greatestDiff);

}
@end
