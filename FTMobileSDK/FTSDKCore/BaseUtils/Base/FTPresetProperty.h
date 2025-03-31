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
@property (nonatomic, copy) NSString *appID;
/// 读写保护的用户信息
@property (nonatomic, strong) FTReadWriteHelper<FTUserInfo*> *userHelper;
@property (nonatomic, copy) NSString *sdkVersion;
@property (nonatomic, strong) NSDictionary *rumGlobalContext;
@property (nonatomic, strong) NSDictionary *logGlobalContext;
/// 设备名称
+ (NSString *)deviceInfo;
+ (NSString *)cpuArch;
+ (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode;
#if FT_MAC
+ (NSString *)getDeviceUUID;
+ (NSString *)macOSDeviceModel;
#endif
+ (NSString *)getOSVersion;
+ (instancetype)sharedInstance;
/// 初始化方法
/// - Parameter version: 版本号
/// - Parameter sdkVersion: SDK 版本号
/// - Parameter env: 环境
/// - Parameter service: 服务
/// - Parameter globalContext: 全局自定义属性
- (void)startWithVersion:(NSString *)version sdkVersion:(NSString *)sdkVersion env:(NSString *)env service:(NSString *)service globalContext:(NSDictionary *)globalContext pkgInfo:(nullable NSDictionary *)pkgInfo;

/// 获取 Rum ES 公共Tag
- (NSMutableDictionary *)rumProperty;
- (NSMutableDictionary *)rumWebViewProperty;
- (NSDictionary *)rumDynamicProperty;
/// 获取 logger 数据公共 Tag
/// - Parameters:
///   - status: 事件等级和状态
- (NSDictionary *)loggerProperty;
- (NSDictionary *)loggerDynamicProperty;

- (void)appendGlobalContext:(NSDictionary *)context;

- (void)appendRUMGlobalContext:(NSDictionary *)context;

- (void)appendLogGlobalContext:(NSDictionary *)context;

- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
