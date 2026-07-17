//
//  FTResourcesFeature.m
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

#import "FTResourcesFeature.h"
#import "FTResourceRequest.h"
#import "FTPerformancePresetOverride.h"
#import "FTTLV.h"
@implementation FTResourcesFeature
-(instancetype)init{
    self = [super init];
    if(self){
        _name = @"session-replay-resources";
        _requestBuilder = [[FTResourceRequest alloc]init];
        FTPerformancePresetOverride *performanceOverride = [[FTPerformancePresetOverride alloc]init];
        performanceOverride.maxObjectSize = FT_MAX_DATA_LENGTH;
        performanceOverride.maxFileSize = FT_MAX_DATA_LENGTH;
        performanceOverride.maxObjectsInFile = 40;
        _performanceOverride = performanceOverride;
    }
    return self;
}
@end

#endif
