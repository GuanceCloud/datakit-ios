//
//  FTMobileConfig.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
///事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info
typedef NS_ENUM(NSInteger, FTLogStatus) {
    FTStatusInfo         = 0,
    FTStatusWarning,
    FTStatusError,
    FTStatusCritical,
    FTStatusOk,
};
/**
 *
 * @constant
 *  FTErrorMonitorBattery  - 电池电量
 *  FTErrorMonitorMemory   - 内存总量、内存使用率
 *  FTErrorMonitorCpu      - CPU使用率
 */
typedef NS_OPTIONS(NSUInteger, FTErrorMonitorType) {
    FTErrorMonitorAll          = 0xFFFFFFFF,
    FTErrorMonitorBattery      = 1 << 1,
    FTErrorMonitorMemory       = 1 << 2,
    FTErrorMonitorCpu          = 1 << 3,
};
/**
 * 监控项
 * @constant
 *  FTDeviceMetricsMonitorMemory   - 平均内存、最高内存
 *  FTDeviceMetricsMonitorCpu      - CPU跳动最大、平均数
 *  FTDeviceMetricsMonitorFps      - fps 最低帧率、平均帧率
 */
typedef NS_OPTIONS(NSUInteger, FTDeviceMetricsMonitorType){
    FTDeviceMetricsMonitorAll      = 0xFFFFFFFF,
    FTDeviceMetricsMonitorMemory   = 1 << 2,
    FTDeviceMetricsMonitorCpu      = 1 << 3,
    FTDeviceMetricsMonitorFps      = 1 << 4,
};
/**
 * 监控项采样周期
 * @constant
 *  FTMonitorFrequencyDefault   - 500ms (默认)
 *  FTMonitorFrequencyFrequent  - 100ms
 *  FTMonitorFrequencyRare      - 1000ms
 */
typedef NS_OPTIONS(NSUInteger, FTMonitorFrequency) {
    FTMonitorFrequencyDefault,
    FTMonitorFrequencyFrequent,
    FTMonitorFrequencyRare,
};
/**
 * @enum
 * 网络链路追踪使用类型
 *
 * @constant
 *  FTNetworkTraceTypeDDtrace       - datadog trace
 *  FTNetworkTraceTypeZipkinMultiHeader   - zipkin multi header
 *  FTNetworkTraceTypeZipkinSingleHeader  - zipkin single header
 *  FTNetworkTraceTypeTraceparent         - w3c traceparent
 *  FTNetworkTraceTypeSkywalking    - skywalking 8.0+
 *  FTNetworkTraceTypeJaeger        - jaeger
 */

typedef NS_ENUM(NSInteger, FTNetworkTraceType) {
    FTNetworkTraceTypeDDtrace,
    FTNetworkTraceTypeZipkinMultiHeader,
    FTNetworkTraceTypeZipkinSingleHeader,
    FTNetworkTraceTypeTraceparent,
    FTNetworkTraceTypeSkywalking,
    FTNetworkTraceTypeJaeger,
};
/**
 * 环境字段。属性值：prod/gray/pre/common/local。其中
 * prod：线上环境
 * gray：灰度环境
 * pre：预发布环境
 * common：日常环境
 * local：本地环境
 */
typedef NS_ENUM(NSInteger, FTEnv) {
    FTEnvProd         = 0,
    FTEnvGray,
    FTEnvPre,
    FTEnvCommon,
    FTEnvLocal,
};
typedef NS_ENUM(NSInteger, FTLogCacheDiscard)  {
    FTDiscard,        //默认，当日志数据大于最大值时 废弃新传入的数据
    FTDiscardOldest   //当日志数据大于最大值时,废弃旧数据
};

NS_ASSUME_NONNULL_BEGIN

@interface FTLoggerConfig : NSObject
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/**
 * 设置日志所属业务或服务的名称 默认：df_rum_ios
 */
@property (nonatomic, copy) NSString *service;
/**
 * 设置日志废弃策略
 */
@property (nonatomic, assign) FTLogCacheDiscard  discardType;
/**
 * 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
 */
@property (nonatomic, assign) int samplerate;
/**
 * 设置是否需要采集控制台日志 默认为NO
 */
@property (nonatomic, assign) BOOL enableConsoleLog;
/**
 * 设置采集控制台日志过滤字符串 包含该字符串控制台日志会被采集 默认为全采集
 */
@property (nonatomic, copy) NSString *prefix;
/**
 * 是否将 logger 数据与 rum 关联
 */
