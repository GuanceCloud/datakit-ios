//
//  FTMonitorManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTMobileConfig.h"
NS_ASSUME_NONNULL_BEGIN
@class CBUUID;
@interface FTMonitorManager : NSObject
/**
 * 获取 FTMonitorManager 单例
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;
/**
 * 设置 监控类型 可不设置直接获取 FTMobileAgent.config
*/
-(void)setMonitorType:(FTMonitorInfoType)type;
/**
 * 设置 监控上传周期
*/
-(void)setFlushInterval:(NSInteger)interval;
/**
 * 开启监控同步
*/
-(void)startFlush;
/**
 * 关闭监控同步
*/
-(void)stopFlush;
/**
 * 设置设备连接过的蓝牙外设 CBUUID 数组，建议用户将已连接过的设备使用NSUserDefault保存起来
 * 用于采集已连接设备相关信息
*/
-(void)setConnectBluetoothCBUUID:(nullable NSArray<CBUUID *> *)serviceUUIDs;
/**
 * 获取监控项的tag、field
*/
-(NSDictionary *)getMonitorTagFiledDict;

- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
