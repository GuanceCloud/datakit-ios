//
//  FTDataReader.m
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

#import "FTDataReader.h"
#import "FTSessionReplayCoreImports.h"
@interface FTDataReader()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) id<FTReader> fileReader;
@end
@implementation FTDataReader
-(instancetype)initWithQueue:(dispatch_queue_t)queue fileReader:(id<FTReader>)fileReader{
    self = [super init];
    if(self){
        _queue = queue;
        _fileReader = fileReader;
    }
    return self;
}
- (void)markBatchAsRead:(nonnull FTBatch *)batch {
    dispatch_sync(self.queue, ^{
        @try {
            [self.fileReader markBatchAsRead:batch];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
- (nullable FTBatch *)readBatch:(nonnull id<FTReadableFile>)file { 
    __block FTBatch *batch;
    dispatch_sync(self.queue, ^{
        @try {
            batch = [self.fileReader readBatch:file];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
    return batch;
}

- (nonnull NSArray<id<FTReadableFile>> *)readFiles:(int)limit { 
    __block NSArray *files;
    dispatch_sync(self.queue, ^{
        files = [self.fileReader readFiles:limit];
    });
    return files;
}

@end

#endif
