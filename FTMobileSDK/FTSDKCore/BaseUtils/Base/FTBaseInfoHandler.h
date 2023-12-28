//
//  FTBaseInfoHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSDKCompat.h"
NS_ASSUME_NONNULL_BEGIN

/// 一些工具方法
@interface FTBaseInfoHandler : NSObject


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

/// 获取随机 uuid 字符串（无`-`、全小写）
+ (NSString *)randomUUID;
#if FT_IOS
/// 电话运营商
+(NSString *)telephonyCarrier;
#endif
/// 设备 IP Adderss
/// - Parameter preferIPv4 是否优先IPv4
+ (NSString *)cellularIPAddress:(BOOL)preferIPv4;
@end

NS_ASSUME_NONNULL_END
