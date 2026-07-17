//
//  FTTimerScheduler.h
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
NS_ASSUME_NONNULL_BEGIN
@protocol FTScheduledTimer <NSObject>
- (void)cancel;
@end

@protocol FTTimeSource <NSObject>
@property (nonatomic, assign, readonly) NSTimeInterval now;
@end

@protocol FTTimerScheduler <FTTimeSource>

- (id<FTScheduledTimer>)scheduleAfterInterval:(NSTimeInterval)interval action:(dispatch_block_t)action;

@end



@interface FTDispatchSourceScheduledTimer : NSObject <FTScheduledTimer>

- (instancetype)initWithDispatchSourceTimer:(dispatch_source_t)timer;

@end

@interface FTDispatchSourceTimerScheduler : NSObject <FTTimerScheduler>

@property (nonatomic, strong, readonly) dispatch_queue_t queue;

- (instancetype)initWithQueue:(dispatch_queue_t)queue;

+ (instancetype)scheduler;

@property (class, nonatomic, strong, readonly) FTDispatchSourceTimerScheduler *dispatchSource;
@end

NS_ASSUME_NONNULL_END

#endif
