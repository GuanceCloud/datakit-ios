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
@property (nonatomic, assign) NSTimeInterval lastErrorTimeInterval;
@property (nonatomic, assign) BOOL isTimerRunning;
@property (nonatomic, assign) long long processStartTime;
@property (nonatomic, assign) long long lastProcessFatalErrorTime;
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
        _lastProcessFatalErrorTime = -1;
        _lastErrorTimeInterval = [self getErrorTimeLineFromFileCache];
    }
    return self;
}
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
        NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumProperty];
        [baseTags addEntriesFromDictionary:rumProperty];
        NSString *type = cache ? FT_DATA_TYPE_RUM_CACHE:FT_DATA_TYPE_RUM;
        FTAddDataType addType = cache ? FTAddDataRUMCache:FTAddDataRUM;
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:source op:type tags:baseTags fields:fields tm:time];
        if(updateTime>0){
            model.tm = updateTime;
        }
        [[FTTrackDataManager sharedInstance] addTrackData:model type:addType];
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            [self setLastErrorTimeInterval:model.tm];
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
-(void)isCacheWriter:(BOOL)cache{
    self.isCache = cache;
}
/// 检查上一进程是否有 ANR 崩溃数据
-(void)lastFatalErrorIfFound:(long long)errorDate{
    _lastProcessFatalErrorTime = 0;
    if (errorDate < self.processStartTime && errorDate>0) {
        _lastProcessFatalErrorTime = self.lastErrorTimeInterval < self.processStartTime && errorDate < self.lastErrorTimeInterval ? self.lastErrorTimeInterval : errorDate;
        FTInnerLogDebug(@"[RUM cache] Last process has fatal error.");
        [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:_lastProcessFatalErrorTime];
    }
    FTInnerLogDebug(@"[RUM cache] Deal last process datas");
    [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE toTime:self.processStartTime];
}
- (void)setLastErrorTimeInterval:(NSTimeInterval)lastErrorTimeInterval{
    //  不处理上一个 error 之前的数据，不处理上一个进程的数据
    if (lastErrorTimeInterval <= self.lastErrorTimeInterval || lastErrorTimeInterval < self.processStartTime){
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(lastErrorTimeInterval) forKey:@"ft_last_error_time"];
    [self checkRUMSessionOnErrorDatasWithExpireTime:lastErrorTimeInterval-self.cacheInvalidTimeInterval];
    _lastErrorTimeInterval = lastErrorTimeInterval;
}
- (long long)getLastProcessFatalErrorTime{
    return _lastProcessFatalErrorTime;
}
- (long long)getErrorTimeLineFromFileCache{
    NSNumber *lastError = [[NSUserDefaults standardUserDefaults] valueForKey:@"ft_last_error_time"];
    if (lastError) {
        return [lastError longLongValue];
    }
    return 0;
}
- (void)checkRUMSessionOnErrorDatasExpired{
    [self checkRUMSessionOnErrorDatasWithExpireTime:[NSDate ft_currentNanosecondTimeStamp] - self.cacheInvalidTimeInterval];
}
- (void)checkRUMSessionOnErrorDatasWithExpireTime:(long long)expireTime{
    if([[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM_CACHE]==0){
        FTInnerLogDebug(@"[RUM cache] No datas.");
        return;
    }
    if (expireTime <= 0) {
        expireTime = [NSDate ft_currentNanosecondTimeStamp] - self.cacheInvalidTimeInterval;
    }
    if(self.lastErrorTimeInterval>0){
        if (self.lastErrorTimeInterval < self.processStartTime) {
            FTInnerLogDebug(@"[RUM cache] Deal last process datas");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:self.lastErrorTimeInterval];
        }else{
            FTInnerLogDebug(@"[RUM cache] has last error, update Datas Type");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM fromTime:self.processStartTime toTime:self.lastErrorTimeInterval];
        }
    }
    FTInnerLogDebug(@"[RUM cache] Delete expire datas");
    [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE fromTime:self.processStartTime toTime:expireTime];
}
@end
