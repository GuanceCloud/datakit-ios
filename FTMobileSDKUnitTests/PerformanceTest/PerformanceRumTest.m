//
//  PerformanceRumTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PerformanceBase.h"
#import "FTMobileAgent.h"
#import "FTRUMManager.h"
#import "FTGlobalRumManager.h"
@interface PerformanceRumTest : PerformanceBase

@end

@implementation PerformanceRumTest


- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAddActionEventPerformance{
    // This is an example of a performance test case.
    [[FTExternalDataManager sharedManager] startViewWithName:@"testAddAction"];
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] addActionName:@"[testAddAction]" actionType:@"click"];
    }];
}
- (void)testAddActionEventWithPropertyPerformance{
    [[FTExternalDataManager sharedManager] startViewWithName:@"testAddAction"];

    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] addActionName:@"[testAddAction]" actionType:@"click" property:@{@"action_property":@"test"}];
    }];
}
- (void)testAddErrorEventPerformance{
    [[FTExternalDataManager sharedManager] startViewWithName:@"testAddError"];
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] addErrorWithType:@"custom" message:@"errorMessage" stack:@"errorStack"];
    }];
}
@end
