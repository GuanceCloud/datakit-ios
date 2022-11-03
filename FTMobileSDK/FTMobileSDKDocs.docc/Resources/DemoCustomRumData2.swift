//
//  DemoViewController.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileAgent


class CustomRumDemo{
    
    func simulationView(){
        
        FTExtensionManager.shared().onCreateView("ViewA", loadTime: NSNumber.init(long: 123456))
        
        FTExtensionManager.shared().startView(withName: "ViewA")
        
        FTExtensionManager.shared().stopView()
        
    }
    
    func simulationAction(){
        FTExtensionManager.shared().addActionName("Custom_action_name", actionType: "click")
        
        FTExtensionManager.shared().addClickAction(withName: "Custom_action_name2")
    }

}



