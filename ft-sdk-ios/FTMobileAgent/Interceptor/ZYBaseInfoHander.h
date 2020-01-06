//
//  ZYDeviceInfoHander.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZYBaseInfoHander : NSObject
+ (NSString *)getDeviceType;
+ (NSString *)getTelephonyInfo;
//+ (NSString *)geZYBaseInfoHanderSString *)resolution;
+ (NSString *)convertToJsonData:(NSDictionary *)dict;
+ (NSString *)resolution;
+ (long)getCurrentTimestamp;
+ (NSString *)getSSOSignWithAkSecret:(NSString *)akSecret datetime:(NSString *)datetime data:(NSString *)data;
+ (NSString *)currentGMT;
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;
+ (NSString *)defaultUUID;
+ (NSString *)ft_cpuUsage;
+ (NSString *)ft_getCPUType;
@end

NS_ASSUME_NONNULL_END
