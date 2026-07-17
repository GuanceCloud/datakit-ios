//
//  FTRecordingCoordinator.h
//  SessionReplay
//
//  Created by hulilei on 2026/6/4.
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
#import "FTFeatureStorage.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FTRecordingSampleState) {
    FTRecordingSampleStateNormal,
    FTRecordingSampleStateError,
    FTRecordingSampleStateNone
};

@class FTRecorder, FTSessionReplayConfig, FTSessionReplayTouches;
@protocol FTScheduler;

typedef void (^FTTrackingConsentChanged)(FTTrackingConsent trackingConsent);

@interface FTRecordingCoordinator : NSObject

@property (nonatomic, strong, nullable) FTRecorder *recorder;
@property (nonatomic, strong) id<FTScheduler> scheduler;
@property (atomic, strong, readonly, nullable) NSDictionary *currentRUMContext;
@property (nonatomic, assign, readonly) FTRecordingSampleState sampleState;
@property (nonatomic, assign, readonly) FTTrackingConsent trackingConsent;

- (instancetype)initWithConfig:(FTSessionReplayConfig *)config
               processorsQueue:(dispatch_queue_t)processorsQueue
                     scheduler:(id<FTScheduler>)scheduler
                       touches:(FTSessionReplayTouches *)touches
      trackingConsentDidChange:(nullable FTTrackingConsentChanged)trackingConsentDidChange;

- (void)startRecording;
- (void)handleRUMContextMessage:(NSDictionary *)message;
- (void)handleSampleRateUpdate;
- (void)setSampleState:(FTRecordingSampleState)sampleState;
- (void)evaluateRecordingConditions;

@end

NS_ASSUME_NONNULL_END

#endif
