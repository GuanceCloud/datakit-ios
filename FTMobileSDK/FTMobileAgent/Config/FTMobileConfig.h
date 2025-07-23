//
//  FTMobileConfig.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 网络链路追踪使用类型
typedef NS_ENUM(NSUInteger, FTNetworkTraceType) {
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
/// 环境。属性值：prod/gray/pre/common/local。
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
/// 数据同步大小
typedef NS_ENUM(NSUInteger, FTSyncPageSize) {
    /// MINI 5
    FTSyncPageSizeMini = 0,
    /// MEDIUM 10
    FTSyncPageSizeMedium,
    /// MAX 50
    FTSyncPageSizeMax,
};

/// DB废弃策略
typedef NS_ENUM(NSInteger, FTDBCacheDiscard)  {
    /// 默认，当数据库存储大于最大值(默认100MB)时，新数据不进行写入
    FTDBDiscard,
    /// 当数据库存储大于最大值,废弃旧数据
    FTDBDiscardOldest
};
#import "FTDataModifier.h"

NS_ASSUME_NONNULL_BEGIN
@class FTTraceContext;
/// 支持自定义 trace, 确认拦截后，返回 TraceContext，不拦截返回 nil
typedef FTTraceContext*_Nullable(^FTTraceInterceptor)(NSURLRequest *_Nonnull request);

/// Trace 功能配置项
@interface FTTraceConfig : NSObject
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int samplerate;
/// 设置网络请求信息采集时 使用链路追踪类型 type 默认为 DDtrace
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
/// 支持通过 URLRequest 判断是否进行自定义 trace,确认拦截后，返回 TraceContext，不拦截返回 nil
@property (nonatomic,copy) FTTraceInterceptor traceInterceptor;
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
- (instancetype)initWithMetricsUrl:(NSString *)metricsUrl DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 -initWithDatakitUrl: 替换");

/// 本地环境部署，设置 datakitUrl
/// - Parameter datakitUrl: datakit 数据上报地址
- (instancetype)initWithDatakitUrl:(NSString *)datakitUrl;

/// 使用公网 DataWay 部署，设置 datawayUrl 与 clientToken
/// - Parameter datawayUrl: datawayUrl 数据上报地址
/// - Parameter clientToken: dataway token
- (instancetype)initWithDatawayUrl:(NSString *)datawayUrl clientToken:(NSString *)clientToken;

/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 数据上报地址
@property (nonatomic, copy) NSString *metricsUrl DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 datakitUrl 替换");
/// 数据上报 datakit 地址
@property (nonatomic, copy) NSString *datakitUrl;
/// 数据上报 dataway 地址
@property (nonatomic, copy) NSString *datawayUrl;
/// client token
@property (nonatomic, copy) NSString *clientToken;
/// 设置自定义环境字段。
@property (nonatomic, copy) NSString *env;
/// 设置是否允许 SDK 打印 Debug 日志。
@property (nonatomic, assign) BOOL enableSDKDebugLog;
/// 应用版本号。默认`CFBundleShortVersionString`值
@property (nonatomic, copy) NSString *version DEPRECATED_MSG_ATTRIBUTE("已废弃，version 将统一使用`CFBundleShortVersionString`值");
/// 所属业务或服务的名称 默认：df_rum_ios
@property (nonatomic, copy) NSString *service;
/// 数据是否进行自动同步上传 默认：YES
@property (nonatomic, assign) BOOL autoSync;
/// 数据同步时每条请求同步条数,最小值 5 默认：10
@property (nonatomic, assign) int syncPageSize;
/// 数据同步时每条请求间隔时间 单位毫秒 0< syncSleepTime <5000
@property (nonatomic, assign) int syncSleepTime;
/// 数据同步时是否开启数据整数兼容，默认 YES
@property (nonatomic, assign) BOOL enableDataIntegerCompatible;
/// 设置内部数据同步时是否开启压缩 默认: NO
@property (nonatomic, assign) BOOL compressIntakeRequests;
/// 开启使用 db 限制数据大小
@property (nonatomic, assign) BOOL enableLimitWithDbSize;
/// db 缓存限制大小,默认 100MB,单位 byte
@property (nonatomic, assign) long dbCacheLimit;
/// 数据库废弃策略
@property (nonatomic, assign) FTDBCacheDiscard dbDiscardType;

/// 设置 SDK 全局 tag
///
/// 保留标签： sdk_package_flutter、sdk_package_react_native
@property (nonatomic, copy) NSDictionary<NSString*,NSString*> *globalContext;

/// 需要采集的 Extensions 对应的 AppGroups Identifier 数组
@property (nonatomic, copy) NSArray<NSString*> *groupIdentifiers;

/// 设置数据更改器，字段替换，适合全局字段替换场景
@property (nonatomic, copy) FTDataModifier dataModifier;

/// 设置数据更改器，可以针对某一行进行判断，再决定是否需要替换某一个数值
@property (nonatomic, copy) FTLineDataModifier lineDataModifier;

/// 设置是否开启远程动态配置
@property (nonatomic, assign) BOOL remoteConfiguration;

/// 设置远程动态配置最小更新间隔，单位秒,默认 12*60*60
@property (nonatomic, assign) int remoteConfigMiniUpdateInterval;
/// 根据提供的 FTEnv 类型设置 env
/// - Parameter envType: 环境
- (void)setEnvWithType:(FTEnv)envType;
/// 根据提供的 FTSyncPageSize 类型设置 syncPageSize
/// - Parameter pageSize: 数据同步大小
- (void)setSyncPageSizeWithType:(FTSyncPageSize)pageSize;

@end

NS_ASSUME_NONNULL_END
