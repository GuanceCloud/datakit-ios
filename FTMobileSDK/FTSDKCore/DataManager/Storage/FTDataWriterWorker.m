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
@end
@implementation FTDataWriterWorker
-(instancetype)init{
    return [self initWithCacheInvalidTimeInterval:60];
}
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval{
    self = [super init];
    if(self){
        _cacheInvalidTimeInterval = timeInterval*1e9;
        _processStartTime = FTAppLaunchTracker.processStartTime * 1e9;
        _lastErrorTimeInterval = [self getErrorTimeLineFromFileCache];
    }
    return self;
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    [self rumWrite:source tags:tags fields:fields time:time updateTime:0];
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime{
    if (![source isKindOfClass:NSString.class] || source.length == 0) {
        return;
    }
    @try {
        NSMutableDictionary *baseTags = [NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:tags];
        NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumProperty];
        [baseTags addEntriesFromDictionary:rumProperty];
        NSString *type = self.isCache ? FT_DATA_TYPE_RUM_CACHE:FT_DATA_TYPE_RUM;
        FTAddDataType addType = self.isCache ? FTAddDataRUMCache:FTAddDataRUM;
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:source op:type tags:baseTags fields:fields tm:time];
        if(updateTime>0){
            model.tm = updateTime;
        }
        if (self.isCache && [source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            [self checkRUMSessionOnErrorDatasWithExpireTime:model.tm-self.cacheInvalidTimeInterval];
            if (time > self.lastErrorTimeInterval){
                self.lastErrorTimeInterval = time;
            }
        }
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
- (void)fatalErrorWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache{
    NSMutableDictionary *baseTags = [NSMutableDictionary new];
    [baseTags addEntriesFromDictionary:tags];
    NSDictionary *rumProperty = [[FTPresetProperty sharedInstance] rumProperty];
    [baseTags addEntriesFromDictionary:rumProperty];
    
    NSString *type = self.isCache ? FT_DATA_TYPE_RUM_CACHE:FT_DATA_TYPE_RUM;
    FTAddDataType addType = self.isCache ? FTAddDataRUMCache:FTAddDataRUM;
    FTRecordModel *model = [[FTRecordModel alloc]initWithSource:source op:type tags:baseTags fields:fields tm:time];
    if (updateTime>time) {
        model.tm = updateTime;
    }
    [[FTTrackDataManager sharedInstance] addTrackData:model type:addType];
}
-(void)isCacheWriter:(BOOL)cache{
    self.isCache = cache;
}
-(void)lastFatalErrorIfFound:(long long)errorDate{
    if (errorDate < self.processStartTime && errorDate>0) {
        [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:errorDate];
    }
    [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE toTime:self.processStartTime];
}
- (void)setLastErrorTimeInterval:(NSTimeInterval)lastErrorTimeInterval{
    _lastErrorTimeInterval = lastErrorTimeInterval;
    [[NSUserDefaults standardUserDefaults] setObject:@(lastErrorTimeInterval) forKey:@"ft_last_error_time"];
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
    if (expireTime <= 0) {
        expireTime = [NSDate ft_currentNanosecondTimeStamp] - self.cacheInvalidTimeInterval;
    }
    if(self.lastErrorTimeInterval>0){
        if (self.lastErrorTimeInterval < self.processStartTime) {
            FTInnerLogDebug(@"-checkRUMSessionOnErrorDatas deal last process datas");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM toTime:self.lastErrorTimeInterval];
        }else{
            FTInnerLogDebug(@"-checkRUMSessionOnErrorDatas has last error, update Datas Type");
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM fromTime:self.processStartTime toTime:self.lastErrorTimeInterval];
        }
    }
    FTInnerLogDebug(@"-checkRUMSessionOnErrorDatas delete expire datas");
    [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE fromTime:self.processStartTime toTime:expireTime];
}
@end
