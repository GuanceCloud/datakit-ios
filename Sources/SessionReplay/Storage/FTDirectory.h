//
//  FTDirectory.h
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
@class FTFile;
@interface FTDirectory : NSObject
@property (nonatomic, strong, readonly) NSURL *url;

-(instancetype)initWithUrl:(NSURL *)url;
-(instancetype)initWithSubdirectoryPath:(NSString *)path;

- (NSArray<FTFile*>*)files;
- (nullable FTFile *)createFile:(NSString *)fileName;
- (BOOL)hasFileWithName:(NSString *)fileName;
- (nullable FTFile *)fileWithName:(NSString *)fileName;
- (nullable FTDirectory *)createSubdirectoryWithPath:(NSString *)path;
- (void)moveAllFilesToDestinationDirectory:(FTDirectory *)directory;
- (void)deleteAllFiles;
@end

NS_ASSUME_NONNULL_END

#endif
