//
//  FTLogger.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTLogger.h"
#import "FTLogger+Private.h"
#import "FTInternalLog.h"
#import "FTBaseInfoHandler.h"
#import "FTConstants.h"
#import "NSString+FTAdd.h"
#import "FTDateUtil.h"
#import "FTRecordModel.h"
@interface FTLogger ()
@property (nonatomic, assign) BOOL printLogsToConsole;
@property (nonatomic, weak) id<FTLoggerDataWriteProtocol> loggerWriter;
@property (nonatomic, assign) int sampletRate;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@property (nonatomic, assign) BOOL enableCustomLog;
@property (nonatomic, strong) dispatch_queue_t loggerQueue;

@end
@implementation FTLogger
static FTLogger *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (void)startWithEablePrintLogsToConsole:(BOOL)enable enableCustomLog:(BOOL)enableCustomLog logLevelFilter:(NSArray<NSNumber*>*)filter sampleRate:(int)sampletRate writer:(id<FTLoggerDataWriteProtocol>)writer{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTLogger alloc] initWithEablePrintLogsToConsole:enable enableCustomLog:enableCustomLog logLevelFilter:filter sampleRate:sampletRate writer:writer];
    });
}
+ (instancetype)sharedInstance {
    return sharedInstance;
}
-(instancetype)initWithEablePrintLogsToConsole:(BOOL)enable enableCustomLog:(BOOL)enableCustomLog logLevelFilter:(NSArray<NSNumber*>*)filter sampleRate:(int)sampletRate writer:(id<FTLoggerDataWriteProtocol>)writer{
    self = [super init];
    if(self){
        _printLogsToConsole = enable;
        _loggerWriter = writer;
        _sampletRate = sampletRate;
        _logLevelFilterSet = [NSSet setWithArray:filter];
        _enableCustomLog = enableCustomLog;
        _loggerQueue = dispatch_queue_create("com.guance.logger", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)log:(NSString *)message
     status:(LogStatus)status
   property:(nullable NSDictionary *)property
{
    dispatch_block_t logBlock = ^{
        if(self.printLogsToConsole){
            NSString *consoleMessage = [NSString stringWithFormat:@"[IOS APP] [%@] %@",[FTStatusStringMap[status] uppercaseString],message];
            FTCONSOLELOG(status,consoleMessage);
        }
        // 上传 datakit
        if(self.loggerWriter && [self.loggerWriter respondsToSelector:@selector(logging:status:tags:field:tm:)]){
            if (!self.enableCustomLog) {
                ZYLogInfo(@"[Logging] enableCustomLog 未开启，数据不进行采集");
                return;
            }
            if (![self.logLevelFilterSet containsObject:@(status)]) {
                ZYLogInfo(@"[Logging] 经过过滤算法判断-此条日志不采集");
                return;
            }
            if (![FTBaseInfoHandler randomSampling:self.sampletRate]){
                ZYLogInfo(@"[Logging] 经过采集算法判断-此条日志不采集");
                return;
            }
            [self.loggerWriter logging:message status:status tags:nil field:property tm:[FTDateUtil currentTimeNanosecond]];
        }else{
            ZYLogError(@"SDK 配置异常，无法采集自定义日志");
        }
    };
    if(status == StatusError){
        dispatch_sync(self.loggerQueue, logBlock);
    }else{
        dispatch_async(self.loggerQueue, logBlock);
    }
}
-(void)info:(NSString *)content property:(NSDictionary *)property{
    [self log:content status:StatusInfo property:property];
}
-(void)warning:(NSString *)content property:(NSDictionary *)property{
    [self log:content status:StatusWarning property:property];
}
-(void)error:(NSString *)content property:(NSDictionary *)property{
    [self log:content status:StatusError property:property];
}
-(void)critical:(NSString *)content property:(NSDictionary *)property{
    [self log:content status:StatusCritical property:property];
}
- (void)ok:(NSString *)content property:(NSDictionary *)property{
    [self log:content status:StatusOk property:property];
}
- (void)syncProcess{
    dispatch_sync(self.loggerQueue, ^{
        
    });
}
- (void)shutDown{
    [self syncProcess];
    onceToken = 0;
    sharedInstance =nil;
    ZYLogInfo(@"[Logging] SHUT DOWN");
}
@end
