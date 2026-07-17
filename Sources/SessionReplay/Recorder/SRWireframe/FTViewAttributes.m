//
//  FTViewAttributes.m
//  SessionReplay
//
//  Created by hulilei on 2023/7/17.
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

#import "FTViewAttributes.h"
#import "FTSRUtils.h"
@implementation FTSRContext
@end

@implementation FTViewAttributes
-(instancetype)initWithView:(UIView *)view frameInRootView:(CGRect)frame clip:(CGRect)clip overrides:(PrivacyOverrides *)overrides{
    self = [super init];
    if(self){
        self.frame = frame;
        self.clip = clip;
        self.alpha = view.alpha;
        self.backgroundColor = [FTSRColorSnapshot snapshotWithColor:view.backgroundColor traitCollection:view.traitCollection];
        self.layerBorderColor = [FTSRColorSnapshot snapshotWithCGColor:view.layer.borderColor];
        self.layerBorderWidth = view.layer.borderWidth;
        self.layerCornerRadius = view.layer.cornerRadius;
        self.isHidden = view.isHidden;
        self.imagePrivacy = overrides.nImagePrivacy;
        self.textAndInputPrivacy = overrides.nTextAndInputPrivacy;
        self.hide = overrides.hide;
    }
    return self;
}
-(BOOL)isVisible{
    return  !self.isHidden && self.alpha > 0 && !CGRectEqualToRect(self.frame, CGRectZero) && !CGRectIsEmpty(CGRectIntersection(self.frame, self.clip));
}
-(BOOL)hasAnyAppearance{
    BOOL hasBorderAppearance = self.layerBorderWidth > 0 && self.layerBorderColor.alpha > 0 ;
    
    BOOL hasFillAppearance = self.backgroundColor.alpha > 0 ;
    return self.isVisible && (hasBorderAppearance || hasFillAppearance);
}
-(BOOL)isTranslucent{
    return  !self.isVisible || self.alpha < 1 || self.backgroundColor.alpha < 1;
}
-(FTTextAndInputPrivacyLevel)resolveTextAndInputPrivacyLevel:(FTSRContext *)context{
    if (self.textAndInputPrivacy != nil) {
        return (FTTextAndInputPrivacyLevel)[self.textAndInputPrivacy intValue];
    }
    return context.textAndInputPrivacy;
}
-(FTImagePrivacyLevel)resolveImagePrivacyLevel:(FTSRContext *)context{
    if (self.imagePrivacy != nil) {
        return (FTImagePrivacyLevel)[self.imagePrivacy intValue];
    }
    return context.imagePrivacy;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTViewAttributes *attributes = [[[self class] allocWithZone:zone] init];
    attributes.frame = self.frame;
    attributes.clip = self.clip;
    attributes.alpha = self.alpha;
    attributes.backgroundColor = self.backgroundColor;
    attributes.layerBorderColor = self.layerBorderColor;
    attributes.layerBorderWidth = self.layerBorderWidth;
    attributes.layerCornerRadius = self.layerCornerRadius;
    attributes.isHidden = self.isHidden;
    attributes.imagePrivacy = self.imagePrivacy;
    attributes.textAndInputPrivacy = self.textAndInputPrivacy;
    attributes.hide = self.hide;
    return attributes;
}
@end

#endif
