//
//  FTScheduler.h
//  SessionReplay
//
//  Created by hulilei on 2026/3/2.
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
#import "FTQueue.h"
#ifndef FTScheduler_h
#define FTScheduler_h

@protocol FTScheduler <NSObject>

@required

@property (nonatomic, strong, readonly) id<FTQueue> queue;


- (void)scheduleWithOperation:(void (^)(void))operation;

- (void)start;


- (void)stop;

@end

#endif /* FTScheduler_h */

#endif
