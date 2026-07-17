//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import UIKit
import GuanceSDK
class NibViewController: UIViewController {
    
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "NibViewController"
        
        button.backgroundColor = .black
        
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(bindUserClick), for: .primaryActionTriggered)
    }
     
   @objc @IBAction func bindUserClick(_ sender: Any) {
        FTMobileAgent.sharedInstance().bindUser(withUserID: "test_user_id_1", userName: "test_user", userEmail: "test@test.com", extra: ["user_age":20])
    }
    
    @IBAction func unBindUserClick(_ sender: Any) {
        FTMobileAgent.sharedInstance().unbindUser()
    }
   
}
