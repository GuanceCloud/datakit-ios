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
    }
    return self;
}
+ (void)log:(NSInteger)status
         file:(const char *)file
     function:(nonnull const char *)function
         line:(NSUInteger)line
     property:(nonnull NSDictionary *)property
       format:(nonnull NSString *)format, ... {
    @try {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [[FTLogger sharedInstance] log:message status:status file:file function:function line:line property:property];
        va_end(args);
    } @catch(NSException *e) {
        ZYLogError(@"exception %@",e);
    }
}
+ (void)log:(NSInteger)status
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
   property:(NSDictionary *)property
     format:(NSString *)format
       args:(va_list)argList{
    @try {
        NSString *message = [[NSString alloc] initWithFormat:format arguments:argList];
        [[FTLogger sharedInstance] log:message status:status file:file function:function line:line property:property];
    } @catch(NSException *e) {
        ZYLogError(@"exception %@",e);
    }
}
- (void)log:(NSString *)content
     status:(LogStatus)status
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
   property:(nullable NSDictionary *)property
{
    // 如果开启格式，拼接字符串
    NSString *filePath = [[NSString alloc] initWithUTF8String:file];
    NSString *name = [filePath componentsSeparatedByString:@"/"].lastObject;
    NSString *formatMessage = [NSString stringWithFormat:@"%@ [%s] [%lu] %@",name,function, (unsigned long)line, content];
    [self log:formatMessage status:status property:property];
}
- (void)log:(NSString *)message
     status:(LogStatus)status
   property:(nullable NSDictionary *)property
{
   // 如果允许控制台打印
    if(self.printLogsToConsole){
        NSString *consoleMessage = [NSString stringWithFormat:@"[IOS APP] [%@] %@",[FTStatusStringMap[status] uppercaseString],message];
        FTCONSOLELOG(status,consoleMessage);
    }
   // 上传 datakit
    if(self.loggerWriter && [self.loggerWriter respondsToSelector:@selector(logging:status:tags:field:tm:)]){
        if (!self.enableCustomLog) {
            ZYLogDebug(@"enableCustomLog 未开启，数据不进行采集");
            return;
        }
        if (![self.logLevelFilterSet containsObject:@(status)]) {
            ZYLogDebug(@"经过过滤算法判断-此条日志不采集");
            return;
        }
        if (![FTBaseInfoHandler randomSampling:self.sampletRate]){
            ZYLogDebug(@"经过采集算法判断-此条日志不采集");
            return;
        }
        [self.loggerWriter logging:message status:status tags:nil field:property tm:[FTDateUtil currentTimeNanosecond]];
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
- (void)shutDown{
    onceToken = 0;
    sharedInstance =nil;
}
@end
