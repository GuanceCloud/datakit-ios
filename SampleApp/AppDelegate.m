//
//  AppDelegate.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//

#import "AppDelegate.h"
#import "UITestManger.h"
#import <FTMobileAgent/FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/FTMonitorManager.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Override point for customization after application launch.
    /**
      测试时 请在scheme 中配置  Environment Variables 键值
      测试 DataFlux账号
      FTTestAccount  = @"Your Test Account";
      FTTestPassword  = @"Your Test Password";

      测试 SDK config
      ACCESS_KEY_ID  = @"Your App akId";
      ACCESS_KEY_SECRET  = @"Your App akSecret";
      ACCESS_SERVER_URL  = @"Your App metricsUrl";
     
      进行单元测试时 在FTMobileSDKUnitTests 的 scheme 中添加
      isUnitTests = 1;
      防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];

    BOOL isUnitTests = [[processInfo environment][@"isUnitTests"] boolValue];

    if (akId && akSecret && url && !isUnitTests) {
        FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
        config.enableLog = YES;
        config.enableDescLog = YES;
        config.enableAutoTrack = YES;
        config.enabledPageVtpDesc = YES;
        config.monitorInfoType = FTMonitorInfoTypeAll;
        config.traceConsoleLog = YES;
        config.networkTrace = YES;
        config.enableTrackAppCrash = YES;
        config.eventFlowLog = YES;
        config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppLaunch|FTAutoTrackEventTypeAppViewScreen;
        [FTMobileAgent startWithConfigOptions:config];
        self.config = config;
        [UITestManger sharedManger];
        [[FTMobileAgent sharedInstance] logout];
        [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    }
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