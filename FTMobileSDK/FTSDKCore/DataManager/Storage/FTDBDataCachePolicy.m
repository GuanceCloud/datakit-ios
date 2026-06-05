//
//  FTLogDataCache.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDBDataCachePolicy.h"
#import "FTTrackerEventDBTool.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTSerialTimer.h"

static const NSUInteger kLogMemoryCacheFlushCount = 20;
static const NSTimeInterval kLogMemoryCacheFlushDelay = 0.1;
static const NSTimeInterval kLogMemoryCacheFlushLeeway = 0.01;
static const NSInteger kDBLimitRemoveCount = 100;
static void *FTLogCacheQueueKey = &FTLogCacheQueueKey;

@interface FTDBDataCachePolicy()

@property (atomic, assign) int logCacheLimitCount;
/// Whether to discard the latest data when logging type data exceeds the maximum value
@property (atomic, assign) BOOL logDiscardNew;
@property (atomic, assign) int  rumCacheLimitCount;
/// Whether to discard the latest data when logging type data exceeds the maximum value
@property (atomic, assign) BOOL rumDiscardNew;
@property (nonatomic, strong) dispatch_queue_t logCacheQueue;
@property (nonatomic, strong) NSMutableArray *messageCaches;
@property (nonatomic, strong) FTSerialTimer *logFlushTimer;
@property (nonatomic, assign) BOOL enableLimitWithDbSize;
@property (nonatomic, assign) long dbLimitSize;

