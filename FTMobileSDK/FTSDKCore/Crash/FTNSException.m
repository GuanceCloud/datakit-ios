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
    NSArray* addresses = [exception callStackReturnAddresses];
    NSUInteger numFrames = addresses.count;
    uintptr_t* callStack = malloc(numFrames * sizeof(*callStack));
    for(NSUInteger i = 0; i < numFrames; i++){
        callStack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
    }
    if (g_onCrashNotify != NULL) {
        thread_t thread_self = mach_thread_self();
        g_onCrashNotify(thread_self,callStack,(int)numFrames,[exception.reason cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    
    if(previousUncaughtExceptionHandler != NULL){
        previousUncaughtExceptionHandler(exception);
    }
}
void installUncaughtExceptionHandler(const FTCrashNotifyCallback onCrashNotify){
    g_onCrashNotify = onCrashNotify;
    NSSetUncaughtExceptionHandler(&handleException);
}

void uninstallUncaughtExceptionHandler(void){
    NSSetUncaughtExceptionHandler(previousUncaughtExceptionHandler);
}
