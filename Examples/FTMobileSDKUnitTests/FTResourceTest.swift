//
//  FTResourceTest.swift
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/1/6.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

import XCTest
import OHHTTPStubs
import KIF
final class FTResourceTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        FTTrackerEventDBTool.sharedManger()?.deleteAllDatas()
        sdkInit()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        FTMobileAgent.shutDown()
    }
    func sdkInit(){
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let config:FTMobileConfig = FTMobileConfig(datakitUrl: url!)
        config.enableSDKDebugLog = true
        config.autoSync = false
        FTMobileAgent.start(withConfigOptions: config)
        let traceConfig = FTTraceConfig()
        traceConfig.enableAutoTrace = true
        traceConfig.enableLinkRumData = true
        FTMobileAgent.sharedInstance().startTrace(withConfigOptions: traceConfig)
        
        let rumConfig = FTRumConfig(appid: appid!)
        rumConfig.enableTraceUserResource = true
        FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
    }
    func testAsyncAwaitURLSession() async throws {

        let dic = ProcessInfo().environment
        let urlStr = dic["TRACE_URL"] ?? "https://www.baidu.com/more/"
        let url = URL(string: urlStr)
        let count = FTTrackerEventDBTool.sharedManger()?.getDatasCount() ?? 0

        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        let request = URLRequest.init(url: url!)
        if #available(iOS 15.0, *) {
            let (_,_) = try await session.data(for: request)
            try await Task.sleep(nanoseconds: 500000000)
            FTGlobalRumManager.sharedInstance().rumManager.syncProcess()
            let newCount = FTTrackerEventDBTool.sharedManger()?.getDatasCount() ?? 0
            XCTAssertTrue(newCount > count)
            let datas = FTTrackerEventDBTool.sharedManger()?.getAllDatas() ?? []
            var hasResource = false
            datas.forEach { model in
                let model = model as! FTRecordModel
                let dict = FTJSONUtil.dictionary(withJsonString: model.data)!
                let opdata = dict["opdata"] as! Dictionary<String, Any>
                let source = opdata["source"] as! String
                let tags = opdata[FT_TAGS] as! Dictionary<String, Any>
                let fields = opdata[FT_FIELDS] as! Dictionary<String, Any>
                if (source == FT_RUM_SOURCE_RESOURCE) {
                    hasResource = true
                    let resource_url_host = tags["resource_url_host"] as! String
                    let request_header = fields["request_header"] as! String
                    if #available(iOS 16.0, *) {
                        XCTAssertTrue(resource_url_host == url?.host())
                    }
                    // 链路添加成功
                    XCTAssertTrue(request_header.components(separatedBy: "datadog").count>1)
                }
            }
            // RUM Resource 采集成功
            XCTAssertTrue(hasResource)
        }
       
    }

}
