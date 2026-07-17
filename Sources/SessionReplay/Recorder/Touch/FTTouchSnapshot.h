//
//  FTTouchSnapshot.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger,FTTouchPhase) {
    TouchDown,
    TouchMoved,
    TouchUp
};

@interface FTTouchCircle : NSObject
@property (nonatomic, assign) CGPoint position;
@property (nonatomic, assign) FTTouchPhase phase;
@property (nonatomic, assign) int identifier;
@property (nonatomic, assign) long long timestamp;
@property (nonatomic, strong ,nullable) NSNumber *touchPrivacyOverride;
@end

@interface FTTouchSnapshot : NSObject

@property (nonatomic, assign) long long timestamp;
@property (nonatomic, strong) NSArray<FTTouchCircle*> *touches;
- (instancetype)initWithTouches:(NSArray<FTTouchCircle*> *)touches;

@end

NS_ASSUME_NONNULL_END

#endif
