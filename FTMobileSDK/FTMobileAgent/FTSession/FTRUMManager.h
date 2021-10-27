//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import <UIKit/UIKit.h>
@class FTRumConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManager : FTRUMHandler
@property (nonatomic, strong) FTRumConfig *rumConfig;
-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig;
/**
 * 进入页面
 * @param viewController  进入页面控制器
 */
-(void)startView:(UIViewController *)viewController;
/**
 * 离开页面
 * @param viewController  控制器
 */
-(void)stopView:(UIViewController *)viewController;
/**
 * 点击事件
 * @param clickView  点击的view
 */
- (void)addAction:(UIView *)clickView;
/**
 * resource Start
 */
- (void)resourceStart:(NSString *)identifier;
/**
 * resource Success
 */
- (void)resourceSuccess:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time;
/**
 * resource Error
 */
- (void)resourceError:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time;

- (void)addWebviewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
/**
 * 当 traceConfig 开启 enableLinkRumData 时 获取 rum 信息
 */
-(NSDictionary *)getCurrentSessionInfo;

#pragma mark - flutter api -
/**
 * 进入页面
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
 * 点击事件
 * @param actionName 点击的事件名称
 */
- (void)addActionWithActionName:(NSString *)actionName;
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
/**
 * 崩溃
 * @param type       错误类型:java_crash/native_crash/abort/ios_crash
 * @param situation  启动时/启动后
 * @param message    错误信息
 * @param stack      错误堆栈
 */
- (void)addErrorWithType:(NSString *)type situation:(NSString *)situation message:(NSString *)message stack:(NSString *)stack;
/**
 * 卡顿
 * @param stack      卡顿堆栈
 * @param duration   卡顿时长
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;

@end

NS_ASSUME_NONNULL_END
