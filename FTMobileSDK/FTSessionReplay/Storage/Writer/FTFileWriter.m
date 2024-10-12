//
//  FTFileWriter.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFileWriter.h"
#import "FTFilesOrchestrator.h"
#import "FTTLV.h"
#import "FTFile.h"
#import "FTSRBaseFrame.h"
#import "FTLog+Private.h"
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
