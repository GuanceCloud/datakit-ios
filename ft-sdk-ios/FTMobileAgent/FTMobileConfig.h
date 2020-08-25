//
//  FTMobileConfig.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


typedef enum FTError : NSInteger {
  NetWorkException = 101,        //网络问题
  InvalidParamsException = 102,  //参数问题
  FileIOException = 103,         //文件 IO 问题
  UnknownException = 104,        //未知问题
} FTError;

/**
 * @enum
 * AutoTrack 抓取信息
 *
 * @constant
 *   FTAutoTrackEventTypeAppLaunch      - 项目启动
 *   FTAutoTrackEventTypeAppClick       - 点击事件
 *   FTAutoTrackEventTypeAppViewScreen  - 页面的生命周期 open/close
 */
typedef NS_OPTIONS(NSInteger, FTAutoTrackEventType) {
    FTAutoTrackTypeNone          = 0,
    FTAutoTrackEventTypeAppLaunch     = 1 << 0,
    FTAutoTrackEventTypeAppClick      = 1 << 1,
    FTAutoTrackEventTypeAppViewScreen = 1 << 2,
};
/**
 * @enum  TAG 中的设备信息
 *
 * @constant
 *   FTMonitorInfoTypeBattery  - 电池总量、使用量
 *   FTMonitorInfoTypeMemory   - 内存总量、使用率
 *   FTMonitorInfoTypeCpu      - CPU型号、占用率
 *   FTMonitorInfoTypeCpu      - GPU型号、占用率
 *   FTMonitorInfoTypeNetwork  - 网络的信号强度、网络速度、类型、代理
 *   FTMonitorInfoTypeCamera   - 前置/后置 像素
 *   FTMonitorInfoTypeLocation - 位置信息  国家、省、市、经纬度
 *   FTMonitorInfoTypeSystem   - 开机时间、设备名
 *   FTMonitorInfoTypeSensor   - 屏幕亮度、当天步数、距离传感器、陀螺仪三轴旋转角速度、三轴线性加速度、三轴地磁强度
 *   FTMonitorInfoTypeBluetooth- 蓝牙对外显示名称
 *   FTMonitorInfoTypeSensorBrightness - 屏幕亮度
 *   FTMonitorInfoTypeSensorStep       - 当天步数
 *   FTMonitorInfoTypeSensorProximity  - 距离传感器
 *   FTMonitorInfoTypeSensorRotation   - 陀螺仪三轴旋转角速度
 *   FTMonitorInfoTypeSensorAcceleration - 三轴线性加速度
 *   FTMonitorInfoTypeSensorMagnetic   - 三轴地磁强度
 *   FTMonitorInfoTypeSensorLight      - 环境光感参数
 *   FTMonitorInfoTypeSensorTorch      - 手电筒亮度级别0-1
 *   FTMonitorInfoTypeFPS              - 每秒传输帧数
 */
typedef NS_OPTIONS(NSUInteger, FTMonitorInfoType) {
    FTMonitorInfoTypeAll          = 0xFFFFFFFF,
    FTMonitorInfoTypeBattery      = 1 << 1,
    FTMonitorInfoTypeMemory       = 1 << 2,
    FTMonitorInfoTypeCpu          = 1 << 3,
    FTMonitorInfoTypeGpu          = 1 << 4,
    FTMonitorInfoTypeNetwork      = 1 << 5,
    FTMonitorInfoTypeCamera       = 1 << 6,
    FTMonitorInfoTypeLocation     = 1 << 7,
    FTMonitorInfoTypeSystem       = 1 << 8,
    FTMonitorInfoTypeSensor       = 1 << 9,
    FTMonitorInfoTypeBluetooth    = 1 << 10,
    FTMonitorInfoTypeSensorBrightness   = 1 << 11,
    FTMonitorInfoTypeSensorStep         = 1 << 12,
    FTMonitorInfoTypeSensorProximity    = 1 << 13,
    FTMonitorInfoTypeSensorRotation     = 1 << 14,
    FTMonitorInfoTypeSensorAcceleration = 1 << 15,
    FTMonitorInfoTypeSensorMagnetic     = 1 << 16,
    FTMonitorInfoTypeSensorLight        = 1 << 17,
    FTMonitorInfoTypeSensorTorch        = 1 << 18,
    FTMonitorInfoTypeFPS                = 1 << 19,
};
/**
 * @enum
 * 网络链路追踪使用类型
 *
 * @constant
 *   FTNetworkTrackTypeZipkin       - Zipkin
 *   FTNetworkTrackTypeJaeger       - Jaeger
 */
typedef NS_ENUM(NSInteger, FTNetworkTrackType) {
    FTNetworkTrackTypeZipkin          = 0,
    FTNetworkTrackTypeJaeger          = 1,
    FTNetworkTrackTypeSKYWALKING_V2   = 2,
    FTNetworkTrackTypeSKYWALKING_V3   = 3,
};
NS_ASSUME_NONNULL_BEGIN

@interface FTMobileConfig : NSObject
/**
 * @method 指定初始化方法，设置 metricsUrl
 * @param metricsUrl FT-GateWay metrics 写入地址
 * @param akId       access key ID
 * @param akSecret   access key Secret
 * @param enableRequestSigning 配置是否需要进行请求签名 为YES 时akId与akSecret 不能为空
 * @return 配置对象
 */
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl datawayToken:(nullable NSString *)token akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning;
/**
 * @method 指定初始化方法，设置 metricsUrl 配置是否不需要进行请求签名
 * @param metricsUrl FT-GateWay metrics 写入地址
 * @return 配置对象
 */
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl datawayToken:(nullable NSString *)token;

