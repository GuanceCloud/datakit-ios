//
//  WidgetNetwork.swift
//  App
//
//  Created by hulilei on 2022/9/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

import Foundation
import FTMobileExtension
class InheritHttpEngine:FTURLSessionDelegate {

    var session:URLSession?
    /// HttpEngine initialization, fails when apiHostUrl is empty or token is ""
    override init(){
        session = nil
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = URLSession.init(configuration: configuration, delegate:self, delegateQueue: nil)
    }
 
    func network(completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void){
        let processInfo = ProcessInfo.processInfo
        let urlStr = processInfo.environment["TRACE_URL"] ?? "https://www.baidu.com"
        let url:URL = URL.init(string: urlStr)!
        let request = URLRequest.init(url: url)
        let task = self.session!.dataTask(with: request) { data,  res,  error in
            completionHandler(data,res,error);
        }
        task.resume()
    }
}

class HttpEngine:NSObject,URLSessionDataDelegate,FTURLSessionDelegateProviding {
    var ftURLSessionDelegate: FTURLSessionDelegate = FTURLSessionDelegate()
    
    var session:URLSession?
    /// HttpEngine initialization, fails when apiHostUrl is empty or token is ""
    override init(){
        session = nil
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = URLSession.init(configuration: configuration, delegate:self, delegateQueue: nil)
    }
    
    func network(completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void){
        let processInfo = ProcessInfo.processInfo
        let urlStr = processInfo.environment["TRACE_URL"] ?? "https://www.baidu.com"
        let url:URL = URL.init(string: urlStr)!
        let request = URLRequest.init(url: url)
        let task = self.session!.dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        ftURLSessionDelegate.urlSession(session, dataTask: dataTask, didReceive: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        ftURLSessionDelegate.urlSession(session, task: task, didFinishCollecting: metrics)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        ftURLSessionDelegate.urlSession(session, task: task, didCompleteWithError: error)
    }
}
