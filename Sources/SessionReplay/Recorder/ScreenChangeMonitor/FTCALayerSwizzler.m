//
//  FTCALayerSwizzler.m
//  SessionReplay
//
//  Created by hulilei on 2026/3/4.
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

#import "FTCALayerSwizzler.h"
#import "FTSessionReplayCoreImports.h"

static __weak id<FTCALayerObserver> ft_currentLayerObserver = nil;
static void *const kFTSwizzleDisplay = (void *)&kFTSwizzleDisplay;
static void *const kFTSwizzleDrawInContext = (void *)&kFTSwizzleDrawInContext;
static void *const kFTSwizzleLayoutSublayers = (void *)&kFTSwizzleLayoutSublayers;

@implementation FTCALayerSwizzler

- (instancetype)initWithObserver:(id<FTCALayerObserver>)observer {
    self = [super init];
    if (self) {
        ft_currentLayerObserver = observer;
    }
    return self;
}

- (void)swizzleIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleDisplay];
        [self swizzleDraw];
        [self swizzleLayoutSublayers];
    });
}

#pragma mark - Display

- (void)swizzleDisplay {
    FTSwizzlerInstanceMethod([CALayer class], @selector(display), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
        FTSWCallOriginal();
        __strong id<FTCALayerObserver> observer = ft_currentLayerObserver;
        if (observer) {
            [observer layerDidDisplay:self];
        }
    }), FTSwizzlerModeOncePerClass, kFTSwizzleDisplay);
}

#pragma mark - Draw

- (void)swizzleDraw {
    FTSwizzlerInstanceMethod([CALayer class], @selector(drawInContext:), FTSWReturnType(void), FTSWArguments(CGContextRef context), FTSWReplacement({
        FTSWCallOriginal(context);
        __strong id<FTCALayerObserver> observer = ft_currentLayerObserver;
        if (observer) {
            [observer layerDidDraw:self inContext:context];
        }
    }), FTSwizzlerModeOncePerClass, kFTSwizzleDrawInContext);
}

#pragma mark - Layout

- (void)swizzleLayoutSublayers {
    FTSwizzlerInstanceMethod([CALayer class], @selector(layoutSublayers), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
        FTSWCallOriginal();
        __strong id<FTCALayerObserver> observer = ft_currentLayerObserver;
        if (observer) {
            [observer layerDidLayoutSublayers:self];
        }
    }), FTSwizzlerModeOncePerClass, kFTSwizzleLayoutSublayers);
}

@end

#endif
