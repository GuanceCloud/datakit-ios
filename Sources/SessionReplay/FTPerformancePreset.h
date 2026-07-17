//
//  FTPerformancePreset.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/25.
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
@class FTPerformancePresetOverride;
NS_ASSUME_NONNULL_BEGIN
@protocol FTStoragePerformancePreset <NSObject>
@property (nonatomic, assign) long long maxFileSize;
@property (nonatomic, assign) long long maxDirectorySize;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForWrite;
@property (nonatomic, assign) NSTimeInterval minFileAgeForRead;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForRead;
@property (nonatomic, assign) int maxObjectsInFile;
@property (nonatomic, assign) long long maxObjectSize;
@end

@protocol FTUploadPerformancePreset <NSObject>

@property (nonatomic, assign) NSTimeInterval initialUploadDelay;
@property (nonatomic, assign) NSTimeInterval minUploadDelay;
@property (nonatomic, assign) NSTimeInterval maxUploadDelay;
@property (nonatomic, assign) double uploadDelayChangeRate;

@end
@interface FTPerformancePreset : NSObject<FTStoragePerformancePreset,FTUploadPerformancePreset>
@property (nonatomic, assign) long long maxFileSize;
@property (nonatomic, assign) long long maxDirectorySize;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForWrite;
@property (nonatomic, assign) NSTimeInterval minFileAgeForRead;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForRead;
@property (nonatomic, assign) int maxObjectsInFile;
@property (nonatomic, assign) long long maxObjectSize;

@property (nonatomic, assign) NSTimeInterval initialUploadDelay;
@property (nonatomic, assign) NSTimeInterval minUploadDelay;
@property (nonatomic, assign) NSTimeInterval maxUploadDelay;
@property (nonatomic, assign) double uploadDelayChangeRate;

-(instancetype)initWithMeanFileAge:(NSTimeInterval)meanFileAge minUploadDelay:(NSTimeInterval)minUploadDelay;
- (FTPerformancePreset *)updateWithOverride:(FTPerformancePresetOverride *)overridePreset;
@end

NS_ASSUME_NONNULL_END

#endif
