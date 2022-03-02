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
@class FTRumConfig,FTResourceMetricsModel,FTResourceContentModel;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManager : FTRUMHandler
@property (nonatomic, assign) AppState appState;
@property (atomic,copy,readwrite) NSString *viewReferrer;
#pragma mark - init -

-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig;

#pragma mark - resource -
/**
 * resource Start
 */
- (void)startResource:(NSString *)identifier;
/**
 * add resource metrics content
 */
- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;

- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(NSString *)spanID traceID:(NSString *)traceID;
/**
 * resource Stop
 */
- (void)stopResource:(NSString *)identifier;
#pragma mark - webview js -

- (void)addWebviewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
#pragma mark - view -
/**
 * 进入页面
 * @param viewId          页面id
 * @param viewName        页面名称
 * @param loadDuration    页面的加载时长
 */
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName  loadDuration:(NSNumber *)loadDuration;
/**
 * 进入页面 viewId 内部管理
 * @param viewName        页面名称
 * @param loadDuration    页面的加载时长
 */
-(void)startViewWithName:(NSString *)viewName  loadDuration:(NSNumber *)loadDuration;
/**
 * 离开页面
 * @param viewId         页面id
 */
-(void)stopViewWithViewID:(NSString *)viewId;
/**
 * 离开页面
 * viewId 内部管理
 */
-(void)stopView;

#pragma mark - action -

/**
 * 点击事件
 * @param actionName 点击的事件名称
 */
- (void)addClickActionWithName:(NSString *)actionName;
/**
 * 应用启动
 * @param isHot     是否是热启动
 * @param duration  启动时长
 */
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration;
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
 */
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
/**
 * 卡顿
 * @param stack      卡顿堆栈
 * @param duration   卡顿时长
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;
#pragma mark - get LinkRumData -

/**
 * 当 traceConfig 开启 enableLinkRumData 时 获取 rum 信息
 */
-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
