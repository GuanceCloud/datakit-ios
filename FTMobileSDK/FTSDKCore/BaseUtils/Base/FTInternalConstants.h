//
//  FTInternalConstants.h
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

extern NSString * const FT_BLACK_LIST_VIEW;
extern NSString * const FT_BLACK_LIST_VIEW_ACTION;

extern NSUInteger const FT_LOGGING_CONTENT_SIZE;

extern int const FT_DB_LOG_MAX_COUNT;
extern int const FT_DB_LOG_MIN_COUNT;

extern int const FT_DB_RUM_MAX_COUNT;
extern int const FT_DB_RUM_MIN_COUNT;

extern long const FT_DEFAULT_DB_SIZE_LIMIT;
extern long const FT_MIN_DB_SIZE_LIMIT;

extern NSString * const FT_SCRIPT_MESSAGE_HANDLER_NAME;
extern NSUInteger const FT_TIME_INTERVAL;
/// Freeze threshold in milliseconds, default 250ms
extern long const FT_DEFAULT_BLOCK_DURATIONS_MS;
/// Minimum freeze duration 100 ms
extern long const FT_MIN_DEFAULT_BLOCK_DURATIONS_MS;

extern long long const FT_ANR_THRESHOLD_NS;
extern long const FT_ANR_THRESHOLD_MS;

#pragma mark ----- HTTP Header Fields -----
extern NSString * const FT_HTTP_HEADER_X_PKG_ID;          
extern NSString * const FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST;
extern NSString * const FT_HTTP_HEADER_X_CLIENT_TIMESTAMP;
