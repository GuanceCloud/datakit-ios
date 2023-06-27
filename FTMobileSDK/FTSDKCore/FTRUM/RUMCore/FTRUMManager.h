//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import "FTEnumConstant.h"
#import "FTErrorDataProtocol.h"
#import "FTRumDatasProtocol.h"
#import "FTRumResourceProtocol.h"
@class FTRumConfig,FTResourceMetricsModel,FTResourceContentModel,FTRUMMonitor;

NS_ASSUME_NONNULL_BEGIN
/// App 启动类型
typedef NS_ENUM(NSUInteger, FTLaunchType) {
    /// 热启动
    FTLaunchHot,
    /// 冷启动
    FTLaunchCold,
    /// 预启动，在APP启动前，系统进行了预加载
    FTLaunchWarm
};
@interface FTRUMManager : FTRUMHandler<FTRumResourceProtocol,FTErrorDataDelegate,FTRumDatasProtocol>
@property (nonatomic, assign) AppState appState;
@property (atomic,copy,readwrite) NSString *viewReferrer;
#pragma mark - init -

-(instancetype)initWithRumSampleRate:(int)sampleRate errorMonitorType:(ErrorMonitorType)errorMonitorType monitor:(nullable FTRUMMonitor *)monitor wirter:(id<FTRUMDataWriteProtocol>)writer;

#pragma mark - resource -
/// HTTP 请求开始
///
/// - Parameters:
///   - key: 请求标识
- (void)startResourceWithKey:(NSString *)key;
/// HTTP 请求开始
/// - Parameters:
///   - key: 请求标识
///   - property: 事件自定义属性(可选)
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

/// HTTP 请求数据
///
/// - Parameters:
///   - key: 请求标识
///   - metrics: 请求相关性能属性
///   - content: 请求相关数据
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/// HTTP 请求结束
///
/// - Parameters:
///   - key: 请求标识
- (void)stopResourceWithKey:(NSString *)key;
/// HTTP 请求结束
/// - Parameters:
///   - key: 请求标识
///   - property: 事件自定义属性(可选)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;
#pragma mark - webview js -

/// 添加 Webview 数据
/// - Parameters:
///   - measurement: measurement description
///   - tags: tags description
///   - fields: fields description
///   - tm: tm description
- (void)addWebviewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
#pragma mark - view -
/**
 * 创建页面
 * @param viewName     页面名称
 * @param loadTime     页面加载时间
 */
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime;
/**
 * 进入页面 viewId 内部管理
 * @param viewName        页面名称
 */
-(void)startViewWithName:(NSString *)viewName;
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property;
/**
 * 进入页面
 * @param viewId          页面id
 * @param viewName        页面名称
 */
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property;

/// 离开页面
-(void)stopView;
/**
 * 离开页面
 * @param viewId         页面id
 */
-(void)stopViewWithViewID:(NSString *)viewId property:(nullable NSDictionary *)property;
/**
 * 离开页面
 */
-(void)stopViewWithProperty:(nullable NSDictionary *)property;

#pragma mark - action -
/// 点击事件
/// @param actionName actionName 点击的事件名称
- (void)addClickActionWithName:(nonnull NSString *)actionName;
/**
 * 点击事件
 * @param actionName 点击的事件名称
 */
- (void)addClickActionWithName:(NSString *)actionName property:(nullable NSDictionary *)property;
/// action 事件
/// @param actionName 事件名称
/// @param actionType 事件类型
- (void)addActionName:(nonnull NSString *)actionName actionType:(nonnull NSString *)actionType;

/// action 事件
/// @param actionName 事件名称
/// @param actionType 事件类型
/// @param property 事件自定义属性(可选)
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;
/**
 * 应用启动
 * @param type      启动类型
 * @param duration  启动时长
 */
- (void)addLaunch:(FTLaunchType)type duration:(NSNumber *)duration;
/**
 * 应用终止使用
 */
- (void)applicationWillTerminate;
#pragma mark - Error / Long Task -
/// 崩溃
/// @param type 错误类型:java_crash/native_crash/abort/ios_crash
/// @param message 错误信息
/// @param stack 错误堆栈
- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack;
/**
 * 崩溃
 * @param type       错误类型:java_crash/native_crash/abort/ios_crash
 * @param message    错误信息
 * @param stack      错误堆栈
 * @param property   事件属性(可选)
 */
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;
/// 卡顿
/// @param stack 卡顿堆栈
/// @param duration 卡顿时长
- (void)addLongTaskWithStack:(nonnull NSString *)stack duration:(nonnull NSNumber *)duration;
/**
 * 卡顿
 * @param stack      卡顿堆栈
 * @param duration   卡顿时长
 * @param property   事件属性(可选)
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(nullable NSDictionary *)property;
#pragma mark - get LinkRumData -

/// 当 FTTraceConfig、FTLoggerConfig 开启 enableLinkRumData 时 获取 rum 信息
-(NSDictionary *)getCurrentSessionInfo;

/// 等待 rum 正在处理数据全部处理
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
