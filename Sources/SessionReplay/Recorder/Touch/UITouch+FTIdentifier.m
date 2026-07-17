//
//  UITouch+FTIdentifier.m
//  SessionReplay
//
//  Created by hulilei on 2023/1/12.
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

#import "UITouch+FTIdentifier.h"
#import <objc/runtime.h>
static char *touchIdentifier = "FTTouchIdentifier";
static char *kTouchPrivacyOverride = "kTouchPrivacyOverride";

@implementation UITouch (FTIdentifier)
-(void)setIdentifier:(NSNumber*)identifier{
    objc_setAssociatedObject(self, &touchIdentifier, identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSNumber*)identifier{
    return objc_getAssociatedObject(self, &touchIdentifier);
}
-(void)setTouchPrivacyOverride:(NSNumber *)touchPrivacyOverride{
    objc_setAssociatedObject(self, &kTouchPrivacyOverride, touchPrivacyOverride, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSNumber *)touchPrivacyOverride{
    return objc_getAssociatedObject(self, &kTouchPrivacyOverride);
}

@end

#endif
