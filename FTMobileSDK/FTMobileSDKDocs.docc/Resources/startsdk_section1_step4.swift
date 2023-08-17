//
//  AppDelegate.swift
//  
//
//  Created by hulilei on 2022/10/25.
//

import Foundation
import FTMobileSDK

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let mobileConfig = FTMobileConfig.init(metricsUrl: "YOUR URL")
        mobileConfig.enableSDKDebugLog = true
        mobileConfig.env = .common
        mobileConfig.globalContext = ["CustomKey":"CustomValue"]
        return true
    }

}

