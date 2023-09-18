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
typedef NS_ENUM(NSUInteger, FTAppState) {
    FTAppStateUnknown,
    FTAppStateStartUp,
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
/// 添加 Action 事件
///
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType;
/// 添加 Action 事件
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
///   - property: 事件自定义属性(可选)
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;

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

@optional
/// 添加 Click Action 事件
///
/// - Parameters:
///   - actionName: 事件名称
- (void)addClickActionWithName:(NSString *)actionName;

/// 添加 Click Action 事件
/// - Parameters:
///   - actionName: 事件名称
///   - property: 事件自定义属性(可选)
- (void)addClickActionWithName:(NSString *)actionName property:(nullable NSDictionary *)property;
/**
 * 进入页面
 * @param viewId          页面id
 * @param viewName        页面名称
 */
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property;
/**
 * 离开页面
 * @param viewId         页面id
 */
-(void)stopViewWithViewID:(NSString *)viewId property:(nullable NSDictionary *)property;
@end
NS_ASSUME_NONNULL_END
#endif 
