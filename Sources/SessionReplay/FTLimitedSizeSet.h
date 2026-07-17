//
//  FTLimitedSizeSet.h
//  SessionReplay
//
//  Created by hulilei on 2025/9/28.
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

@interface FTLimitedSizeSet : NSObject
- (instancetype)initWithMaxCount:(NSUInteger)maxCount;

- (void)addObject:(id<NSCopying>)object;

- (BOOL)containsObject:(id)object;

- (void)removeObject:(id)object;

- (NSUInteger)count;

- (void)removeAllObjects;
@end

NS_ASSUME_NONNULL_END

#endif
