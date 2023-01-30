//
//  FTBaseInfoHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// 一些工具方法
@interface FTBaseInfoHandler : NSObject
/// FT access 签名算法
/// - Parameters:
///   - method: HTTP方法
///   - contentType: 请求的 contentType
///   - dateStr: GMT 格式时间字符串
///   - akSecret: akSecret
///   - data: 加密数据 data
/// - Returns: 签名后字符串
+(NSString*)signatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data;

/// HTTP 请求头 X-Datakit-UUID 数据采集端
+ (NSString *)XDataKitUUID;

/// userID 用户未设置时的默认值
+ (NSString *)userSessionId;

/// 将字典转换成字符串
/// - Parameter dict: 待转化字典
+ (NSString *)convertToStringData:(NSDictionary *)dict;

/// url_path_group 处理
/// - Parameter url: URL
+ (NSString *)replaceNumberCharByUrl:(NSURL *)url;

/// bool 值转换字符串
/// - Parameter isTrue: bool 值
+ (NSString *)boolStr:(BOOL)isTrue;

/// 采样率判断
/// - Parameter sampling: 用户设置的采样率
/// - Returns: 是否进行采样
+ (BOOL)randomSampling:(int)sampling;

#if !TARGET_OS_OSX
/// 电话运营商
+(NSString *)telephonyCarrier;
#endif
@end

NS_ASSUME_NONNULL_END
