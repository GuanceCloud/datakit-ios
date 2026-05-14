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
#import "FTInnerLog.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "NSDictionary+FTCopyProperties.h"
#import <os/lock.h>
#import "FTDateUtil.h"
#import "FTDataFilterManager.h"
#import "FTBaseInfoHandler.h"
@interface FTDataWriterWorker()
@property (atomic, assign) BOOL isCache;
@property (nonatomic, assign) NSTimeInterval cacheInvalidTimeInterval;
@property (atomic, assign) NSTimeInterval lastErrorTimeInterval;
@property (nonatomic, assign) BOOL isTimerRunning;
@property (nonatomic, assign) long long processStartTime;
@property (nonatomic, assign) long long lastProcessFatalErrorTime;
@property (nonatomic, strong) dispatch_queue_t errorSampledConsumeQueue;

- (void)writeSource:(NSString *)source
                 op:(NSString *)op
        contextTags:(NSDictionary *)contextTags
               tags:(NSDictionary *)tags
             fields:(NSDictionary *)fields
               time:(long long)time
         updateTime:(long long)updateTime
              cache:(BOOL)cache;
@end
@implementation FTDataWriterWorker
-(instancetype)init{
    return [self initWithCacheInvalidTimeInterval:60];
}
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval{
    self = [super init];
    if(self){
        _cacheInvalidTimeInterval = timeInterval*1e9;
        _processStartTime = [[FTDateUtil processStartTimestamp] ft_nanosecondTimeStamp];
        _errorSampledConsumeQueue = dispatch_queue_create("com.ft.errorSampledConsume", 0);
        _lastProcessFatalErrorTime = -1;
        _lastErrorTimeInterval = 0;
        [self checkLastProcessErrorSampled];
    }
    return self;
}
// Called in RUM queue or longtask queue
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time{
    [self rumWrite:source tags:tags fields:fields dynamicContext:dynamicContext time:time updateTime:0];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime{
    [self rumWrite:source tags:tags fields:fields dynamicContext:dynamicContext time:time updateTime:updateTime cache:self.isCache];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache{
    if (![source isKindOfClass:NSString.class] || source.length == 0) {
        return;
    }
    @try {
        FTPresetProperty *preset = [FTPresetProperty sharedInstance];
        NSMutableDictionary *contextTags = [NSMutableDictionary dictionary];
        [contextTags addEntriesFromDictionary:[preset rumTags]];
        [contextTags addEntriesFromDictionary:[NSObject ft_normalizedDictionaryWithObject:dynamicContext]];
        [self writeSource:source
                       op:cache ? FT_DATA_TYPE_RUM_CACHE:FT_DATA_TYPE_RUM
              contextTags:contextTags
                     tags:tags
                   fields:fields
                     time:time
               updateTime:updateTime
                    cache:cache];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)rumWriteAssembledData:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    [self writeSource:source op:FT_DATA_TYPE_RUM contextTags:nil tags:tags fields:fields time:time updateTime:0 cache:NO];
}
- (void)writeSource:(NSString *)source
                 op:(NSString *)op
        contextTags:(NSDictionary *)contextTags
               tags:(NSDictionary *)tags
             fields:(NSDictionary *)fields
               time:(long long)time
         updateTime:(long long)updateTime
              cache:(BOOL)cache {
    if (![source isKindOfClass:NSString.class] || source.length == 0 || ![op isKindOfClass:NSString.class] || op.length == 0) {
        return;
    }
    FTPresetProperty *preset = [FTPresetProperty sharedInstance];
    NSDictionary *eventTags = [preset applyModifier:tags];
    NSDictionary *eventFields = [preset applyModifier:fields];
    NSDictionary *safeContextTags = [NSObject ft_normalizedDictionaryWithObject:contextTags];
    NSMutableDictionary *tagsDict = [eventTags mutableCopy] ?: [NSMutableDictionary dictionary];
    [tagsDict addEntriesFromDictionary:safeContextTags];
    NSDictionary *pkgInfo = eventTags[FT_SDK_PKG_INFO];
    if (pkgInfo && pkgInfo.count > 0) {
        NSDictionary *info = safeContextTags[FT_SDK_PKG_INFO];
        if (info) {
            NSMutableDictionary *mutableInfo = [info mutableCopy];
            [mutableInfo addEntriesFromDictionary:pkgInfo];
            pkgInfo = mutableInfo;
        }
        tagsDict[FT_SDK_PKG_INFO] = pkgInfo;
    }
    NSArray *array = [preset applyLineModifier:source tags:tagsDict fields:eventFields];
    NSDictionary *recordTags = tagsDict;
    NSDictionary *recordFields = eventFields;
    if (array) {
        recordTags = array[0];
        recordFields = array[1];
    }
    NSString *category = nil;
    if ([op isEqualToString:FT_DATA_TYPE_LOGGING]) {
        category = @"logging";
    } else if ([op isEqualToString:FT_DATA_TYPE_RUM] || [op isEqualToString:FT_DATA_TYPE_RUM_CACHE]) {
        category = @"rum";
    }
    if (category) {
        NSString *uuid = [FTBaseInfoHandler random16UUID];
        if ([[FTDataFilterManager sharedInstance] isFilteredWithCategory:category
                                                                  source:source
                                                                    uuid:uuid
                                                                    tags:recordTags
                                                                  fields:recordFields]) {
            return;
        }
    }
    long long recordTime = updateTime > 0 ? updateTime : time;
    FTRecordModel *model = [[FTRecordModel alloc] initWithSource:source op:op tags:recordTags fields:recordFields tm:recordTime];
    FTAddDataType addType = FTAddDataLogging;
    if ([op isEqualToString:FT_DATA_TYPE_RUM_CACHE]) {
        addType = FTAddDataRUMCache;
    } else if ([op isEqualToString:FT_DATA_TYPE_RUM]) {
        addType = FTAddDataRUM;
    }
    [[FTTrackDataManager sharedInstance] addTrackData:model type:addType];
    if (cache && [source isEqualToString:FT_RUM_SOURCE_ERROR]) {
        [self lastErrorTimeInterval:model.tm];
    }
}
- (void)extensionRumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    if (![source isKindOfClass:NSString.class] || source.length == 0) {
        return;
    }
    [self rumWrite:source tags:tags fields:fields dynamicContext:@{} time:time updateTime:0 cache:NO];
}
// FT_DATA_TYPE_LOGGING
-(void)loggingTags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time linkRum:(BOOL)linkRum{
    @try {
        FTPresetProperty *preset = [FTPresetProperty sharedInstance];
        NSMutableDictionary *contextTags = [NSMutableDictionary dictionary];
        [contextTags addEntriesFromDictionary:[preset loggerTags]];
        if (linkRum) {
            [contextTags addEntriesFromDictionary:[preset rumTags]];
        }
#if TARGET_OS_TV
        NSString *source = FT_LOGGER_TVOS_SOURCE;
#else
        NSString *source = FT_LOGGER_SOURCE;
#endif
        [self writeSource:source
                       op:FT_DATA_TYPE_LOGGING
              contextTags:contextTags
                     tags:tags
                   fields:field
                     time:time
               updateTime:0
                    cache:NO];
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
            [[FTTrackerEventDBTool sharedManager] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:error];
        }
    });
}
/// Check if the previous process has ANR crash data, update and delete error sampled from the previous process
-(void)lastFatalErrorIfFound:(long long)errorDate{
    _lastProcessFatalErrorTime = errorDate;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.errorSampledConsumeQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (errorDate>0) {
            FTInnerLogDebug(@"[RUM errorSampledConsume] Last process has fatal error.");
            [[FTTrackerEventDBTool sharedManager] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:errorDate];
        }
        FTInnerLogDebug(@"[RUM errorSampledConsume] Delete last process datas");
        [[FTTrackerEventDBTool sharedManager] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE toTime:strongSelf.processStartTime];
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
        if([[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_RUM_CACHE]==0){
            FTInnerLogDebug(@"[RUM errorSampledConsume] No datas.");
            return;
        }
        long long expire = expireTime;
        if (expire <= 0) {
            expire = [NSDate ft_currentNanosecondTimeStamp] - strongSelf.cacheInvalidTimeInterval;
        }
        if(self.lastErrorTimeInterval>0){
            FTInnerLogDebug(@"[RUM errorSampledConsume] has last error, update Datas Type");
            [[FTTrackerEventDBTool sharedManager] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM fromTime:strongSelf.processStartTime toTime:strongSelf.lastErrorTimeInterval];
        }
        FTInnerLogDebug(@"[RUM errorSampledConsume] Delete expire(%lld) datas",expire);
        [[FTTrackerEventDBTool sharedManager] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE fromTime:strongSelf.processStartTime toTime:expire];
        FTInnerLogDebug(@"[RUM errorSampledConsume] End");

    });
}
@end
