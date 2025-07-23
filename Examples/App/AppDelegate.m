//
//  AppDelegate.m
//  FTMobileAgent
//
//  Created by hulilei on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//

#import "AppDelegate.h"
#import <FTMobileSDK/FTMobileAgent.h>
#import "DemoViewController.h"
#import "RootTabbarVC.h"
#import "FTMobileSDK/FTLog.h"
#import <FTMobileSDK/FTRumSessionReplay.h>
//Target -> Build Settings -> GCC_PREPROCESSOR_DEFINITIONS 进行配置预设定义
#if PREPROD
#define STATIC_TAG     @"preprod"
#else
#define STATIC_TAG     @"formal"
#endif
@interface AppDelegate ()

@end

@implementation AppDelegate
@synthesize window = _window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Override point for customization after application launch.
    /**
     Test SDK config
     APP_ID  = @"Your AppId";
     ACCESS_SERVER_URL  = @"Your App metricsUrl";
     
     When running unit tests, add in FTMobileSDKUnitTests scheme:
     isUnitTests = 1;
     To prevent SDK startup in AppDelegate from affecting unit tests
     
     When running UI tests, add in FTMobileSDKUnitTests scheme:
     isUITests = 1;
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
//    NSString *datakitUrl = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *datawayUrl = [processInfo environment][@"ACCESS_DATAWAY_URL"];
    NSString *clientToken = [processInfo environment][@"CLIENT_TOKEN"];
    NSString *rumAppid = [processInfo environment][@"APP_ID"];
    NSString *trackid = [processInfo environment][@"TRACK_ID"]?:@"N/A";
    BOOL isUnitTests = [[processInfo environment][@"isUnitTests"] boolValue];
    BOOL isUITests = [[processInfo environment][@"isUITests"] boolValue];
    if ( !isUnitTests && !isUITests) {
        [[FTLog sharedInstance] registerInnerLogCacheToLogsDirectory:nil fileNamePrefix:nil];
        // Local environment deployment
      //  FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:datakitUrl];
        // Use public network DataWay deployment
//        FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatawayUrl:datawayUrl clientToken:clientToken];
        config.enableSDKDebugLog = YES;
        config.autoSync = YES;
        [config setEnvWithType:FTEnvPre];
        config.globalContext = @{@"example_id":@"example_id_1"};//eg.
        config.groupIdentifiers = @[@"group.com.ft.widget.demo"];
        // Enable rum
        FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:rumAppid];
        rumConfig.enableTrackAppCrash = YES;
        rumConfig.enableTrackAppANR = YES;
        rumConfig.enableTrackAppFreeze = YES;
        rumConfig.enableTraceUserAction = YES;
        rumConfig.enableTraceUserView = YES;
        rumConfig.enableTraceUserResource = YES;
//        rumConfig.resourceUrlHandler = ^(NSURL *url){
//            return NO;
//        };
        rumConfig.errorMonitorType = FTErrorMonitorAll;
        rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
        rumConfig.monitorFrequency = FTMonitorFrequencyRare;
        rumConfig.globalContext = @{@"track_id":trackid};//eg.
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        loggerConfig.enableLinkRumData = YES;
        loggerConfig.printCustomLogToConsole = YES;
        loggerConfig.logLevelFilter = @[@(FTStatusError),@(FTStatusCritical)];
        loggerConfig.discardType = FTDiscardOldest;
        loggerConfig.globalContext = @{@"log_id":@"log_id_1"};//eg.
        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.enableLinkRumData = YES;
        traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
        traceConfig.enableAutoTrace = YES;
        [FTMobileAgent startWithConfigOptions:config];
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
        [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];

        FTSessionReplayConfig *srConfig = [[FTSessionReplayConfig alloc]init];
        srConfig.textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskSensitiveInputs;
        srConfig.touchPrivacy = FTTouchPrivacyLevelShow;
        srConfig.sampleRate = 100;

        [[FTRumSessionReplay sharedInstance] startWithSessionReplayConfig:srConfig];

    }
    // UI test
   
    if (@available(iOS 13.0, *)) {
        //iOS 13+
    } else {
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        UITabBarController *tab = [[UITabBarController alloc]init];
        DemoViewController *rootVC = [[DemoViewController alloc] init];
        rootVC.title = @"home";
        
        UINavigationController *rootNav = [[UINavigationController alloc] initWithRootViewController:rootVC];
        RootTabbarVC *second =  [RootTabbarVC new];
        second.title = @"second";
        tab.viewControllers = @[rootNav,second];
        
        self.window.rootViewController = tab;
        [self.window makeKeyAndVisible];
    }
    return YES;
}


#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options  API_AVAILABLE(ios(13.0)){
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions  API_AVAILABLE(ios(13.0)){
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

@end
