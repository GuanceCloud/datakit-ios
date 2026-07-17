//
//  FTTouchSnapshot.m
//  SessionReplay
//
//  Created by hulilei on 2024/9/5.
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

#import "FTTouchSnapshot.h"
@implementation FTTouchCircle

@end
@implementation FTTouchSnapshot
- (instancetype)initWithTouches:(NSArray<FTTouchCircle*> *)touches{
    self = [super init];
    if(self){
        _touches = touches;
        _timestamp = touches.firstObject.timestamp;
    }
    return self;
}
@end

#endif
