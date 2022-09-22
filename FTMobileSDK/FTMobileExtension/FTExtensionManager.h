//
//  FTExtensionManager.h
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTRumConfig,FTTraceConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTExtensionManager : NSObject
/**
 *    @brief  设置开启采集 Crash。在初始化方法
 *
 *    @param groupIdentifier 设置文件共享 Group Identifier。
*/
+ (void)startWithApplicationGroupIdentifier:(NSString *)groupIdentifier;

+ (instancetype)sharedInstance;
/**
 * @abstract
 * 配置 RUM Config 开启 RUM 功能
 *
 * @param rumConfigOptions   rum配置参数
 */
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions;
/**
 * @abstract
 * 配置 Trace Config 开启 Trace 功能
 *
 * @param traceConfigOptions   trace配置参数
 */
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions;
/**
 *    @brief  设置是否开启打印 sdk 的 log 信息，默认关闭。在初始化方法之前调用
 *
 *    @param enable 设置为YES，则打印sdk的log信息。
*/
+ (void)enableLog:(BOOL)enable;

@end

NS_ASSUME_NONNULL_END
