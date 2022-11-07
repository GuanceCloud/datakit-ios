//
//  FTAddRumDatasProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/13.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#ifndef FTAddRumDatasProtocol_h
#define FTAddRumDatasProtocol_h
NS_ASSUME_NONNULL_BEGIN
/// rum 数据协议
@protocol FTRumDatasProtocol <NSObject>
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
 * 添加  Action 事件
 * @param actionName 事件名称
 * @param actionType 事件类型
 */
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType;
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
 * 进入页面
 * @param viewId          页面id
 * @param viewName        页面名称
 */
@optional
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName;
/**
 * 离开页面
 * @param viewId         页面id
 */
-(void)stopViewWithViewID:(NSString *)viewId;
@end
NS_ASSUME_NONNULL_END
#endif /* FTExternalRumProtocol_h */
