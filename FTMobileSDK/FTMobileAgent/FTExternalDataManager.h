//
//  FTExternalDataManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTExternalRumProtocol.h"
NS_ASSUME_NONNULL_BEGIN
/// 用户自定义数据管理类
///
/// 用户可以自定义 RUM 相关数据
@interface FTExternalDataManager : NSObject<FTExternalRum>
/// 单例
+ (instancetype)sharedManager;
/// 创建页面
///
/// 在 `-startViewWithName` 方法前调用，该方法用于记录页面的加载时间，如果无法获得加载时间该方法可以不调用。
///
/// - Parameters:
///   - viewName: 页面名称
///   - loadTime: 页面加载时间
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime;
/// 进入页面
///
/// - Parameters:
///   - viewName: 页面名称
-(void)startViewWithName:(NSString *)viewName;
/// 离开页面
-(void)stopView;
/// 添加 Click Action 事件
///
/// - Parameters:
///   - actionName: 事件名称
- (void)addClickActionWithName:(NSString *)actionName;
/// 添加 Action 事件
///
/// - Parameters:
///   - actionName: 事件名称
///   - actionType: 事件类型
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType;
/// 添加 Error 事件
///
/// - Parameters:
///   - type: error 类型
///   - message: 错误信息
///   - stack: 堆栈信息
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
/// 添加 卡顿 事件
///
/// - Parameters:
///   - stack: 卡顿堆栈
///   - duration: 卡顿时长（纳秒）
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;
/// HTTP 请求开始
///
/// - Parameters:
///   - key: 请求标识
- (void)startResourceWithKey:(NSString *)key;
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
@end

NS_ASSUME_NONNULL_END
