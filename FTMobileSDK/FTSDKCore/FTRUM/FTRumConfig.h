//
//  FTRumConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/22.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTRumView.h"
NS_ASSUME_NONNULL_BEGIN

/// RUM 过滤 resource 回调，返回：NO 表示要采集，YES 表示不需要采集。
typedef BOOL(^FTResourceUrlHandler)(NSURL * url);
/// RUM Resource 自定义添加额外属性
typedef NSDictionary<NSString *,id>* _Nullable (^FTResourcePropertyProvider)( NSURLRequest * _Nullable request, NSURLResponse * _Nullable response,NSData *_Nullable data, NSError *_Nullable error);
/// 支持自定义拦截 URLSessionTask Error，确认拦截返回 YES，不拦截返回 NO
typedef BOOL (^FTSessionTaskErrorFilter)(NSError *_Nonnull error);

typedef FTRumView* _Nullable (^FTUIKitViewsHandler)(UIViewController *viewController);

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

/// RUM废弃策略
typedef NS_ENUM(NSInteger, FTRUMCacheDiscard)  {
    /// 默认，当日志数据数量大于最大值（100_000）时，新数据不进行写入
    FTRUMDiscard,
    /// 当日志数据大于最大值时,废弃旧数据
    FTRUMDiscardOldest
};

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
/// 采集发生 Error 的会话
/// 当功能开启后，若原本未被采样率选中的 Session 发生错误，SDK 将对这些原本不采集的 Session 进行数据采集
@property (nonatomic, assign) int sessionOnErrorSampleRate;
/// 设置是否追踪用户操作，目前支持应用启动和点击操作，
/// 在有 View 事件的情况下，开启才能生效
@property (nonatomic, assign) BOOL enableTraceUserAction;
/// 设置是否追踪页面生命周期
@property (nonatomic, assign) BOOL enableTraceUserView;
/// 设置是否追踪用户网络请求  (仅作用于native http)
@property (nonatomic, assign) BOOL enableTraceUserResource;
/// 设置是否采集网络请求 Host IP (仅作用于native http，iOS 13及以上)
@property (nonatomic, assign) BOOL enableResourceHostIP;
/// 自定义采集 resource 规则。
/// 根据请求资源 url 判断是否需要采集对应资源数据，默认都采集。 返回：NO 表示要采集，YES 表示不需要采集。
@property (nonatomic, copy) FTResourceUrlHandler resourceUrlHandler;
/// 设置是否需要采集崩溃日志
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/// 设置是否需要采集卡顿
@property (nonatomic, assign) BOOL enableTrackAppFreeze;
/// 设置卡顿的阈值。单位毫秒 100 < freezeDurationMs ，默认 250ms
@property (nonatomic, assign) long freezeDurationMs;
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
@property (nonatomic, copy) NSDictionary<NSString*,NSString*> *globalContext;
/// RUM 最大缓存量,  默认 100_000
@property (nonatomic, assign) int rumCacheLimitCount;
/// RUM废弃策略
@property (nonatomic, assign) FTRUMCacheDiscard rumDiscardType;
/// RUM Resource 添加自定义属性
@property (nonatomic, copy) FTResourcePropertyProvider resourcePropertyProvider;
/// 拦截 URLSessionTask Error，确认拦截返回 YES，不拦截返回 NO
@property (nonatomic, copy) FTSessionTaskErrorFilter sessionTaskErrorFilter;

/// 设置开启采集 webview 数据，默认 YES
@property (nonatomic, assign) BOOL enableTraceWebView;
/// 设置允许采集 WebView 数据的特定主机或域名，nil 时全采集。
@property (nonatomic, copy) NSArray *allowWebViewHost;

/// A handler for user-defined collection of `UIViewControllers` as RUM views for tracking.
/// It takes effect when enableTraceUserView = YES.
/// RUM 将针对应用程序中呈现的每个 `UIViewController` 调用此回调。
///  - 如果给定的控制器需要启动一个 RUM 视图，需要返回 FTRumView 视图参数；
///  - 若要忽略该控制器，则返回 nil
@property (nonatomic, copy) FTUIKitViewsHandler uiKitViewsHandler;


/// 开启采集卡顿并设置卡顿的阈值。
/// - Parameter enableTrackAppFreeze: 设置是否需要采集卡顿
/// - Parameter freezeDurationMs: 卡顿的阈值，单位毫秒 100 < freezeDurationMs ，默认 250ms
-(void)setEnableTrackAppFreeze:(BOOL)enableTrackAppFreeze freezeDurationMs:(long)freezeDurationMs;
@end
NS_ASSUME_NONNULL_END
