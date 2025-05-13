//
//  FTDataWriterWorker.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/26.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDataWriterWorker.h"
#import "FTRUMDataWriteProtocol.h"
#import "FTConstants.h"
#import "FTTrackDataManager.h"
#import "FTRecordModel.h"
#import "FTPresetProperty.h"
#import "FTLog+Private.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import <os/lock.h>
#import "FTAppLaunchTracker.h"
@interface FTDataWriterWorker()
@property (atomic, assign) BOOL isCache;
@property (nonatomic, assign) NSTimeInterval cacheInvalidTimeInterval;
@property (atomic, assign) NSTimeInterval lastErrorTimeInterval;
@property (nonatomic, assign) BOOL isTimerRunning;
@property (nonatomic, assign) long long processStartTime;
@property (nonatomic, assign) long long lastProcessFatalErrorTime;
@property (nonatomic, strong) dispatch_queue_t errorSampledConsumeQueue;
@end
@implementation FTDataWriterWorker
-(instancetype)init{
    return [self initWithCacheInvalidTimeInterval:60];
}
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval{
    self = [super init];
    if(self){
        _cacheInvalidTimeInterval = timeInterval*1e9;
        _processStartTime = [[NSDate dateWithTimeIntervalSinceReferenceDate:FTAppLaunchTracker.processStartTime] ft_nanosecondTimeStamp];
        _errorSampledConsumeQueue = dispatch_queue_create("com.guance.errorSampledConsume", 0);
        _lastProcessFatalErrorTime = -1;
        _lastErrorTimeInterval = 0;
        [self checkLastProcessErrorSampled];
    }
    return self;
}
// 在 rum 队列或者 longtask 队列调用
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    [self rumWrite:source tags:tags fields:fields time:time updateTime:0];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime{
    [self rumWrite:source tags:tags fields:fields time:time updateTime:updateTime cache:self.isCache];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache{
    if (![source isKindOfClass:NSString.class] || source.length == 0) {
        return;
    }
    @try {
        NSMutableDictionary *baseTags = [NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:tags];
        NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumTags];
        [baseTags addEntriesFromDictionary:rumProperty];
        NSDictionary *pkgInfo = tags[FT_SDK_PKG_INFO];
        if(pkgInfo && pkgInfo.count>0){
            NSDictionary *info = [rumProperty valueForKey:FT_SDK_PKG_INFO];
            if(info){
                NSMutableDictionary *mutableInfo = [info mutableCopy];
                [mutableInfo addEntriesFromDictionary:pkgInfo];
                pkgInfo = mutableInfo;
            }
            [baseTags setValue:pkgInfo forKey:FT_SDK_PKG_INFO];
        }
        NSString *type = cache ? FT_DATA_TYPE_RUM_CACHE:FT_DATA_TYPE_RUM;
        FTAddDataType addType = cache ? FTAddDataRUMCache:FTAddDataRUM;
        FTRecordModel *model;
        if ([FTPresetProperty sharedInstance].lineDataModifier) {
            NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:source tags:baseTags fields:fields];
            model = [[FTRecordModel alloc]initWithSource:source op:type tags:array[0] fields:array[1] tm:time];
        }else{
            model = [[FTRecordModel alloc]initWithSource:source op:type tags:baseTags fields:fields tm:time];
        }
        if(updateTime>0){
            model.tm = updateTime;
        }
        [[FTTrackDataManager sharedInstance] addTrackData:model type:addType];
        if (cache && [source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            [self lastErrorTimeInterval:model.tm];
        }
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
        NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumTags];
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
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[[FTPresetProperty sharedInstance] loggerTags]];
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
-(void)isCacheWriter:(BOOL)cache{
    self.isCache = cache;
}
- (void)lastErrorTimeInterval:(NSTimeInterval)lastErrorTimeInterval{
    //  不处理上一个 error 之前的数据，不处理上一个进程的数据
    if (lastErrorTimeInterval <= self.lastErrorTimeInterval || lastErrorTimeInterval < self.processStartTime){
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(lastErrorTimeInterval) forKey:@"ft_last_error_time"];
    [self checkRUMSessionOnErrorDatasWithExpireTime:lastErrorTimeInterval-self.cacheInvalidTimeInterval];
    self.lastErrorTimeInterval = lastErrorTimeInterval;
}
- (long long)getLastProcessFatalErrorTime{
    return _lastProcessFatalErrorTime;
}
- (long long)getErrorTimeLineFromFileCache{
    NSNumber *lastError = [[NSUserDefaults standardUserDefaults] objectForKey:@"ft_last_error_time"];
    if (lastError != nil) {
        return [lastError longLongValue];
    }
    return 0;
}
#pragma mark - RUM ERROR SAMPLED CONSUME
#pragma mark ========== LAST PROCESS ==========
- (void)checkLastProcessErrorSampled{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.errorSampledConsumeQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        long long error = [strongSelf getErrorTimeLineFromFileCache];
        if (error > 0) {
            FTInnerLogDebug(@"[RUM errorSampledConsume] Deal last process datas");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:error];
        }
    });
}
/// 检查上一进程是否有 ANR 崩溃数据，更新删除上一进程 error sampled
-(void)lastFatalErrorIfFound:(long long)errorDate{
    _lastProcessFatalErrorTime = errorDate;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.errorSampledConsumeQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (errorDate>0) {
            FTInnerLogDebug(@"[RUM errorSampledConsume] Last process has fatal error.");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:errorDate];
        }
        FTInnerLogDebug(@"[RUM errorSampledConsume] Delete last process datas");
        [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE toTime:strongSelf.processStartTime];
    });
}
#pragma mark ========== CURRENT PROCESS ==========
/// 处理当前进程的 cache 数据
- (void)checkRUMSessionOnErrorDatasExpired{
    FTInnerLogDebug(@"[RUM errorSampledConsume] Start Check.");
    [self checkRUMSessionOnErrorDatasWithExpireTime:[NSDate ft_currentNanosecondTimeStamp] - self.cacheInvalidTimeInterval];
}
- (void)checkRUMSessionOnErrorDatasWithExpireTime:(long long)expireTime{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.errorSampledConsumeQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if([[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM_CACHE]==0){
            FTInnerLogDebug(@"[RUM errorSampledConsume] No datas.");
            return;
        }
        long long expire = expireTime;
        if (expire <= 0) {
            expire = [NSDate ft_currentNanosecondTimeStamp] - strongSelf.cacheInvalidTimeInterval;
        }
        if(self.lastErrorTimeInterval>0){
            FTInnerLogDebug(@"[RUM errorSampledConsume] has last error, update Datas Type");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM fromTime:strongSelf.processStartTime toTime:strongSelf.lastErrorTimeInterval];
        }
        FTInnerLogDebug(@"[RUM errorSampledConsume] Delete expire(%lld) datas",expire);
        [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE fromTime:strongSelf.processStartTime toTime:expire];
        FTInnerLogDebug(@"[RUM errorSampledConsume] End");

    });
}
@end
