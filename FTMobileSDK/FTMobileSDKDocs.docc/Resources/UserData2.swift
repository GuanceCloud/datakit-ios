//
//  UserData.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileSDK


func userLogin(userId:String,userName:String?,userEmail:String?){
    //方法一：
    FTMobileAgent.sharedInstance().bindUser(withUserID: userId);
    
    //方法二：
    FTMobileAgent.sharedInstance().bindUser(withUserID: userId, userName: userName, userEmail: userEmail);
    
    //方法三：
    FTMobileAgent.sharedInstance().bindUser(withUserID: userId, userName: userName, userEmail: userEmail, extra: ["Custom_User_key":"value"]);
    
}

/// 用户登出
func userLogout(){
    FTMobileAgent.sharedInstance().logout()
}
