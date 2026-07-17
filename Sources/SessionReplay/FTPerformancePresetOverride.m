//
//  FTPerformancePresetOverride.m
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

#import "FTPerformancePresetOverride.h"

@implementation FTPerformancePresetOverride
-(instancetype)init{
    self = [super init];
    if(self){
        _maxFileSize = -1;
        _maxObjectSize = -1;
        _maxObjectsInFile = -1;
        
        _maxFileAgeForWrite = -1;
        _minFileAgeForRead = -1;
        
        _initialUploadDelay = -1;
        _minUploadDelay = -1;
        _maxUploadDelay = -1;
        _uploadDelayChangeRate = -1;
    }
    return self;
}
-(instancetype)initWithMeanFileAge:(NSTimeInterval)meanFileAge minUploadDelay:(NSTimeInterval)minUploadDelay{
    self = [self init];
    _maxFileAgeForWrite = meanFileAge * 0.95;
    _minFileAgeForRead = meanFileAge * 1.05;
    _minUploadDelay = minUploadDelay;
    _maxUploadDelay = minUploadDelay * 10;
    return self;
}
@end

#endif
