//
//  FTFeatureScope.h
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

typedef FTTrackingConsent (^FTTrackingConsentProvider)(void);

@interface FTFeatureContext : NSObject
@property (nonatomic, assign, readonly) FTTrackingConsent trackingConsent;

- (instancetype)initWithTrackingConsent:(FTTrackingConsent)trackingConsent;

@end

typedef void (^FTFeatureWriteContext)(FTFeatureContext *context, id<FTWriter> writer);

@interface FTFeatureScope : NSObject
@property (nonatomic, assign, readonly) FTTrackingConsent trackingConsent;
@property (nonatomic, assign, readonly) BOOL isErrorSampled;

- (instancetype)initWithStorage:(FTFeatureStorage *)storage
        trackingConsentProvider:(FTTrackingConsentProvider)trackingConsentProvider;
- (void)updateTrackingConsent;
- (void)eventWriteContext:(FTFeatureWriteContext)block;
- (void)webViewEventWriteContext:(FTFeatureWriteContext)block;

@end

NS_ASSUME_NONNULL_END

#endif
