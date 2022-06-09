//
//  FTMobileAgent.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
#import "FTExternalDataManager.h"
#import "FTResourceMetricsModel.h"
#import "FTResourceContentModel.h"
#import "FTTraceManager.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTMobileAgent : NSObject

-(instancetype) init __attribute__((unavailable("请使用 sharedInstance 进行访问")));

#pragma mark ========== init instance ==========
/**
 * @abstract
 * 返回之前所初始化好的单例
 *
 * @discussion
 * 调用这个方法之前，必须先调用 startWithConfigOptions 这个方法
 *
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;
/**
 * @abstract
 * SDK 初始化方法
 * @param configOptions     配置参数
*/
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;
/**
 * @abstract
 * 配置 RUM Config 开启 RUM 功能
 *
 * @param rumConfigOptions   rum配置参数
 */
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions;
/**
 * @abstract
 * 配置 Logger Config 开启 Logger 功能
 *
 * @param loggerConfigOptions   logger配置参数
 */
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions;
/**
 * @abstract
 * 配置 Trace Config 开启 Trace 功能
 *
 * @param traceConfigOptions   trace配置参数
 */
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions;

/**
 * @abstract
 * 日志上报
 *
 * @param content  日志内容，可为json字符串
 * @param status   事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info

 */
-(void)logging:(NSString *)content status:(FTLogStatus)status;

/**
 * @abstract
 * 绑定用户信息
 * 
 * @param Id        用户Id
*/
- (void)bindUserWithUserID:(NSString *)Id;
/**
 * @abstract
 * 注销当前用户
*/
- (void)logout;


@end

NS_ASSUME_NONNULL_END
