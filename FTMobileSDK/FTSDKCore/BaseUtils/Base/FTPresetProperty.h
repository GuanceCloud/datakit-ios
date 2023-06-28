//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
#import "FTSDKCompat.h"
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
@property (nonatomic, copy) NSString *sdkVersion;
/// 设备名称
+ (NSString *)deviceInfo;
#if FT_MAC
+ (NSString *)getDeviceUUID;
+ (NSString *)macOSdeviceModel;
+ (NSString *)macOSSystermVersion;
#endif

/// 初始化方法
/// - Parameter version: 版本号
/// - Parameter env: 环境
/// - Parameter service: 服务
/// - Parameter globalContext: 全局自定义属性
- (instancetype)initWithVersion:(NSString *)version env:(NSString *)env service:(NSString *)service globalContext:(NSDictionary *)globalContext;
/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;

/// 获取 Rum ES 公共Tag
- (NSDictionary *)rumProperty;
/// 获取 logger 数据公共 Tag
/// - Parameters:
///   - status: 事件等级和状态
- (NSDictionary *)loggerPropertyWithStatus:(LogStatus)status;
/// 重新设置 SDK 配置项
/// - Parameter version: 版本号
/// - Parameter env: 环境
/// - Parameter service: 服务
/// - Parameter globalContext: 全局自定义属性
- (void)resetWithVersion:(NSString *)version env:(NSString *)env service:(NSString *)service globalContext:(NSDictionary *)globalContext;
@end

NS_ASSUME_NONNULL_END
