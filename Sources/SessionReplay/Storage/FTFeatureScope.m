//
//  FTFeatureScope.m
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

#import "FTFeatureScope.h"

@interface FTFeatureContext()
@property (nonatomic, assign, readwrite) FTTrackingConsent trackingConsent;
@end

@implementation FTFeatureContext

- (instancetype)initWithTrackingConsent:(FTTrackingConsent)trackingConsent{
    self = [super init];
    if (self) {
        _trackingConsent = trackingConsent;
    }
    return self;
}

@end

@interface FTFeatureScope()
@property (nonatomic, strong) FTFeatureStorage *storage;
@property (nonatomic, copy) FTTrackingConsentProvider trackingConsentProvider;
@end

@implementation FTFeatureScope

- (instancetype)initWithStorage:(FTFeatureStorage *)storage
        trackingConsentProvider:(FTTrackingConsentProvider)trackingConsentProvider{
    self = [super init];
    if(self){
        _storage = storage;
        _trackingConsentProvider = [trackingConsentProvider copy];
    }
    return self;
}

- (FTTrackingConsent)trackingConsent{
    if (self.trackingConsentProvider) {
        return self.trackingConsentProvider();
    }
    return FTTrackingConsentNotGranted;
}

- (BOOL)isErrorSampled{
    return self.trackingConsent == FTTrackingConsentErrorSampled;
}

- (void)updateTrackingConsent{
    FTFeatureContext *context;
    @synchronized (self) {
        context = [self featureContext];
    }
    [self.storage updateTrackingConsent:context.trackingConsent];
}

- (void)eventWriteContext:(FTFeatureWriteContext)block{
    if (!block) {
        return;
    }
    FTFeatureContext *context;
    id<FTWriter> writer;
    @synchronized (self) {
        context = [self featureContext];
        writer = [self.storage writerForTrackingConsent:context.trackingConsent];
    }
    block(context, writer);
}

- (void)webViewEventWriteContext:(FTFeatureWriteContext)block{
    if (!block) {
        return;
    }
    FTFeatureContext *context;
    id<FTWriter> writer;
    @synchronized (self) {
        context = [self featureContext];
        writer = [self.storage webViewWriterForTrackingConsent:context.trackingConsent];
    }
    block(context, writer);
}

- (FTFeatureContext *)featureContext{
    return [[FTFeatureContext alloc]initWithTrackingConsent:self.trackingConsent];
}

@end

#endif
