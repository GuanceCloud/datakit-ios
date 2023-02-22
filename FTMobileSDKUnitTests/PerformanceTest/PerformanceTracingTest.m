//
//  PerformanceTracingTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PerformanceBase.h"
#import "FTMobileAgent.h"

@interface PerformanceTracingTest : PerformanceBase

@end

@implementation PerformanceTracingTest


- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}

@end
