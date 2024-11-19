//
//  FTCrashThread.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTCrashThread.h"
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <pthread.h>
#include <sys/sysctl.h>

FTCrashThread ftcrashthread_self(void){
    thread_t thread_self = mach_thread_self();
    mach_port_deallocate(mach_task_self(), thread_self);
    return (FTCrashThread)thread_self;
}

bool ftcrashthread_getThreadName(
                                 const FTCrashThread thread, char *const buffer, int bufLength){
    const pthread_t pthread = pthread_from_mach_thread_np((thread_t)thread);
    return pthread_getname_np(pthread, buffer, (unsigned)bufLength) == 0;
}

