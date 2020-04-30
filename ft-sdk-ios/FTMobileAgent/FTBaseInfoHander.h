//
//  FTBaseInfoHander.h
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
/**
 *  获取设备相关信息
 */
+ (NSDictionary *)ft_getDeviceInfo;
/**
 *  获取运营商信息
 */
+ (NSString *)ft_getTelephonyInfo;
/**
 *  将字典转化Json字符串
 *  @param dict 需要转化的字典
 *  @return Json字符串
 */
+ (NSString *)ft_convertToJsonData:(NSDictionary *)dict;
/**
 *  获取设备分辨率
 */
+ (NSString *)ft_resolution;
/**
 *  @abstract
 *  获取当前时间戳
 *
 *  @return 时间戳
 */
+ (long long)ft_getCurrentTimestamp;
/**
 *  @abstract
 *  FT access 签名算法
 *
 *  @return 签名后字符串
 */
+(NSString*)ft_getSSOSignWithRequest:(NSMutableURLRequest *)request akSecret:(NSString *)akSecret data:(NSString *)data;
/**
 *  @abstract
 *  获取GMT格式的时间
 *
 *  @return GMT格式的时间
 */
+ (NSString *)ft_currentGMT;
/**
 *  @abstract
 *  将json字符串转换成字典
 *
 *  @return 转换后字典
 */
+ (NSDictionary *)ft_dictionaryWithJsonString:(NSString *)jsonString;

/**
 *  @abstract
 *  获取当前设备CPU使用率
 */
+ (long )ft_cpuUsage;
/**
 *  @abstract
 *  获取当前电池电量使用率
 */
+ (double)ft_getBatteryUse;
/**
 *  @abstract
 *  电池是否充电中
 */
+ (BOOL)ft_batteryIsCharing;
/**
 *  @abstract
 *  获取设备总内存
 */
+ (NSString *)ft_getTotalMemorySize;
/**
 *  @abstract
 *  获取当前内存使用率
 */
+ (double)ft_usedMemory;
/**
 *  @abstract
 *  获取前置摄像头像素
 */
+ (NSString *)ft_getFrontCameraPixel;
/**
 *  @abstract
 *  获取后置摄像头像素
 */
+ (NSString *)ft_getBackCameraPixel;
/**
 *  @abstract
 *  清除字符串前后的空格
 */
+ (NSString *)removeFrontBackBlank:(NSString *)str;
/**
 *  @abstract
 *  tags key、value 替换特殊字符 ',' '=' ' '
*/
+ (id)repleacingSpecialCharacters:(id )str;
/**
 *  @abstract
 *  Measurement 替换特殊字符 ' ' ','
*/
+ (id)repleacingSpecialCharactersMeasurement:(id )str;
/**
 *  @abstract
 *  校验 product 是否符合 只能包含英文字母、数字、中划线和下划线，最长 40 个字符，区分大小写
*/
+ (BOOL)verifyProductStr:(NSString *)product;
/**
 *  @abstract
 *  MD5
*/
+ (NSString *)ft_md5EncryptStr:(NSString *)string;
@end

NS_ASSUME_NONNULL_END
