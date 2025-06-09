//
//  FTLog.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/19.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "FTLog+Private.h"
#import <os/log.h>
#import "FTLogMessage.h"
#import "FTFileLogger.h"
#import "FTOSLogger.h"
@implementation FTAbstractLogger

-(void)logMessage:(FTLogMessage *)logMessage{
    // base implementation
}
- (NSString *)formatLogMessage:(FTLogMessage *)logMessage{
    if(logMessage.userLog){
        NSString *prefix = @"IOS APP" ;
#if FT_MAC
        prefix = @"MACOS APP";
#endif
        NSString *status = logMessage.status.length>0?[logMessage.status uppercaseString]:[FTStatusStringMap[logMessage.level] uppercaseString];
        NSString *consoleMessage = [NSString stringWithFormat:@"[%@][%@] %@",prefix,status, logMessage.message];
        NSMutableArray *mutableStrs = [NSMutableArray array];
        if(logMessage.property && logMessage.property.allKeys.count>0){
            for (NSString *key in logMessage.property.allKeys) {
                [mutableStrs addObject:[NSString stringWithFormat:@"%@=%@",key,logMessage.property[key]]];
            }
            consoleMessage =[consoleMessage stringByAppendingFormat:@" ,{%@}",[mutableStrs componentsJoinedByString:@","]];
        }
        return consoleMessage;
    }else{
        NSString *prefix = @"FTLog";
        return [NSString stringWithFormat:@"[%@][%@] %@ [Line %lu] %@",prefix,[FTStatusStringMap[logMessage.level] uppercaseString],logMessage.function,(unsigned long)logMessage.line, logMessage.message];
    }
}

@end


static BOOL _enableLog;
void *FTInnerLogQueueIdentityKey = &FTInnerLogQueueIdentityKey;

static dispatch_queue_t _loggingQueue;
static dispatch_group_t _loggingGroup;
@interface FTLog()
@property (nonatomic, strong) NSMutableArray <id <FTDebugLogger>>*loggers;
@end
@implementation FTLog

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        _loggingQueue = dispatch_queue_create("com.guance.debugLog", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_loggingQueue, FTInnerLogQueueIdentityKey, &FTInnerLogQueueIdentityKey, NULL);
        _loggingGroup = dispatch_group_create();
    });
    return sharedInstance;
}
+ (BOOL)isLoggerEnabled{
    return _enableLog;
}
+ (void)enableLog:(BOOL)enableLog {
    _enableLog = enableLog;
    static FTOSLogger *sdkOSLogger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sdkOSLogger = [[FTOSLogger alloc]init];
    });
    if(enableLog){
        [[FTLog sharedInstance] addLogger:sdkOSLogger];
    }
}
+ (void)log:(BOOL)asynchronous
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(5,6){
    if (!_enableLog) {
        return;
    }
    @try {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self log:asynchronous message:message level:level function:function line:line];
        va_end(args);
    } @catch(NSException *e) {
        FTNSLogError(@"[FTLog] %@",e.description);
    }
}
+ (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line{
    [self.sharedInstance log:asynchronous message:message level:level function:function line:line];
}
+ (void)addLogger:(id <FTDebugLogger>)logger {
    [[self sharedInstance] addLogger:logger];
}
+ (void)removeLogger:(id <FTDebugLogger>)logger {
    [[self sharedInstance] removeLogger:logger];
}
- (void)registerInnerLogCacheToDefaultPath{
    [self registerInnerLogCacheToLogsDirectory:nil fileNamePrefix:nil];
}
- (void)registerInnerLogCacheToLogsDirectory:(NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix{
    FTLogFileManager *logFileManager = [[FTLogFileManager alloc]initWithLogsDirectory:logsDirectory fileNamePrefix:fileNamePrefix];
    FTFileLogger *fileLogger = [[FTFileLogger alloc]initWithLogFileManager:logFileManager];
    [FTLog addLogger:fileLogger];
}
- (void)registerInnerLogCacheToLogsFilePath:(NSString *)filePath{
    FTLogFileManager *logFileManager = [[FTLogFileManager alloc]initWithLogsFilePath:filePath];
    FTFileLogger *fileLogger = [[FTFileLogger alloc]initWithLogFileManager:logFileManager];
    [FTLog addLogger:fileLogger];
}
- (void)addLogger:(id <FTDebugLogger>)logger {
    if (!logger) {
        return;
    }
    dispatch_async(_loggingQueue, ^{
        if ([self.loggers containsObject:logger]) {
            return;
        }
        [self.loggers addObject:logger];
    });
}
- (void)removeLogger:(id <FTDebugLogger>)logger {
    if (!logger) {
        return;
    }
    dispatch_async(_loggingQueue, ^{
        [self.loggers removeObject:logger];
    });
}
- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line{
    @try {
        NSDate *timestamp = [NSDate date];
        FTLogMessage *logMessage = [[FTLogMessage alloc] initWithMessage:message level:level function:[NSString stringWithUTF8String:function] line:line timestamp:timestamp];
        [self queueLogMessage:logMessage asynchronously:asynchronous];
    } @catch(NSException *e) {
        FTNSLogError(@"[FTLog] %@",e.description);
    }
}
- (void)userLog:(BOOL)asynchronous
        message:(NSString *)message
          level:(LogStatus)level
         status:(NSString *)status
   property:(nullable NSDictionary *)property{
    @try {
        NSDate *timestamp = [NSDate date];
        FTLogMessage *logMessage = [[FTLogMessage alloc] initWithMessage:message  level:level status:status property:property timestamp:timestamp];
        [self queueLogMessage:logMessage asynchronously:asynchronous];
    } @catch(NSException *e) {
        FTNSLogError(@"[FTLog] %@",e.description);
    }
}
- (void)queueLogMessage:(FTLogMessage *)logMessage asynchronously:(BOOL)asyncFlag {
    dispatch_block_t logBlock = ^{
        @autoreleasepool {
            [self log:logMessage];
        }
    };
    if (asyncFlag) {
        dispatch_async(_loggingQueue, logBlock);
    } else if (dispatch_get_specific(FTInnerLogQueueIdentityKey)) {
        logBlock();
    } else {
        dispatch_sync(_loggingQueue, logBlock);
    }
}
- (void)log:(FTLogMessage *)logMessage {
    for (FTAbstractLogger *logger in self.loggers) {
        dispatch_group_async(_loggingGroup, logger->_loggerQueue, ^{
            @autoreleasepool {
                [logger logMessage:logMessage];
            }
        });
    }
    dispatch_group_wait(_loggingGroup, DISPATCH_TIME_FOREVER);
}
- (NSMutableArray<id <FTDebugLogger>>*)loggers {
    if (!_loggers) {
        _loggers = [[NSMutableArray alloc] init];
    }
    return _loggers;
}
- (void)removeAllLoggers {
    dispatch_async(_loggingQueue, ^{
        [self.loggers removeAllObjects];
    });
}
- (void)shutDown{
    [self removeAllLoggers];
    [FTLog enableLog:NO];
}
@end
