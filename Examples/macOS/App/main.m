//
//  main.m
//  Example
//
//  Created by hulilei on 2021/8/31.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import <Cocoa/Cocoa.h>
#import "GuanceSDKExampleImports.h"
// Configure preprocessor definitions in Target -> Build Settings -> GCC_PREPROCESSOR_DEFINITIONS
#if PRE
#define Track_id       @"0000000001"
#define STATIC_TAG     @"preprod"
#elif  DEVELOP
#define Track_id       @"0000000002"
#define STATIC_TAG     @"common"
#else
#define Track_id       @"0000000003"
#define STATIC_TAG     @"prod"
#endif
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
        NSString *appid = [processInfo environment][@"APP_ID"];
        BOOL isRuningUnitTest = [[processInfo environment][@"isUnitTests"] boolValue];
        if(!isRuningUnitTest){
            FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:url];
            config.enableSDKDebugLog = YES;
            [FTMobileAgent startWithConfigOptions:config];
            FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
            rumConfig.enableTrackAppANR = YES;
            rumConfig.enableTrackAppCrash = YES;
            rumConfig.enableTrackAppFreeze = YES;
            rumConfig.enableTraceUserView = YES;
            rumConfig.enableTraceUserAction = YES;
            rumConfig.enableTraceUserResource = YES;
            rumConfig.errorMonitorType = FTErrorMonitorAll;
            rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
            rumConfig.globalContext = @{@"track_id":Track_id,@"static_tag":STATIC_TAG};
            [[FTMobileAgent sharedInstance]startRumWithConfigOptions:rumConfig];
            FTLoggerConfig *logger = [[FTLoggerConfig alloc]init];
            logger.enableCustomLog = YES;
            logger.enableLinkRumData = YES;
            logger.printCustomLogToConsole = YES;
            [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:logger];
            FTTraceConfig *trace = [[FTTraceConfig alloc]init];
            trace.enableAutoTrace = YES;
            trace.enableLinkRumData = YES;
            [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:trace];
            [[FTMobileAgent sharedInstance] logging:@"main" status:FTStatusInfo];
        }
    }
    return NSApplicationMain(argc, argv);
}
