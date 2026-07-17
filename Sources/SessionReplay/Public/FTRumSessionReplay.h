//
//  FTRumSessionReplay.h
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
#import "FTSessionReplayConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTRumSessionReplay : NSObject

/// Singleton
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());;

/// Configure Config to enable Session Replay
/// - Parameter config: Session Replay configuration items
- (void)startWithSessionReplayConfig:(FTSessionReplayConfig *)config;
@end

NS_ASSUME_NONNULL_END

#endif
