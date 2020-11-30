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
 * @enum  TAG 中的设备信息
 *
 * @constant
 *   FTMonitorInfoTypeMemory   - 内存总量、使用率
 *   FTMonitorInfoTypeLocation - 位置信息  国家、省、市、经纬度
 *   FTMonitorInfoTypeBluetooth- 蓝牙对外显示名称
 *   FTMonitorInfoTypeFPS      - 每秒传输帧数
 */
typedef NS_OPTIONS(NSUInteger, FTMonitorInfoType) {
    FTMonitorInfoTypeAll          = 0xFFFFFFFF,
    FTMonitorInfoTypeMemory       = 1 << 1,
    FTMonitorInfoTypeLocation     = 1 << 2,
    FTMonitorInfoTypeBluetooth    = 1 << 3,
    FTMonitorInfoTypeFPS          = 1 << 4,
};
/**
 * @enum
 * 网络链路追踪使用类型
 *
 * @constant
 *   FTNetworkTrackTypeZipkin       - Zipkin
 *   FTNetworkTrackTypeJaeger       - Jaeger
 */
typedef NS_ENUM(NSInteger, FTNetworkTraceType) {
    FTNetworkTraceTypeZipkin          = 0,
    FTNetworkTraceTypeJaeger          = 1,
    FTNetworkTraceTypeSKYWALKING_V2   = 2,
    FTNetworkTraceTypeSKYWALKING_V3   = 3,
};
NS_ASSUME_NONNULL_BEGIN

@interface FTMobileConfig : NSObject
/**
 * @method 指定初始化方法，设置 datawayUrl
 * @param datawayUrl FT-GateWay metrics 写入地址
 * @param akId       access key ID
 * @param akSecret   access key Secret
 * @param enableRequestSigning 配置是否需要进行请求签名 为YES 时akId与akSecret 不能为空
 * @return 配置对象
 */
- (instancetype)initWithDatawayUrl:(nonnull NSString *)datawayUrl datawayToken:(nullable NSString *)token akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning;
/**
 * @method 指定初始化方法，设置 datawayUrl 配置是否不需要进行请求签名
 * @param datawayUrl FT-GateWay metrics 写入地址
 * @return 配置对象
 */
- (instancetype)initWithDatawayUrl:(nonnull NSString *)datawayUrl datawayToken:(nullable NSString *)token;

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
@property (nonatomic, copy) NSString *datawayUrl;
/**
 * 应用唯一ID，在DataFlux控制台上面创建监控时自动生成。
 */
@property (nonatomic, copy) NSString *appid;
/**
 * 应用名称。
 */
@property (nonatomic, copy) NSString *service;
/**
 * 应用版本号。
 */
@property (nonatomic, copy) NSString *version;

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
/*设置是否允许打印日志*/
@property (nonatomic, assign) BOOL enableLog;
/*设置日志所属业务或服务的名称*/
@property (nonatomic, copy) NSString *traceServiceName;
/*日志的来源 默认为：ft_mobile_sdk_ios*/
@property (nonatomic, copy) NSString *source;
/**
 * 环境字段。属性值：prod/gray/pre/common/local。其中
 * prod：线上环境
 * gray：灰度环境
 * pre：预发布环境
 * common：日常环境
 * local：本地环境
 */
@property (nonatomic, copy) NSString *env;
/**
 * 预留业务自定义字段，打好标后每一条日志都会带有此标记。（不限量）
 */
@property (nonatomic, copy) NSString *tags;
/**
 *  日志采样配置，属性值：0或者100，100则表示百分百采集，不做数据样本压缩。
 */
@property (nonatomic, assign) int samplerate;
/*设置是否需要采集崩溃日志*/
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/**
 * 设置是否需要采集卡顿
 * 采集fps小于10
 */
@property (nonatomic, assign) BOOL enableTrackAppUIBlock;
/**
 * 设置是否需要采集卡顿
 * runloop采集主线程卡顿
*/
@property (nonatomic, assign) BOOL enableTrackAppANR;
#pragma mark - 网络请求信息采集
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
/**
 *  设置 网络请求采集 支持的 contentType
 *  默认采集  Content-Type（application/json、application/xml、application/javascript、text/html、text/xml、text/plain、application/x-www-form-urlencoded、multipart/form-data）
*/
@property (nonatomic, copy) NSArray <NSString *> *networkContentType;
@end

NS_ASSUME_NONNULL_END
