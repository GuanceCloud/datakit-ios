//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
#import "FTReadWriteHelper.h"

NS_ASSUME_NONNULL_BEGIN
@class FTUserInfo;
/// 预置属性
@interface FTPresetProperty : NSObject
/// 应用唯一 ID
@property (nonatomic, copy) NSString *appid;
/// 用户设置的 logger globalContext
@property (nonatomic, strong) NSDictionary *logContext;
/// 用户设置的 rum globalContext
@property (nonatomic, strong) NSDictionary *rumContext;
/// 读写保护的用户信息
@property (nonatomic, strong) FTReadWriteHelper<FTUserInfo*> *userHelper;
/// 设备名称
+ (NSString *)deviceInfo;
/// 通讯公司
+ (NSString *)telephonyCarrier;
/// 初始化方法
/// - Parameter config: SDK 基本配置
- (instancetype)initWithMobileConfig:(FTMobileConfig *)config;
/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;

/// 获取 Rum ES 公共Tag
/// - Parameter terminal: 设备类型
- (NSDictionary *)rumPropertyWithTerminal:(NSString *)terminal;
/// 获取 logger 数据公共 Tag
/// - Parameters:
///   - status: 事件等级和状态
///   - serviceName: 日志所属业务或服务的名称
- (NSDictionary *)loggerPropertyWithStatus:(FTLogStatus)status serviceName:(NSString *)serviceName;

/// 重置
/// - Parameter config: SDK 基础配置
- (void)resetWithMobileConfig:(FTMobileConfig *)config;
@end

NS_ASSUME_NONNULL_END
