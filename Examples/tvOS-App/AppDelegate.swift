//
//  AppDelegate.swift
//  tvOS-App
//
//  Created by hulilei on 2024/12/16.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

import UIKit
import FTMobileSDK
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let isUnitTests = dic["isUnitTests"];
        if let isUnitTests = isUnitTests {
            return true
        }
        FTLog.sharedInstance().registerInnerLogCacheToDefaultPath()
        if let url = url,let appid = appid{
            let config = FTMobileConfig(datakitUrl: url)
            config.enableSDKDebugLog = true
            FTMobileAgent.start(withConfigOptions: config)
            let rumConfig = FTRumConfig(appid: appid)
            rumConfig.enableTraceUserAction = true
            rumConfig.enableTrackAppANR = true
            rumConfig.enableTraceUserView = true
            rumConfig.enableTraceUserResource = true
            rumConfig.enableTrackAppCrash = true
            rumConfig.enableTrackAppFreeze = true
            rumConfig.deviceMetricsMonitorType = .all
            let traceConfig = FTTraceConfig.init()
            traceConfig.enableLinkRumData = true
            traceConfig.enableAutoTrace = true
            let loggerConfig = FTLoggerConfig()
            loggerConfig.enableCustomLog = true
            loggerConfig.enableLinkRumData = true
            loggerConfig.printCustomLogToConsole = true
            FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
            FTMobileAgent.sharedInstance().startTrace(withConfigOptions: traceConfig)
            FTMobileAgent.sharedInstance().startLogger(withConfigOptions: loggerConfig)
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


}

