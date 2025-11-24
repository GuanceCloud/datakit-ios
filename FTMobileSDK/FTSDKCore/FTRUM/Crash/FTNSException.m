//
//  FTNSException.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "FTSignalException.h"
#import "FTCrashMonitor.h"
#import "FTCrashLogger.h"

static NSUncaughtExceptionHandler *previousUncaughtExceptionHandler;

static void handleException(NSException *exception) {
    if (!ftcm_setCrashHandling(true)) {
        NSArray* addresses = [exception callStackReturnAddresses];
        NSUInteger numFrames = addresses.count;
        uintptr_t* callStack = malloc(numFrames * sizeof(*callStack));
        NSString *message = [NSString stringWithFormat:@"*** Terminating app due to uncaught exception '%@', reason: '%@'",
                             [exception name], [exception reason]];
        for(NSUInteger i = 0; i < numFrames; i++){
            callStack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }
        FTThread thread_self = ftthread_self();
        ftcm_handleException(thread_self,callStack,(int)numFrames,[message cStringUsingEncoding:NSUTF8StringEncoding]);
    }else{
        FTLOG_INFO("‌An unhandled crash occurred, and it might be a second crash.");
    }
    if(previousUncaughtExceptionHandler != NULL){
        previousUncaughtExceptionHandler(exception);
    }
}
void FTInstallUncaughtExceptionHandler(void){
    previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&handleException);
}

void FTUninstallUncaughtExceptionHandler(void){
    NSSetUncaughtExceptionHandler(previousUncaughtExceptionHandler);
}
