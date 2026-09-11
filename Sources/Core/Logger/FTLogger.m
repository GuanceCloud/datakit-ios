//
//  FTLogger.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/24.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTLogger+Private.h"
#import "FTBaseInfoHandler.h"
#import "FTConstants.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTUtil.h"
#import "FTRecordModel.h"
#import "FTSDKCompat.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTInternalConstants.h"
#import "FTPresetProperty.h"
#import "FTLoggerConfig+Private.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "FTWebViewLogEventMapper.h"
#import <pthread.h>

void *FTLoggerQueueIdentityKey = &FTLoggerQueueIdentityKey;

@interface FTLogger ()
@property (nonatomic, weak, nullable) id<FTLoggerDataWriteProtocol> loggerWriter;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@property (nonatomic, strong) dispatch_queue_t loggerQueue;
@property (nonatomic, strong) FTLoggerConfig *config;
- (void)writeWebViewLogEvent:(FTWebViewLogEvent *)event linkRum:(BOOL)linkRum;
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
            [levels addObject:FTStringFromLogStatus((LogStatus)[level intValue])];
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
    NSDictionary *safeProperty = [property ft_deepCopy];
    [self _log:content statusType:(LogStatus)statusType status:FTStringFromLogStatus((LogStatus)statusType) property:safeProperty];
}
- (void)log:(NSString *)content status:(NSString *)status{
    [self log:content status:status property:nil];
}
- (void)log:(NSString *)content status:(NSString *)status property:(nullable NSDictionary *)property{
    NSDictionary *safeProperty = [property ft_deepCopy];
    NSString *safeStatus = status.length > 0 ? status : FTStringFromLogStatus(StatusCustom);
    [self _log:content statusType:StatusCustom status:safeStatus property:safeProperty];
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
- (void)_log:(NSString *)content statusType:(LogStatus)type status:(NSString *)status property:(nullable NSDictionary *)safeProperty{
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
        FT_CONSOLE_LOG(type,status,content,safeProperty);
    }
    if (!config.enableCustomLog) {
        FTInnerLogInfo(@"[Logging][Disable Custom Log] %@",content);
        return;
    }
    if (self.logLevelFilterSet && ![self.logLevelFilterSet containsObject:status]) {
        FTInnerLogInfo(@"[Logging][Not Filtered] %@",content);
        return;
    }
    if (![FTBaseInfoHandler randomSampling:config.sampleRate]){
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
                [strongSelf writeLogWithTags:tags content:content property:safeProperty time:timeStamp];
            }];
            return;
        }
    }
    [self writeLogWithTags:tags content:content property:safeProperty time:timeStamp];
}
- (void)logWebViewEvent:(NSDictionary *)event linkToNativeRum:(BOOL)linkToNativeRum {
    FTLoggerConfig *config = self.config;
    if (!config || !config.enableWebViewLog || ![event isKindOfClass:NSDictionary.class]) {
        return;
    }
    NSDictionary *eventPayload = event;
    NSSet *logLevelFilterSet = [self.logLevelFilterSet copy];
    int sampleRate = config.sampleRate;
    BOOL enableLinkRumData = config.enableLinkRumData;
    long long receivedTime = [NSDate ft_currentNanosecondTimeStamp];
    dispatch_async(self.loggerQueue, ^{
        NSDictionary *safeEvent = [eventPayload ft_deepCopy];
        FTWebViewLogEvent *logEvent =
            [FTWebViewLogEventMapper mapEvent:safeEvent
                      fallbackNanosecondTime:receivedTime];
        if (!logEvent) {
            FTInnerLogWarning(@"[WebView][Logging] Invalid Browser Log event");
            return;
        }
        if (logLevelFilterSet && ![logLevelFilterSet containsObject:logEvent.status]) {
            FTInnerLogInfo(@"[WebView][Logging][Not Filtered] %@",logEvent.content);
            return;
        }
        if (![FTBaseInfoHandler randomSampling:sampleRate]) {
            FTInnerLogInfo(@"[WebView][Logging][Not Sampled] %@",logEvent.content);
            return;
        }

        NSMutableDictionary *tags = [logEvent.tags mutableCopy];
        tags[FT_KEY_STATUS] = logEvent.status;
        logEvent.tags = [tags copy];
        if (!enableLinkRumData) {
            [FTWebViewLogEventMapper removeRumLinkDataFromEvent:logEvent];
            [self writeWebViewLogEvent:logEvent linkRum:NO];
            return;
        }
        if (!linkToNativeRum) {
            [self writeWebViewLogEvent:logEvent linkRum:NO];
            return;
        }

        NSString *applicationId = [FTPresetProperty sharedInstance].rumTags[FT_APP_ID];
        id<FTLinkRumDataProvider> provider = self.linkRumDataProvider;
        if (provider && [provider respondsToSelector:@selector(getLinkRUMDataWithCompletion:)]) {
            __weak typeof(self) weakSelf = self;
            [provider getLinkRUMDataWithCompletion:^(NSDictionary * _Nullable rumContext) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                NSString *sessionId = [rumContext[FT_RUM_KEY_SESSION_ID] isKindOfClass:NSString.class]
                    ? rumContext[FT_RUM_KEY_SESSION_ID] : nil;
                [FTWebViewLogEventMapper replaceRumLinkDataInEvent:logEvent
                                                     applicationId:applicationId
                                                          sessionId:sessionId];
                [strongSelf writeWebViewLogEvent:logEvent linkRum:YES];
            }];
            return;
        }
        [FTWebViewLogEventMapper replaceRumLinkDataInEvent:logEvent
                                             applicationId:applicationId
                                                  sessionId:nil];
        [self writeWebViewLogEvent:logEvent linkRum:YES];
    });
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
- (void)writeWebViewLogEvent:(FTWebViewLogEvent *)event linkRum:(BOOL)linkRum {
    dispatch_block_t writeBlock = ^{
        id<FTLoggerDataWriteProtocol> writer = self.loggerWriter;
        if (!writer) {
            FTInnerLogError(@"SDK configuration error, unable to collect WebView logs");
            return;
        }
        NSString *content = [event.content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];
        NSMutableDictionary *fields = [event.fields mutableCopy] ?: [NSMutableDictionary dictionary];
        fields[FT_KEY_MESSAGE] = content ?: @"";
        [writer loggingTags:event.tags
                      field:[fields copy]
                       time:event.time
                    linkRum:linkRum];
    };
    if (dispatch_get_specific(FTLoggerQueueIdentityKey) != NULL) {
        writeBlock();
    } else {
        dispatch_async(self.loggerQueue, writeBlock);
    }
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
