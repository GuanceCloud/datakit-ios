//
//  WidgetNetwork.swift
//  App
//
//  Created by hulilei on 2022/9/23.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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
import GuanceWidgetExtension
class InheritHttpEngine:FTURLSessionDelegate, @unchecked Sendable {

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
        let urlStr = "https://httpbin.org/status/200"
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
        let urlStr = "https://httpbin.org/status/200"
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
