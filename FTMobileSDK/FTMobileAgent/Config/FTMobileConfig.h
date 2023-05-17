//
//  FTMobileConfig.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
///事件等级和状态，默认：FTStatusInfo
typedef NS_ENUM(NSInteger, FTLogStatus) {
    /// 提示
    FTStatusInfo         = 0,
    /// 警告
    FTStatusWarning,
    /// 错误
    FTStatusError,
    /// 严重
    FTStatusCritical,
    /// 恢复
    FTStatusOk,
};
/// ERROR 中的设备信息
typedef NS_OPTIONS(NSUInteger, FTErrorMonitorType) {
    /// 开启所有监控： 电池、内存、CPU使用率
    FTErrorMonitorAll          = 0xFFFFFFFF,
    /// 电池电量
    FTErrorMonitorBattery      = 1 << 1,
    /// 内存总量、内存使用率
    FTErrorMonitorMemory       = 1 << 2,
    /// CPU使用率
    FTErrorMonitorCpu          = 1 << 3,
};
/// 设备信息监控项
typedef NS_OPTIONS(NSUInteger, FTDeviceMetricsMonitorType){
    /// 开启所有监控项:内存、CPU、FPS
    FTDeviceMetricsMonitorAll      = 0xFFFFFFFF,
    /// 平均内存、最高内存
    FTDeviceMetricsMonitorMemory   = 1 << 2,
    /// CPU 跳动最大、平均数
    FTDeviceMetricsMonitorCpu      = 1 << 3,
    /// fps 最低帧率、平均帧率
    FTDeviceMetricsMonitorFps      = 1 << 4,
};
/// 监控项采样周期
typedef NS_ENUM(NSUInteger, FTMonitorFrequency) {
    /// 500ms (默认)
    FTMonitorFrequencyDefault,
    /// 100ms
    FTMonitorFrequencyFrequent,
    /// 1000ms
    FTMonitorFrequencyRare,
};
/// 网络链路追踪使用类型
typedef NS_ENUM(NSInteger, FTNetworkTraceType) {
    /// datadog trace
    FTNetworkTraceTypeDDtrace,
    /// zipkin multi header
    FTNetworkTraceTypeZipkinMultiHeader,
    /// zipkin single header
    FTNetworkTraceTypeZipkinSingleHeader,
    /// w3c traceparent
    FTNetworkTraceTypeTraceparent,
    /// skywalking 8.0+
    FTNetworkTraceTypeSkywalking,
    /// jaeger
    FTNetworkTraceTypeJaeger,
};
/// 环境字段。属性值：prod/gray/pre/common/local。
typedef NS_ENUM(NSInteger, FTEnv) {
    /// 线上环境
    FTEnvProd         = 0,
    /// 灰度环境
    FTEnvGray,
    /// 预发布环境
    FTEnvPre,
    /// 日常环境
    FTEnvCommon,
    /// 本地环境
    FTEnvLocal,
};
/// 日志废弃策略
typedef NS_ENUM(NSInteger, FTLogCacheDiscard)  {
    /// 默认，当日志数据数量大于最大值（5000）时，新数据不进行写入
    FTDiscard,
    /// 当日志数据大于最大值时,废弃旧数据
    FTDiscardOldest
};

NS_ASSUME_NONNULL_BEGIN

/// logger 功能配置项
@interface FTLoggerConfig : NSObject
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 日志废弃策略
@property (nonatomic, assign) FTLogCacheDiscard  discardType;
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int samplerate;
/// 是否需要采集控制台日志 默认为 NO
@property (nonatomic, assign) BOOL enableConsoleLog;
/// 采集控制台日志过滤字符串 包含该字符串控制台日志会被采集 默认为全采集
@property (nonatomic, copy) NSString *prefix;
/// 是否将 logger 数据与 rum 关联
@property (nonatomic, assign) BOOL enableLinkRumData;
/// 是否上传自定义 log
@property (nonatomic, assign) BOOL enableCustomLog;
/// 采集自定义日志的状态数组，默认为全采集
///
/// 例: @[@(FTStatusInfo),@(FTStatusError)]
/// 或 @[@0,@1]
@property (nonatomic, strong) NSArray<NSNumber*> *logLevelFilter;
/// logger 全局 tag
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *globalContext;

