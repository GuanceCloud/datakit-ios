//
//  FTCMMotionrManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTCMMotionManager.h"
#import <CoreMotion/CoreMotion.h>
@interface FTCMMotionManager()
@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end
@implementation FTCMMotionManager
+ (FTCMMotionManager *)shared {
  static dispatch_once_t pred;
  static FTCMMotionManager *sharedInstance = nil;

  dispatch_once(&pred, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}
- (instancetype)init {
  self = [super init];
  if (self) {
    if ([CMPedometer isStepCountingAvailable]) {
      self.pedometer = [[CMPedometer alloc] init];
    }
  }
  return self;
}
-(CMMotionManager *)motionManager{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc]init];
    }
    return _motionManager;
}
- (void)startMotionUpdate{
    if([self.motionManager isGyroAvailable] && ![self.motionManager isGyroActive]){
        [self.motionManager startGyroUpdates];
    }
    if ([self.motionManager isAccelerometerAvailable] && ![self.motionManager isAccelerometerActive]) {
        [self.motionManager startAccelerometerUpdates];
    }
    if ([self.motionManager isMagnetometerAvailable] && ![self.motionManager isMagnetometerActive]) {
        [self.motionManager startMagnetometerUpdates];
    }
}
/**
 *  查询某时间段的运动数据
 *
 *  @param start   开始时间
 *  @param end     结束时间
 *  @param handler 查询结果
 */
- (void)queryPedometerDataFromDate:(NSDate *)start
                            toDate:(NSDate *)end
                       withHandler:(FTPedometerHandler)handler {

  [_pedometer
      queryPedometerDataFromDate:start
                          toDate:end
                     withHandler:^(CMPedometerData *_Nullable pedometerData,
                                   NSError *_Nullable error) {
                       dispatch_async(dispatch_get_main_queue(), ^{
                         handler(pedometerData.numberOfSteps, error);
                       });
                     }];

}
/**
 *  监听今天（从零点开始）的行走数据
 *
 *  @param handler 查询结果、变化就更新
 */
- (void)startPedometerUpdatesTodayWithHandler:(FTPedometerHandler)handler{
  NSDate *toDate = [NSDate date];
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd"];
  NSDate *fromDate =
      [dateFormatter dateFromString:[dateFormatter stringFromDate:toDate]];
  [_pedometer
      startPedometerUpdatesFromDate:fromDate
                        withHandler:^(CMPedometerData *_Nullable pedometerData,
                                      NSError *_Nullable error) {
                            handler(pedometerData.numberOfSteps, error);
                        }];
}
- (NSDictionary *)getMotionDatas{
    NSMutableDictionary *field = [NSMutableDictionary new];
    if([self.motionManager isGyroAvailable]){
        [field addEntriesFromDictionary:@{@"rotation_x":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.x],
                                          @"rotation_y":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.y],
                                          @"rotation_z":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.z]}];
    }
    if ([self.motionManager isAccelerometerAvailable] ) {
        [field addEntriesFromDictionary:@{@"acceleration_x":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.x],
                                          @"acceleration_y":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.y],
                                          @"acceleration_z":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.z]}];
    }
    if ([self.motionManager isMagnetometerAvailable]) {
        [field addEntriesFromDictionary:@{@"magnetic_x":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.x],
                                          @"magnetic_y":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.y],
                                          @"magnetic_z":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.z]}];
    }
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    [self startPedometerUpdatesTodayWithHandler:^(NSNumber * _Nonnull steps, NSError * _Nonnull error) {
        [field addEntriesFromDictionary:@{@"steps":steps}];
          dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return field;
}
/**
 *  停止监听运动数据
 */
- (void)stopMotionUpdates {
    [_pedometer stopPedometerUpdates];
    if([_motionManager isGyroActive]){
        [_motionManager stopGyroUpdates];
    }
    if ([_motionManager isAccelerometerActive]) {
        [_motionManager stopAccelerometerUpdates];
    }
    if ([_motionManager isMagnetometerActive]) {
        [_motionManager stopMagnetometerUpdates];
    }
}
/**
 *  计步器是否可以使用
 *
 *  @return YES or NO
 */
+ (BOOL)isStepCountingAvailable {
  return [CMPedometer isStepCountingAvailable];
}
@end
