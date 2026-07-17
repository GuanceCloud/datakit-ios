//
//  PerformanceRumTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent+Private.h"
#import "FTRUMManager.h"
#import "FTGlobalRumManager+Private.h"
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
        [[FTExternalDataManager sharedManager] startAction:@"[testAddAction]" actionType:@"click" property:nil];
    }];
}
- (void)testAddActionEventWithPropertyPerformance{
    [[FTExternalDataManager sharedManager] startViewWithName:@"testAddAction"];

    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] startAction:@"[testAddAction]" actionType:@"click" property:@{@"action_property":@"test"}];
    }];
}
- (void)testAddErrorEventPerformance{
    [[FTExternalDataManager sharedManager] startViewWithName:@"testAddError"];
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] addErrorWithType:@"custom" message:@"errorMessage" stack:@"errorStack"];
    }];
}
@end
