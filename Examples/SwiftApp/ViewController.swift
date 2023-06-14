//
//  ViewController.swift
//  SwiftApp
//
//  Created by hulilei on 2023/2/27.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

import UIKit
import FTMobileSDK
class ViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    
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
        self.navigationItem.title = "Home"
        self.view.backgroundColor = UIColor.white
        // Do any additional setup after loading the view.
        createUI()
    }
    
    func createUI(){
        dataSource = ["绑定用户","解绑用户","日志输出","手动采集网络链路追踪","手动采集RUM数据采集"]
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
        switch indexPath.row {
        case 0:
            FTMobileAgent.sharedInstance().bindUser(withUserID: "test_user_id_1", userName: "test_user", userEmail: "test@test.com", extra: ["user_age":20])
        case 1:
            FTMobileAgent.sharedInstance().logout()
        case 2:
            self.navigationController?.pushViewController(LogViewController.init(), animated: true)
        case 3:
            self.navigationController?.pushViewController(TraceViewController.init(), animated: true)
        case 4:
            self.navigationController?.pushViewController(RUMViewController.init(), animated: true)
        default:
            print("default")
        }
    }
}

