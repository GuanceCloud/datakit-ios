import Foundation
import UIKit
import FTMobileSDK
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
