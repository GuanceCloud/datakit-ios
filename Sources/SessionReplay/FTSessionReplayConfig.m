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
#if TARGET_OS_IOS

#import "FTSessionReplayConfig.h"
#import "FTSessionReplayConfig+Private.h"
#import "FTSessionReplayCoreImports.h"

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
@property (nonatomic, assign) BOOL fineGrainedMaskingSet;
@end
@implementation FTSessionReplayConfig
-(instancetype)init{
    self = [super init];
    if(self){
        _sampleRate = 100;
        _sessionReplayOnErrorSampleRate = 0;
        _imagePrivacy = FTImagePrivacyLevelMaskAll;
        _touchPrivacy = FTTouchPrivacyLevelHide;
        _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAll;
        _privacy = FTSRPrivacyMask;
        _enableHeatmap = NO;
        _enableSwiftUI = NO;
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
    config.sampleRate = self.sampleRate;
    config.sessionReplayOnErrorSampleRate = self.sessionReplayOnErrorSampleRate;
    config.touchPrivacy = self.touchPrivacy;
    config.imagePrivacy = self.imagePrivacy;
    config.textAndInputPrivacy = self.textAndInputPrivacy;
    config.enableSwiftUI = self.enableSwiftUI;
    config.additionalNodeRecorders = [self.additionalNodeRecorders copy];
    config.enableLinkRUMKeys = [self.enableLinkRUMKeys copy];
    config.enableHeatmap = self.enableHeatmap;
    return config;
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"====== Config ======\n sampleRate:%d\n sessionReplayOnErrorSampleRate:%d\n textAndInputPrivacy:%@\n touchPrivacy:%@\n imagePrivacy:%@\n enableSwiftUI:%@ enableHeatmap:%@\n ================== ",self.sampleRate,self.sessionReplayOnErrorSampleRate,FTStringFromTextAndInputPrivacyLevel(self.textAndInputPrivacy),FTStringFromTouchPrivacyLevel(self.touchPrivacy),FTStringFromImagePrivacyLevel(self.imagePrivacy),self.enableSwiftUI?@"YES":@"NO",self.enableHeatmap ? @"true" : @"false"];
}
#pragma mark remote
-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model{
    @try {
        if (!model) {
            return;
        }
        if (model.sessionReplaySampleRate != nil) {
            self.sampleRate = [model.sessionReplaySampleRate doubleValue] * 100;
        }
        if (model.sessionReplayOnErrorSampleRate != nil) {
            self.sessionReplayOnErrorSampleRate = [model.sessionReplayOnErrorSampleRate doubleValue] * 100;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
@end

#endif