@property (nonatomic, assign) BOOL enableLinkRumData;
/**
 * 是否上传自定义 log
 */
@property (nonatomic, assign) BOOL enableCustomLog;
/**
 * 设置采集自定义日志的状态数组  默认为全采集
 * 例: @[@(FTStatusInfo),@(FTStatusError)]
 * 或 @[@0,@1]
 */
@property (nonatomic, strong) NSArray<NSNumber*> *logLevelFilter;
/**
 * 设置 logger 全局 tag
 */
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *globalContext;

- (void)enableConsoleLog:(BOOL)enable prefix:(NSString *)prefix;
@end


@interface FTRumConfig : NSObject
/**
 * @method 指定初始化方法，设置 appid
 * @param appid 应用唯一ID 设置后 rum 数据才能正常上报
 * @return 配置对象
 */
- (instancetype)initWithAppid:(nonnull NSString *)appid;
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/**
 * 应用唯一ID，在DataFlux控制台上面创建监控时自动生成。
 */
@property (nonatomic, copy) NSString *appid;
/**
 * 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
 */
@property (nonatomic, assign) int samplerate;
/**
 * 设置是否追踪用户操作，目前支持应用启动和点击操作，
 * 在 enableTraceUserView 开启的状况下 开启才能生效（仅作用于autotrack）
 */
@property (nonatomic, assign) BOOL enableTraceUserAction;
/**
 * 设置是否追踪页面生命周期 （仅作用于autotrack）
 */
@property (nonatomic, assign) BOOL enableTraceUserView;
/**
 * 设置是否追踪用户网络请求  (仅作用于native http)
 */
@property (nonatomic, assign) BOOL enableTraceUserResource;
/**
 * 设置是否需要采集崩溃日志
 */
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/**
 * 设置是否需要采集卡顿
 */
@property (nonatomic, assign) BOOL enableTrackAppFreeze;
/**
 * 设置是否需要采集卡顿
 * runloop采集主线程卡顿
*/
@property (nonatomic, assign) BOOL enableTrackAppANR;
/**
 * ERROR 中的设备信息
 */
@property (nonatomic, assign) FTErrorMonitorType errorMonitorType;
/**
 * 设置监控类型 不设置则不开启监控
 */
@property (nonatomic, assign) FTDeviceMetricsMonitorType deviceMetricsMonitorType;
/**
 * 设置监控采样周期
 */
@property (nonatomic, assign) FTMonitorFrequency monitorFrequency;
/**
 * 设置 rum 全局 tag
 * 特殊 key : track_id (用于追踪功能)
 */
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *globalContext;
@end
@interface FTTraceConfig : NSObject
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/**
 * 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
 */
@property (nonatomic, assign) int samplerate;
/**
 *  设置网络请求信息采集时 使用链路追踪类型 type 默认为 Zipkin
*/
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
/**
 * 是否将 Trace 数据与 rum 关联
 * 仅在 FTNetworkTraceType 设置为 FTNetworkTraceTypeDDtrace 时生效
 */
@property (nonatomic, assign) BOOL enableLinkRumData;
/**
 * 设置是否开启自动 http trace
 */
@property (nonatomic, assign) BOOL enableAutoTrace;
@end

@interface FTMobileConfig : NSObject
/**
 * @method 指定初始化方法，设置 metricsUrl
 * @param metricsUrl 数据上报地址
 * @return 配置对象
 */
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl;

/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/**
 * 数据上报地址，两种模式：
 * ①使用Dataflux的数据网关，可在控制台获取对应网址；
 * ②使用私有化部署的数据网关，填写对应网址即可。
*/
@property (nonatomic, copy) NSString *metricsUrl;
/**
 * 请求HTTP请求头X-Datakit-UUID 数据采集端  如果用户不设置会自动配置
 */
@property (nonatomic, copy) NSString *XDataKitUUID;
/**
 * 环境字段。
 */
@property (nonatomic, assign) FTEnv env;
/**
 * 设置是否允许 SDK 打印 Debug 日志
 */
@property (nonatomic, assign) BOOL enableSDKDebugLog;
/**
 * 应用版本号。
 */
@property (nonatomic, copy) NSString *version;
/**
 * 设置 SDK 全局 tag
 * 保留标签： sdk_package_flutter、sdk_package_react_native
 */
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *globalContext;

@end

NS_ASSUME_NONNULL_END
