//
//  FTLogDataCache.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDBDataCachePolicy.h"
#import "FTTrackerEventDBTool.h"
#import <pthread.h>
#import "FTConstants.h"
#import "FTLog+Private.h"
#import "FTTrackerEventDBTool.h"
@interface FTDBDataCachePolicy()

@property (atomic, assign) int logCacheLimitCount;
/// Whether to discard the latest data when logging type data exceeds the maximum value
@property (atomic, assign) BOOL logDiscardNew;
@property (atomic, assign) int  rumCacheLimitCount;
/// Whether to discard the latest data when logging type data exceeds the maximum value
@property (atomic, assign) BOOL rumDiscardNew;
@property (nonatomic, strong) dispatch_queue_t logCacheQueue;
@property (nonatomic, strong) NSMutableArray *messageCaches;
@property (nonatomic, strong) dispatch_semaphore_t logSemaphore;
@property (atomic, assign) BOOL semaphoreWaiting;
@property (nonatomic, assign) BOOL enableLimitWithDbSize;
@property (nonatomic, assign) long dbLimitSize;

@end
@implementation FTDBDataCachePolicy{
    pthread_mutex_t _lock;
}
- (instancetype)init{
    self = [super init];
    if(self){
        _enableLimitWithDbSize = NO;
        _logCacheQueue = dispatch_queue_create("com.guance.logger.write", DISPATCH_QUEUE_SERIAL);
        _logSemaphore = dispatch_semaphore_create(0);
        _semaphoreWaiting = NO;
        pthread_mutex_init(&(self->_lock), NULL);
        _rumCacheLimitCount = FT_DB_RUM_MAX_COUNT;
        _logCacheLimitCount = FT_DB_LOG_MAX_COUNT;
        _rumCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
        _messageCaches = [NSMutableArray array];
        _logCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    }
    return self;
}
-(void)setDBLimitWithSize:(long)size discardNew:(BOOL)discardNew{
    _enableLimitWithDbSize = YES;
    _dbLimitSize = size;
    _dbDiscardNew = discardNew;
}
- (void)setLogCacheLimitCount:(int)count discardNew:(BOOL)discardNew{
    _logCacheLimitCount = count;
    _logDiscardNew = discardNew;
   
}
- (void)setRumCacheLimitCount:(int)count discardNew:(BOOL)discardNew{
    _rumCacheLimitCount = count;
    _rumDiscardNew = discardNew;
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
- (BOOL)addRumData:(id)data{
    if(self.enableLimitWithDbSize){
        if([self reachDbLimit]){
            return NO;
        }
    }else{
        self.rumCount += 1;
        NSInteger count = self.rumCacheLimitCount-self.rumCount;
        if(count<0){
            FTInnerLogInfo(@"RUM: DiscardData (%@)",self.rumDiscardNew?@"NEW":@"OLD");
            self.rumCount += count;
            if(self.rumDiscardNew){
                return NO;
            }
            [[FTTrackerEventDBTool sharedManger] deleteDataWithType:FT_DATA_TYPE_RUM count:-count];
        }
    }
   return [[FTTrackerEventDBTool sharedManger] insertItem:data];
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
    if(self.enableLimitWithDbSize){
        if([self reachDbLimit]){
            return 0;
        }
    }else{
        NSInteger count = self.logCacheLimitCount - self.logCount;
        if(count<0){
            FTInnerLogInfo(@"LOG: DiscardData (%@) Counts %ld",self.rumDiscardNew?@"NEW":@"OLD",(long)-count);
            self.logCount += count;
            if(self.logDiscardNew){
                NSInteger sum = count+messageCaches;
                if (sum>=0) {
                    return sum;
                }
            }else{
                [[FTTrackerEventDBTool sharedManger] deleteDataWithType:FT_DATA_TYPE_LOGGING count:-count];
                return -1;
            }
        }
    }
    return -1;
}
// NO: Not exceeded\Exceeded but delete old data YES: Exceeded, delete new data
- (BOOL)reachDbLimit{
    long pageSize = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    self.currentDbSize = pageSize;
    if (pageSize > self.dbLimitSize){
        FTInnerLogInfo(@"ReachDbLimit(%ld KB)-DiscardData (%@)",pageSize/1024,self.dbDiscardNew?@"NEW":@"OLD");
        if (self.dbDiscardNew) {
            return YES;
        }else{
           BOOL delete = [[FTTrackerEventDBTool sharedManger] deleteDataWithCount:100];
           return !delete;
        }
    }
    return NO;
}
- (BOOL)reachHalfLimit{
    if(_enableLimitWithDbSize){
        return self.dbLimitSize>0 && self.currentDbSize > self.dbLimitSize / 2;
    }else{
        return [self reachLogHalfLimit] || [self reachRumHalfLimit];
    }
}
// Added log count exceeds half the limit
- (BOOL)reachLogHalfLimit{
    return self.logCacheLimitCount > 0 && self.logCount > self.logCacheLimitCount / 2;
}
- (BOOL)reachRumHalfLimit{
    return self.rumCacheLimitCount > 0 && self.rumCount > self.rumCacheLimitCount / 2;
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
        if (self.callback) self.callback();
    }else{
        pthread_mutex_unlock(&_lock);
    }
}
#pragma mark --------- FTUploadCountProtocol ----------
- (void)uploadLogCount:(NSInteger)count{
    self.logCount -= count;
}
- (void)uploadRUMCount:(NSInteger)count{
    self.rumCount -= count;
}
-(void)dealloc{
    if(self.logSemaphore) dispatch_semaphore_signal(self.logSemaphore);
    [self insertCacheToDB];
}
@end
