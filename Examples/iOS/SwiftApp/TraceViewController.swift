//
//  TraceViewController.swift
//  SwiftApp
//
//  Created by hulilei on 2023/2/27.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

import UIKit
import GuanceSDK
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
        let traceStr = "https://httpbin.org/status/200"
        if let url = URL.init(string: traceStr) {
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
