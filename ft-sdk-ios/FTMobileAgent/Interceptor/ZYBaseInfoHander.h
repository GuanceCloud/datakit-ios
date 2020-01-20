//
//  ZYDeviceInfoHander.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
extern NSString * _Nullable const ZYBaseInfoHanderDeviceType;
extern NSString * _Nullable const ZYBaseInfoHanderDeviceCPUType;
extern NSString * _Nullable const ZYBaseInfoHanderDeviceCPUClock;
extern NSString * _Nullable const ZYBaseInfoHanderBatteryTotal;
extern NSString * _Nullable const ZYBaseInfoHanderDeviceGPUType;

NS_ASSUME_NONNULL_BEGIN

@interface ZYBaseInfoHander : NSObject
+ (NSDictionary *)ft_getDeviceInfo;
+ (NSString *)getTelephonyInfo;
+ (NSString *)convertToJsonData:(NSDictionary *)dict;
+ (NSString *)resolution;
+ (long)getCurrentTimestamp;
+ (NSString *)getSSOSignWithAkSecret:(NSString *)akSecret datetime:(NSString *)datetime data:(NSString *)data;
+ (NSString *)currentGMT;
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;
+ (NSString *)defaultUUID;
+ (long )ft_cpuUsage;
+ (NSString *)ft_getBatteryUse;
+ (long long)getTotalMemorySize;
+ (NSString *)usedMemory;
+ (NSString *)gt_getFrontCameraPixel;
+ (NSString *)gt_getBackCameraPixel;
@end

NS_ASSUME_NONNULL_END