@end
@implementation FTDBDataCachePolicy
- (instancetype)init{
    self = [super init];
    if(self){
        _enableLimitWithDbSize = NO;
        _logCacheQueue = dispatch_queue_create("com.ft.logger.write", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_logCacheQueue, FTLogCacheQueueKey, FTLogCacheQueueKey, NULL);
        _rumCacheLimitCount = FT_DB_RUM_MAX_COUNT;
        _logCacheLimitCount = FT_DB_LOG_MAX_COUNT;
        _rumCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
        _messageCaches = [NSMutableArray array];
        _logCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        __weak typeof(self) weakSelf = self;
        _logFlushTimer = [[FTSerialTimer alloc] initWithQueue:_logCacheQueue eventHandler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf flushLogCacheOnQueue];
        }];
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
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.logCacheQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.logCount += 1;
        [strongSelf.messageCaches addObject:data];
        if (strongSelf.messageCaches.count >= kLogMemoryCacheFlushCount) {
            [strongSelf cancelLogCacheFlushOnQueue];
            [strongSelf flushLogCacheOnQueue];
        } else {
            [strongSelf scheduleLogCacheFlushOnQueue];
        }
    });
}
- (BOOL)addRumData:(id)data{
    BOOL countIncludesPendingRUM = NO;
    if(self.enableLimitWithDbSize){
        if([self shouldDropRUMForDbLimit]){
            return NO;
        }
    }else{
        self.rumCount += 1;
        countIncludesPendingRUM = YES;
        NSInteger count = self.rumCacheLimitCount-self.rumCount;
        if(count<0){
            FTInnerLogInfo(@"RUM: DiscardData (%@)",self.rumDiscardNew?@"NEW":@"OLD");
            self.rumCount += count;
            if(self.rumDiscardNew){
                return NO;
            }
            [[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_RUM count:-count];
        }
    }
   BOOL result = [[FTTrackerEventDBTool sharedManager] insertItem:data];
   if (result) {
       [self trimDBBelowLimitAfterInsertIfNeeded];
   } else if (countIncludesPendingRUM) {
       self.rumCount = MAX(0, self.rumCount - 1);
   }
   return result;
}
- (NSInteger)optLogCachePolicy:(NSInteger)messageCaches{
    if(self.enableLimitWithDbSize){
        if([self shouldDropLogForDbLimitWithCount:messageCaches]){
            self.logCount -= messageCaches;
            return 0;
        }
    }else{
        NSInteger overflowCount = self.logCount - self.logCacheLimitCount;
        if(overflowCount>0){
            FTInnerLogInfo(@"LOG: DiscardData (%@) Counts %ld",self.logDiscardNew?@"NEW":@"OLD",(long)overflowCount);
            if(self.logDiscardNew){
                NSInteger keepCount = MAX(0, messageCaches - overflowCount);
                self.logCount -= (messageCaches - keepCount);
                return keepCount;
            }else{
                self.logCount -= overflowCount;
                [[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_LOGGING count:overflowCount];
                return -1;
            }
        }
    }
    return -1;
}
- (long long)refreshCurrentDbSize{
    long long pageSize = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    self.currentDbSize = pageSize;
    return pageSize;
}
- (NSInteger)deleteOldLogRecordsForDbLimitWithCount:(NSInteger)count{
    NSInteger before = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    if (before <= 0) {
        return 0;
    }
    NSInteger deleteCount = MIN(MAX(1, count), before);
    if (![[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_LOGGING count:deleteCount]) {
        return 0;
    }
    NSInteger after = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    NSInteger deletedCount = MAX(0, before - after);
    self.logCount = MAX(0, self.logCount - deletedCount);
    if (deletedCount > 0) {
        FTInnerLogInfo(@"ReachDbLimit: cleared old LOG data count %ld",(long)deletedCount);
    }
    return deletedCount;
}
- (NSInteger)deleteOldRUMRecordsForDbLimitWithCount:(NSInteger)count{
    NSInteger before = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
    if (before <= 0) {
        return 0;
    }
    NSInteger deleteCount = MIN(MAX(1, count), before);
    if (![[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_RUM count:deleteCount]) {
        return 0;
    }
    NSInteger after = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
    NSInteger deletedCount = MAX(0, before - after);
    self.rumCount = MAX(0, self.rumCount - deletedCount);
    return deletedCount;
}
- (NSInteger)deleteOldUploadRecordsForDbLimit{
    NSInteger beforeLogCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    NSInteger beforeRUMCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
    if (beforeLogCount + beforeRUMCount <= 0) {
        return 0;
    }
    if (![[FTTrackerEventDBTool sharedManager] deleteUploadDataWithCount:kDBLimitRemoveCount]) {
        return 0;
    }
    NSInteger afterLogCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    NSInteger afterRUMCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
    NSInteger deletedLogCount = MAX(0, beforeLogCount - afterLogCount);
    NSInteger deletedRUMCount = MAX(0, beforeRUMCount - afterRUMCount);
    self.logCount = MAX(0, self.logCount - deletedLogCount);
    self.rumCount = MAX(0, self.rumCount - deletedRUMCount);
    return deletedLogCount + deletedRUMCount;
}
- (BOOL)trimDBBelowLimitByDeletingOldestRecords{
    while ([self refreshCurrentDbSize] >= self.dbLimitSize) {
        NSInteger deletedCount = [self deleteOldLogRecordsForDbLimitWithCount:kDBLimitRemoveCount];
        if (deletedCount <= 0) {
            deletedCount = [self deleteOldUploadRecordsForDbLimit];
        }
        if (deletedCount <= 0) {
            return NO;
        }
    }
    return YES;
}
// NO: Not exceeded\Exceeded but deleted old data YES: Exceeded, discard new data
- (BOOL)shouldDropRUMForDbLimit{
    long long pageSize = [self refreshCurrentDbSize];
    if (pageSize < self.dbLimitSize){
        return NO;
    }
    FTInnerLogInfo(@"ReachDbLimit(%lld KB)-RUM priority discard strategy (%@)",pageSize/1024,self.dbDiscardNew?@"NEW":@"OLD");
    if ([self deleteOldLogRecordsForDbLimitWithCount:kDBLimitRemoveCount] > 0) {
        return NO;
    }
    if (self.dbDiscardNew) {
        return YES;
    }
    [self deleteOldRUMRecordsForDbLimitWithCount:1];
    return NO;
}
// NO: Not exceeded\Exceeded but deleted old LOG data YES: Exceeded, discard new LOG data
- (BOOL)shouldDropLogForDbLimitWithCount:(NSInteger)count{
    long long pageSize = [self refreshCurrentDbSize];
    if (pageSize < self.dbLimitSize){
        return NO;
    }
    FTInnerLogInfo(@"ReachDbLimit(%lld KB)-LOG discard strategy (%@)",pageSize/1024,self.dbDiscardNew?@"NEW":@"OLD");
    if (self.dbDiscardNew) {
        return YES;
    }
    return [self deleteOldLogRecordsForDbLimitWithCount:count] <= 0;
}
- (void)trimDBBelowLimitAfterInsertIfNeeded{
    if (!self.enableLimitWithDbSize || self.dbDiscardNew) {
        return;
    }
    [self trimDBBelowLimitByDeletingOldestRecords];
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

- (void)scheduleLogCacheFlushOnQueue{
    [self.logFlushTimer scheduleAfter:kLogMemoryCacheFlushDelay leeway:kLogMemoryCacheFlushLeeway];
}
- (void)cancelLogCacheFlushOnQueue{
    [self.logFlushTimer cancel];
}
- (void)flushLogCacheOnQueueWithCallback:(BOOL)shouldCallback{
    if (self.messageCaches.count == 0) {
        return;
    }
    NSInteger sum = [self optLogCachePolicy:self.messageCaches.count];
    if (sum>=0) {
        [self.messageCaches removeObjectsInRange:NSMakeRange(sum, self.messageCaches.count-sum)];
    }
    NSArray *array = [self.messageCaches copy];
    [self.messageCaches removeAllObjects];
    if (array.count == 0) {
        return;
    }
    BOOL result = [[FTTrackerEventDBTool sharedManager] insertItemsWithDatas:array];
    if (!result) {
        FTInnerLogError(@"LOG: Failed to insert cache into database, count %lu",(unsigned long)array.count);
        self.logCount = MAX(0, self.logCount - (NSInteger)array.count);
        return;
    }
    [self trimDBBelowLimitAfterInsertIfNeeded];
    if (shouldCallback && self.callback) self.callback();
}
- (void)flushLogCacheOnQueue{
    [self flushLogCacheOnQueueWithCallback:YES];
}
- (void)insertCacheToDB{
    [self insertCacheToDBWithCallback:YES];
}
- (void)insertCacheToDBWithoutCallback{
    [self insertCacheToDBWithCallback:NO];
}
- (void)insertCacheToDBWithCallback:(BOOL)shouldCallback{
    if (dispatch_get_specific(FTLogCacheQueueKey)) {
        [self cancelLogCacheFlushOnQueue];
        [self flushLogCacheOnQueueWithCallback:shouldCallback];
        return;
    }
    dispatch_queue_t logCacheQueue = self.logCacheQueue;
    __weak typeof(self) weakSelf = self;
    dispatch_sync(logCacheQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf cancelLogCacheFlushOnQueue];
        [strongSelf flushLogCacheOnQueueWithCallback:shouldCallback];
    });
}
#pragma mark --------- FTUploadCountProtocol ----------
- (void)uploadLogCount:(NSInteger)count{
    self.logCount -= count;
}
- (void)uploadRUMCount:(NSInteger)count{
    self.rumCount -= count;
}
-(void)dealloc{
    [self.logFlushTimer invalidate];
}
@end
