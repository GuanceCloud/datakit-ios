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
#import "FTURLSessionDelegate.h"
#import "FTTraceManager.h"

NS_ASSUME_NONNULL_BEGIN

/// FTMobileSDK
@interface FTMobileAgent : NSObject

-(instancetype) init __attribute__((unavailable("请使用 sharedInstance 进行访问")));

#pragma mark ========== init instance ==========
/// 返回之前所初始化好的单例.
/// 调用这个方法之前，必须先调用 startWithConfigOptions 这个方法
+ (instancetype)sharedInstance;
/// SDK 初始化方法
///
/// 在启动 SDK 的同时配置基础的配置项，必要的配置项有 FT-GateWay metrics 写入地址。
///
/// SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 launch 事件）。
/// - Parameter configOptions: SDK 基础配置项.
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;

/// 配置 RUM Config 开启 RUM 功能
///
/// RUM 用户监测，采集用户的行为数据，支持采集 View、Action、Resource、LongTask、Error。支持自动采集和手动添加。
/// - Parameter rumConfigOptions: rum 配置项.
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions;
/// 配置 Logger Config 开启 Logger 功能
///
/// - Parameters:
///   - loggerConfigOptions: logger 配置项.
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions;

/// 设置过滤 Trace Resource 域名
/// - Parameter handler: 判断是否采集回调，返回 YES 采集， NO 过滤掉
- (void)isIntakeUrl:(BOOL(^)(NSURL *url))handler;
/// 配置 Trace Config 开启 Trace 功能
///
/// - Parameters:
///   - traceConfigOptions: trace 配置项.
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions;
/// 添加自定义日志
///
/// - Parameters:
///   - content: 日志内容，可为 json 字符串
///   - status: 事件等级和状态
-(void)logging:(NSString *)content status:(FTLogStatus)status;

/// 添加自定义日志
/// - Parameters:
///   - content: 日志内容，可为 json 字符串
///   - status: 事件等级和状态
///   - property: 事件自定义属性(可选)
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;

/// 绑定用户信息
///
/// - Parameters:
///   - Id:  用户Id
- (void)bindUserWithUserID:(NSString *)userId;

/// 绑定用户信息
///
/// - Parameters:
///   - Id:  用户Id
///   - userName: 用户名称
///   - userEmailL: 用户邮箱
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail;
/// 绑定用户信息
///
/// - Parameters:
///   - Id:  用户Id
///   - userName: 用户名称
///   - userEmail: 用户邮箱
///   - extra: 用户的额外信息
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail extra:(nullable NSDictionary *)extra;

/// 注销当前用户
- (void)logout;

/// Track App Extension groupIdentifier 中缓存的数据
/// - Parameters:
///   - groupIdentifier: groupIdentifier
///   - completion: 完成 track 后的 callback
- (void)trackEventFromExtensionWithGroupIdentifier:(NSString *)groupIdentifier completion:(nullable void (^)(NSString *groupIdentifier, NSArray *events)) completion;


@end

NS_ASSUME_NONNULL_END
