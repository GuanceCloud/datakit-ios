//
//  FTDataWriterManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/26.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDataWriterManager.h"
#import "FTRUMDataWriteProtocol.h"
#import "FTConstants.h"
#import "FTTrackDataManager.h"
#import "FTRecordModel.h"
#import "FTPresetProperty.h"
#import "FTLog+Private.h"
#import "FTTrackerEventDBTool.h"
#import <os/lock.h>

@interface FTDataWriterManager()
@property (atomic, assign) BOOL isCache;
@property (nonatomic, assign) NSTimeInterval cacheInvalidTimeInterval;
@property (nonatomic, strong) dispatch_source_t deleteTimer; // GCD 定时器
@property (nonatomic, assign) BOOL isTimerRunning;
@end
@implementation FTDataWriterManager{
    dispatch_queue_t _timerControlQueue; // 串行队列用于控制定时器
    os_unfair_lock _timerLock; // 互斥锁保护定时器状态
}
-(instancetype)init{
    return [self initWithCacheInvalidTimeInterval:60];
}
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval{
    self = [super init];
    if(self){
        _cacheInvalidTimeInterval = timeInterval;
        _timerControlQueue = dispatch_queue_create("com.guance.rumOnError.cache", DISPATCH_QUEUE_SERIAL);
        _timerLock = OS_UNFAIR_LOCK_INIT; // 初始化锁
        // 应用进入新的生命周期，删除旧的 session 数据
        [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE];
    }
    return self;
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    if (![source isKindOfClass:NSString.class] || source.length == 0) {
        return;
    }
    @try {
        NSMutableDictionary *baseTags = [NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:tags];
        NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumProperty];
        [baseTags addEntriesFromDictionary:rumProperty];
        // 如果是 session on error 的数据，在写入 error 时切换成正常的 rum 数据写入类型。并将发生 error 前 cacheInvalidTimeInterval 的数据类型更新为 rum.
        if(self.isCache && [source isEqualToString:FT_RUM_SOURCE_ERROR]){
            self.isCache = NO;
            long long deleteTime = time - self.cacheInvalidTimeInterval * 1e9;
            if(deleteTime <= 0){
                deleteTime = [NSDate dateWithTimeIntervalSinceNow:-self.cacheInvalidTimeInterval].timeIntervalSince1970 * 1e9;
            }
            [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE time:deleteTime];
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM time:time];
            [self stopCacheDeleteTimer];
        }
        NSString *type = self.isCache ? FT_DATA_TYPE_RUM_CACHE : FT_DATA_TYPE_RUM;
        FTAddDataType addType = self.isCache ? FTAddDataRUMCache : FTAddDataRUM;
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:source op:type tags:baseTags fields:fields tm:time];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:addType];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}

- (void)extensionRumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    if (![source isKindOfClass:NSString.class] || source.length == 0) {
        return;
    }
    @try {
        NSMutableDictionary *baseTags = [NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:tags];
        NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumProperty];
        [baseTags addEntriesFromDictionary:rumProperty];
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:source op:FT_DATA_TYPE_RUM tags:baseTags fields:fields tm:time];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
// FT_DATA_TYPE_LOGGING
-(void)logging:(NSString *)content status:(NSString *)status tags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time{
    @try {
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[[FTPresetProperty sharedInstance] loggerProperty]];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        [tagDict setValue:status forKey:FT_KEY_STATUS];
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content?:@"",
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
#if TARGET_OS_TV
        NSString *source = FT_LOGGER_TVOS_SOURCE;
#else
        NSString *source = FT_LOGGER_SOURCE;
#endif
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:source op:FT_DATA_TYPE_LOGGING tags:tagDict fields:filedDict tm:time];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}

-(void)switchToCacheWriter{
    self.isCache = YES;
    [self startCacheDeleteTimer];
}
#pragma mark -- Cache Delete GCD Timer --
- (void)startCacheDeleteTimer{
    dispatch_async(_timerControlQueue, ^{
        os_unfair_lock_lock(&self->_timerLock); // 加锁
        if (self.isTimerRunning) {
            os_unfair_lock_unlock(&self->_timerLock);
            return; // 已运行则直接返回
        }
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.deleteTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        
        if (self.deleteTimer) {
        
            dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC));
            uint64_t interval = (uint64_t)(self.cacheInvalidTimeInterval * NSEC_PER_SEC);
            
            dispatch_source_set_timer(self.deleteTimer, startTime, interval, 0);
            
            __weak typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(self.deleteTimer, ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf deleteDatas];
            });
            
            dispatch_resume(self.deleteTimer);
            self.isTimerRunning = YES; // 更新状态
        }
        
        os_unfair_lock_unlock(&self->_timerLock); // 解锁
    });
}
- (void)stopCacheDeleteTimer{
    dispatch_sync(_timerControlQueue, ^{
        os_unfair_lock_lock(&self->_timerLock);
        if (self.deleteTimer) {
            if (dispatch_source_testcancel(self.deleteTimer) == 0) {
                dispatch_source_cancel(self.deleteTimer); // 安全取消
            }
            self.deleteTimer = nil;
            self.isTimerRunning = NO; // 更新状态
        }
        os_unfair_lock_unlock(&self->_timerLock);
    });
}
- (void)deleteDatas{
    long long deleteTime = [NSDate dateWithTimeIntervalSinceNow:-self.cacheInvalidTimeInterval].timeIntervalSince1970 * 1e9;
    [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE time:deleteTime];
}
-(void)dealloc{
    [self stopCacheDeleteTimer];
}
@end