/// 设置控制台日志采集条件
/// - Parameters:
///   - enable: 是否上传自定义 log
///   - prefix: 采集控制台日志过滤字符串 包含该字符串控制台日志会被采集 默认为全采集
- (void)enableConsoleLog:(BOOL)enable prefix:(NSString *)prefix;
@end


/// RUM 功能的配置项
@interface FTRumConfig : NSObject
/// 指定初始化方法，设置 appid
///
/// - Parameters:
///   - appid: 用户访问监测应用 ID 唯一标识，在用户访问监测控制台上面创建监控时自动生成.
/// - Returns: rum 配置项.
- (instancetype)initWithAppid:(nonnull NSString *)appid;
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 用户访问监测应用 ID 唯一标识，在用户访问监测控制台上面创建监控时自动生成.
@property (nonatomic, copy) NSString *appid;
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int samplerate;
/// 设置是否追踪用户操作，目前支持应用启动和点击操作，
/// 在有 View 事件的情况下，开启才能生效
@property (nonatomic, assign) BOOL enableTraceUserAction;
/// 设置是否追踪页面生命周期 （仅作用于autotrack）
@property (nonatomic, assign) BOOL enableTraceUserView;
/// 设置是否追踪用户网络请求  (仅作用于native http)
@property (nonatomic, assign) BOOL enableTraceUserResource;
/// 设置是否需要采集崩溃日志
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/// 设置是否需要采集卡顿
@property (nonatomic, assign) BOOL enableTrackAppFreeze;
/// 设置是否需要采集 ANR
///
/// runloop 采集主线程卡顿
@property (nonatomic, assign) BOOL enableTrackAppANR;
/// ERROR 中的设备信息
@property (nonatomic, assign) FTErrorMonitorType errorMonitorType;
/// 设置监控类型 不设置则不开启监控
@property (nonatomic, assign) FTDeviceMetricsMonitorType deviceMetricsMonitorType;
/// 设置监控采样周期
@property (nonatomic, assign) FTMonitorFrequency monitorFrequency;
/// 设置 rum 全局 tag
///
/// 保留标签:特殊 key - track_id (用于追踪功能)
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *globalContext;
@end
/// Trace 功能配置项
@interface FTTraceConfig : NSObject
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int samplerate;
/// 设置网络请求信息采集时 使用链路追踪类型 type 默认为 DDtrace
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
/// 是否将 Trace 数据与 rum 关联
///
/// 仅在 FTNetworkTraceType 设置为 FTNetworkTraceTypeDDtrace 时生效
@property (nonatomic, assign) BOOL enableLinkRumData;
/// 设置是否开启自动 http trace
@property (nonatomic, assign) BOOL enableAutoTrace;
@end

/// SDK 基础配置项
@interface FTMobileConfig : NSObject
/// 指定初始化方法，设置 metricsUrl
/// - Parameter metricsUrl: 数据上报地址
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl;

/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 数据上报地址
@property (nonatomic, copy) NSString *metricsUrl;
/// 环境字段。
@property (nonatomic, assign) FTEnv env;
/// 设置是否允许 SDK 打印 Debug 日志。
@property (nonatomic, assign) BOOL enableSDKDebugLog;
/// 应用版本号。
@property (nonatomic, copy) NSString *version;
/// 所属业务或服务的名称 默认：df_rum_ios
@property (nonatomic, copy) NSString *service;
/// 设置 SDK 全局 tag
///
/// 保留标签： sdk_package_flutter、sdk_package_react_native
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *globalContext;

/// 需要采集的 Extensions 对应的 AppGroups Identifier 数组
@property (nonatomic, strong) NSArray *groupIdentifiers;
@end

NS_ASSUME_NONNULL_END
