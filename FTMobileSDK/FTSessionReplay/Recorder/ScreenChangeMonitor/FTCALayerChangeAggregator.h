//
//  FTCALayerChangeAggregator.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTTimerScheduler.h"
#import "FTCALayerChangeSnapshot.h"
#import "FTCALayerSwizzler.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTCALayerChangeAggregator : NSObject<FTCALayerObserver>

@property (nonatomic, assign, readonly) NSTimeInterval minimumDeliveryInterval;
@property (nonatomic, strong, readonly) id<FTTimerScheduler> timerScheduler;
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;


- (instancetype)initWithMinimumDeliveryInterval:(NSTimeInterval)minimumDeliveryInterval
                                 timerScheduler:(id<FTTimerScheduler>)timerScheduler
                                        handler:(void (^)(FTCALayerChangeSnapshot *snapshot))handler;

- (void)start;

- (void)stop;
@end

NS_ASSUME_NONNULL_END
