//
//  FTRecordingCoordinator.m
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

#import "FTRecordingCoordinator.h"
#import "FTRecorder.h"
#import "FTSessionReplayConfig+Private.h"
#import "FTSessionReplayCoreImports.h"
#import "FTSessionReplayTouches.h"
#import "FTScheduler.h"
#import "FTViewAttributes.h"

static FTTrackingConsent FTTrackingConsentFromSampleState(FTRecordingSampleState sampleState) {
    switch (sampleState) {
        case FTRecordingSampleStateNormal:
            return FTTrackingConsentGranted;
        case FTRecordingSampleStateError:
            return FTTrackingConsentErrorSampled;
        case FTRecordingSampleStateNone:
            return FTTrackingConsentNotGranted;
    }
}

@interface FTRecordingCoordinator()
@property (nonatomic, strong) FTSessionReplayConfig *config;
@property (nonatomic, strong) FTSessionReplayTouches *touches;
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (atomic, strong, nullable) NSDictionary *currentRUMContext;
@property (atomic, strong, nullable) NSDictionary *bindInfo;
@property (nonatomic, assign) FTRecordingSampleState sampleState;
@property (atomic, assign) BOOL recordingEnabled;
@property (nonatomic, copy, nullable) FTTrackingConsentChanged trackingConsentDidChange;
@end

@implementation FTRecordingCoordinator
@synthesize sampleState = _sampleState;

- (instancetype)initWithConfig:(FTSessionReplayConfig *)config
               processorsQueue:(dispatch_queue_t)processorsQueue
                     scheduler:(id<FTScheduler>)scheduler
                       touches:(FTSessionReplayTouches *)touches
      trackingConsentDidChange:(nullable FTTrackingConsentChanged)trackingConsentDidChange{
    self = [super init];
    if (self) {
        _config = config;
        _processorsQueue = processorsQueue;
        _touches = touches;
        _recordingEnabled = NO;
        _sampleState = FTRecordingSampleStateNone;
        _trackingConsentDidChange = [trackingConsentDidChange copy];
        [self setScheduler:scheduler];
    }
    return self;
}

- (void)setScheduler:(id<FTScheduler>)scheduler{
    _scheduler = scheduler;
    __weak typeof(self) weakSelf = self;
    [_scheduler scheduleWithOperation:^{
        [weakSelf captureNextRecord];
    }];
}

- (FTRecordingSampleState)sampleState{
    @synchronized (self) {
        return _sampleState;
    }
}

- (FTTrackingConsent)trackingConsent{
    return FTTrackingConsentFromSampleState(self.sampleState);
}

- (void)setSampleState:(FTRecordingSampleState)sampleState{
    FTTrackingConsentChanged trackingConsentDidChange = nil;
    FTTrackingConsent trackingConsent = FTTrackingConsentNotGranted;
    @synchronized (self) {
        if (_sampleState == sampleState) {
            return;
        }
        _sampleState = sampleState;
        trackingConsent = FTTrackingConsentFromSampleState(sampleState);
        trackingConsentDidChange = [self.trackingConsentDidChange copy];
    }
    if (trackingConsentDidChange) {
        trackingConsentDidChange(trackingConsent);
    }
}

- (void)startRecording{
    __weak typeof(self) weakSelf = self;
    [self.scheduler.queue run:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.recordingEnabled = YES;
        [strongSelf evaluateRecordingConditions];
    }];
}

- (void)handleRUMContextMessage:(NSDictionary *)message{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.processorsQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([strongSelf.currentRUMContext isEqualToDictionary:message]) return;
        [strongSelf onRUMContextChanged:message];
    });
}

- (void)handleSampleRateUpdate{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.processorsQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf evaluateRecordingConditionsForSamplingRateUpdate];
    });
}

- (void)captureNextRecord{
    @try {
        NSDictionary *rumContext = [self.currentRUMContext copy];
        NSString *viewID = rumContext[FT_KEY_VIEW_ID];
        if (!viewID || !self.recorder) {
            return;
        }
        FTSRContext *context = [[FTSRContext alloc]init];
        context.sessionID = rumContext[FT_RUM_KEY_SESSION_ID];
        context.viewID = viewID;
        context.viewPath = rumContext[FT_KEY_VIEW_NAME];
        context.applicationID = rumContext[FT_APP_ID];
        context.date = [NSDate date];
        context.imagePrivacy = self.config.imagePrivacy;
        context.touchPrivacy = self.config.touchPrivacy;
        context.textAndInputPrivacy = self.config.textAndInputPrivacy;
        context.bindInfo = self.bindInfo;
        [self.recorder taskSnapShot:context touchSnapshot:[self.touches takeTouchSnapshotWithContext:context]];
    } @catch (NSException *exception) {
        FTInnerLogError(@"[session-replay] EXCEPTION: %@", exception.description);
    }
}

