//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTRunloopDetectorDelegate <NSObject>
@optional
- (void)longTaskStackDetected:(NSString*)slowStack duration:(long long)duration;
- (void)anrStackDetected:(NSString*)slowStack;
@end
@interface FTLongTaskDetector : NSObject

/// 超过多少毫秒为一次卡顿 默认 250 毫秒
@property (nonatomic, assign) NSUInteger limitMillisecond;
/// 超过 1000 毫秒, 记做 anr 卡顿一次
@property (nonatomic, assign) NSUInteger limitANRMillisecond;
/// 多少次 anr 卡顿纪录为一次有效 ANR
@property (nonatomic, assign) NSUInteger standstillCount;
-(instancetype)initWithDelegate:(id<FTRunloopDetectorDelegate>)delegate enableTrackAppANR:(BOOL)enableANR enableTrackAppFreeze:(BOOL)enableFreeze;

//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
