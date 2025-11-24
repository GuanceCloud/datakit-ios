//
//  XCTestCase+Utils.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/7.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//
#import <XCTest/XCTest.h>
#import "XCTestCase+Utils.h"

@implementation XCTestCase (Utils)
- (void)waitForTimeInterval:(NSTimeInterval)interval{
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"expectation"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:interval+1];
}
@end
