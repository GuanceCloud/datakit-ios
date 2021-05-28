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

@interface FTMonitorUtils : NSObject
/**
 * 获取开机时间
 */
+ (NSString *)launchSystemTime;
/**
 * 获取WiFi的 Access 与 IPAddress
 * iOS 12 之后WifiSSID 需要配置 'capability' ->'Access WiFi Infomation' 才能获取 还需要配置证书
 * iOS 13 之后需要定位开启 才能获取到信息
 */
+ (NSDictionary *)wifiAccessAndIPAddress;
+ (NSString *)currentWifiSSID;
+ (NSString *)ipAddress;
/**
 * 获取设备屏幕亮度
 */
+ (CGFloat)screenBrightness;
/**
 * 检测是否有物品靠近
 */
+ (BOOL)proximityState;
/**
 * 获取APP内调用闪光灯亮度Level
 */
+ (float)torchLevel;
/**
 *  @abstract
 *  获取当前设备CPU使用率
 */
+ (long )cpuUsage;
/**
 *  @abstract
 *  获取当前电池电量使用率
 */
+ (double)batteryUse;
/**
 *  @abstract
 *  电池是否充电中
 */
+ (NSString *)batteryStatus;
/**
 *  @abstract
 *  获取设备总内存
 */
+ (NSString *)totalMemorySize;
/**
 *  @abstract
 *  获取当前内存使用率
 */
+ (double)usedMemory;
+ (NSString *)cellularIPAddress:(BOOL)preferIPv4;

@end

NS_ASSUME_NONNULL_END
