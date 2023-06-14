//
//  FTEnumConstant.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/1/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AppState) {
    AppStateUnknown,
    AppStateStartUp,
    AppStateRun,
};

typedef NS_ENUM(NSUInteger, FTError) {
  NetWorkException = 101,        //网络问题
  InvalidParamsException = 102,  //参数问题
  FileIOException = 103,         //文件 IO 问题
  UnknownException = 104,        //未知问题
};
typedef NS_ENUM(NSInteger, LogStatus) {
    /// 提示
    StatusInfo         = 0,
    /// 警告
    StatusWarning,
    /// 错误
    StatusError,
    /// 严重
    StatusCritical,
    /// 恢复
    StatusOk,
};
typedef NS_OPTIONS(NSUInteger, ErrorMonitorType) {
    /// 开启所有监控： 电池、内存、CPU使用率
    ErrorMonitorAll          = 0xFFFFFFFF,
    /// 电池电量
    ErrorMonitorBattery      = 1 << 1,
    /// 内存总量、内存使用率
    ErrorMonitorMemory       = 1 << 2,
    /// CPU使用率
    ErrorMonitorCpu          = 1 << 3,
};
/// 设备信息监控项
typedef NS_OPTIONS(NSUInteger, DeviceMetricsMonitorType){
    /// 开启所有监控项:内存、CPU、FPS
    DeviceMetricsMonitorAll      = 0xFFFFFFFF,
    /// 平均内存、最高内存
    DeviceMetricsMonitorMemory   = 1 << 2,
    /// CPU 跳动最大、平均数
    DeviceMetricsMonitorCpu      = 1 << 3,
    /// fps 最低帧率、平均帧率
    DeviceMetricsMonitorFps      = 1 << 4,
};
/// 监控项采样周期
typedef NS_ENUM(NSUInteger, MonitorFrequency) {
    /// 500ms (默认)
    MonitorFrequencyDefault,
    /// 100ms
    MonitorFrequencyFrequent,
    /// 1000ms
    MonitorFrequencyRare,
};
/// 网络链路追踪使用类型
typedef NS_ENUM(NSInteger, NetworkTraceType) {
    /// datadog trace
    DDtrace,
    /// zipkin multi header
    ZipkinMultiHeader,
    /// zipkin single header
    ZipkinSingleHeader,
    /// w3c traceparent
    Traceparent,
    /// skywalking 8.0+
    Skywalking,
    /// jaeger
    Jaeger,
};
/// 环境字段。属性值：prod/gray/pre/common/local。
typedef NS_ENUM(NSInteger, Env) {
    /// 线上环境
    Prod         = 0,
    /// 灰度环境
    Gray,
    /// 预发布环境
    Pre,
    /// 日常环境
    Common,
    /// 本地环境
    Local,
};
/// 日志废弃策略
typedef NS_ENUM(NSInteger, LogCacheDiscard)  {
    /// 默认，当日志数据数量大于最大值（5000）时，新数据不进行写入
    Discard,
    /// 当日志数据大于最大值时,废弃旧数据
    DiscardOldest
};
extern NSString * const AppStateStringMap[];
extern NSString * const FTStatusStringMap[];
extern NSString * const FTNetworkTraceStringMap[];
extern NSString * const FTEnvStringMap[];
extern NSTimeInterval const MonitorFrequencyMap[];
