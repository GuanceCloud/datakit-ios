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
#import "FTLinkRumDataProvider.h"
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
@interface FTRUMManager : FTRUMHandler<FTRumResourceProtocol,FTErrorDataDelegate,FTRumDatasProtocol,FTLinkRumDataProvider>
@property (nonatomic, assign) FTAppState appState;
@property (atomic,copy,readwrite) NSString *viewReferrer;
#pragma mark - init -
-(instancetype)initWithRumDependencies:(FTRUMDependencies *)dependencies;

-(void)notifyRumInit;
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
#pragma mark - webView js -

/// 添加 WebView 数据
/// - Parameters:
///   - measurement: measurement description
///   - tags: tags description
///   - fields: fields description
///   - tm: tm description
- (void)addWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
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
-(void)stopViewWithViewID:(nullable NSString *)viewId property:(nullable NSDictionary *)property;
/**
 * 离开页面
 */
-(void)stopViewWithProperty:(nullable NSDictionary *)property;

#pragma mark - Action -

/// 启动 RUM Action。
///
/// RUM 会绑定该 Action 可能触发的 Resource、Error、LongTask 事件。避免在 0.1 s 内多次添加，同一个 View 在同一时间只会关联一个 Action，在上一个 Action 未结束时，新增的 Action 会被丢弃。
/// 与 `addAction:actionType:property` 方法添加 Action 互不影响。
///
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
///   - property: 事件自定义属性(可选)
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;

/// 添加 Action 事件.无 duration，无丢弃逻辑
///
/// 与 `startAction:actionType:property:` 启动的 RUM Action 互不影响。
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
///   - property: 事件自定义属性(可选)
- (void)addAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;
/**
 * 应用启动
 * @param type      启动类型
 * @param duration  启动时长
 */
- (void)addLaunch:(FTLaunchType)type launchTime:(NSDate*)time duration:(NSNumber *)duration;

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

- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack date:(NSDate *)date;
/// 卡顿
/// @param stack 卡顿堆栈
/// @param duration 卡顿时长
- (void)addLongTaskWithStack:(nonnull NSString *)stack duration:(nonnull NSNumber *)duration startTime:(long long)time;
/**
 * 卡顿
 * @param stack      卡顿堆栈
 * @param duration   卡顿时长
 * @param property   事件属性(可选)
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)time property:(nullable NSDictionary *)property;
#pragma mark - get LinkRumData -

/// 等待 rum 正在处理数据全部处理
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
