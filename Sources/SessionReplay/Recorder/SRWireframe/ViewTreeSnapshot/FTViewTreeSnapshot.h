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
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import "FTSessionReplayWireframesBuilder.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,NodeSubtreeStrategy){
    NodeSubtreeStrategyRecord,
    NodeSubtreeStrategyIgnore
};

@protocol FTSRNodeWireframesBuilder,FTSRResource;
@interface FTSRNodeSemantics : NSObject
@property (nonatomic, assign) int importance;
@property (nonatomic, strong) NSArray<id<FTSRNodeWireframesBuilder>> *nodes;
@property (nonatomic, assign) NodeSubtreeStrategy subtreeStrategy;
-(instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy;

@end

@protocol FTSRNodeWireframesBuilder;
@protocol FTSRResource;
@class FTSRContext;
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

@interface FTUnknownElement : FTSRNodeSemantics
+ (instancetype)constant;
@end
@interface FTInvisibleElement : FTSRNodeSemantics
+ (instancetype)constant;
@end
@interface FTIgnoredElement : FTSRNodeSemantics

@end

@interface FTAmbiguousElement : FTSRNodeSemantics

@end

@interface FTSpecificElement : FTSRNodeSemantics

@end
NS_ASSUME_NONNULL_END

#endif
