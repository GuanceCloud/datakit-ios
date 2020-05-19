//
//  FTLog.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/19.
//  Copyright © 2020 hll. All rights reserved.
//
#import <UIKit/UIKit.h>

#import "FTLog.h"
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
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {
    if (![FTLog isLoggerEnabled]) {
        return;
    }
    
    NSInteger systemVersion = UIDevice.currentDevice.systemVersion.integerValue;
    if (systemVersion == 10) {
        return;
    }
    @try {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:message level:level file:file function:function line:line];
        va_end(args);
    } @catch(NSException *e) {
       
    }
}
- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line {
    @try {
        dispatch_async(_loggingQueue , ^{
            NSString *logMessage = [[NSString alloc] initWithFormat:@"[FTLog][%@]  %s [line %lu]  %@", [self descriptionForLevel:level], function, (unsigned long)line, message];
            NSLog(@"%@", logMessage);
        });
        //file
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
