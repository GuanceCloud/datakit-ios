//
//  FTSessionReplayConfig.m
//  SessionReplay
//
//  Created by hulilei on 2024/7/4.
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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTSessionReplayConfig.h"
#import "FTSessionReplayConfig+Private.h"
#import "FTSessionReplayCoreImports.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *FTStringFromTextAndInputPrivacyLevel(FTTextAndInputPrivacyLevel level) {
    switch (level) {
        case FTTextAndInputPrivacyLevelMaskSensitiveInputs:
            return @"MaskSensitiveInputs";
        case FTTextAndInputPrivacyLevelMaskAllInputs:
            return @"MaskAllInputs";
        case FTTextAndInputPrivacyLevelMaskAll:
            return @"MaskAll";
        default:
            return @"MaskAll";
    }
}

static NSString *FTStringFromTouchPrivacyLevel(FTTouchPrivacyLevel level) {
    switch (level) {
        case FTTouchPrivacyLevelShow:
            return @"Show";
        case FTTouchPrivacyLevelHide:
            return @"Hide";
        default:
            return @"Hide";
    }
}

static NSString *FTStringFromImagePrivacyLevel(FTImagePrivacyLevel level) {
    switch (level) {
        case FTImagePrivacyLevelMaskNonBundledOnly:
            return @"MaskNonBundledOnly";
        case FTImagePrivacyLevelMaskAll:
            return @"MaskAll";
        case FTImagePrivacyLevelMaskNone:
            return @"MaskNone";
        default:
            return @"MaskAll";
    }
}
@interface FTSessionReplayConfig()
@property (nonatomic, strong, nullable) NSArray<id<FTSRWireframesRecorder>> *additionalNodeRecorders;
@property (nonatomic, assign) BOOL externalRecorderMode;
@property (nonatomic, assign) BOOL fineGrainedMaskingSet;
@property (nonatomic, assign) FTSRPrivacy privacy;
@end
@implementation FTSessionReplayConfig
// Keep deprecated sampling accessors for backward compatibility.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (int)sampleRate {
    return (int)_sessionReplaySamplingRate;
}
- (void)setSampleRate:(int)sampleRate {
    self.sessionReplaySamplingRate = (float)sampleRate;
}
#pragma clang diagnostic pop
- (void)setSessionReplaySamplingRate:(float)sessionReplaySamplingRate {
    if (![FTBaseInfoHandler isValidSamplingRate:sessionReplaySamplingRate]) {
        FTInnerLogWarning(@"[sampling] Ignore invalid sessionReplaySamplingRate: %g", sessionReplaySamplingRate);
        return;
    }
    _sessionReplaySamplingRate = sessionReplaySamplingRate;
}
// Keep deprecated sampling accessors for backward compatibility.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (int)sessionReplayOnErrorSampleRate {
    return (int)_sessionReplayOnErrorSamplingRate;
}
- (void)setSessionReplayOnErrorSampleRate:(int)sessionReplayOnErrorSampleRate {
    self.sessionReplayOnErrorSamplingRate = (float)sessionReplayOnErrorSampleRate;
}
#pragma clang diagnostic pop
- (void)setSessionReplayOnErrorSamplingRate:(float)sessionReplayOnErrorSamplingRate {
    if (![FTBaseInfoHandler isValidSamplingRate:sessionReplayOnErrorSamplingRate]) {
        FTInnerLogWarning(@"[sampling] Ignore invalid sessionReplayOnErrorSamplingRate: %g", sessionReplayOnErrorSamplingRate);
        return;
    }
    _sessionReplayOnErrorSamplingRate = sessionReplayOnErrorSamplingRate;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _sessionReplaySamplingRate = 100.0f;
        _sessionReplayOnErrorSamplingRate = 0.0f;
        _imagePrivacy = FTImagePrivacyLevelMaskAll;
        _touchPrivacy = FTTouchPrivacyLevelHide;
        _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAll;
        _privacy = FTSRPrivacyMask;
        _enableHeatmap = NO;
        _enableSwiftUI = NO;
        _externalRecorderMode = NO;
    }
    return self;
}
-(void)setEnableLinkRUMKeys:(NSArray *)enableLinkRUMKeys{
    _enableLinkRUMKeys = [enableLinkRUMKeys copy];
}
-(void)setAdditionalNodeRecorders:(NSArray<id<FTSRWireframesRecorder>> *)additionalNodeRecorders{
    _additionalNodeRecorders = additionalNodeRecorders;
}
-(void)setPrivacy:(FTSRPrivacy)privacy{
    _privacy = privacy;
    if(_fineGrainedMaskingSet == YES){
        return;
    }
    switch (privacy) {
        case FTSRPrivacyMask:
            _imagePrivacy = FTImagePrivacyLevelMaskAll;
            _touchPrivacy = FTTouchPrivacyLevelHide;
            _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAll;
            break;
     
        case FTSRPrivacyAllow:
            _imagePrivacy = FTImagePrivacyLevelMaskNone;
            _touchPrivacy = FTTouchPrivacyLevelShow;
            _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskSensitiveInputs;
            break;
        case FTSRPrivacyMaskUserInput:
            _imagePrivacy = FTImagePrivacyLevelMaskNonBundledOnly;
            _touchPrivacy = FTTouchPrivacyLevelHide;
            _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAllInputs;
            break;
    }
}
-(void)setTouchPrivacy:(FTTouchPrivacyLevel)touchPrivacy{
    _fineGrainedMaskingSet = YES;
    _touchPrivacy = touchPrivacy;
}
-(void)setTextAndInputPrivacy:(FTTextAndInputPrivacyLevel)textAndInputPrivacy{
    _fineGrainedMaskingSet = YES;
    _textAndInputPrivacy = textAndInputPrivacy;
}
-(void)setImagePrivacy:(FTImagePrivacyLevel)imagePrivacy{
    _fineGrainedMaskingSet = YES;
    _imagePrivacy = imagePrivacy;
}
- (id)copyWithZone:(nullable NSZone *)zone {
    FTSessionReplayConfig *config = [[[self class] allocWithZone:zone] init];
    config->_sessionReplaySamplingRate = _sessionReplaySamplingRate;
    config->_sessionReplayOnErrorSamplingRate = _sessionReplayOnErrorSamplingRate;
    config.touchPrivacy = self.touchPrivacy;
    config.imagePrivacy = self.imagePrivacy;
    config.textAndInputPrivacy = self.textAndInputPrivacy;
    config.enableSwiftUI = self.enableSwiftUI;
    config.additionalNodeRecorders = [self.additionalNodeRecorders copy];
    config.enableLinkRUMKeys = [self.enableLinkRUMKeys copy];
    config.enableHeatmap = self.enableHeatmap;
    config.externalRecorderMode = self.externalRecorderMode;
    return config;
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"====== Config ======\n sessionReplaySamplingRate:%g\n sessionReplayOnErrorSamplingRate:%g\n textAndInputPrivacy:%@\n touchPrivacy:%@\n imagePrivacy:%@\n enableSwiftUI:%@ enableHeatmap:%@ externalRecorderMode:%@\n ================== ",self.sessionReplaySamplingRate,self.sessionReplayOnErrorSamplingRate,FTStringFromTextAndInputPrivacyLevel(self.textAndInputPrivacy),FTStringFromTouchPrivacyLevel(self.touchPrivacy),FTStringFromImagePrivacyLevel(self.imagePrivacy),self.enableSwiftUI?@"YES":@"NO",self.enableHeatmap ? @"true" : @"false",self.externalRecorderMode ? @"true" : @"false"];
}
#pragma mark remote
-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model{
    @try {
        if (!model) {
            return;
        }
        if (model.sessionReplaySampleRate != nil) {
            self.sessionReplaySamplingRate = model.sessionReplaySampleRate.floatValue * 100.0f;
        }
        if (model.sessionReplaySamplingRate != nil) {
            self.sessionReplaySamplingRate = model.sessionReplaySamplingRate.floatValue;
        }
        if (model.sessionReplayOnErrorSampleRate != nil) {
            self.sessionReplayOnErrorSamplingRate = model.sessionReplayOnErrorSampleRate.floatValue * 100.0f;
        }
        if (model.sessionReplayOnErrorSamplingRate != nil) {
            self.sessionReplayOnErrorSamplingRate = model.sessionReplayOnErrorSamplingRate.floatValue;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
@end

#pragma clang diagnostic pop

#endif
