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

- (FTRecordModel *)_recordModelWithSource:(NSString *)source
                                     tags:(NSDictionary *)tags
                                   fields:(NSDictionary *)fields
                                     time:(long long)time
                                       op:(NSString *)op;
@end
@implementation FTDataWriterWorker
-(instancetype)init{
    return [self initWithCacheInvalidTimeInterval:60];
}
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval{
    self = [super init];
    if(self){
        _cacheInvalidTimeInterval = timeInterval*1e9;
        _processStartTime = [[FTAppLaunchTracker processStartTimestamp] ft_nanosecondTimeStamp];
        _errorSampledConsumeQueue = dispatch_queue_create("com.ft.errorSampledConsume", 0);
        _lastErrorTimeInterval = 0;
        [self checkLastProcessErrorSampled];
    }
    return self;
}
// Called in RUM queue or longtask queue
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
        NSMutableDictionary *tagsDict = [NSMutableDictionary new];
        NSMutableDictionary *fieldsDict = [NSMutableDictionary new];
        NSDictionary *rumStaticTags = [[FTPresetProperty sharedInstance] rumTags];

        [tagsDict addEntriesFromDictionary:tags];
        [tagsDict addEntriesFromDictionary:rumStaticTags];
        [fieldsDict addEntriesFromDictionary:fields];
        NSDictionary *pkgInfo = tags[FT_SDK_PKG_INFO];
        if(pkgInfo && pkgInfo.count>0){
            NSDictionary *info = [rumStaticTags valueForKey:FT_SDK_PKG_INFO];
            if(info){
                NSMutableDictionary *mutableInfo = [info mutableCopy];
                [mutableInfo addEntriesFromDictionary:pkgInfo];
                pkgInfo = mutableInfo;
            }
            [tagsDict setValue:pkgInfo forKey:FT_SDK_PKG_INFO];
        }
        NSString *type = cache ? FT_DATA_TYPE_RUM_CACHE:FT_DATA_TYPE_RUM;
        FTAddDataType addType = cache ? FTAddDataRUMCache:FTAddDataRUM;
        FTRecordModel *model = [self _recordModelWithSource:source tags:tagsDict fields:fieldsDict time:time op:type];
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
- (void)rumWriteAssembledData:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    FTRecordModel *model = [self _recordModelWithSource:source tags:tags fields:fields time:time op:FT_DATA_TYPE_RUM];
    [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];
}
- (FTRecordModel *)_recordModelWithSource:(NSString *)source
                                     tags:(NSDictionary *)tags
                                   fields:(NSDictionary *)fields
                                     time:(long long)time
                                       op:(NSString *)op {
    FTRecordModel *model = nil;
    if ([FTPresetProperty sharedInstance].lineDataModifier) {
        NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:source tags:tags fields:fields];
        model = [[FTRecordModel alloc] initWithSource:source op:op tags:array[0] fields:array[1] tm:time];
    } else {
        model = [[FTRecordModel alloc] initWithSource:source op:op tags:tags fields:fields tm:time];
    }
    return model;
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
        NSMutableDictionary *tagDict = [NSMutableDictionary new];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        [tagDict setValue:status forKey:FT_KEY_STATUS];
        [tagDict addEntriesFromDictionary:[[FTPresetProperty sharedInstance] loggerTags]];
        NSMutableDictionary *filedDict = [NSMutableDictionary dictionary];
        [filedDict setValue:content forKey:FT_KEY_MESSAGE];
        [filedDict addEntriesFromDictionary:field];
#if TARGET_OS_TV
        NSString *source = FT_LOGGER_TVOS_SOURCE;
#else
        NSString *source = FT_LOGGER_SOURCE;
#endif
        FTRecordModel *model;
        if ([FTPresetProperty sharedInstance].lineDataModifier) {
            NSArray *array = [[FTPresetProperty sharedInstance] applyLineModifier:source tags:tagDict fields:filedDict];
            model = [[FTRecordModel alloc]initWithSource:source op:FT_DATA_TYPE_LOGGING tags:array[0] fields:array[1] tm:time];
        }else{
            model = [[FTRecordModel alloc]initWithSource:source op:FT_DATA_TYPE_LOGGING tags:tagDict fields:filedDict tm:time];
        }
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
-(void)isCacheWriter:(BOOL)cache{
    self.isCache = cache;
}
- (void)lastErrorTimeInterval:(NSTimeInterval)lastErrorTimeInterval{
    //  Do not process data before the previous error, do not process data from the previous process
    if (lastErrorTimeInterval <= self.lastErrorTimeInterval || lastErrorTimeInterval < self.processStartTime){
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(lastErrorTimeInterval) forKey:@"ft_last_error_time"];
    [self checkRUMSessionOnErrorDatasWithExpireTime:lastErrorTimeInterval-self.cacheInvalidTimeInterval];
    self.lastErrorTimeInterval = lastErrorTimeInterval;
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
/// Check if the previous process has ANR crash data, update and delete error sampled from the previous process
-(void)lastFatalErrorIfFound:(long long)errorDate{
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
/// Process cache data for the current process
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
