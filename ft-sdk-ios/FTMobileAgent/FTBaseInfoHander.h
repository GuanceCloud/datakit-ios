//
//  FTBaseInfoHander.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FTTrackBean.h"
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
 *  FT access 签名算法
 *
 *  @return 签名后字符串
 */
+(NSString*)ft_getSSOSignWithRequest:(NSMutableURLRequest *)request akSecret:(NSString *)akSecret data:(NSString *)data;
/**
 *  @abstract
 *  将json字符串转换成字典
 *
 *  @return 转换后字典
 */
+ (NSDictionary *)ft_dictionaryWithJsonString:(NSString *)jsonString;
+ (id)repleacingSpecialCharactersField:(id )str;
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
 *  FTStatus 字符串转换
*/
+(NSString *)ft_getFTstatueStr:(FTStatus)status;
+(NSString *)ft_getNetworkSpanID;
+(NSString *)ft_getNetworkTraceID;
@end

NS_ASSUME_NONNULL_END
