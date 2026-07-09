//
//  FTLogDataCache.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTDBDataCachePolicy.h"
#import "FTTrackerEventDBTool.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTSerialTimer.h"
#import <pthread.h>

static const NSUInteger kLogMemoryCacheFlushCount = 20;
static const NSTimeInterval kLogMemoryCacheFlushDelay = 0.1;
static const NSTimeInterval kLogMemoryCacheFlushLeeway = 0.01;
static const NSInteger kDBLimitRemoveCount = 100;

@interface FTDBDataCachePolicy()

@property (atomic, assign) int logCacheLimitCount;
/// Whether to discard the latest data when logging type data exceeds the maximum value
@property (atomic, assign) BOOL logDiscardNew;
@property (atomic, assign) int  rumCacheLimitCount;
/// Whether to discard the latest data when logging type data exceeds the maximum value
@property (atomic, assign) BOOL rumDiscardNew;
@property (nonatomic, strong) NSMutableArray *messageCaches;
@property (nonatomic, strong) FTSerialTimer *logFlushTimer;
@property (nonatomic, assign) BOOL enableLimitWithDbSize;
@property (nonatomic, assign) long dbLimitSize;
@property (atomic, assign) NSInteger logCount;
@property (atomic, assign) NSInteger rumCount;

@end
@implementation FTDBDataCachePolicy{
    pthread_mutex_t _logCacheLock;
}
- (instancetype)init{
    self = [super init];
    if(self){
        _enableLimitWithDbSize = NO;
        pthread_mutex_init(&_logCacheLock, NULL);
        _rumCacheLimitCount = FT_DB_RUM_MAX_COUNT;
        _logCacheLimitCount = FT_DB_LOG_MAX_COUNT;
        _rumCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM];
        _messageCaches = [NSMutableArray array];
        _logCount = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        __weak typeof(self) weakSelf = self;
        _logFlushTimer = [[FTSerialTimer alloc] initWithEventHandler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf flushLogCache];
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
    BOOL shouldFlush = NO;
    pthread_mutex_lock(&_logCacheLock);
    self.logCount += 1;
    [self.messageCaches addObject:data];
    shouldFlush = self.messageCaches.count >= kLogMemoryCacheFlushCount;
    pthread_mutex_unlock(&_logCacheLock);
    if (shouldFlush) {
        [self cancelLogCacheFlush];
        [self flushLogCache];
    } else {
        [self scheduleLogCacheFlush];
    }
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
    [self decreaseLogCount:deletedCount];
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
    [self decreaseLogCount:deletedLogCount];
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
    pthread_mutex_lock(&_logCacheLock);
    BOOL reach = self.logCacheLimitCount > 0 && self.logCount > self.logCacheLimitCount / 2;
    pthread_mutex_unlock(&_logCacheLock);
    return reach;
}
- (BOOL)reachRumHalfLimit{
    return self.rumCacheLimitCount > 0 && self.rumCount > self.rumCacheLimitCount / 2;
}

- (void)scheduleLogCacheFlush{
    [self.logFlushTimer scheduleAfter:kLogMemoryCacheFlushDelay leeway:kLogMemoryCacheFlushLeeway];
}
- (void)cancelLogCacheFlush{
    [self.logFlushTimer cancel];
}
- (void)decreaseLogCount:(NSInteger)count{
    if (count <= 0) {
        return;
    }
    pthread_mutex_lock(&_logCacheLock);
    self.logCount = MAX(0, self.logCount - count);
    pthread_mutex_unlock(&_logCacheLock);
}
- (NSArray *)drainLogCache{
    pthread_mutex_lock(&_logCacheLock);
    if (self.messageCaches.count == 0) {
        pthread_mutex_unlock(&_logCacheLock);
        return @[];
    }
    NSArray *array = [self.messageCaches copy];
    [self.messageCaches removeAllObjects];
    pthread_mutex_unlock(&_logCacheLock);
    return array;
}
- (NSArray *)logsByApplyingCachePolicy:(NSArray *)logs{
    NSInteger logCacheCount = logs.count;
    if (logCacheCount == 0) {
        return logs;
    }
    if(self.enableLimitWithDbSize){
        if([self shouldDropLogForDbLimitWithCount:logCacheCount]){
            [self decreaseLogCount:logCacheCount];
            return @[];
        }
        return logs;
    }
    pthread_mutex_lock(&_logCacheLock);
    NSInteger overflowCount = self.logCount - self.logCacheLimitCount;
    BOOL logDiscardNew = self.logDiscardNew;
    pthread_mutex_unlock(&_logCacheLock);
    if(overflowCount<=0){
        return logs;
    }
    FTInnerLogInfo(@"LOG: DiscardData (%@) Counts %ld",logDiscardNew?@"NEW":@"OLD",(long)overflowCount);
    if(logDiscardNew){
        NSInteger keepCount = MAX(0, logCacheCount - overflowCount);
        NSInteger dropCount = logCacheCount - keepCount;
        [self decreaseLogCount:dropCount];
        if (keepCount == 0) {
            return @[];
        }
        return [logs subarrayWithRange:NSMakeRange(0, keepCount)];
    }else{
        NSInteger deletedCount = [self deleteOldLogRecordsForDbLimitWithCount:overflowCount];
        NSInteger dropCount = MIN(MAX(0, overflowCount - deletedCount), logCacheCount);
        [self decreaseLogCount:dropCount];
        if (dropCount == 0) {
            return logs;
        }
        if (dropCount == logCacheCount) {
            return @[];
        }
        return [logs subarrayWithRange:NSMakeRange(dropCount, logCacheCount - dropCount)];
    }
}
- (void)flushLogCacheWithCallback:(BOOL)shouldCallback{
    NSArray *array = [self drainLogCache];
    array = [self logsByApplyingCachePolicy:array];
    if (array.count == 0) {
        return;
    }
    BOOL result = [[FTTrackerEventDBTool sharedManager] insertItemsWithDatas:array];
    if (!result) {
        FTInnerLogError(@"LOG: Failed to insert cache into database, count %lu",(unsigned long)array.count);
        [self decreaseLogCount:(NSInteger)array.count];
        return;
    }
    [self trimDBBelowLimitAfterInsertIfNeeded];
    if (shouldCallback && self.callback) self.callback();
}
- (void)flushLogCache{
    [self flushLogCacheWithCallback:YES];
}
- (void)insertCacheToDB{
    [self insertCacheToDBWithCallback:YES];
}
- (void)insertCacheToDBWithoutCallback{
    [self insertCacheToDBWithCallback:NO];
}
- (void)insertCacheToDBWithCallback:(BOOL)shouldCallback{
    [self cancelLogCacheFlush];
    [self flushLogCacheWithCallback:shouldCallback];
}
#pragma mark --------- FTUploadCountProtocol ----------
- (void)uploadLogCount:(NSInteger)count{
    [self decreaseLogCount:count];
}
- (void)uploadRUMCount:(NSInteger)count{
    self.rumCount -= count;
}
-(void)dealloc{
    [self.logFlushTimer invalidate];
    pthread_mutex_destroy(&_logCacheLock);
}
@end
