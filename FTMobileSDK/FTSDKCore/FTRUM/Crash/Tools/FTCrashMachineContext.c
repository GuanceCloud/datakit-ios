//
//  FTCrashMachineContext.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTCrashCPU.h"
#include "FTCrashMachineContext.h"
#include "FTCrashMachineContext_Apple.h"
#include "FTStackCursor_MachineContext.h"
#include "FTStackCursor.h"
#include "FTCrashThread.h"
static FTCrashThread g_reservedThreads[10];
static int g_reservedThreadsMaxIndex = sizeof(g_reservedThreads) / sizeof(g_reservedThreads[0]) - 1;
static int g_reservedThreadsCount = 0;
static inline bool
isStackOverflow(const FTCrashMachineContext *const context)
{
    FTStackCursor stackCursor;
    ftsc_initWithMachineContext(
        &stackCursor, FTSC_STACK_OVERFLOW_THRESHOLD, context);
    while (stackCursor.advanceCursor(&stackCursor)) { }
    bool rv = stackCursor.state.hasGivenUp;
    return rv;
}
static inline bool
getThreadList(FTCrashMachineContext *context)
{
    const task_t thisTask = mach_task_self();
    //("Getting thread list");
    kern_return_t kr;
    thread_act_array_t threads;
    mach_msg_type_number_t actualThreadCount;

    if ((kr = task_threads(thisTask, &threads, &actualThreadCount)) != KERN_SUCCESS) {
        //("task_threads: %s", mach_error_string(kr));
        return false;
    }
    //("Got %d threads", context->threadCount);
    int threadCount = (int)actualThreadCount;
    int maxThreadCount = sizeof(context->allThreads) / sizeof(context->allThreads[0]);
    if (threadCount > maxThreadCount) {
        //("Thread count %d is higher than maximum of %d", threadCount, maxThreadCount);
        threadCount = maxThreadCount;
    }
    for (int i = 0; i < threadCount; i++) {
        context->allThreads[i] = threads[i];
    }
    context->threadCount = threadCount;

    for (mach_msg_type_number_t i = 0; i < actualThreadCount; i++) {
        mach_port_deallocate(thisTask, context->allThreads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * actualThreadCount);

    return true;
}

int ftCrashmc_contextSize(void){
    return sizeof(FTCrashMachineContext);
}

bool
ftcrashmc_getContextForThread(
    FTCrashThread thread, FTCrashMachineContext *destinationContext, bool isCrashedContext)
{
    //("Fill thread 0x%x context into %p. is crashed = %d", thread,destinationContext, isCrashedContext);
    memset(destinationContext, 0, sizeof(*destinationContext));
    destinationContext->thisThread = (thread_t)thread;
    destinationContext->isCurrentThread = thread == ftcrashthread_self();
    destinationContext->isCrashedContext = isCrashedContext;
    destinationContext->isSignalContext = false;
    if (ftcrashmc_canHaveCPUState(destinationContext)) {
       ftcrashcpu_getState(destinationContext);
    }
    if (ftcrashmc_isCrashedContext(destinationContext)) {
        destinationContext->isStackOverflow = isStackOverflow(destinationContext);
        getThreadList(destinationContext);
    }
    //("Context retrieved.");
    return true;
}
void ftmc_addReservedThread(FTCrashThread thread)
{
    int nextIndex = g_reservedThreadsCount;
    if (nextIndex > g_reservedThreadsMaxIndex) {
        //("Too many reserved threads (%d). Max is %d", nextIndex, g_reservedThreadsMaxIndex);
        return;
    }
    g_reservedThreads[g_reservedThreadsCount++] = thread;
}
static inline bool isThreadInList(thread_t thread, FTCrashThread *list, int listCount)
{
    for (int i = 0; i < listCount; i++) {
        if (list[i] == (FTCrashThread)thread) {
            return true;
        }
    }
    return false;
}
void ftmc_suspendEnvironment(__unused thread_act_array_t *suspendedThreads,
                             __unused mach_msg_type_number_t *numSuspendedThreads)
{
    //("Suspending environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ftcrashthread_self();

    if ((kr = task_threads(thisTask, suspendedThreads, numSuspendedThreads)) != KERN_SUCCESS) {
        //("task_threads: %s", mach_error_string(kr));
        return;
    }

    for (mach_msg_type_number_t i = 0; i < *numSuspendedThreads; i++) {
        thread_t thread = (*suspendedThreads)[i];
        if (thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount)) {
            if ((kr = thread_suspend(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                //("thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    //("Suspend complete.");
}

void ftmc_resumeEnvironment(__unused thread_act_array_t threads, __unused mach_msg_type_number_t numThreads)
{
    //("Resuming environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ftcrashthread_self();

    if (threads == NULL || numThreads == 0) {
        //("we should call ksmc_suspendEnvironment() first");
        return;
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        thread_t thread = threads[i];
        if (thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount)) {
            if ((kr = thread_resume(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                //("thread_resume (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);

    //("Resume complete.");
}

int
ftcrashmc_getThreadCount(const FTCrashMachineContext *const context)
{
    return context->threadCount;
}
FTCrashThread
ftcrashmc_getThreadAtIndex(const FTCrashMachineContext *const context, int index)
{
    return context->allThreads[index];
}
bool
ftcrashmc_isCrashedContext(const FTCrashMachineContext *const context)
{
    return context->isCrashedContext;
}
static inline bool
isContextForCurrentThread(const FTCrashMachineContext *const context)
{
    return context->isCurrentThread;
}

static inline bool
isSignalContext(const FTCrashMachineContext *const context)
{
    return context->isSignalContext;
}
bool
ftcrashmc_canHaveCPUState(const FTCrashMachineContext *const context)
{
    return !isContextForCurrentThread(context) || isSignalContext(context);
}


