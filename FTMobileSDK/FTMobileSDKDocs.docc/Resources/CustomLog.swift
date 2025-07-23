//
//  CustomLog.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileSDK


/// Extension example for using custom log API based on FTMobileSDK.
/// Add file name, method name, and line number to custom logs.
/// - Parameters:
///   - content: Log content
///   - property: Custom properties (optional)
///   - file: File name
///   - function: Method name
///   - line: Line number
public func FTLogInfo(_ content: @autoclosure () -> String = "",
                              property:[String:String]? = nil,
                              file: String = #file,
                              function: StaticString = #function,
                              line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.shared().info(contentStr, property: property)
}


public func FTLogWarning(_ content: @autoclosure () -> String = "",
                                 property:[String:String]? = nil,
                                 file: String = #file,
                                 function: StaticString = #function,
                                 line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.shared().warning(contentStr, property: property)
}


public func FTLogError(_ content: @autoclosure () -> String = "",
                               property:[String:String]? = nil,
                               file: String = #file,
                               function: StaticString = #function,
                               line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.shared().error(contentStr, property: property)
}

public func FTLogCritical(_ content: @autoclosure () -> String = "",
                                  property:[String:String]? = nil,
                                  file: String = #file,
                                  function: StaticString = #function,
                                  line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.shared().critical(contentStr, property: property)
}


public func FTLogOk(_ content: @autoclosure () -> String = "",
                            property:[String:String]? = nil,
                            file: String = #file,
                            function: StaticString = #function,
                            line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.shared().ok(contentStr, property: property)
}


func funA(){
    // Method 1: Through FTMobileAgent
    // Note: Need to ensure SDK is successfully initialized when using, otherwise it will fail assertion and crash in test environment.
    FTMobileAgent.sharedInstance().logging("Custom_logging_content", status: .statusInfo)
    
    // Method 2: Through FTLogger (recommended)
    // If SDK is not successfully initialized, calling methods in FTLogger to add custom logs will fail, but there won't be assertion failure crash issues.
    FTLogger.shared().warning("Custom_logging_content", property: nil)
    
    // Method 3: Extension example for custom log methods.
    FTLogOk("aaaa",property:["a":"b"])
}
