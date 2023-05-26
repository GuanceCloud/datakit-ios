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
#define FTLogger(...) NSLog(__VA_ARGS__)

#import "FTInternalLog.h"
#import <os/log.h>

static BOOL _enableLog;

static dispatch_queue_t _loggingQueue;
@implementation FTInternalLog
+ (void)initialize {
    _enableLog = NO;
    _loggingQueue = dispatch_queue_create("com.cloudcare.ft.mobile.sdk.log", DISPATCH_QUEUE_SERIAL);
}
+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
+ (BOOL)isLoggerEnabled {
    __block BOOL enable = NO;
    dispatch_sync(_loggingQueue, ^{
        enable = _enableLog;
    });
    return enable;
}
+ (void)enableLog:(BOOL)enableLog {
    dispatch_async(_loggingQueue, ^{
        _enableLog = enableLog;
    });
}
+ (void)log:(BOOL)asynchronous
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(5,6){
    if (![FTInternalLog isLoggerEnabled]) {
        return;
    }
    @try {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:[NSString stringWithFormat:@"[FTLog][%@] %s [line %lu] %@",[FTStatusStringMap[level] uppercaseString],function, (unsigned long)line, message] level:level];
        va_end(args);
    } @catch(NSException *e) {
       
    }
}
- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(LogStatus)level{
    @try {
        dispatch_async(_loggingQueue , ^{
            switch (level) {
                case StatusWarning:
                case StatusCritical:
                case StatusOk:
                case StatusInfo:
                    os_log_info(OS_LOG_DEFAULT,"%{public}s",[message UTF8String]);
                    break;
                case StatusError:
                    os_log_error(OS_LOG_DEFAULT, "%{public}s",[message UTF8String]);
                    break;
                case StatusDebug:
                    os_log_debug(OS_LOG_DEFAULT, "%{public}s",[message UTF8String]);
                    break;
            }
        });
    } @catch(NSException *e) {
       
    }
}
@end
