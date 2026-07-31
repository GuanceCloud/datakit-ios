//
//  FTWindowObserver.h
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
#import "FTSessionReplayPlatform.h"
NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_OSX
typedef NSWindow * _Nullable (^FTSRKeyWindowProvider)(void);
#endif

@interface FTWindowObserver : NSObject
#if TARGET_OS_IOS
@property (nonatomic, strong, nullable) UIWindow *keyWindow;
- (nullable NSArray<UIWindow *>*)windows;
#elif TARGET_OS_OSX
- (instancetype)initWithKeyWindowProvider:(FTSRKeyWindowProvider)keyWindowProvider;
#endif
/// Root native views included in the next snapshot.
- (nullable NSArray<FTSRPlatformView *> *)rootViews;
/// Coordinate-space reference for the next snapshot.
- (nullable FTSRPlatformView *)referenceView;
@end

NS_ASSUME_NONNULL_END

#endif
