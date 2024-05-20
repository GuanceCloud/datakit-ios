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
#import "FTEnumConstant.h"

void *FTLoggerQueueIdentityKey = &FTLoggerQueueIdentityKey;

@interface FTLogger ()
@property (nonatomic, assign) BOOL printLogsToConsole;
@property (nonatomic, weak) id<FTLoggerDataWriteProtocol> loggerWriter;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@property (nonatomic, assign) BOOL enableCustomLog;
@property (nonatomic, strong) dispatch_queue_t loggerQueue;

@end
@implementation FTLogger
static FTLogger *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (void)startWithEnablePrintLogsToConsole:(BOOL)enable enableCustomLog:(BOOL)enableCustomLog logLevelFilter:(NSArray<NSNumber*>*)filter sampleRate:(int)sampleRate writer:(id<FTLoggerDataWriteProtocol>)writer{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTLogger alloc] initWithEnablePrintLogsToConsole:enable enableCustomLog:enableCustomLog logLevelFilter:filter sampleRate:sampleRate writer:writer];
    });
}
+ (instancetype)sharedInstance {
    if(!sharedInstance){
        FTInnerLogError(@"SDK configuration `Logger` error, unable to collect custom logs");
    }
    return sharedInstance;
}
-(instancetype)initWithEnablePrintLogsToConsole:(BOOL)enable enableCustomLog:(BOOL)enableCustomLog logLevelFilter:(NSArray<NSNumber*>*)filter sampleRate:(int)sampleRate writer:(id<FTLoggerDataWriteProtocol>)writer{
    self = [super init];
    if(self){
        _printLogsToConsole = enable;
        _loggerWriter = writer;
        _sampleRate = sampleRate;
        _logLevelFilterSet = [NSSet setWithArray:filter];
        _enableCustomLog = enableCustomLog;
        _loggerQueue = dispatch_queue_create("com.guance.logger", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_loggerQueue,FTLoggerQueueIdentityKey, &FTLoggerQueueIdentityKey, NULL);
    }
    return self;
}
- (void)log:(NSString *)message
     statusType:(LogStatus)statusType
   property:(nullable NSDictionary *)property{
    if(self.printLogsToConsole){
        FT_CONSOLE_LOG(statusType,message,property);
    }
    if (!self.enableCustomLog) {
        return;
    }
    if (![self.logLevelFilterSet containsObject:@(statusType)]) {
        return;
    }
    [self _log:message async:statusType == StatusError status:FTStatusStringMap[statusType] property:property];
}
- (void)log:(NSString *)content status:(NSString *)status{
    [self log:content status:status property:nil];
}
- (void)log:(NSString *)content status:(NSString *)status property:(nullable NSDictionary *)property{
    if(self.printLogsToConsole){
        FT_CONSOLE_CUSTOM_LOG(status, content, property);
    }
    if (!self.enableCustomLog) {
        return;
    }
    [self _log:content async:NO status:status property:property];
}
-(void)info:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:StatusInfo property:property];
}
-(void)warning:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:StatusWarning property:property];
}
-(void)error:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:StatusError property:property];
}
-(void)critical:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:StatusCritical property:property];
}
- (void)ok:(NSString *)content property:(NSDictionary *)property{
    [self log:content statusType:StatusOk property:property];
}
- (void)_log:(NSString *)content async:(BOOL)async status:(NSString *)status property:(nullable NSDictionary *)property{
    dispatch_block_t logBlock = ^{
        // 上传 datakit
        if(self.loggerWriter && [self.loggerWriter respondsToSelector:@selector(logging:status:tags:field:time:)]){
            if (![FTBaseInfoHandler randomSampling:self.sampleRate]){
                FTInnerLogInfo(@"[Logging][Not Sampled] %@",content);
                return;
            }
            NSString *newContent = [content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];

            [self.loggerWriter logging:newContent status:status tags:nil field:property time:[NSDate ft_currentNanosecondTimeStamp]];
        }else{
            FTInnerLogError(@"SDK configuration error, unable to collect custom logs");
        }
    };
    if(async){
        dispatch_async(self.loggerQueue, logBlock);
    }else{
        [self syncProcess:logBlock];
    }
    
}
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
    [self syncProcess:^{}];
    onceToken = 0;
    sharedInstance =nil;
    FTInnerLogInfo(@"[Logging] SHUT DOWN");
}
@end
