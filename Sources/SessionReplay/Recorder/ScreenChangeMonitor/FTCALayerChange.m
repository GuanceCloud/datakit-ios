//
//  FTCALayerChange.m
//  SessionReplay
//
//  Created by hulilei on 2026/3/3.
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

#import "FTCALayerChange.h"

@implementation FTCALayerChange

- (instancetype)initWithLayer:(CALayer *)layer aspects:(FTCALayerChangeAspect)aspects {
    if (self = [super init]) {
        _layer = layer;
        _aspects = aspects;
    }
    return self;
}

@end

#endif
