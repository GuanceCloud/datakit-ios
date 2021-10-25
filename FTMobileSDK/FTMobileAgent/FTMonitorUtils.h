//
//  FTMonitorUtils.h
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
