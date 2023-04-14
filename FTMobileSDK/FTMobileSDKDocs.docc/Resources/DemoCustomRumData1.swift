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
}
