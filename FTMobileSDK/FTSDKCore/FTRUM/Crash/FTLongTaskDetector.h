//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTLongTaskProtocol<NSObject>
- (void)startLongTask:(NSDate *)startDate backtrace:(NSString *)backtrace;
- (void)updateLongTaskDate:(NSDate *)date;
- (void)endLongTask;
@end
@interface FTLongTaskDetector : NSObject

/// 超过多少毫秒为一次 longTask 默认 1000 毫秒
@property (nonatomic, assign) NSUInteger limitMillisecond;
/// 超过 1000 毫秒, 记做 ANR 卡顿一次
@property (nonatomic, assign) NSUInteger limitANRMillisecond;
/// 多少次 anr 卡顿纪录为一次有效 ANR
@property (nonatomic, assign) NSUInteger standstillCount;

-(instancetype)initWithDelegate:(id<FTLongTaskProtocol>)delegate;

//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
