//
//  FTViewTreeSnapshot.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/13.
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
#import "FTSRNodeSemantics.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTSRNodeWireframesBuilder,FTSRResource;
@protocol FTSRNodeWireframesBuilder;
@protocol FTSRResource;
@class FTSRContext, FTViewAttributes, FTSessionReplayWireframesBuilder;
@interface FTViewTreeSnapshot : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) FTSRContext *context;
@property (nonatomic, assign) CGSize viewportSize;
@property (nonatomic, strong) NSArray<id<FTSRNodeWireframesBuilder>> *nodes;
@property (nonatomic, strong) NSArray<id<FTSRResource>> *resources;
@property (nonatomic, strong) NSSet<NSNumber *>* webViewSlotIDs;
@end

@interface FTSessionReplayNode: NSObject
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) FTSessionReplayWireframesBuilder *builder;
@end

NS_ASSUME_NONNULL_END

#endif
