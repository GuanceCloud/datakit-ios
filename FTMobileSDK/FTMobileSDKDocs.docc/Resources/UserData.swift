//
//  UserData.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileSDK


func userLogin(userId:String,userName:String?,userEmail:String?){
    //Method 1:
    FTMobileAgent.sharedInstance().bindUser(withUserID: userId);
    
    //Method 2:
    FTMobileAgent.sharedInstance().bindUser(withUserID: userId, userName: userName, userEmail: userEmail);
    
    //Method 3:
    FTMobileAgent.sharedInstance().bindUser(withUserID: userId, userName: userName, userEmail: userEmail, extra: ["Custom_User_key":"value"]);
    
}


