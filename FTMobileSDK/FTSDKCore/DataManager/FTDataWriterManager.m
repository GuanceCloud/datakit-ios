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

@interface FTDataWriterManager()
@property (atomic, assign) BOOL isCache;
@property (nonatomic, assign) NSTimeInterval cacheInvalidTimeInterval;
@end
@implementation FTDataWriterManager
-(instancetype)init{
    self = [super init];
    if (self) {
        _cacheInvalidTimeInterval = 60;
        // 应用进入新的生命周期，删除旧的数据
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
        if(self.isCache && [source isEqualToString:FT_RUM_SOURCE_ERROR]){
            self.isCache = NO;
            long long deleteTime = time - self.cacheInvalidTimeInterval * 1e9;
            if(deleteTime <= 0){
                deleteTime = [NSDate dateWithTimeIntervalSinceNow:-self.cacheInvalidTimeInterval].timeIntervalSince1970 * 1e9;
            }
            [[FTTrackerEventDBTool sharedManger] deleteDatasWithType:FT_DATA_TYPE_RUM_CACHE time:deleteTime];
            [[FTTrackerEventDBTool sharedManger] updateDatasWithType:FT_DATA_TYPE_RUM_CACHE toType:FT_DATA_TYPE_RUM time:time];
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
-(void)switchToCacheWriter{
    self.isCache = YES;
}
// FT_DATA_TYPE_LOGGING
-(void)logging:(NSString *)content status:(NSString *)status tags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time{
    @try {
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[[FTPresetProperty sharedInstance] loggerProperty]];        
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        [tagDict setValue:status forKey:FT_KEY_STATUS];
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
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

@end
