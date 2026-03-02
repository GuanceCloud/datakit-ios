//
//  SessionReplayUtilsTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/2/2.
//  Copyright © 2026 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTSRBaseFrame.h"

BOOL isNull(id value)
{
    if (!value) return YES;
    if ([value isKindOfClass:[NSNull class]]) return YES;

    return NO;
}
BOOL isNAN(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *num = (NSNumber *)value;
        return num.doubleValue != num.doubleValue;
    }
    
    if ([value isKindOfClass:[NSValue class]]) {
        const char *type = [value objCType];
        if (strcmp(type, @encode(double)) == 0) {
            return isnan([value doubleValue]);
        } else if (strcmp(type, @encode(float)) == 0) {
            return isnan([value floatValue]);
        }
    }
    return NO;
}

@interface FTTestSRFrame : FTSRBaseFrame
@property (nonatomic, copy) NSString *testName;
@property (nonatomic, strong,nullable) NSDictionary *property;

@end
@implementation FTTestSRFrame


@end
@interface SessionReplayUtil : XCTestCase

@end

@implementation SessionReplayUtil

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testFuncConflict{
    FTTestSRFrame *test = [[FTTestSRFrame alloc]init];
    test.testName = @"testFuncConflict";
    
    NSDictionary *dict = [test toDictionary];
    XCTAssertEqual(dict[@"testName"] , @"testFuncConflict");
    XCTAssertNil(dict[@"property"]);
}
@end
