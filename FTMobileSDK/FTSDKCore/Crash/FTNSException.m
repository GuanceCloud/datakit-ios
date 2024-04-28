//
//  FTNSException.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include "FTSignalException.h"
static FTCrashNotifyCallback g_onCrashNotify;

static NSUncaughtExceptionHandler *previousUncaughtExceptionHandler;

static void handleException(NSException *exception) {
    if (g_onCrashNotify != NULL) {
        NSArray* addresses = [exception callStackReturnAddresses];
        NSUInteger numFrames = addresses.count;
        uintptr_t* callStack = malloc(numFrames * sizeof(*callStack));
        NSString *message = [NSString stringWithFormat:@"*** Terminating app due to uncaught exception '%@', reason: '%@'",
                             [exception name], [exception reason]];
        for(NSUInteger i = 0; i < numFrames; i++){
            callStack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }
        thread_t thread_self = mach_thread_self();
        g_onCrashNotify(thread_self,callStack,(int)numFrames,[message cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    if(previousUncaughtExceptionHandler != NULL){
        previousUncaughtExceptionHandler(exception);
    }
}
void FTInstallUncaughtExceptionHandler(const FTCrashNotifyCallback onCrashNotify){
    g_onCrashNotify = onCrashNotify;
    previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&handleException);
}

void FTUninstallUncaughtExceptionHandler(void){
    NSSetUncaughtExceptionHandler(previousUncaughtExceptionHandler);
}
