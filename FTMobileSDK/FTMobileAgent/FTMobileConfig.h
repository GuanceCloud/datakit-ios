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
typedef NS_ENUM(NSInteger, FTStatus) {
    FTStatusInfo         = 0,
    FTStatusWarning,
    FTStatusError,
    FTStatusCritical,
    FTStatusOk,
};
/**
 *
 * @constant
 *  FTMonitorInfoTypeBattery  - 电池电量
 *  FTMonitorInfoTypeMemory   - 内存总量、内存使用率
 *  FTMonitorInfoTypeCpu      - CPU使用率
 */
typedef NS_OPTIONS(NSUInteger, FTMonitorInfoType) {
    FTMonitorInfoTypeAll          = 0xFFFFFFFF,
    FTMonitorInfoTypeBattery      = 1 << 1,
    FTMonitorInfoTypeMemory       = 1 << 2,
    FTMonitorInfoTypeCpu          = 1 << 3,
};
/**
 * @enum
 * 网络链路追踪使用类型
 *
 * @constant
 *  FTNetworkTrackTypeZipkin       - Zipkin
 *  FTNetworkTrackTypeJaeger       - Jaeger
 */
typedef NS_ENUM(NSInteger, FTNetworkTraceType) {
    FTNetworkTraceTypeZipkin          = 0,
    FTNetworkTraceTypeJaeger          = 1,
};
typedef NS_ENUM(NSInteger, FTEnv) {
    FTEnvProd         = 0,
    FTEnvGray,
    FTEnvPre,
    FTEnvCommon,
    FTEnvLocal,
};
NS_ASSUME_NONNULL_BEGIN

@interface FTMobileConfig : NSObject
/**
 * @method 指定初始化方法，设置 metricsUrl
 * @param metricsUrl FT-GateWay metrics 写入地址
 * @return 配置对象
 */
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl;

/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
#pragma mark ========== 基本设置 ==========
/**
 * 数据上报地址，两种模式：
 * ①使用Dataflux的数据网关，可在控制台获取对应网址；
 * ②使用私有化部署的数据网关，填写对应网址即可。
*/
@property (nonatomic, copy) NSString *metricsUrl;
/**
 * 应用唯一ID，在DataFlux控制台上面创建监控时自动生成。
 */
@property (nonatomic, copy) NSString *appid;
/**
 * 应用版本号。
 */
@property (nonatomic, copy) NSString *version;
/**
 * TAG 中的设备信息
 */
@property (nonatomic) FTMonitorInfoType monitorInfoType;
/**
 * 环境字段。属性值：prod/gray/pre/common/local。其中
 * prod：线上环境
 * gray：灰度环境
 * pre：预发布环境
 * common：日常环境
 * local：本地环境
 */
@property (nonatomic, assign) FTEnv env;
/**
 * 采样配置，属性值：0或者100，100则表示百分百采集，不做数据样本压缩。
 */
@property (nonatomic, assign) int samplerate;
/**
 * 请求HTTP请求头X-Datakit-UUID 数据采集端  如果用户不设置会自动配置
 */
@property (nonatomic, copy) NSString *XDataKitUUID;
/**
 * 设置是否允许 SDK 打印 Debug
 * 日志
 */
@property (nonatomic, assign) BOOL enableSDKDebugLog;
#pragma mark ========== 日志相关 ==========
/**
 * 日志的来源 默认为：ft_mobile_sdk_ios
 */
@property (nonatomic, copy) NSString *source;
/**
 * 设置日志所属业务或服务的名称
 */
@property (nonatomic, copy) NSString *serviceName;
/**
 * 设置是否追踪用户操作，目前支持应用启动和点击操作
 */
@property (nonatomic, assign) BOOL enableTraceUserAction;
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
 * 设置是否需要采集控制台日志 默认为NO
 */
@property (nonatomic, assign) BOOL traceConsoleLog;
/**
 * 设置网络请求信息采集 默认为NO
*/
@property (nonatomic, assign) BOOL networkTrace;
/**
 *  设置网络请求信息采集时 使用链路追踪类型 type 默认为 Zipkin
*/
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
/**
 *  开启网络请求信息采集 并设置链路追踪类型 type 默认为 Zipkin
 *  @param  type   链路追踪类型 默认为 Zipkin
*/
-(void)networkTraceWithTraceType:(FTNetworkTraceType)type;

@end

NS_ASSUME_NONNULL_END
