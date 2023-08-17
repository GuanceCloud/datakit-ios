//
//  CustomLog.swift
//  
//
//  Created by hulilei on 2022/11/2.
//

import Foundation
import FTMobileSDK


/// 基于 FTMobileSDK 自定义日志 API 的使用扩展示例。
/// 在自定义日志中添加文件名、方法名称、行号。
/// - Parameters:
///   - content: 日志内容
///   - property: 自定义属性(可选)
///   - file: 文件名
///   - function: 方法名
///   - line: 行号
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
    // 方法一：通过 FTMobileAgent
    // 注意：需要保证在使用的时候 SDK 已经初始化成功，否则在测试环境会断言失败从而崩溃。
    FTMobileAgent.sharedInstance().logging("Custom_logging_content", status: .statusInfo)
    
    // 方法二：通过 FTLogger （推荐）
    // SDK 如果没有初始化成功，调用 FTLogger 中方法添加自定义日志会失败，但不会有断言失败崩溃问题。
    FTLogger.shared().warning("Custom_logging_content", property: nil)
    
    // 方法三：针对自定义日志方法的扩展示例。
    FTLogOk("aaaa",property:["a":"b"])
}
