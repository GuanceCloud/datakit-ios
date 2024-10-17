//
//  PerformanceLoggingTest.m
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
@interface PerformanceLoggingTest : XCTestCase

@end

@implementation PerformanceLoggingTest

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [FTMobileAgent clearAllData];
}
- (void)initSDK:(BOOL)enableLinkRumData{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    [FTMobileAgent startWithConfigOptions:config];
    FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
    logger.enableCustomLog = YES;
    logger.enableLinkRumData = enableLinkRumData;
    if(enableLinkRumData){
        FTRumConfig *rum = [[FTRumConfig alloc]initWithAppid:appid];
        rum.enableTraceUserView = YES;
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
    }
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
}
- (void)testCustomLoggingPerformance{
    // This is an example of a performance test case.
    [self initSDK:NO];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [[FTMobileAgent sharedInstance] logging:@"testCustomLoggingPerformance" status:FTStatusOk];
    }];
}
- (void)testCustomLoggingWithPropertyPerformance{
    [self initSDK:NO];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [[FTMobileAgent sharedInstance] logging:@"testCustomLoggingWithPropertyPerformance" status:FTStatusOk property:@{@"logging_property":@"test"}];
    }];
}
- (void)testCustomLoggingLinkRumPerformance{
    [self initSDK:YES];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [[FTMobileAgent sharedInstance] logging:@"testCustomLoggingLinkRumPerformance" status:FTStatusOk];
    }];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
}
@end
