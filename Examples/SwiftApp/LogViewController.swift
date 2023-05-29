//
//  LogViewController.swift
//  SwiftApp
//
//  Created by hulilei on 2023/2/27.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

import UIKit
import FTMobileSDK
class LogViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    var dataSource:Array<String> = []
    
    lazy var tableView:UITableView = {
        let tab = UITableView.init(frame: self.view.bounds)
        tab.delegate = self
        tab.dataSource = self
        tab.rowHeight = 45
        tab.register(UITableViewCell.self, forCellReuseIdentifier: "tableView")
        return tab
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Logger"
        self.view.backgroundColor = .white
        createUI()
    }
    func createUI(){
        dataSource = ["logging with status: info","logging with status: warning","logging with status: error","logging with status: critical","logging with status: ok"]
        self.view.addSubview(tableView)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tableView")
        cell?.textLabel?.text = dataSource[indexPath.row] 
        return cell!
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let logger = FTLogger.sharedInstance()
        switch indexPath.row {
        case 0:
            logger.info("logging : info", property: ["test_logging":"test"])
        case 1:
            FTMobileAgent.sharedInstance().logging("logging : warning", status: .statusWarning)
        case 2:
            FTLogError("logging : error")
        case 3:
            FTLogCriticalProperty("logging : critical",property: ["key_logging":"test"])
        case 4:
            FTLogOk("logging : ok")
        default:
            print("default")
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
