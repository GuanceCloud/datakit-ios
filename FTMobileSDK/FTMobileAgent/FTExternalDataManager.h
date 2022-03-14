//
//  FTExternalDataManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
@class FTResourceContentModel,FTResourceMetricsModel;
NS_ASSUME_NONNULL_BEGIN
@protocol FTExternalTracing <NSObject>
/**
 * 获取 trace 请求头
 * @param url 请求标识
 */
- (NSDictionary *)getTraceHeaderUrl:(NSURL *)url;
@end
@protocol FTExternalRum <NSObject>
/**
 * 进入页面 viewId 内部管理
 * @param viewName        页面名称
 * @param viewReferrer    页面父视图
 * @param loadDuration    页面的加载时长
 */
-(void)startViewWithName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer loadDuration:(NSNumber *)loadDuration;
/**
 * 离开页面
 */
-(void)stopView;
/**
 * 添加 Action 事件
 * @param actionName 事件名称
 * @param actionType 事件类型
 */
- (void)addActionWithName:(NSString *)actionName actionType:(NSString *)actionType;
/**
 * 添加 Error 事件
 * @param type       error 类型
 * @param situation  APP状态
 * @param message    错误信息
 * @param stack      堆栈信息
 */
- (void)addErrorWithType:(NSString *)type situation:(AppState)situation message:(NSString *)message stack:(NSString *)stack;
/**
 * 添加 卡顿 事件
 * @param stack      卡顿堆栈
 * @param duration   卡顿时长
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;
/**
 * 请求开始
 * @param key       请求标识
 */
- (void)startResourceWithKey:(NSString *)key;
/**
 * 请求数据
 * @param key       请求标识
 * @param metrics   请求相关性能属性
 * @param content   请求相关数据
 */
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/**
 * 请求结束
 * @param key       请求标识
 */
- (void)stopResourceWithKey:(NSString *)key;
@end
@interface FTExternalDataManager : NSObject<FTExternalTracing,FTExternalRum>
+ (instancetype)sharedManager;

@end

NS_ASSUME_NONNULL_END
