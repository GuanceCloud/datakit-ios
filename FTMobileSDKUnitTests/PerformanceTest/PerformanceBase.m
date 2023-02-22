//
//  PerformanceBase.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import "PerformanceBase.h"
#import "FTMobileAgent.h"

@interface PerformanceBase()

@end
static BOOL isFirstInitialize = YES;
@implementation PerformanceBase

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    if(isFirstInitialize){
        isFirstInitialize = NO;
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        NSString *appid = [processInfo environment][@"APP_ID"];
        NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
        [FTMobileAgent startWithConfigOptions:config];
        FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
        [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

@end
