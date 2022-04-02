//
//  RumDataBuilderTest.m
//  AppTests
//
//  Created by hulilei on 2022/4/1.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>

@interface RumDataBuilderTest : KIFTestCase

@end

@implementation RumDataBuilderTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    NSString *url  = @"http://172.16.5.9:9529";
    NSString *appid = @"appid_0910323588ab45b28e4cbdc78aa7f8a4";
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[tester waitForViewWithAccessibilityLabel:@"NetworkTrace_clienthttp"] tap];
   
    [tester waitForTimeInterval:5];

    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];

    [tester waitForTimeInterval:2];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];
    [tester waitForTimeInterval:2];

    
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
