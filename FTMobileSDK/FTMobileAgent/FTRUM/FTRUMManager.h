//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import <UIKit/UIKit.h>
#import "FTEnumConstant.h"

@class FTRumConfig,FTResourceMetricsModel,FTResourceContentModel,FTRUMMonitor;

NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManager : FTRUMHandler
@property (nonatomic, assign) AppState appState;
@property (atomic,copy,readwrite) NSString *viewReferrer;
#pragma mark - init -

-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig monitor:(FTRUMMonitor *)monitor;

#pragma mark - resource -
/**
 * resource Start
 */
- (void)startResource:(NSString *)identifier context:(nullable NSDictionary *)context;
/**
 * add resource metrics content
 */
- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;

- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID;
/**
 * resource Stop
 */
- (void)stopResourceWithKey:(NSString *)key context:(nullable NSDictionary *)context;
#pragma mark - webview js -

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
-(void)startViewWithName:(NSString *)viewName context:(nullable NSDictionary *)context;
/**
 * 进入页面
 * @param viewId          页面id
 * @param viewName        页面名称
 */
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName context:(nullable NSDictionary *)context;
/**
 * 离开页面
 * @param viewId         页面id
 */
-(void)stopViewWithViewID:(NSString *)viewId context:(nullable NSDictionary *)context;
/**
 * 离开页面
 * viewId 内部管理
 */
-(void)stopViewWithContext:(nullable NSDictionary *)context;

#pragma mark - action -

/**
 * 点击事件
 * @param actionName 点击的事件名称
 */
- (void)addClickActionWithName:(NSString *)actionName context:(nullable NSDictionary *)context;
/**
 * action 事件
 * @param actionName 事件名称
 * @param actionType 事件类型
 */
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType context:(nullable NSDictionary *)context;
/**
 * 应用启动
 * @param isHot     是否是热启动
 * @param duration  启动时长
 */
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration;
/**
 * 应用启动
 * @param isHot     是否是热启动
 * @param duration  启动时长
 * @param isPreWarming 是否进行了预热
 */
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming;
/**
 * 应用终止使用
 */
- (void)applicationWillTerminate;
#pragma mark - Error / Long Task -
/**
 * 崩溃
 * @param type       错误类型:java_crash/native_crash/abort/ios_crash
 * @param message    错误信息
 * @param stack      错误堆栈
 * @param context 事件上下文(可选)
 */
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack context:(nullable NSDictionary *)context;
/**
 * 卡顿
 * @param stack      卡顿堆栈
 * @param duration   卡顿时长
 * @param context 事件上下文(可选)
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration context:(nullable NSDictionary *)context;
#pragma mark - get LinkRumData -

/**
 * 当 traceConfig 开启 enableLinkRumData 时 获取 rum 信息
 */
-(NSDictionary *)getCurrentSessionInfo;
/**
 * 等待 rum 正在处理数据全部处理
 */
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
