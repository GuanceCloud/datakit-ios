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
#import "FTMobileAgentVersion.h"
@interface PerformanceBaseTest : XCTestCase

@end

@implementation PerformanceBaseTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
        
}
- (void)testGetRumPropertyPerformance {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    [[FTPresetProperty sharedInstance] startWithVersion:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] sdkVersion:SDK_VERSION env:config.env service:config.service globalContext:config.globalContext pkgInfo:nil];
    FTPresetProperty  *presetProperty = [FTPresetProperty sharedInstance];
                                         
    [self measureBlock:^{
      [presetProperty rumProperty];
    }];
}
- (void)testGetLoggerPropertyPerformance {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    [[FTPresetProperty sharedInstance] startWithVersion:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] sdkVersion:SDK_VERSION env:config.env service:config.service globalContext:config.globalContext pkgInfo:nil];
    FTPresetProperty  *presetProperty = [FTPresetProperty sharedInstance];
    [self measureBlock:^{
         [presetProperty loggerProperty];
    }];
}
- (void)testSDKInitPerformance {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    [self measureMetrics:[self class].defaultPerformanceMetrics automaticallyStartMeasuring:NO forBlock:^{
        [self startMeasuring];
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
        config.enableSDKDebugLog = YES;
        [FTMobileAgent startWithConfigOptions:config];
        FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
        rumConfig.appid = appid;
        rumConfig.enableTrackAppCrash = YES;
        rumConfig.enableTrackAppANR = YES;
        rumConfig.enableTrackAppFreeze = YES;
        rumConfig.enableTraceUserAction = YES;
        rumConfig.enableTraceUserView = YES;
        rumConfig.enableTraceUserResource = YES;
        rumConfig.errorMonitorType = FTErrorMonitorAll;
        rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        loggerConfig.enableLinkRumData = YES;
        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.enableLinkRumData = YES;
        traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
        traceConfig.enableAutoTrace = YES;
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
        [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
        [self stopMeasuring];
        [FTMobileAgent shutDown];
    }];
   
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

@end
