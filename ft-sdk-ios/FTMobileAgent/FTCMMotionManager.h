//
//  FTPedometerManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTPedometerData;
@interface FTCMMotionManager : NSObject
typedef void (^FTPedometerHandler)(FTPedometerData *pedometerData,
NSError *error);
+ (FTCMMotionManager *)shared;
/**
 *  计步器是否可以使用
 *
 *  @return YES or NO
 */
+ (BOOL)isStepCountingAvailable;
/**
 *  查询某时间段的行走数据
 *
 *  @param start   开始时间
 *  @param end     结束时间
 *  @param handler 查询结果
 */
- (void)queryPedometerDataFromDate:(NSDate *)start
                            toDate:(NSDate *)end
                       withHandler:(FTPedometerHandler)handler;
/**
 *  监听今天（从零点开始）的行走数据
 *
 *  @param handler 查询结果、变化就更新
 */
- (void)startPedometerUpdatesTodayWithHandler:(FTPedometerHandler)handler;
- (NSDictionary *)getMotionDatas;
/**
 *  开启监听运动数据
*/
- (void)startMotionUpdate;
/**
 *  停止监听运动数据
 */
- (void)stopMotionUpdates;
@end

NS_ASSUME_NONNULL_END
