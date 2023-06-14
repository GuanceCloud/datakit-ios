//
//  DemoViewController.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileSDK

class CustomRumDemo{
    
    func simulationView(){
        
        FTExternalDataManager.shared().onCreateView("ViewA", loadTime: NSNumber.init(long: 123456))
        
        FTExternalDataManager.shared().startView(withName: "ViewA")
        
        FTExternalDataManager.shared().stopView()
        
    }
    
    func simulationAction(){
        FTExternalDataManager.shared().addActionName("Custom_action_name", actionType: "click")
        
        FTExternalDataManager.shared().addClickAction(withName: "Custom_action_name2")
    }

    func simulationError(){
        FTExternalDataManager.shared().addError(withType: "ios_crash", message: "Error_Message", stack: "Error_Stack")
    }
}



