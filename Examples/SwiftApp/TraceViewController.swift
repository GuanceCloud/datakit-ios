//
//  TraceViewController.swift
//  SwiftApp
//
//  Created by hulilei on 2023/2/27.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

import UIKit
import FTMobileSDK
class TraceViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
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
        self.navigationItem.title = "Custom Trace"
        createUI()
    }
    func createUI() {
        dataSource = ["Manual Network Link Tracing"]
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
        let dic = ProcessInfo().environment
        let traceStr = dic["TRACE_URL"]
        if let traceStr = traceStr,let url = URL.init(string: traceStr) {
            if let traceHeader = FTExternalDataManager.shared().getTraceHeader(withKey: NSUUID().uuidString, url: url) {
                let request = NSMutableURLRequest(url: url)
                for (a,b) in traceHeader {
                    request.setValue(b as? String, forHTTPHeaderField: a as! String)
                }
                let task = URLSession.shared.dataTask(with: request as URLRequest) {  data,  response,  error in
                    if let httpResponse = response as? HTTPURLResponse {
                        print("response statusCode:\(httpResponse.statusCode)")
                    }
                }
                task.resume()
            }
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
