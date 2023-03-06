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
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
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
            NSString *logMessage = [[NSString alloc] initWithFormat:@"[FTLog][%@] %s [line %lu] %@",[self descriptionForLevel:level],function,(unsigned long)line,message];
            os_log_info(OS_LOG_DEFAULT,"%@",logMessage);
        });
    } @catch(NSException *e) {
       
    }
}

- (NSString *)descriptionForLevel:(FTLogLevel)level {
    NSString *desc = nil;
    switch (level) {
        case FTLogLevelInfo:
            desc = @"INFO";
            break;
        case FTLogLevelWarning:
            desc = @"WARN";
            break;
        case FTLogLevelError:
            desc = @"ERROR";
            break;
        default:
            desc = @"UNKNOW";
            break;
    }
    return desc;
}
@end
