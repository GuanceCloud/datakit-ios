//
//  RUMViewController.swift
//  SwiftApp
//
//  Created by hulilei on 2023/2/27.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

import UIKit
import FTMobileAgent
struct RUMResource {
    var key:String
    var data:Data?
    var metrics:URLSessionTaskMetrics?
    init(key: String) {
        self.key = key
    }
}
class RUMViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,URLSessionDataDelegate,URLSessionTaskDelegate {
    var dataSource:Array<String> = []
    var taskDict:[URLSessionTask:RUMResource] = [:]
    
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
        self.navigationItem.title = "Custom RUM"
        self.view.backgroundColor = .white
        createUI()
    }
    func createUI(){
        dataSource = ["onCreateView","startView","stopView","addAction","addError","addLongTask","resourse"]
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
            FTExternalDataManager.shared().onCreateView("CustomRUM", loadTime: 0)
        case 1:
            FTExternalDataManager.shared().startView(withName: "CustomRUM", property: ["startView_property" : "test"])
        case 2:
            FTExternalDataManager.shared().stopView()
        case 3:
            FTExternalDataManager.shared().addActionName("custom_action", actionType: "click")
        case 4:
            FTExternalDataManager.shared().addError(withType: "custom_type", message: "custom_message", stack: "custom_stack")
        case 5:
            FTExternalDataManager.shared().addLongTask(withStack: "longtask_stack", duration: 1000000000)
        case 6:
            customResource()
        default:
            print("default")
        }
    }
    
    func customResource (){
        // 完整的数据采集过程
        let key = UUID().uuidString
        FTExternalDataManager.shared().startResource(withKey: key)
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        let dic = ProcessInfo().environment
        if let urlStr = dic["TRACE_URL"] {
            if let url = URL(string: urlStr) {
                let request = URLRequest(url: url)
                let task = session.dataTask(with: request)
                taskDict[task] = RUMResource(key: key)
                task.resume()
            }
        }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        taskDict[dataTask]?.data = data
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        taskDict[task]?.metrics = metrics
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let resource = taskDict[task] {
            FTExternalDataManager.shared().stopResource(withKey: resource.key)
            var metricsModel:FTResourceMetricsModel?
            if let metrics = resource.metrics {
                metricsModel = FTResourceMetricsModel(taskMetrics:metrics)
            }
            let contentModel = FTResourceContentModel(request: task.currentRequest!, response: task.response as? HTTPURLResponse, data: resource.data, error: error)
            FTExternalDataManager.shared().addResource(withKey: resource.key, metrics: metricsModel, content: contentModel)
        }
        taskDict.removeValue(forKey: task)
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
