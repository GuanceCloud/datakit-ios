//
//  Logger.swift
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/29.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//
#if SWIFT_PACKAGE
import _FTLogger
#endif


@inlinable
public func FTLogInfo(_ content: @autoclosure () -> String = "",
                      file: String = #file,
                      function: StaticString = #function,
                      line: UInt = #line){
    FTLogInfoProperty(content(),
                      property: nil,
                      file: file,
                      function: function,
                      line: line
    )
}

@inlinable
public func FTLogWarning(_ content: @autoclosure () -> String = "",
                         file: String = #file,
                         function: StaticString = #function,
                         line: UInt = #line){
    FTLogWarningProperty(content(),
                         property: nil,
                         file: file,
                         function: function,
                         line: line
    )
}

@inlinable
public func FTLogError(_ content: @autoclosure () -> String = "",
                       file: String = #file,
                       function: StaticString = #function,
                       line: UInt = #line){
    FTLogErrorProperty(content(),
                       property: nil,
                       file: file,
                       function: function,
                       line: line
    )
}

@inlinable
public func FTLogCritical(_ content: @autoclosure () -> String = "",
                          file: String = #file,
                          function: StaticString = #function,
                          line: UInt = #line){
    FTLogCriticalProperty(content(),
                          property: nil,
                          file: file,
                          function: function,
                          line: line
    )
}

@inlinable
public func FTLogOk(_ content: @autoclosure () -> String = "",
                    file: String = #file,
                    function: StaticString = #function,
                    line: UInt = #line){
    FTLogOkProperty(content(),
                    property: nil,
                    file: file,
                    function: function,
                    line: line
    )
}

@inlinable
public func FTLogInfoProperty(_ content: @autoclosure () -> String = "",
                              property:[String:String]? = nil,
                              file: String = #file,
                              function: StaticString = #function,
                              line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.sharedInstance().info(contentStr, property: property)
}

@inlinable
public func FTLogWarningProperty(_ content: @autoclosure () -> String = "",
                                 property:[String:String]? = nil,
                                 file: String = #file,
                                 function: StaticString = #function,
                                 line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.sharedInstance().warning(contentStr, property: property)
}

@inlinable
public func FTLogErrorProperty(_ content: @autoclosure () -> String = "",
                               property:[String:String]? = nil,
                               file: String = #file,
                               function: StaticString = #function,
                               line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.sharedInstance().error(contentStr, property: property)
}

@inlinable
public func FTLogCriticalProperty(_ content: @autoclosure () -> String = "",
                                  property:[String:String]? = nil,
                                  file: String = #file,
                                  function: StaticString = #function,
                                  line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.sharedInstance().critical(contentStr, property: property)
}

@inlinable
public func FTLogOkProperty(_ content: @autoclosure () -> String = "",
                            property:[String:String]? = nil,
                            file: String = #file,
                            function: StaticString = #function,
                            line: UInt = #line){
    var contentStr = String(describing: content())
    contentStr = "\(file.split(separator: "/").last!) [\(function)] [\(line)] \(contentStr)"
    FTLogger.sharedInstance().ok(contentStr, property: property)
}

