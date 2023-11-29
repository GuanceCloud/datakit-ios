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
#import "FTSDKCompat.h"
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
    if(!sharedInstance){
        FTInnerLogError(@"SDK configuration `Logger` error, unable to collect custom logs");
    }
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
            NSString *prefix = @"[IOS APP]" ;
#if FT_MAC
            prefix = @"[MACOS APP]";
#endif
            NSString *consoleMessage = [NSString stringWithFormat:@"%@ [%@] %@",prefix,[FTStatusStringMap[status] uppercaseString],message];
            NSMutableArray *mutableStrs = [NSMutableArray array];
            if(property && property.allKeys.count>0){
                for (NSString *key in property.allKeys) {
                    [mutableStrs addObject:[NSString stringWithFormat:@"%@=%@",key,property[key]]];
                }
                consoleMessage =[consoleMessage stringByAppendingFormat:@" ,{%@}",[mutableStrs componentsJoinedByString:@","]];
            }
            FTCONSOLELOG(status,consoleMessage);
        }
        // 上传 datakit
        if(self.loggerWriter && [self.loggerWriter respondsToSelector:@selector(logging:status:tags:field:tm:)]){
            if (!self.enableCustomLog) {
                FTInnerLogInfo(@"[Logging] Based on the `enableCustomLog` setting, `%@` will not be collected",message);
                return;
            }
            if (![self.logLevelFilterSet containsObject:@(status)]) {
                FTInnerLogInfo(@"[Logging] Based on the `logLevelFilter` setting, `%@` will not be collected",message);
                return;
            }
            if (![FTBaseInfoHandler randomSampling:self.sampletRate]){
                FTInnerLogInfo(@"[Logging] Based on the `sampletrate` setting, `%@` will not be collected",message);
                return;
            }
            [self.loggerWriter logging:message status:status tags:nil field:property tm:[FTDateUtil currentTimeNanosecond]];
        }else{
            FTInnerLogError(@"SDK configuration error, unable to collect custom logs");
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
    FTInnerLogInfo(@"[Logging] SHUT DOWN");
}
@end
