//
//  DemoViewController.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileSDK

class CustomRumDemo:URLSessionTaskDelegate,URLSessionDataDelegate{
    
    func simulationView(){
        
        FTExternalDataManager.shared().onCreateView("ViewA", loadTime: NSNumber.init(long: 123456))
        
        FTExternalDataManager.shared().startView(withName: "ViewA")
        
        FTExternalDataManager.shared().stopView()
        
    }
    
    func simulationAction(){
        FTExternalDataManager.shared().addActionName("Custom_action_name", actionType: "click")
        
        FTExternalDataManager.shared().addClickAction(withName: "Custom_action_name2")
    }

    func simulationError(){
        FTExternalDataManager.shared().addError(withType: "ios_crash", message: "Error_Message", stack: "Error_Stack")
    }
    
    func simulationLongTask(){
        FTExternalDataManager.shared().addLongTask(withStack: "Stack", duration: NSNumber.init(long: 1000000000))
    }
    
    var data:Data?
    var metrics:URLSessionTaskMetrics?
    var key = ""
    func simulationResource(){
        key = NSUUID().uuidString
        
        FTExternalDataManager.shared().startResource(withKey: key)
        
        let session = URLSession(configuration: URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil))
        let request = URLRequest.init(url: URL.init(string: "https://www.baidu.com"))
        let task = session.dataTask(with: request)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data = data
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        FTExternalDataManager.shared().stopResource(withKey: key)
        
        let contentModel:FTResourceContentModel = FTResourceContentModel()
        let metricsModel:FTResourceMetricsModel? = nil

        let httpResponse: URLResponse = task.response as URLResponse

        if let body = self.data {
            let bodyStr = String.init(data: data, encoding: UTF8)
            contentModel.responseBody = bodyStr
        }
        contentModel.requestHeader = task.originalRequest?.allHTTPHeaderFields
        contentModel.httpMethod = task.originalRequest?.httpMethod
        contentModel.requestHeader = task.originalRequest.allHTTPHeaderFields
        contentModel.responseHeader = httpResponse.allHeaderFields
        contentModel.httpStatusCode = httpResponse.statusCode
        contentModel.responseBody = responseBody
        contentModel.error = error
        
        if let metrics = self.metrics {
            metricsModel = FTResourceMetricsModel.init(taskMetrics: metrics)
        }
        FTExternalDataManager.shared().addResource(withKey: key, metrics: metricsModel, content: contentModel)
    }
}
