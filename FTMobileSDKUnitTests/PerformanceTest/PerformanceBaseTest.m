//
//  PerformanceBase.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//
#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTPresetProperty.h"
@interface PerformanceBaseTest : XCTestCase

@end

@implementation PerformanceBaseTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
        
}
- (void)testGetRumPropertyPerformance {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTPresetProperty  *presetProperty = [[FTPresetProperty alloc]initWithMobileConfig:config];
    [self measureBlock:^{
      [presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP];

    }];
}
- (void)testGetLoggerPropertyPerformance {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTPresetProperty  *presetProperty = [[FTPresetProperty alloc]initWithMobileConfig:config];
    [self measureBlock:^{
         [presetProperty loggerPropertyWithStatus:FTStatusInfo];
    }];
}
- (void)testSDKInitPerformance {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    [self measureBlock:^{
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
        config.enableSDKDebugLog = YES;
        [FTMobileAgent startWithConfigOptions:config];
    }];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

@end
