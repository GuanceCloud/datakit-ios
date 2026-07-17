//
//  FTSessionReplayFeature.h
//  SessionReplay
//
//  Created by hulilei on 2024/7/4.
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
#import "FTFeature.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTRemoteFeature,FTDataStore,FTCacheWriter,FTScheduler;
@class FTSessionReplayConfig,FTFeatureStorage;
@interface FTSessionReplayFeature : NSObject<FTRemoteFeature>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) FTPerformancePresetOverride *performanceOverride;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;

-(instancetype)initWithConfig:(FTSessionReplayConfig *)config;

-(void)startWithRecordStorage:(FTFeatureStorage *)recordStorage resourceStorage:(FTFeatureStorage *)resourceStorage resourceDataStore:(nullable id<FTDataStore>)dataStore;

- (void)startRecording;


@end

NS_ASSUME_NONNULL_END

#endif
