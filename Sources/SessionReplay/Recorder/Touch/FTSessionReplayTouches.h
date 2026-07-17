//
//  FTSessionReplayTouches.h
//  SessionReplay
//
//  Created by hulilei on 2022/12/23.
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
#import <UIKit/UIKit.h>
#import "FTViewAttributes.h"
NS_ASSUME_NONNULL_BEGIN
@class FTTouchSnapshot,FTWindowObserver;
@interface FTSessionReplayTouches : NSObject
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer;
/// Get collection of touch points (main thread operation)
-(nullable FTTouchSnapshot *)takeTouchSnapshotWithContext:(FTSRContext *)context;

@end

NS_ASSUME_NONNULL_END

#endif
