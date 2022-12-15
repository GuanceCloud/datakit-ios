//
//  CustomLog.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileAgent

func funA(){
    
    FTMobileAgent.sharedInstance().logging("Custom_logging_content", status: .statusInfo)
}
