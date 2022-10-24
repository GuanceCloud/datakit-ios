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
/// 返回之前所初始化好的单例.
///
/// 调用这个方法之前，必须先调用 startWithConfigOptions 这个方法
///
/// - Returns: Agent 单例.
+ (instancetype)sharedInstance;
/// SDK 初始化方法
///
/// 在启动 SDK 的同时配置基础的配置项，必要的配置项有 FT-GateWay metrics 写入地址。
///
/// SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 launch 事件）。
///
/// - Parameters:
///   - configOptions: SDK 基础配置项.
///
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;

/// 配置 RUM Config 开启 RUM 功能
///
/// RUM 用户监测，采集用户的行为数据，支持采集 View、Action、Resource、LongTask、Error。支持自动采集和手动添加。
///
/// - Parameters:
///   - rumConfigOptions: rum 配置项.
///
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions;
/// 配置 Logger Config 开启 Logger 功能
///
/// 日志服务
///
/// - Parameters:
///   - loggerConfigOptions: logger 配置项.
///
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions;

/// 配置 Trace Config 开启 Trace 功能
///
/// Trace
///
/// - Parameters:
///   - traceConfigOptions: trace 配置项.
///
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions;
/// 日志上报
///
/// 可以添加自定义日志。
///
/// - Parameters:
///   - content: 日志内容，可为 json 字符串
///   - status: 事件等级和状态
///
-(void)logging:(NSString *)content status:(FTLogStatus)status;

/// 绑定用户信息
///
/// - Parameters:
///   - Id:  用户Id
///
- (void)bindUserWithUserID:(NSString *)Id;

/// 绑定用户信息
///
/// - Parameters:
///   - Id:  用户Id
///   - userName: 用户名称
///   - userEmailL: 用户邮箱
///
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail;
/// 绑定用户信息
///
/// - Parameters:
///   - Id:  用户Id
///   - userName: 用户名称
///   - userEmail: 用户邮箱
///   - extra: 用户的额外信息
///
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail extra:(nullable NSDictionary *)extra;

/// 注销当前用户
///
- (void)logout;

@end

NS_ASSUME_NONNULL_END
