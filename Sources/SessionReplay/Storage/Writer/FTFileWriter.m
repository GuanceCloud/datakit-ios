//
//  FTFileWriter.m
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

#import "FTFileWriter.h"
#import "FTFilesOrchestrator.h"
#import "FTTLV.h"
#import "FTFile.h"
#import "FTSRBaseFrame.h"
#import "FTSessionReplayCoreImports.h"
@interface FTFileWriter()
@property (nonatomic, strong) id<FTFilesOrchestratorType> orchestrator;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation FTFileWriter
-(instancetype)initWithOrchestrator:(id<FTFilesOrchestratorType>)orchestrator queue:(dispatch_queue_t)queue{
    self = [super init];
    if(self){
        _orchestrator = orchestrator;
        _queue = queue;
    }
    return self;
}
-(void)write:(NSData *)datas{
    [self write:datas forceNewFile:NO];
}
- (void)write:(NSData *)datas forceNewFile:(BOOL)force{
    dispatch_async(self.queue, ^{
        @try {
            NSData *data = datas;
            FTTLV *tlv = [[FTTLV alloc]initWithType:1 value:data];
            data = [tlv serialize];
            long long fileSize = data.length;
            id<FTWritableFile> file = [self.orchestrator getWritableFile:fileSize forceNewFile:force];
            [file append:data];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
@end

#endif
