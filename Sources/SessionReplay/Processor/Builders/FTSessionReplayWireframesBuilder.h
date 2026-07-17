//
//  FTSessionReplayWireframesBuilder.h
//  SessionReplay
//
//  Created by hulilei on 2025/4/21.
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
#import "FTSRNodeWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN
@class FTSRWebViewWireframe,FTUIImageResource,FTSRImageWireframe,FTHeatmapIdentifier;
@interface FTSessionReplayWireframesBuilder : NSObject
@property (nonatomic, strong) NSMutableArray<id<FTSRResource>> *resources;
@property (nonatomic, strong, nullable) FTHeatmapIdentifier *heatmapIdentifier;
-(instancetype)initWithResources:(NSArray<id <FTSRResource>>*)resources webViewSlotIDs:( NSSet<NSNumber *> *)webViewSlotIDs;

- (void)addResources:(NSArray<id <FTSRResource>>*)resources;
- (FTSRWireframe *)createShapeWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes;

- (FTSRImageWireframe *)createImageWireframeWithID:(int64_t)identifier resource:(id<FTSRResource>)resource frame:(CGRect)frame clip:(CGRect)clip;

- (FTSRWebViewWireframe *)visibleWebViewWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes linkRUMKeysInfo:(nullable NSDictionary *)linkRUMKeysInfo;
- (NSArray<FTSRWireframe*>*)hiddenWebViewWireframes;

- (NSSet<NSNumber *> *)hiddenWebViewSlotIDs;
- (NSDictionary *)linkRumKeysInfo;
@end

NS_ASSUME_NONNULL_END

#endif
