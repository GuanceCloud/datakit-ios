//
//  FTFileReader.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/26.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFileReader.h"
#import "FTFilesOrchestrator.h"
#import "FTFile.h"
#import "FTTLVReader.h"
#import "FTPerformancePreset.h"
#import "FTLog+Private.h"
@interface FTFileReader ()
@property (nonatomic, strong) id<FTFilesOrchestratorType> orchestrator;
@property (nonatomic, strong) NSMutableSet *filesRead;
@end
@implementation FTFileReader
- (instancetype)initWithOrchestrator:(id<FTFilesOrchestratorType>)orchestrator{
    self = [super init];
    if(self){
        _orchestrator = orchestrator;
    }
    return self;
}
- (void)markBatchAsRead:(nonnull FTBatch *)batch {
    [self.orchestrator deleteReadableFile:batch.file];
    [self.filesRead addObject:batch.file.name];
}

- (nullable FTBatch *)readBatch:(nonnull id<FTReadableFile>)file { 
    FTTLVReader *reader = [[FTTLVReader alloc]initWithStream:file.stream maxDataLength:self.orchestrator.performance.maxObjectSize];
    NSArray *datas = [reader all];
    if(datas.count == 0){
        return nil;
    }
    return [[FTBatch alloc]initWithFile:file datas:datas];
}

- (nonnull NSArray<id<FTReadableFile>> *)readFiles:(int)limit { 
    return [self.orchestrator getReadableFiles:self.filesRead limit:limit];
}

@end
