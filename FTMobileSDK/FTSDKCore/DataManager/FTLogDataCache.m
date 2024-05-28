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
@property (atomic, strong) dispatch_semaphore_t logSemaphore;
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
    }
    return self;
}
- (void)addLogData:(id)data{
    if (!data) {
        return;
    }
    pthread_mutex_lock(&_lock);
    [self.messageCaches addObject:data];
    self.logCount += 1;
    if (self.messageCaches.count>=20) {
        // 判断当前日志是否超额
        NSInteger sum = [self optLogCachePolicy:self.messageCaches.count];
        if (sum>=0) {
            [self.messageCaches removeObjectsInRange:NSMakeRange(sum, self.messageCaches.count-sum)];
        }
        [[FTTrackerEventDBTool sharedManger] insertItemsWithDatas:self.messageCaches];
        [self.messageCaches removeAllObjects];
    }
    pthread_mutex_unlock(&_lock);
    [self autoInsertCacheToDB];
}
- (void)autoInsertCacheToDB{
    if(self.logSemaphore){
        dispatch_semaphore_signal(self.logSemaphore);
    }else{
        self.logSemaphore = dispatch_semaphore_create(0);
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_async(self.logCacheQueue, ^{
        long result = dispatch_semaphore_wait(weakSelf.logSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)10*NSEC_PER_MSEC));
        if(result!=0){
            [weakSelf insertCacheToDB];
            if(weakSelf.logSemaphore) dispatch_semaphore_wait(weakSelf.logSemaphore, DISPATCH_TIME_FOREVER);
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
    if(self.logSemaphore)dispatch_semaphore_signal(self.logSemaphore);
    [self insertCacheToDB];
}
@end
