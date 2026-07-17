//
//  FTSessionReplayPrivacyOverrides.m
//  SessionReplay
//
//  Created by hulilei on 2025/3/11.
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

#import "FTSessionReplayPrivacyOverrides.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"

@implementation FTSessionReplayPrivacyOverrides
-(void)setImagePrivacy:(FTImagePrivacyLevelOverride)imagePrivacy{
    _imagePrivacy = imagePrivacy;
    switch (imagePrivacy) {
        case FTImagePrivacyLevelOverrideNone:
            _nImagePrivacy = nil;
            break;
        case FTImagePrivacyLevelOverrideMaskNonBundledOnly:
            _nImagePrivacy = @(FTImagePrivacyLevelMaskNonBundledOnly);
            break;
        case FTImagePrivacyLevelOverrideMaskAll:
            _nImagePrivacy = @(FTImagePrivacyLevelMaskAll);
            break;
        case FTImagePrivacyLevelOverrideMaskNone:
            _nImagePrivacy = @(FTImagePrivacyLevelMaskNone);
            break;
    }
}
-(void)setTouchPrivacy:(FTTouchPrivacyLevelOverride)touchPrivacy{
    _touchPrivacy = touchPrivacy;
    switch (touchPrivacy) {
        case FTTouchPrivacyLevelOverrideNone:
            _nTouchPrivacy = nil;
            break;
        case FTTouchPrivacyLevelOverrideShow:
            _nTouchPrivacy = @(FTTouchPrivacyLevelShow);
            break;
        case FTTouchPrivacyLevelOverrideHide:
            _nTouchPrivacy = @(FTTouchPrivacyLevelHide);
            break;
    }
}
- (void)setTextAndInputPrivacy:(FTTextAndInputPrivacyLevelOverride)textAndInputPrivacy{
    _textAndInputPrivacy = textAndInputPrivacy;
    switch (textAndInputPrivacy) {
        case FTTextAndInputPrivacyLevelOverrideNone:
            _nTextAndInputPrivacy = nil;
            break;
        case FTTextAndInputPrivacyLevelOverrideMaskSensitiveInputs:
            _nTextAndInputPrivacy = @(FTTextAndInputPrivacyLevelMaskSensitiveInputs);
            break;
        case FTTextAndInputPrivacyLevelOverrideMaskAllInputs:
            _nTextAndInputPrivacy = @(FTTextAndInputPrivacyLevelMaskAllInputs);
            break;
        case FTTextAndInputPrivacyLevelOverrideMaskAll:
            _nTextAndInputPrivacy = @(FTTextAndInputPrivacyLevelMaskAll);
            break;
    }
}
+ (PrivacyOverrides *)mergeChild:(PrivacyOverrides *)child parent:(PrivacyOverrides *)parent{
    if (!child) {
        return parent;
    }
    if (!parent) {
        return child;
    }
    child.nTextAndInputPrivacy = child.nTextAndInputPrivacy ?: parent.nTextAndInputPrivacy;
    child.nImagePrivacy = child.nImagePrivacy ?: parent.nImagePrivacy;
    child.nTouchPrivacy = child.nTouchPrivacy ?: parent.nTouchPrivacy;
    if (child.hide == YES || parent.hide == YES) {
        child.hide = YES;
    }
    return child;
}
@end

#endif
