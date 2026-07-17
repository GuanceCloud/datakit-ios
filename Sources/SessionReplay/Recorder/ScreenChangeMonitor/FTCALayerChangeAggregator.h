//
//  FTCALayerChangeAggregator.h
//  SessionReplay
//
//  Created by hulilei on 2026/3/3.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

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

#endif
