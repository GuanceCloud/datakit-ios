//
//  DemoViewController.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileAgent


func simulationView(){
    
    FTExtensionManager.shared().onCreateView("ViewA", loadTime: NSNumber.init(long: 123456))

    FTExtensionManager.shared().startView(withName: "ViewA")
    
    FTExtensionManager.shared().stopView()
    
}
