//
//  FTFilesOrchestrator.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/21.
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
@class FTFile,FTDirectory;
@protocol FTStoragePerformancePreset,FTWritableFile,FTReadableFile;
@protocol FTFilesOrchestratorType <NSObject>

@property (nonatomic, strong) id<FTStoragePerformancePreset> performance;
@property (nonatomic, assign) BOOL ignoreFilesAgeWhenReading;
- (nullable id<FTWritableFile>)getWritableFile:(long long)writeSize;
- (nullable id<FTWritableFile>)getWritableFile:(long long)writeSize forceNewFile:(BOOL)force;
- (nullable NSArray<FTFile *>*)getReadableFiles:(NSSet *)excludedFileNames limit:(int)limit;
- (void)deleteReadableFile:(id<FTReadableFile>)readableFile;
@end

@interface FTFilesOrchestrator : NSObject<FTFilesOrchestratorType>
@property (nonatomic, strong) id<FTStoragePerformancePreset> performance;
@property (nonatomic, assign) BOOL ignoreFilesAgeWhenReading;

-(instancetype)initWithDirectory:(FTDirectory *)directory performance:(id <FTStoragePerformancePreset>)performance;

// prefix: not allowed to contain `_`
-(instancetype)initWithDirectory:(FTDirectory *)directory performance:(id <FTStoragePerformancePreset>)performance prefix:(NSString *)prefix;

@end

NS_ASSUME_NONNULL_END

#endif
