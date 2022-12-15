//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTANRDetectorDelegate <NSObject>
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack;
@end
@interface FTANRDetector : NSObject

+ (instancetype)sharedInstance;
/// 超过多少毫秒为一次卡顿 400毫秒
@property (nonatomic, assign) NSUInteger limitMillisecond;

/// 多少次卡顿纪录为一次有效，默认为5次
@property (nonatomic, assign) NSUInteger standstillCount;

@property (nonatomic, weak) id<FTANRDetectorDelegate> delegate;


//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
