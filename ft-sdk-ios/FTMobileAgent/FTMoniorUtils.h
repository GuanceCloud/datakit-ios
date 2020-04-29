//
//  FTMoniorUtils.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface FTMoniorUtils : NSObject
/**
 * 获取开机时间
 */
+ (NSString *)getLaunchSystemTime;
/**
 * 获取设备自定义名称
 */
+ (NSString *)userDeviceName;
/**
 * 获取网络dns
 */
+ (NSDictionary *)getDNSInfo;
/**
 * 获取WiFi的 Access 与 IPAddress
 * iOS 12 之后WifiSSID 需要配置 'capability' ->'Access WiFi Infomation' 才能获取 还需要配置证书
 * iOS 13 之后需要定位开启 才能获取到信息
 */
+ (NSDictionary *)getWifiAccessAndIPAddress;
+ (NSString *)getCurrentWifiSSID;
+ (NSString *)getIPAddress;
/**
 * 获取设备屏幕亮度
 */
+ (CGFloat)screenBrightness;
/**
 * 检测是否有物品靠近
 */
+ (BOOL)getProximityState;
/**
 * 获取APP内调用闪光灯亮度Level
 */
+ (float)getTorchLevel;
@end

NS_ASSUME_NONNULL_END
