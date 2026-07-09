//
//  UIView+FTSRPrivacy.m
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

#import "UIView+FTSRPrivacy.h"
#import <objc/runtime.h>
static char *associatedOverridesKey = "associatedOverridesKey";

@implementation UIView (FTSRPrivacy)

-(FTSessionReplayPrivacyOverrides *)sessionReplayPrivacyOverrides{
    FTSessionReplayPrivacyOverrides *overrides = [self _privacyOverrides];
    if(overrides){
        return overrides;
    }
    overrides = [FTSessionReplayPrivacyOverrides new];
    objc_setAssociatedObject(self, &associatedOverridesKey, overrides, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return overrides;
}

- (FTSessionReplayPrivacyOverrides *)_privacyOverrides{
    return objc_getAssociatedObject(self, &associatedOverridesKey);
}
@end

#endif
