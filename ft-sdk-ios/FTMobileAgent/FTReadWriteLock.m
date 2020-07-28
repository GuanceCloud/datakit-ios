//
//  FTReadWriteLock.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/7/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTReadWriteLock.h"
@interface FTReadWriteLock ()
@property (nonatomic, strong) dispatch_queue_t concurentQueue;
@end
@implementation FTReadWriteLock
- (instancetype)initWithQueueLabel:(NSString *)queueLabel {
    self = [super init];
    if (self) {
        NSString *concurentQueueLabel = nil;
        if (queueLabel && queueLabel.length>0) {
            concurentQueueLabel = queueLabel;
        } else {
            concurentQueueLabel = [NSString stringWithFormat:@"com.readWriteLock.%p", self];
        }
        
        self.concurentQueue = dispatch_queue_create([concurentQueueLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
- (id)readWithBlock:(id(^)(void))block{
    if (!block) {
        return nil;
    }
    __block id obj = nil;
    dispatch_sync(self.concurentQueue, ^{
        obj = block();
    });
    return obj;
}

- (void)writeWithBlock:(void (^)(void))block{
    if (!block) {
        return;
    }
    dispatch_barrier_async(self.concurentQueue, ^{
        block();
    });
}
- (void)dealloc
{
    _concurentQueue = nil;
}

@end
