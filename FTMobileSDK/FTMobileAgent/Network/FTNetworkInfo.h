//
//  FTNetworkInfo.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkInfo : NSObject
/**
 * 获取网络类型
*/
+ (NSString *)getNetworkType;
/**
 * 网络强度 由于获取的是statusBar上控件信息
 * 移动网络信号强度最大值：4
 * WiFi最大值：3
*/
+ (int)getNetSignalStrength;
/**
 * 获取网络代理host信息 无则为：N/A
 */
+ (NSString *)getProxyHost;
@end

NS_ASSUME_NONNULL_END