- (void)onRUMContextChanged:(NSDictionary *)context{
    NSDictionary *rumContext = [self.currentRUMContext copy];
    if(rumContext == nil || ![context[FT_RUM_KEY_SESSION_ID] isEqualToString:rumContext[FT_RUM_KEY_SESSION_ID]]){
        [self updateSamplingStatusWithRUMContext:context];
    }
    [self checkLinkRumKeys:context];
    self.currentRUMContext = context;
    [self evaluateRecordingConditions];
}

- (void)updateSamplingStatusWithRUMContext:(NSDictionary *)context{
    BOOL isErrorSession = [context[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue];
    BOOL isNormalSampled = [FTBaseInfoHandler randomSampling:self.config.sampleRate];
    BOOL isErrorSampled = isNormalSampled ? NO : [FTBaseInfoHandler randomSampling:self.config.sessionReplayOnErrorSampleRate];

    BOOL needSampleForErrorReplay = (isErrorSession && isNormalSampled) || isErrorSampled;

    FTRecordingSampleState sampleState = needSampleForErrorReplay ? FTRecordingSampleStateError
                                      : (isNormalSampled ? FTRecordingSampleStateNormal : FTRecordingSampleStateNone);
    self.sampleState = sampleState;
}

- (void)checkLinkRumKeys:(NSDictionary *)rumContext{
    NSDictionary *bindInfo = rumContext[FT_LINK_RUM_KEYS];
    if (bindInfo) {
        NSArray *whiteLists = self.config.enableLinkRUMKeys;
        if (whiteLists.count>0) {
            NSMutableDictionary *infoDict = [[NSMutableDictionary alloc]init];
            NSEnumerator *en = [whiteLists objectEnumerator];
            NSString *key;
            while ((key = en.nextObject) != nil) {
                [infoDict setValue:bindInfo[key] forKey:key];
            }
            self.bindInfo = [infoDict copy];
        }
    }
}

- (void)evaluateRecordingConditions{
    FTRecordingSampleState sampleState = self.sampleState;
    if (self.recordingEnabled && sampleState != FTRecordingSampleStateNone) {
        [self.scheduler start];
    } else {
        [self.scheduler stop];
    }
    [self updateHasReplay];
}

- (void)evaluateRecordingConditionsForSamplingRateUpdate{
    [self.config mergeWithRemoteConfigModel:[FTRemoteConfigManager sharedInstance].lastRemoteModel];
    BOOL needUpdate = NO;
    FTRecordingSampleState sampleState = self.sampleState;

    if (sampleState != FTRecordingSampleStateNone) {
        if (self.config.sampleRate == 0 && self.config.sessionReplayOnErrorSampleRate == 0) {
            needUpdate = YES;
        }
        if (sampleState == FTRecordingSampleStateError && self.config.sampleRate == 100) {
            needUpdate = YES;
        }
    } else {
        if (self.config.sampleRate == 100 || self.config.sessionReplayOnErrorSampleRate == 100) {
            needUpdate = YES;
        }
    }

    if (needUpdate) {
        [self updateSamplingStatusWithRUMContext:[self.currentRUMContext copy]];
        [self evaluateRecordingConditions];
    }
}

- (void)updateHasReplay{
    FTRecordingSampleState sampleState = self.sampleState;
    BOOL hasReplay = self.recordingEnabled && sampleState != FTRecordingSampleStateNone;
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySessionHasReplay message:@{
        FT_SESSION_HAS_REPLAY:@(hasReplay),
        FT_RUM_SESSION_REPLAY_SAMPLE_RATE:@(self.config.sampleRate),
        FT_RUM_SESSION_REPLAY_ON_ERROR_SAMPLE_RATE:@(self.config.sessionReplayOnErrorSampleRate),
        FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY:@(sampleState == FTRecordingSampleStateError)
    }];
}

@end

#endif
