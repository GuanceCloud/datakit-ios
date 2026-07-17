//
//  FTCoreDirectory.m
//  SessionReplay
//
//  Created by hulilei on 2026/6/4.
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

#import "FTCoreDirectory.h"
#import "FTDirectory.h"
#import "FTFeatureDirectories.h"

@implementation FTCoreDirectory

- (instancetype)initWithDirectory:(FTDirectory *)directory{
    self = [super init];
    if (self) {
        _directory = directory;
    }
    return self;
}

- (instancetype)initWithSubdirectoryPath:(NSString *)path{
    return [self initWithDirectory:[[FTDirectory alloc]initWithSubdirectoryPath:path]];
}

- (FTFeatureDirectories *)featureDirectoriesForFeatureName:(NSString *)featureName{
    FTDirectory *granted = [self.directory createSubdirectoryWithPath:featureName];
    if (!granted) {
        return nil;
    }
    FTDirectory *pending = [self.directory createSubdirectoryWithPath:[featureName stringByAppendingString:@".pending"]];
    FTDirectory *errorSampled = [self.directory createSubdirectoryWithPath:[featureName stringByAppendingString:@".cache"]];
    return [[FTFeatureDirectories alloc]initWithGranted:granted
                                                pending:pending
                                           errorSampled:errorSampled];
}

@end

#endif