/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
#pragma mark ========== 基本设置 ==========
/* SDK版本 */
@property (nonatomic, copy) NSString *sdkAgentVersion;
/* SDK版本 */
@property (nonatomic, copy) NSString *sdkTrackVersion;

/*应用名称（默认：info.plist中的CFBundleDisplayName）*/
@property (nonatomic ,copy) NSString *appName;

/*FT-GateWay metrics 写入地址*/
@property (nonatomic, copy) NSString *metricsUrl;

@property (nonatomic, copy) NSString *datawayToken;

/*配置是否需要进行请求签名*/
@property (nonatomic, assign) BOOL enableRequestSigning;
/*access key ID*/
@property (nonatomic, copy) NSString *akId;

/*access key Secret*/
@property (nonatomic, copy) NSString *akSecret;

/*TAG 中的设备信息*/
@property (nonatomic) FTMonitorInfoType monitorInfoType;

/*是否开启绑定用户数据*/
@property (nonatomic, assign) BOOL needBindUser;

/*请求HTTP请求头X-Datakit-UUID 数据采集端  如果用户不设置会自动配置 */
@property (nonatomic, copy) NSString *XDataKitUUID;
#pragma mark ==========  FTAutoTrack 全埋点配置 ==========
/**
 * 默认为NO   开启需要使用 FTAutoTrackSDK  总开关
 */
@property (nonatomic, assign) BOOL enableAutoTrack;
/**
 * @property
 *
 * @abstract
 * 打开 SDK 设置追踪事件类型, 默认只追踪 App 启动 / 关闭、进入页面、元素点击
 *
 * @discussion
 * 该功能自动追踪 App 的一些行为，例如 SDK 初始化、App 启动 / 关闭、进入页面 等等，具体信息请参考文档:
 * 该功能默认关闭   开启需要使用 FTAutoTrackSDK 且 enableAutoTrack = YES
 */
@property (nonatomic) FTAutoTrackEventType autoTrackEventType;

/**
 * @abstract
 *  抓取某一类型的 View
 *  与 黑名单  二选一使用  若都没有则为全抓取
 *  eg: @[UITableView.class];
 */
@property (nonatomic, copy) NSArray<Class> *whiteViewClass;
/**
 * @abstract
 *  忽略某一类型的 View
 *  与 白名单  二选一使用  若都没有则为全抓取
 */
@property (nonatomic, copy) NSArray<Class> *blackViewClass;

/**
 *  抓取界面（实例对象数组）  白名单 与 黑名单 二选一使用  若都没有则为全抓取
 * eg: @[@"HomeViewController"];  字符串类型
 */
@property (nonatomic, copy) NSArray *whiteVCList;
/**
 *  抓取界面（实例对象数组）  黑名单 与白名单  二选一使用  若都没有则为全抓取
 */
@property (nonatomic, copy) NSArray *blackVCList;
/**
 * 是否开启页面、视图树 描述 默认 NO
*/
@property (nonatomic, assign) BOOL enabledPageVtpDesc;
#pragma mark ========== 日志相关 ==========
/*设置是否允许打印日志*/
@property (nonatomic, assign) BOOL enableLog;
/*设置是否允许打印描述日志*/
@property (nonatomic, assign) BOOL enableDescLog;
/*设置是否需要采集崩溃日志*/
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/*设置日志所属业务或服务的名称*/
@property (nonatomic, copy) NSString *traceServiceName;
/*日志的来源 默认为：ft_mobile_sdk_ios*/
@property (nonatomic, copy) NSString *source;
/**
 *设置是否需要采集控制台日志 默认为NO
 */
@property (nonatomic, assign) BOOL traceConsoleLog;
/**
 * 可以在 web 版本日志中，查看到对应上报的日志，事件支持启动应用，进入页面，离开页面，事件点击等等  默认为NO
 * 需 AutoTrack 开启 ，设置对应采集类型时生效
*/
@property (nonatomic, assign) BOOL eventFlowLog;

#pragma mark - 网络请求信息采集
/**
 * 设置网络请求信息采集 默认为NO
*/
@property (nonatomic, assign) BOOL networkTrace;
/**
 *  设置网络请求信息采集时 采样率 0-1 默认为 1
 */
@property (nonatomic, assign) float traceSamplingRate;
/**
 *  设置网络请求信息采集时 使用链路追踪类型 type 默认为 Zipkin
*/
@property (nonatomic, assign) FTNetworkTrackType networkTraceType;
/**
 *  开启网络请求信息采集 并设置链路追踪类型 type 默认为 Zipkin
 *  @param  type   链路追踪类型 默认为 Zipkin
*/
-(void)networkTraceWithTraceType:(FTNetworkTrackType)type;
/**
 *  设置 网络请求采集 支持的 contentType
 *  默认采集  Content-Type（application/json、application/xml、application/javascript、text/html、text/xml、text/plain、application/x-www-form-urlencoded、multipart/form-data）
*/
@property (nonatomic, copy) NSArray <NSString *> *networkContentType;
@end

NS_ASSUME_NONNULL_END
