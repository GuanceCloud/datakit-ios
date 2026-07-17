//
//  FTRecordWriter.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FTFeatureScope;

@interface FTRecordWriter : NSObject
@property (nonatomic, assign, readonly) BOOL isErrorSampled;

- (instancetype)initWithFeatureScope:(FTFeatureScope *)featureScope;
- (void)write:(NSData *)data;
- (void)write:(NSData *)data forceNewFile:(BOOL)force;

@end

NS_ASSUME_NONNULL_END

#endif
