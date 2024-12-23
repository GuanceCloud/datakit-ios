//
//  FTTestInteraction.swift
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/26.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

import XCTest

final class FTTestInteraction: XCTestCase {
    var tracerManager:FTTracer?
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
    }
    // MARK: - SDK INIT
    func testSDKInit() throws {
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let config:FTMobileConfig = FTMobileConfig(datakitUrl: url!)
        config.service = "test_swift"
        config.enableSDKDebugLog = true
        config.globalContext = ["key":"value"]
        FTMobileAgent.start(withConfigOptions: config)
        XCTAssertNoThrow(FTMobileAgent.sharedInstance())
        
        
        let traceConfig = FTTraceConfig()
        traceConfig.networkTraceType = .dDtrace
        traceConfig.enableAutoTrace = true
        traceConfig.enableLinkRumData = true
        FTMobileAgent.sharedInstance().startTrace(withConfigOptions: traceConfig)
        let tracer = FTURLSessionInstrumentation.sharedInstance().value(forKey: "tracer")
        XCTAssertTrue(tracer != nil)
        
        let rumConfig = FTRumConfig(appid: appid!)
        rumConfig.enableTraceUserAction = true
        rumConfig.enableTrackAppANR = true
        rumConfig.enableTraceUserView = true
        rumConfig.enableTraceUserResource = true
        rumConfig.enableTrackAppCrash = true
        rumConfig.enableTrackAppFreeze = true
        rumConfig.deviceMetricsMonitorType = .all
        let oldManager = FTGlobalRumManager.sharedInstance().rumManager
        FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
        let manager = FTGlobalRumManager.sharedInstance().rumManager
        XCTAssertTrue(oldManager != manager)
        
        let logConfig = FTLoggerConfig()
        logConfig.enableCustomLog = true
        logConfig.enableLinkRumData = true
        logConfig.printCustomLogToConsole = true
        let oldLogger = FTLogger.shared()
        FTMobileAgent.sharedInstance().startLogger(withConfigOptions: logConfig)
        let logger = FTLogger.shared()
        XCTAssertTrue(oldLogger != logger)
        FTMobileAgent.sharedInstance().shutDown()
    }
    
    // MARK: - Trace - Get trace header
    
    func testCustomTraceHeaderGet_ddtrace() throws {
        traceSDKInit(traceType: .dDtrace)
    }
    func testCustomTraceHeaderGet_skyWalking() throws {
        traceSDKInit(traceType: .skywalking)
    }
    func testCustomTraceHeaderGet_zipkinMultiHeader() throws {
        traceSDKInit(traceType: .zipkinMultiHeader)
    }
    func testCustomTraceHeaderGet_zipkinSingleHeader() throws {
        traceSDKInit(traceType: .zipkinSingleHeader)
    }
    func testCustomTraceHeaderGet_traceparent() throws {
        traceSDKInit(traceType: .traceparent)
    }
    func testCustomTraceHeaderGet_ddtrace_nullTrace() throws {
        traceSDKInit(traceType: .dDtrace,enableTrace: false)
    }
    func testCustomTraceHeaderGet_skyWalking_nullTrace() throws {
        traceSDKInit(traceType: .skywalking,enableTrace: false)
    }
    func testCustomTraceHeaderGet_zipkinMultiHeader_nullTrace() throws {
        traceSDKInit(traceType: .zipkinMultiHeader,enableTrace: false)
    }
    func testCustomTraceHeaderGet_zipkinSingleHeader_nullTrace() throws {
        traceSDKInit(traceType: .zipkinSingleHeader,enableTrace: false)
    }
    func testCustomTraceHeaderGet_traceparent_nullTrace() throws {
        traceSDKInit(traceType: .traceparent,enableTrace: false)
    }
    
    func traceSDKInit(traceType:FTNetworkTraceType,enableTrace:Bool? = true) {
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
//        let appid = dic["APP_ID"]
        let config:FTMobileConfig = FTMobileConfig(datakitUrl: url!)
        config.autoSync = false
        FTMobileAgent.start(withConfigOptions: config)
        
        if(enableTrace == nil || enableTrace == true){
            let traceConfig = FTTraceConfig()
            traceConfig.networkTraceType = traceType
            traceConfig.enableAutoTrace = true
            traceConfig.enableLinkRumData = true
            FTMobileAgent.sharedInstance().startTrace(withConfigOptions: traceConfig)
        }
        let dict = FTExternalDataManager.shared().getTraceHeader(with: URL(string: "http://www.test.com/some/url/string")!)
        
        if(enableTrace == true){
            XCTAssertTrue(dict != nil)
        }else{
            XCTAssertTrue(dict == nil)
        }
        FTMobileAgent.shutDown()
    }
    // MARK: - SessionInterceptor -
    func testSessionInterceptor_injectTraceHeader() throws {
        let delegate = FTURLSessionDelegate.init()
        let expectation = XCTestExpectation.init()

        delegate.requestInterceptor = { request in
            var newRequest = request
            newRequest.setValue("test", forHTTPHeaderField: "test")
            return newRequest
        }
        
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let config:FTMobileConfig = FTMobileConfig(datakitUrl: url!)
        config.autoSync = false
        FTMobileAgent.start(withConfigOptions: config)
    
        
        let rumConfig = FTRumConfig(appid: appid!)
        rumConfig.enableTraceUserAction = true
        rumConfig.enableTrackAppANR = true
        rumConfig.enableTraceUserView = true
        rumConfig.enableTrackAppCrash = true
        rumConfig.enableTrackAppFreeze = true
        rumConfig.deviceMetricsMonitorType = .all
        FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
        FTExternalDataManager.shared().startView(withName: "testSessionInterceptor")
        if let url = dic["TRACE_URL"] {
            let urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: nil)
            let dataTask = urlSession.dataTask(with: URL(string: url)!) { data, response, error in
                
                expectation.fulfill()
            }
            dataTask.resume()
            wait(for: [expectation])
            let value = dataTask.currentRequest?.allHTTPHeaderFields?["test"]
            XCTAssertTrue(value == "test")
        }
        FTMobileAgent.shutDown()
    }
    func testSessionInterceptor_resourceProvider() throws {
        let time = NSDate.ft_currentNanosecondTimeStamp()
        FTTrackerEventDBTool.sharedManger()!.deleteAllDatas()
        let expectation = XCTestExpectation.init()

        let delegate = FTURLSessionDelegate.init()
        delegate.provider = { request,response,data,error  in
            XCTAssertTrue(request is URLRequest?)
            XCTAssertTrue(response is URLResponse?)
            XCTAssertTrue(data is Data?)
            XCTAssertTrue(error is Error?)
            expectation.fulfill()
            return ["test":"test"]
        }
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let config:FTMobileConfig = FTMobileConfig(datakitUrl: url!)
        config.autoSync = false
        FTMobileAgent.start(withConfigOptions: config)
        
        let rumConfig = FTRumConfig(appid: appid!)
        rumConfig.enableTraceUserAction = true
        rumConfig.enableTrackAppANR = true
        rumConfig.enableTraceUserView = true
        rumConfig.enableTrackAppCrash = true
        rumConfig.enableTrackAppFreeze = true
        rumConfig.deviceMetricsMonitorType = .all
        FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
        
        FTExternalDataManager.shared().startView(withName: "testSessionInterceptor")
        if let url = dic["TRACE_URL"] {
            let urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: nil)
            let dataTask = urlSession.dataTask(with: URL(string: url)!) { data, response, error in
                
                expectation.fulfill()
            }
            dataTask.resume()
            wait(for: [expectation])
            Thread.sleep(forTimeInterval: 0.5)
            FTGlobalRumManager.sharedInstance().rumManager.syncProcess()
            let newArray = FTTrackerEventDBTool.sharedManger()!.getAllDatas();
            for data in newArray {
                let model:FTRecordModel = data as! FTRecordModel
                let dict = FTJSONUtil.dictionary(withJsonString: model.data)
                let opdata = dict?["opdata"] as! [String:Any]
                let source = opdata["source"] as! String
                let fields = opdata[FT_FIELDS] as! [String:Any]
                if(source == FT_RUM_SOURCE_RESOURCE){
                    XCTAssertNoThrow(fields["test"] as! String)
                    XCTAssertTrue(fields["test"] as! String == "test")
                    break;
                }
            }
        }
        FTMobileAgent.shutDown()
    }
    // MARK: - RUM - Resource filter
    func testResourceFilter_intakeUrlHandler() throws {
        resourceFilter(oldMethod: true, hasUrl: true)
    }
    func testResourceFilter_intakeUrlHandler_nullUrl() throws {
        resourceFilter(oldMethod: true, hasUrl: false)
    }
    func testResourceFilter_resourceUrlHandler_nullUrl()throws {
        resourceFilter(oldMethod: false, hasUrl: false)
    }
    func testResourceFilter_resourceUrlHandler() throws {
        resourceFilter(oldMethod: false, hasUrl: true)
    }
    
    func resourceFilter(oldMethod:Bool,hasUrl:Bool){
        let dic = ProcessInfo().environment
        let url = dic["ACCESS_SERVER_URL"]
        let appid = dic["APP_ID"]
        let config:FTMobileConfig = FTMobileConfig(datakitUrl: url!)
        config.autoSync = false
        FTMobileAgent.start(withConfigOptions: config)
    
        var hasResourceFilter = false
        
        let rumConfig = FTRumConfig(appid: appid!)
        rumConfig.enableTraceUserAction = true
        rumConfig.enableTrackAppANR = true
        rumConfig.enableTraceUserView = true
        rumConfig.enableTrackAppCrash = true
        rumConfig.enableTrackAppFreeze = true
        rumConfig.deviceMetricsMonitorType = .all
        if(oldMethod == false){
            rumConfig.resourceUrlHandler =  { url in
                hasResourceFilter = true
                return false
            }
        }
        FTMobileAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
        
        if(oldMethod == true){
            FTMobileAgent.sharedInstance().isIntakeUrl { url in
                hasResourceFilter = true
                return false
            }
        }
        
        let request = URLRequest(url:  URL(string: "http://www.test.com/some/url/string")!)
        let task = URLSession.shared.dataTask(with:request)
        if(hasUrl == false){
            task.setValue(nil, forKey: "originalRequest")
            task.setValue(nil, forKey: "currentRequest")
        }
        FTURLSessionInterceptor.shared().interceptTask(task)
        FTURLSessionInterceptor.shared().shutDown()
        XCTAssertTrue(hasResourceFilter == hasUrl)
        FTMobileAgent.shutDown()
    }

}
