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
void *FTLoggerQueueIdentityKey = &FTLoggerQueueIdentityKey;

@interface FTLogger ()
@property (nonatomic, weak) id<FTLoggerDataWriteProtocol> loggerWriter;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@property (nonatomic, strong) dispatch_queue_t loggerQueue;
@property (nonatomic, strong) FTLoggerConfig *config;
@end
@implementation FTLogger
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
        _loggerQueue = dispatch_queue_create("com.ft.logger", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_loggerQueue,FTLoggerQueueIdentityKey, &FTLoggerQueueIdentityKey, NULL);
    }
    return self;
}
- (void)startWithLoggerConfig:(FTLoggerConfig *)config writer:(id<FTLoggerDataWriteProtocol>)writer{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.loggerQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.config = config;
        strongSelf.loggerWriter = writer;
        [strongSelf dealLogLevelFilter:strongSelf.config.logLevelFilter];
    });
}
-(void)setLinkRumDataProvider:(id<FTLinkRumDataProvider>)linkRumDataProvider{
    dispatch_async(self.loggerQueue, ^{
        self->_linkRumDataProvider = linkRumDataProvider;
    });
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
-(void)updateWithRemoteConfiguration:(NSDictionary *)configuration{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.loggerQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.config mergeWithRemoteConfigDict:configuration];
        [strongSelf dealLogLevelFilter:strongSelf.config.logLevelFilter];
    });
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
    NSDictionary *copyDict = [property ft_deepCopy];
    long long time = [NSDate ft_currentNanosecondTimeStamp];
    __weak typeof(self) weakSelf = self;
    dispatch_block_t logBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        FTLoggerConfig *config = strongSelf.config;
        if (!config) {
            FTInnerLogError(@"SDK configuration `Logger` error, unable to collect custom logs");
            return;
        }
        if (!content || content.length == 0 ) {
            FTInnerLogError(@"[Logging] The passed data format is incorrect");
            return;
        }
        if(config.printCustomLogToConsole){
            FT_CONSOLE_LOG(type,status,content,copyDict);
        }
        if (!config.enableCustomLog) {
            FTInnerLogInfo(@"[Logging][Disable Custom Log] %@",content);
            return;
        }
        if (strongSelf.logLevelFilterSet && ![strongSelf.logLevelFilterSet containsObject:status]) {
            FTInnerLogInfo(@"[Logging][Not Filtered] %@",content);
            return;
        }
        if (![FTBaseInfoHandler randomSampling:config.samplerate]){
            FTInnerLogInfo(@"[Logging][Not Sampled] %@",content);
            return;
        }
        NSMutableDictionary *context = [NSMutableDictionary dictionary];
        [context addEntriesFromDictionary:[[FTPresetProperty sharedInstance] loggerDynamicTags]];
        if(config.enableLinkRumData){
            if (strongSelf.linkRumDataProvider && [strongSelf.linkRumDataProvider respondsToSelector:@selector(getLinkRUMData)]) {
                NSDictionary *rumTag = [strongSelf.linkRumDataProvider getLinkRUMData];
                [context addEntriesFromDictionary:rumTag];
            }
            [context addEntriesFromDictionary:[[FTPresetProperty sharedInstance] rumTags]];
        }
        if(strongSelf.loggerWriter && [strongSelf.loggerWriter respondsToSelector:@selector(logging:status:tags:field:time:)]){
            NSString *newContent = [content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];
            [strongSelf.loggerWriter logging:newContent status:status tags:context field:property time:time];
        }else{
            FTInnerLogError(@"SDK configuration error, unable to collect custom logs");
        }
    };
    dispatch_async(self.loggerQueue, logBlock);
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
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.loggerQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.config = nil;
        strongSelf.loggerWriter = nil;
    });
    FTInnerLogInfo(@"[Logging] SHUT DOWN");
}
@end
