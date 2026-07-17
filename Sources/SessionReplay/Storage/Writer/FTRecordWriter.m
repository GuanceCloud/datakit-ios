//
//  FTRecordWriter.m
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

#import "FTRecordWriter.h"
#import "FTFileWriter.h"
#import "FTFeatureScope.h"

@interface FTRecordWriter()
@property (nonatomic, strong) FTFeatureScope *featureScope;
@end

@implementation FTRecordWriter

- (instancetype)initWithFeatureScope:(FTFeatureScope *)featureScope{
    self = [super init];
    if(self){
        _featureScope = featureScope;
    }
    return self;
}

- (BOOL)isErrorSampled{
    return self.featureScope.isErrorSampled;
}

- (void)write:(NSData *)data{
    [self write:data forceNewFile:NO];
}

- (void)write:(NSData *)data forceNewFile:(BOOL)force{
    [self.featureScope eventWriteContext:^(__unused FTFeatureContext *context, id<FTWriter> writer) {
        [writer write:data forceNewFile:force];
    }];
}

@end

#endif
