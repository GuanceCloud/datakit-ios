//
//  PerformanceLoggingTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PerformanceBase.h"
#import "FTMobileAgent.h"
@interface PerformanceLoggingTest : PerformanceBase

@end

@implementation PerformanceLoggingTest

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testCustomLoggingPerformance{
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [[FTMobileAgent sharedInstance] logging:@"testCustomLoggingPerformance" status:FTStatusOk];
    }];
}
- (void)testCustomLoggingWithPropertyPerformance{
   
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [[FTMobileAgent sharedInstance] logging:@"testCustomLoggingWithPropertyPerformance" status:FTStatusOk property:@{@"logging_property":@"test"}];
    }];
}
@end
