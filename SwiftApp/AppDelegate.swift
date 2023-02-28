//
//  AppDelegate.swift
//  SwiftApp
//
//  Created by hulilei on 2023/2/27.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

import UIKit
import FTMobileAgent
@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let config = FTMobileConfig(metricsUrl: url!)
        config.enableSDKDebugLog = true
        FTMobileAgent.start(withConfigOptions: config)
        let rumConfig = FTRumConfig(appid: appid!)
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
        loggerConfig.enableConsoleLog = true
        FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
        FTMobileAgent.sharedInstance().startTrace(withConfigOptions: traceConfig)
        FTMobileAgent.sharedInstance().startLogger(withConfigOptions: loggerConfig)
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

