//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTDataModifier.h"
#import "FTEnumConstant.h"
#import "FTSDKCompat.h"
#import "FTReadWriteHelper.h"
NS_ASSUME_NONNULL_BEGIN
@class FTUserInfo;
/// 预置属性
@interface FTPresetProperty : NSObject

/// 读写保护的用户信息
@property (nonatomic, strong) FTReadWriteHelper<FTUserInfo*> *userHelper;
@property (nonatomic, strong, readonly) NSDictionary *loggerTags;
@property (nonatomic, strong, readonly) NSMutableDictionary *rumTags;
@property (nonatomic, strong, readonly) NSDictionary *rumStaticFields;
@property (nonatomic, strong, readonly) NSMutableDictionary *sessionReplayTags;

/// 设置数据更改器
@property (nonatomic, copy) FTLineDataModifier lineDataModifier;
@property (nonatomic, copy) NSString *sessionReplaySource;
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

- (void)setDataModifier:(FTDataModifier)dataModifier lineDataModifier:(FTLineDataModifier)lineDataModifier;

- (void)setRUMAppID:(NSString *)appID sampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate rumGlobalContext:(NSDictionary *)rumGlobalContext;

-(void)setLogGlobalContext:(NSDictionary *)logGlobalContext;

- (NSDictionary *)rumDynamicTags;

-(void)setSessionReplaySource:(NSString *)sessionReplaySource;

- (NSDictionary *)rumDynamicProperty;

- (NSDictionary *)loggerDynamicTags;

- (void)appendGlobalContext:(NSDictionary *)context;

- (void)appendRUMGlobalContext:(NSDictionary *)context;

- (void)appendLogGlobalContext:(NSDictionary *)context;

- (NSArray<NSDictionary *> *)applyLineModifier:(NSString *)measurement
                                          tags:(NSDictionary *)tags
                                        fields:(NSDictionary *)fields;

- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
