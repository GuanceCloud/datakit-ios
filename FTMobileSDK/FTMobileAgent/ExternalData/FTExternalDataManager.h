//
//  FTExternalDataManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef enum FTAppState:NSUInteger FTAppState;

@class FTResourceMetricsModel,FTResourceContentModel;

/// 实现用户自定义 RUM、 Trace 功能的类
@interface FTExternalDataManager : NSObject

/// 单例
+ (instancetype)sharedManager;
#pragma mark --------- Rum ----------
/// 创建页面
///
/// 在 `-startViewWithName` 方法前调用，该方法用于记录页面的加载时间，如果无法获得加载时间该方法可以不调用。
/// - Parameters:
///   - viewName: 页面名称
///   - loadTime: 页面加载时间
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime;
/// 进入页面
///
/// - Parameters:
///   - viewName: 页面名称
-(void)startViewWithName:(NSString *)viewName;

/// 进入页面
/// - Parameters:
///   - viewName: 页面名称
///   - property: 事件自定义属性(可选)
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property;

/// 离开页面
-(void)stopView;

/// 离开页面
/// - Parameter property: 事件自定义属性(可选)
-(void)stopViewWithProperty:(nullable NSDictionary *)property;


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
/// 添加 Error 事件
///
/// - Parameters:
///   - type: error 类型
///   - message: 错误信息
///   - stack: 堆栈信息
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
/// 添加 Error 事件
/// - Parameters:
///   - type: error 类型
///   - message: 错误信息
///   - stack: 堆栈信息
///   - property: 事件自定义属性(可选)
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

/// 添加 Error 事件
/// - Parameters:
///   - type: error 类型
///   - state: 程序运行状态
///   - message: 错误信息
///   - stack: 堆栈信息
///   - property: 事件自定义属性(可选)
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state  message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

/// 添加 卡顿 事件
///
/// - Parameters:
///   - stack: 卡顿堆栈
///   - duration: 卡顿时长（纳秒）
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;

/// 添加 卡顿 事件
/// - Parameters:
///   - stack: 卡顿堆栈
///   - duration: 卡顿时长（纳秒）
///   - property: 事件自定义属性(可选)
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(nullable NSDictionary *)property;

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

/// HTTP 添加请求数据
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

#pragma mark --------- Trace ----------
/// 获取 trace（链路追踪）需要添加的请求头
/// - Parameters:
///   - url: 请求 URL
- (nullable NSDictionary *)getTraceHeaderWithUrl:(NSURL *)url;
/// 开启 `enableLinkRUMData` 时，获取 trace（链路追踪）需要添加的请求头，
/// - Parameters:
///   - key: 请求标识
///   - url: 请求 URL
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;
#pragma mark --------- DEPRECATED ----------

/// 添加 Click Action 事件. actionType 默认为 `click`
///
/// - Parameters:
///   - actionName: 事件名称
- (void)addClickActionWithName:(NSString *)actionName DEPRECATED_MSG_ATTRIBUTE("已废弃，请使用 -startAction:actionType:property: 方法替换");

/// 添加 Click Action 事件，actionType 默认为 `click`
/// - Parameters:
///   - actionName: 事件名称
///   - property: 事件自定义属性(可选)
- (void)addClickActionWithName:(NSString *)actionName property:(nullable NSDictionary *)property DEPRECATED_MSG_ATTRIBUTE("已废弃，请使用 -startAction:actionType:property: 方法替换");

/// 添加 Action 事件
///
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType DEPRECATED_MSG_ATTRIBUTE("已废弃，请使用 -startAction:actionType:property: 方法替换");
/// 添加 Action 事件
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
///   - property: 事件自定义属性(可选)
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property DEPRECATED_MSG_ATTRIBUTE("已废弃，请使用 -startAction:actionType:property: 方法替换");
@end

NS_ASSUME_NONNULL_END
