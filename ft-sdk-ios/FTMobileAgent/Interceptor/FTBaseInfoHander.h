//
//  ZYDeviceInfoHander.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
extern NSString * _Nullable const FTBaseInfoHanderDeviceType;
extern NSString * _Nullable const FTBaseInfoHanderDeviceCPUType;
extern NSString * _Nullable const FTBaseInfoHanderDeviceCPUClock;
extern NSString * _Nullable const FTBaseInfoHanderBatteryTotal;
extern NSString * _Nullable const FTBaseInfoHanderDeviceGPUType;

NS_ASSUME_NONNULL_BEGIN

@interface FTBaseInfoHander : NSObject
+ (NSDictionary *)ft_getDeviceInfo;
/**
  获取运营商信息
 */
+ (NSString *)ft_getTelephonyInfo;
+ (NSString *)ft_convertToJsonData:(NSDictionary *)dict;
+ (NSString *)ft_resolution;
+ (long)ft_getCurrentTimestamp;
+ (NSString *)ft_getSSOSignWithAkSecret:(NSString *)akSecret datetime:(NSString *)datetime data:(NSString *)data;
+ (NSString *)ft_currentGMT;
+ (NSDictionary *)ft_dictionaryWithJsonString:(NSString *)jsonString;
+ (NSString *)ft_defaultUUID;
+ (long )ft_cpuUsage;
+ (NSString *)ft_getBatteryUse;
+ (long long)ft_getTotalMemorySize;
+ (NSString *)ft_usedMemory;
+ (NSString *)ft_getFrontCameraPixel;
+ (NSString *)ft_getBackCameraPixel;
@end

NS_ASSUME_NONNULL_END
