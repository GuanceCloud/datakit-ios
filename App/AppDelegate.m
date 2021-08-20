//
//  AppDelegate.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//

#import "AppDelegate.h"
#import <FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/FTMonitorManager.h>
#import <FTDateUtil.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "DemoViewController.h"
#import "RootTabbarVC.h"
@interface AppDelegate ()

@end

@implementation AppDelegate
@synthesize window = _window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Override point for customization after application launch.
    /**
     测试 SDK config
     APP_ID  = @"Your AppId";
     ACCESS_SERVER_URL  = @"Your App metricsUrl";
     
     进行单元测试时 在FTMobileSDKUnitTests 的 scheme 中添加
     isUnitTests = 1;
     防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     
     进行单UI试时 在FTMobileSDKUnitTests 的 scheme 中添加
     isUITests = 1;
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    BOOL isUnitTests = [[processInfo environment][@"isUnitTests"] boolValue];
    BOOL isUITests = [[processInfo environment][@"isUITests"] boolValue];
    if ( url && !isUnitTests && !isUITests) {
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
        config.enableSDKDebugLog = YES;
        FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
        rumConfig.appid = appid;
        rumConfig.enableTrackAppCrash = YES;
        rumConfig.enableTrackAppANR = YES;
        rumConfig.enableTrackAppFreeze = YES;
        rumConfig.enableTraceUserAction = YES;
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        loggerConfig.enableLinkRumData = YES;
        loggerConfig.traceConsoleLog = YES;
        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.enableLinkRumData = YES;
        traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
        [FTMobileAgent startWithConfigOptions:config];
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
        [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];

    }
    // UI 测试
    if(isUITests){
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
        config.enableSDKDebugLog = YES;
        FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
        rumConfig.appid = appid;
        rumConfig.enableTrackAppCrash = YES;
        rumConfig.enableTrackAppANR = YES;
        rumConfig.enableTrackAppFreeze = YES;
        rumConfig.enableTraceUserAction = YES;
        [FTMobileAgent startWithConfigOptions:config];
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    }
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options  API_AVAILABLE(ios(13.0)){
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    if (@available(iOS 13.0, *)) {
        return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
    } else {
        // Fallback on earlier versions
    }
    return nil;
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions  API_AVAILABLE(ios(13.0)){
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

@end
