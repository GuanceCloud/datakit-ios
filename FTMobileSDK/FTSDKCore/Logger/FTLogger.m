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
    }
    return self;
}
- (void)log:(NSString *)message
     status:(LogStatus)status
   property:(nullable NSDictionary *)property
{
    dispatch_block_t logBlock = ^{
        if(self.printLogsToConsole){
            FT_CONSOLE_LOG(status,message,property);
        }
        // 上传 datakit
        if(self.loggerWriter && [self.loggerWriter respondsToSelector:@selector(logging:status:tags:field:time:)]){
            if (!self.enableCustomLog) {
                return;
            }
            if (![self.logLevelFilterSet containsObject:@(status)]) {
                return;
            }
            if (![FTBaseInfoHandler randomSampling:self.sampleRate]){
                FTInnerLogInfo(@"[Logging][Not Sampled] %@",message);
                return;
            }
            [self.loggerWriter logging:message status:status tags:nil field:property time:[NSDate ft_currentNanosecondTimeStamp]];
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
