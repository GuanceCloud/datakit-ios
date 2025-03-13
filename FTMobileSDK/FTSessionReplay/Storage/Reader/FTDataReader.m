//
//  FTDataReader.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDataReader.h"
#import "FTLog+Private.h"
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
