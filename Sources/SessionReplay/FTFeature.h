//
//  FTFeature.h
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

#ifndef FTFeature_h
#define FTFeature_h
@class FTPerformancePresetOverride;
@protocol FTFeatureRequestBuilder;
@protocol FTFeature <NSObject>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) FTPerformancePresetOverride *performanceOverride;
@end

@protocol FTRemoteFeature <NSObject,FTFeature>
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;
@end
#endif /* FTFeature_h */

#endif
