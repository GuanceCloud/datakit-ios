//
//  FTMobileAgent+Public.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

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
 * 设置过滤 Trace Resource 域名
 */
- (void)isIntakeUrl:(BOOL(^)(NSURL *url))handler;
/**
 * @abstract
 * 日志上报
 *
 * @param content  日志内容，可为json字符串
 * @param status   事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info

 */
-(void)logging:(NSString *)content status:(FTLogStatus)status;

/// 日志上报
/// @param content 日志内容，可为json字符串
/// @param status  事件等级和状态
/// @param property 事件属性
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;

/**
 * @abstract
 * 绑定用户信息
 *
 * @param Id        用户Id
*/
- (void)bindUserWithUserID:(NSString *)Id;
/**
 * @abstract
 * 绑定用户信息
 *
 * @param Id        用户Id
 * @param userName  用户名称
*/
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail;
/**
 * @abstract
 * 绑定用户信息
 *
 * @param Id        用户Id
 * @param userName  用户名称
 * @param extra     用户的额外信息

*/
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail extra:(nullable NSDictionary *)extra;
/**
 * @abstract
 * 注销当前用户
*/
- (void)logout;

@end

NS_ASSUME_NONNULL_END
