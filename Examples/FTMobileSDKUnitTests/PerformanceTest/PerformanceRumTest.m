//
//  PerformanceRumTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent+Private.h"
#import "FTRUMManager.h"
#import "FTGlobalRumManager.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
@interface PerformanceRumTest : XCTestCase

@end

@implementation PerformanceRumTest

-(void)setUp{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
//    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:appid];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [FTMobileAgent shutDown];
    [FTMobileAgent clearAllData];
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
