//
//  FTEnumConstant.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/1/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, FTError) {
  NetWorkException = 101,        //Network issue
  InvalidParamsException = 102,  //Parameter issue
  FileIOException = 103,         //File IO issue
  UnknownException = 104,        //Unknown issue
};
typedef NS_ENUM(NSInteger, LogStatus) {
    /// Info
    StatusInfo         = 0,
    /// Warning
    StatusWarning,
    /// Error
    StatusError,
    /// Critical
    StatusCritical,
    /// Recovery
    StatusOk,
    /// Debug, SDK debug logs
    StatusDebug,
    /// User custom
    StatusCustom,
};
typedef NS_OPTIONS(NSUInteger, ErrorMonitorType) {
    /// Enable all monitoring: battery, memory, CPU usage
    ErrorMonitorAll          = 0xFFFFFFFF,
    /// Battery level
    ErrorMonitorBattery      = 1 << 1,
    /// Total memory, memory usage
    ErrorMonitorMemory       = 1 << 2,
    /// CPU usage
    ErrorMonitorCpu          = 1 << 3,
};
/// Device information monitoring items
typedef NS_OPTIONS(NSUInteger, DeviceMetricsMonitorType){
    /// Enable all monitoring items: memory, CPU, FPS
    DeviceMetricsMonitorAll      = 0xFFFFFFFF,
    /// Average memory, peak memory
    DeviceMetricsMonitorMemory   = 1 << 2,
    /// CPU maximum fluctuation, average
    DeviceMetricsMonitorCpu      = 1 << 3,
    /// FPS minimum frame rate, average frame rate
    DeviceMetricsMonitorFps      = 1 << 4,
};
/// Monitoring item sampling period
typedef NS_ENUM(NSUInteger, MonitorFrequency) {
    /// 500ms (default)
    MonitorFrequencyDefault,
    /// 100ms
    MonitorFrequencyFrequent,
    /// 1000ms
    MonitorFrequencyRare,
};
/// Network link tracing usage type
typedef NS_ENUM(NSInteger, NetworkTraceType) {
    /// datadog trace
    DDtrace,
    /// zipkin multi header
    ZipkinMultiHeader,
    /// zipkin single header
    ZipkinSingleHeader,
    /// w3c traceparent
    TraceParent,
    /// skywalking 8.0+
    SkyWalking,
    /// jaeger
    Jaeger,
};
/// Environment field. Property values: prod/gray/pre/common/local.
typedef NS_ENUM(NSInteger, Env) {
    /// Production environment
    Prod         = 0,
    /// Gray environment
    Gray,
    /// Pre-release environment
    Pre,
    /// Daily environment
    Common,
    /// Local environment
    Local,
};
/// Log discard strategy
typedef NS_ENUM(NSInteger, LogCacheDiscard)  {
    /// Default, when log data count exceeds maximum value (5000), new data is not written
    Discard,
    /// When log data exceeds maximum value, discard old data
    DiscardOldest
};
extern NSString * const AppStateStringMap[];
extern NSString * const FTStatusStringMap[];
extern NSString * const FTNetworkTraceStringMap[];
extern NSString * const FTEnvStringMap[];
extern NSTimeInterval const MonitorFrequencyMap[];
