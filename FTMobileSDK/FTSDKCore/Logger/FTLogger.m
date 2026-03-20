//
//  FTLogger.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//
#import "FTLogger+Private.h"
#import "FTLog+Private.h"
#import "FTBaseInfoHandler.h"
#import "FTConstants.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTUtil.h"
#import "FTRecordModel.h"
#import "FTSDKCompat.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTEnumConstant.h"
#import "FTPresetProperty.h"
#import "FTLoggerConfig+Private.h"
#import "FTJSONUtil.h"
#import <pthread.h>

void *FTLoggerQueueIdentityKey = &FTLoggerQueueIdentityKey;

@interface FTLogger ()
@property (nonatomic, weak) id<FTLoggerDataWriteProtocol> loggerWriter;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@property (nonatomic, strong) dispatch_queue_t loggerQueue;
@property (nonatomic, strong) FTLoggerConfig *config;
@end
@implementation FTLogger{
    pthread_rwlock_t _rwLock;
}
+ (instancetype)sharedInstance {
    static FTLogger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTLogger alloc] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        pthread_rwlock_init(&_rwLock, NULL);
        _loggerQueue = dispatch_queue_create("com.ft.logger", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_loggerQueue,FTLoggerQueueIdentityKey, &FTLoggerQueueIdentityKey, NULL);
    }
    return self;
}
- (void)startWithLoggerConfig:(FTLoggerConfig *)config writer:(id<FTLoggerDataWriteProtocol>)writer{
    pthread_rwlock_wrlock(&_rwLock);
    _config = config;
    self.loggerWriter = writer;
    [self dealLogLevelFilter:config.logLevelFilter];
    pthread_rwlock_unlock(&_rwLock);
}
-(void)dealLogLevelFilter:(NSArray *)logLevelFilter{
    if (!logLevelFilter || logLevelFilter.count == 0) {
        _logLevelFilterSet = nil;
        return;
    }
    NSMutableArray *levels = [[NSMutableArray alloc]init];
    for (id level in logLevelFilter) {
        if ([level isKindOfClass:NSNumber.class] && [level intValue]<5 && [level intValue]>=0) {
            [levels addObject:FTStatusStringMap[[level intValue]]];
        }else{
            [levels addObject:level];
        }
    }
    _logLevelFilterSet = [NSSet setWithArray:levels];
}
-(void)updateLoggerConfiguration:(FTLoggerConfig *)configuration{
    pthread_rwlock_wrlock(&_rwLock);
    _config = [configuration copy];
    [self dealLogLevelFilter:_config.logLevelFilter];
    pthread_rwlock_unlock(&_rwLock);
}
-(FTLoggerConfig *)config{
    FTLoggerConfig *temp;
    pthread_rwlock_rdlock(&_rwLock);
    temp = _config;
    pthread_rwlock_unlock(&_rwLock);
    return temp;
}
-(NSSet *)logLevelFilterSet{
    NSSet *temp;
    pthread_rwlock_rdlock(&_rwLock);
    temp = _logLevelFilterSet;
    pthread_rwlock_unlock(&_rwLock);
    return temp;
}
- (void)log:(NSString *)content
     statusType:(FTLogStatus)statusType
   property:(nullable NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    [self _log:content statusType:(LogStatus)statusType status:FTStatusStringMap[statusType] property:copyDict];
}
- (void)log:(NSString *)content status:(NSString *)status{
    [self log:content status:status property:nil];
}
- (void)log:(NSString *)content status:(NSString *)status property:(nullable NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    [self _log:content statusType:StatusCustom status:status property:copyDict];
}
-(void)info:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:FTStatusInfo property:property];
}
-(void)warning:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:FTStatusWarning property:property];
}
-(void)error:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:FTStatusError property:property];
}
-(void)critical:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:FTStatusCritical property:property];
}
- (void)ok:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:FTStatusOk property:property];
}
- (void)_log:(NSString *)content statusType:(LogStatus)type status:(NSString *)status property:(nullable NSDictionary *)property{
    NSDictionary *copyProperty = [property ft_deepCopy];
    long long timeStamp = [NSDate ft_currentNanosecondTimeStamp];
    FTLoggerConfig *config = self.config;
    if (!config) {
        FTInnerLogError(@"SDK configuration `Logger` error, unable to collect custom logs");
        return;
    }
    if (!content || content.length == 0 ) {
        FTInnerLogError(@"[Logging] The passed data format is incorrect");
        return;
    }
    if(config.printCustomLogToConsole){
        FT_CONSOLE_LOG(type,status,content,copyProperty);
    }
    if (!config.enableCustomLog) {
        FTInnerLogInfo(@"[Logging][Disable Custom Log] %@",content);
        return;
    }
    if (self.logLevelFilterSet && ![self.logLevelFilterSet containsObject:status]) {
        FTInnerLogInfo(@"[Logging][Not Filtered] %@",content);
        return;
    }
    if (![FTBaseInfoHandler randomSampling:config.samplerate]){
        FTInnerLogInfo(@"[Logging][Not Sampled] %@",content);
        return;
    }
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    tags[FT_KEY_STATUS] = status;
    if (config.enableLinkRumData) {
        id<FTLinkRumDataProvider> provider = self.linkRumDataProvider;
        if (provider && [provider respondsToSelector:@selector(getLinkRUMDataWithCompletion:)]) {
            __weak typeof(self) weakSelf = self;
            [provider getLinkRUMDataWithCompletion:^(NSDictionary * _Nullable rumContext) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                
                if (rumContext) {
                    [tags addEntriesFromDictionary:rumContext];
                }
                [strongSelf writeLogWithTags:tags content:content property:copyProperty time:timeStamp];
            }];
            return;
        }
    }
    [self writeLogWithTags:tags content:content property:copyProperty time:timeStamp];
}
- (void)writeLogWithTags:(NSDictionary *)tags
                  content:(NSString *)content
                 property:(NSDictionary *)property
                     time:(long long)time {
    BOOL enableLinkRum = self.config.enableLinkRumData;
    dispatch_async(self.loggerQueue, ^{
        id<FTLoggerDataWriteProtocol> writer = self.loggerWriter;
        if (!writer) {
            FTInnerLogError(@"SDK configuration error, unable to collect custom logs");
            return;
        }
        NSString *newContent = [content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];
        NSMutableDictionary *filedDict = [NSMutableDictionary dictionary];
        filedDict[FT_KEY_MESSAGE] = newContent;
        [filedDict addEntriesFromDictionary:property];
        
        [writer loggingTags:tags
                      field:filedDict
                       time:time
                    linkRum:enableLinkRum];
    });
}
/**
 *  just for test
 */
- (void)syncProcess{
    [self syncProcess:^{}];
}
- (void)syncProcess:(dispatch_block_t)block{
    if(dispatch_get_specific(FTLoggerQueueIdentityKey) == NULL){
        dispatch_sync(self.loggerQueue, block);
    }else{
        block();
    }
}
- (void)shutDown{
    pthread_rwlock_wrlock(&_rwLock);
    self.config = nil;
    self.loggerWriter = nil;
    pthread_rwlock_unlock(&_rwLock);
    FTInnerLogInfo(@"[Logging] SHUT DOWN");
}
@end
