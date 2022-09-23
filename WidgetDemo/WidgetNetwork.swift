//
//  WidgetNetwork.swift
//  App
//
//  Created by hulilei on 2022/9/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

import Foundation

struct HttpEngine {

    let session:URLSession
    /// HttpEngine 初始化，当 apiHostUrl 为空 或 token 为"" 则初始化失败
    init(){
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession.init(configuration: configuration)
    }
    
    func network(completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void){
        let url:URL = URL.init(string: "http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions")!
        var request = URLRequest.init(url: url)
        let task = self.session.dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }
}
