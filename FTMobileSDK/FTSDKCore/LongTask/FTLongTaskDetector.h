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
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack duration:(long long)duration;
@end
@interface FTLongTaskDetector : NSObject

/// 超过多少毫秒为一次卡顿 默认 250 毫秒
@property (nonatomic, assign) NSUInteger limitMillisecond;

-(instancetype)initWithDelegate:(id<FTANRDetectorDelegate>)delegate;

//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
