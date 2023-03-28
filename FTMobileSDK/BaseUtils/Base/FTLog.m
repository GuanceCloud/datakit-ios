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

#import "FTLog.h"
#import <os/log.h>

static BOOL _enableLog;

static dispatch_queue_t _loggingQueue;
@implementation FTLog
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
      level:(NSInteger)level
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {
    if (![FTLog isLoggerEnabled]) {
        return;
    }
    @try {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:message level:level function:function line:line];
        va_end(args);
    } @catch(NSException *e) {
       
    }
}
- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(NSInteger)level
   function:(const char *)function
       line:(NSUInteger)line {
    @try {
        dispatch_async(_loggingQueue , ^{
            switch (level) {
                case FTLogLevelInfo:
                    os_log_info(OS_LOG_DEFAULT,"[FTLog][%@] %s [line %lu] %@", @"INFO", function, (unsigned long)line, message);
                    break;
                case FTLogLevelWarning:
                    os_log_info(OS_LOG_DEFAULT,"[FTLog][%@] %s [line %lu] %@", @"WARN", function, (unsigned long)line, message);
                    break;
                case FTLogLevelError:
                    os_log_error(OS_LOG_DEFAULT, "[FTLog][%@] %s [line %lu] %@", @"ERROR", function, (unsigned long)line, message);
                    break;
                default:
                    os_log_debug(OS_LOG_DEFAULT,"[FTLog][%@] %s [line %lu] %@", @"DEBUG", function, (unsigned long)line, message);
                    break;
            }
        });
    } @catch(NSException *e) {
       
    }
}
@end