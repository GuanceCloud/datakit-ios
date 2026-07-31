//
//  FTViewAttributes.h
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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import <Foundation/Foundation.h>
#import "FTViewTreeSnapshot.h"
#import "FTSessionReplayPlatform.h"
#import "FTSRViewID.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"
NS_ASSUME_NONNULL_BEGIN
@class FTSRColorSnapshot;

@interface FTSRContext : NSObject
@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;
@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;
@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;
@property (nonatomic, copy) NSString *applicationID;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *viewID;
@property (nonatomic, copy, nullable) NSString *viewPath;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSDictionary *bindInfo;
@end

@interface FTViewAttributes : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect clip;
@property (nonatomic, strong, nullable) FTSRColorSnapshot *backgroundColor;
@property (nonatomic, strong, nullable) FTSRColorSnapshot *layerBorderColor;
@property (nonatomic, assign) CGFloat layerBorderWidth;
@property (nonatomic, assign) CGFloat layerCornerRadius;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) BOOL  isHidden;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL hasAnyAppearance;
@property (nonatomic, assign) BOOL isTranslucent;
@property (nonatomic, strong, nullable) NSNumber *imagePrivacy;
@property (nonatomic, strong, nullable) NSNumber *textAndInputPrivacy;
@property (nonatomic, assign) BOOL hide;

-(instancetype)initWithView:(FTSRPlatformView *)view frameInRootView:(CGRect)frame clip:(CGRect)clip overrides:(PrivacyOverrides *)overrides;
-(FTTextAndInputPrivacyLevel)resolveTextAndInputPrivacyLevel:(FTSRContext *)context;
-(FTImagePrivacyLevel)resolveImagePrivacyLevel:(FTSRContext *)context;

@end


NS_ASSUME_NONNULL_END

#endif
