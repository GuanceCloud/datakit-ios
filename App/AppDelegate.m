//
//  AppDelegate.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//

#import "AppDelegate.h"
#import "FTTrackerEventDBTool.h"
#import "FTBaseInfoHandler.h"
#import "FTDateUtil.h"
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "DemoViewController.h"
#import "RootTabbarVC.h"
#import "FTTrackDataManger.h"
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
    NSString *trackid = [processInfo environment][@"TRACK_ID"]?:@"NULL_VALUE";
    BOOL isUnitTests = [[processInfo environment][@"isUnitTests"] boolValue];
    BOOL isUITests = [[processInfo environment][@"isUITests"] boolValue];
    if ( url && !isUnitTests && !isUITests) {
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
        config.enableSDKDebugLog = YES;
        config.globalContext = @{@"example_id":@"example_id_1"};//eg.
        config.groupIdentifiers = @[@"group.com.ft.widget.demo"];
        NSString *dynamicTag = [[NSUserDefaults standardUserDefaults] valueForKey:@"DYNAMIC_TAG"]?:@"NULL_VALUE";
        //开启 rum
        FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
        rumConfig.appid = appid;
        rumConfig.enableTrackAppCrash = YES;
        rumConfig.enableTrackAppANR = YES;
        rumConfig.enableTrackAppFreeze = YES;
        rumConfig.enableTraceUserAction = YES;
        rumConfig.enableTraceUserView = YES;
        rumConfig.enableTraceUserResource = NO;
        rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
        rumConfig.globalContext = @{@"track_id":trackid,
                                    @"static_tag":STATIC_TAG,
                                    @"dynamic_tag":dynamicTag};//eg.
        FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
        loggerConfig.enableCustomLog = YES;
        loggerConfig.enableLinkRumData = YES;
        loggerConfig.enableConsoleLog = YES;
        loggerConfig.globalContext = @{@"log_id":@"log_id_1"};//eg.
        FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
        traceConfig.enableLinkRumData = YES;
        traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
        traceConfig.enableAutoTrace = YES;
        [FTMobileAgent startWithConfigOptions:config];
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
        [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    }
    // UI 测试
    if(url && isUITests){
        //禁止上传逻辑
        [[FTTrackDataManger sharedInstance] setValue:@YES forKey:@"isUploading"];
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
        config.enableSDKDebugLog = YES;
        FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
        rumConfig.appid = appid;
        rumConfig.enableTrackAppCrash = YES;
        rumConfig.enableTrackAppANR = YES;
        rumConfig.enableTrackAppFreeze = YES;
        rumConfig.enableTraceUserAction = YES;
        rumConfig.enableTraceUserView = YES;
        rumConfig.enableTraceUserResource = YES;
        rumConfig.globalContext = @{@"track_id":trackid};//eg.
        [FTMobileAgent startWithConfigOptions:config];
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
        if([[processInfo environment] valueForKey:@"CLEAN_DATAS"]){
            [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
        }
    }
    if (@available(iOS 13.0, *)) {
        //iOS 13以上系统
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
