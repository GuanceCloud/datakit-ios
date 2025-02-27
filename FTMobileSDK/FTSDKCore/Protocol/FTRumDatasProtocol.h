//
//  FTRumDatasProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/13.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#ifndef FTAddRumDatasProtocol_h
#define FTAddRumDatasProtocol_h
NS_ASSUME_NONNULL_BEGIN
/// App 运行状态
typedef NS_ENUM(NSUInteger, FTAppState) {
    /// 未知
    FTAppStateUnknown,
    /// 启动中
    FTAppStateStartUp,
    /// 运行中
    FTAppStateRun,
};
/// rum 数据协议
@protocol FTRumDatasProtocol <NSObject>
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
///   - startTime: 卡顿开始时间
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)startTime;

/// 添加 卡顿 事件
/// - Parameters:
///   - stack: 卡顿堆栈
///   - duration: 卡顿时长（纳秒）
///   - startTime: 卡顿开始时间（纳秒级时间戳）
///   - property: 事件自定义属性(可选)
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)startTime property:(nullable NSDictionary *)property;

@optional
/**
 * 进入页面
 * @param viewId          页面id
 * @param viewName        页面名称
 * @param property        事件自定义属性(可选)
 */
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property;
/**
 * 离开页面
 * @param viewId         页面id
 * @param property       事件自定义属性(可选)
 */
-(void)stopViewWithViewID:(NSString *)viewId property:(nullable NSDictionary *)property;
@end
NS_ASSUME_NONNULL_END
#endif 
