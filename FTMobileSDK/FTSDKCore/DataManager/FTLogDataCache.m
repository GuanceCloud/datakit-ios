//
//  FTLogDataCache.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTLogDataCache.h"
#import "FTTrackerEventDBTool.h"
#import <pthread.h>
#import "FTConstants.h"
@interface FTLogDataCache()
@property (nonatomic, strong) dispatch_queue_t logCacheQueue;
@property (nonatomic, strong) NSMutableArray *messageCaches;
@property (nonatomic, strong) dispatch_semaphore_t logSemaphore;
@property (atomic, assign) BOOL semaphoreWaiting;

@end
@implementation FTLogDataCache{
    pthread_mutex_t _lock;
}
-(instancetype)init{
    return [self initWithLogCacheLimitCount:FT_DB_CONTENT_MAX_COUNT logDiscardNew:YES];
}
- (instancetype)initWithLogCacheLimitCount:(int)count logDiscardNew:(BOOL)discardNew{
    self = [super init];
    if(self){
        _logCacheLimitCount = count;
        _discardNew = discardNew;
        _messageCaches = [NSMutableArray array];
        _logCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        _logCacheQueue = dispatch_queue_create("com.guance.logger.write", DISPATCH_QUEUE_SERIAL);
        _logSemaphore = dispatch_semaphore_create(0);
        _semaphoreWaiting = NO;
        pthread_mutex_init(&(self->_lock), NULL);
    }
    return self;
}
- (void)addLogData:(id)data{
    if (!data) {
        return;
    }
    BOOL fullArray = NO;
    pthread_mutex_lock(&_lock);
    [self.messageCaches addObject:data];
    self.logCount += 1;
    fullArray = self.messageCaches.count == 20;
    pthread_mutex_unlock(&_lock);
    [self autoInsertCacheToDB];
    if(fullArray){
        [self insertCacheToDB];
    }
}
- (void)autoInsertCacheToDB{
    if(self.semaphoreWaiting){
        dispatch_semaphore_signal(self.logSemaphore);
    }else{
        self.semaphoreWaiting = YES;
    }
    dispatch_async(self.logCacheQueue, ^{
        if(self.logSemaphore){
            long result = dispatch_semaphore_wait(self.logSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)FT_TIME_INTERVAL*NSEC_PER_MSEC));
            if(result!=0){
                self.semaphoreWaiting = NO;
                [self insertCacheToDB];
            }
        }
    });
}
- (NSInteger)optLogCachePolicy:(NSInteger)messageCaches{
    NSInteger count = self.logCacheLimitCount - self.logCount;
    if(count<0){
        self.logCount += count;
        if(self.discardNew){
            NSInteger sum = count+messageCaches;
            if (sum>=0) {
                return sum;
            }
        }else{
            [[FTTrackerEventDBTool sharedManger] deleteLoggingItem:-count];
            return -1;
        }
    }
    return -1;
}
// 添加的日志数量超多限额一半
- (BOOL)reachHalfLimit{
    return self.logCacheLimitCount > 0 && self.logCount > self.logCacheLimitCount / 2;
}
- (void)insertCacheToDB{
    pthread_mutex_lock(&_lock);
    if (self.messageCaches.count > 0) {
        NSInteger sum = [self optLogCachePolicy:self.messageCaches.count];
        if (sum>=0) {
            [self.messageCaches removeObjectsInRange:NSMakeRange(sum, self.messageCaches.count-sum)];
        }
        NSArray *array = [self.messageCaches copy];
        [self.messageCaches removeAllObjects];
        pthread_mutex_unlock(&_lock);
        [[FTTrackerEventDBTool sharedManger] insertItemsWithDatas:array];
    }else{
        pthread_mutex_unlock(&_lock);
    }
}
-(void)dealloc{
    if(self.logSemaphore) dispatch_semaphore_signal(self.logSemaphore);
    [self insertCacheToDB];
}
@end
