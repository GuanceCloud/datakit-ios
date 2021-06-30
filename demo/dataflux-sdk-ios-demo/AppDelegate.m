//
//  AppDelegate.m
//  dataflux-sdk-ios-demo
//
//  Created by 胡蕾蕾 on 2021/6/28.
//

#import "AppDelegate.h"
#import <FTMobileAgent.h>
#import <FTMobileConfig.h>
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    //运行demo的时候替换自己的 url 与 appid
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    
    //启动sdk
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    //开启 rum
    FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
    rumConfig.appid = appid;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.enableTrackAppANR = YES;
    rumConfig.enableTrackAppFreeze = YES;
    rumConfig.enableTraceUserAction = YES;
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    //开启 logger
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.traceConsoleLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    //开启 trace
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTrace = YES;
    traceConfig.enableLinkRumData = YES;
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
