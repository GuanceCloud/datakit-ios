//
//  FTCrashDefaultMachineContextWrapper.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTCrashDefaultMachineContextWrapper.h"
#import "FTThread.h"
#include "FTCrashMachineContext.h"
#import <Foundation/Foundation.h>
#include <execinfo.h>
#include <pthread.h>
FTCrashThread mainThreadID;

@implementation FTCrashDefaultMachineContextWrapper
+ (void)load
{
    mainThreadID = pthread_mach_thread_np(pthread_self());
}

- (void)fillContextForCurrentThread:(struct FTCrashMachineContext *)context
{
    ftcrashmc_getContextForThread(ftcrashthread_self(), context, YES);
}
- (int)getThreadCount:(struct FTCrashMachineContext *)context
{
    return ftcrashmc_getThreadCount(context);
}
- (FTCrashThread)getThread:(struct FTCrashMachineContext *)context withIndex:(int)index
{
    FTCrashThread thread = ftcrashmc_getThreadAtIndex(context, index);
    return thread;
}
- (BOOL)getThreadName:(const FTCrashThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength
{
    return ftcrashthread_getThreadName(thread, buffer, bufLength) == true;
}
- (BOOL)isMainThread:(FTCrashThread)thread
{
    return thread == mainThreadID;
}

@end
