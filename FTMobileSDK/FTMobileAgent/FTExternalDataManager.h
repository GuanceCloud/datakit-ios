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
@interface FTExternalDataManager : NSObject<FTExternalRum>
+ (instancetype)sharedManager;
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
/**
 * 离开页面
 */
-(void)stopView;
/**
 * 添加 Click Action 事件
 * @param actionName 事件名称
 */
- (void)addClickActionWithName:(NSString *)actionName;
/**
 * 添加 Error 事件
 * @param type       error 类型
 * @param message    错误信息
 * @param stack      堆栈信息
 */
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
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

NS_ASSUME_NONNULL_END
