//
//  FTCrashMachineContext.c
//
//  Created by Karl Stenerud on 2016-12-02.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "FTCrashCPU.h"

#include <mach/mach.h>

#if __has_include(<sys/_types/_ucontext64.h>)
#include <sys/_types/_ucontext64.h>
#endif

#include "FTCrashCPU.h"
#include "FTCrashCPU_Apple.h"
#include "FTCrashMachineContext_Apple.h"
#include "FTCrashStackCursor_MachineContext.h"
#include "FTSDKCompat.h"

#include "FTCrashLogger.h"

#ifdef __arm64__
#if !(FTCRASH_HOST_MAC)
#define FTCRASH_CONTEXT_64
#endif
#endif

#ifdef FTCRASH_CONTEXT_64
#define UC_MCONTEXT uc_mcontext64
typedef ucontext64_t SignalUserContext;
#undef FTCRASH_CONTEXT_64
#else
#define UC_MCONTEXT uc_mcontext
typedef ucontext_t SignalUserContext;
#endif

static FTCrashThread g_reservedThreads[10];
static int g_reservedThreadsMaxIndex = sizeof(g_reservedThreads) / sizeof(g_reservedThreads[0]) - 1;
static int g_reservedThreadsCount = 0;

static inline bool isStackOverflow(const FTCrashMachineContext *const context)
{
    FTCrashStackCursor stackCursor;
    ftcrashsc_initWithMachineContext(&stackCursor, FTCRASHSC_STACK_OVERFLOW_THRESHOLD, context);
    while (stackCursor.advanceCursor(&stackCursor)) {
    }
    return stackCursor.state.hasGivenUp;
}

static inline bool getThreadList(FTCrashMachineContext *context)
{
    const task_t thisTask = mach_task_self();
    FTLOG_DEBUG("Getting thread list");
    kern_return_t kr;
    thread_act_array_t threads;
    mach_msg_type_number_t actualThreadCount;

    if ((kr = task_threads(thisTask, &threads, &actualThreadCount)) != KERN_SUCCESS) {
        FTLOG_ERROR("task_threads: %s", mach_error_string(kr));
        return false;
    }
    mach_msg_type_number_t threadCount = actualThreadCount;
    if (threadCount > MAX_CAPTURED_THREADS) {
        FTLOG_ERROR("Thread count %d is higher than maximum of %d", threadCount, MAX_CAPTURED_THREADS);
        threadCount = MAX_CAPTURED_THREADS;
    }
    const thread_t crashedThread = context->thisThread;
    bool isCrashedThreadInList = false;
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        thread_t thread = threads[i];
        context->allThreads[i] = thread;
        if (thread == crashedThread) {
            isCrashedThreadInList = true;
        }
    }
    if (threadCount > 0 && !isCrashedThreadInList) {
        // If the crashed thread isn't in our list (because we blew past MAX_CAPTURED_THREADS),
        // put it in the last entry.
        context->allThreads[threadCount - 1] = crashedThread;
    }
    context->threadCount = (int)threadCount;

    for (mach_msg_type_number_t i = 0; i < actualThreadCount; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * actualThreadCount);

    return true;
}

int ftcrashmc_contextSize(void) { return sizeof(FTCrashMachineContext); }

FTCrashThread ftcrashmc_getThreadFromContext(const FTCrashMachineContext *const context) { return context->thisThread; }

bool ftcrashmc_getContextForThread(FTCrashThread thread, FTCrashMachineContext *destinationContext, bool isCrashedContext)
{
    FTLOG_DEBUG("Fill thread 0x%x context into %p. is crashed = %d", thread, destinationContext, isCrashedContext);
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
    return true;
}

bool ftcrashmc_getContextForSignal(void *signalUserContext, FTCrashMachineContext *destinationContext)
{
    FTLOG_DEBUG("Get context from signal user context and put into %p.", destinationContext);
    _STRUCT_MCONTEXT *sourceContext = ((SignalUserContext *)signalUserContext)->UC_MCONTEXT;
    memcpy(&destinationContext->machineContext, sourceContext, sizeof(destinationContext->machineContext));
    destinationContext->thisThread = (thread_t)ftcrashthread_self();
    destinationContext->isCrashedContext = true;
    destinationContext->isSignalContext = true;
    destinationContext->isStackOverflow = isStackOverflow(destinationContext);
    getThreadList(destinationContext);
    return true;
}

void ftcrashmc_addReservedThread(FTCrashThread thread)
{
    int nextIndex = g_reservedThreadsCount;
    if (nextIndex > g_reservedThreadsMaxIndex) {
        FTLOG_ERROR("Too many reserved threads (%d). Max is %d", nextIndex, g_reservedThreadsMaxIndex);
        return;
    }
    g_reservedThreads[g_reservedThreadsCount++] = thread;
}

#if FT_HAS_THREADS_API
static inline bool isThreadInList(thread_t thread, FTCrashThread *list, int listCount)
{
    for (int i = 0; i < listCount; i++) {
        if (list[i] == (FTCrashThread)thread) {
            return true;
        }
    }
    return false;
}
#endif
void ftcrashmc_suspendEnvironment(thread_act_array_t *threadsToSuspend, mach_msg_type_number_t *threadsToSuspendCount){
    ftcrashmc_suspendEnvironment_upToMaxSupportedThreads(threadsToSuspend, threadsToSuspendCount,UINT32_MAX);
}
void ftcrashmc_suspendEnvironment_upToMaxSupportedThreads(thread_act_array_t *threadsToSuspend, mach_msg_type_number_t *threadsToSuspendCount,mach_msg_type_number_t maxSupportedThreads)
{
#if FT_HAS_THREADS_API
    if (threadsToSuspend == NULL || threadsToSuspendCount == NULL) {
        FTLOG_ERROR("Passed in null pointer");
        goto failed;
    }

    if (*threadsToSuspend != NULL) {
        // This might be a double-call, or it might just be a dirty pointer. We can't be sure, so assume a double-call
        // and return with the data untouched. But issue a log message just in case.
        FTLOG_WARN("POTENTIAL BUG: Passed in dirty pointer");
        return;
    }

    FTLOG_DEBUG("Suspending environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ftcrashthread_self();

    if ((kr = task_threads(thisTask, threadsToSuspend, threadsToSuspendCount)) != KERN_SUCCESS) {
        FTLOG_ERROR("task_threads: %s", mach_error_string(kr));
        goto failed;
    }
    const thread_act_array_t threads = *threadsToSuspend;
    const mach_msg_type_number_t threadsCount = *threadsToSuspendCount;
    if (threadsCount > maxSupportedThreads) {
        threadsToSuspendCount = 0;
        FTLOG_ERROR("Too many threads to suspend. Aborting operation.");
        return;
    }
    for (mach_msg_type_number_t i = 0; i < threadsCount; i++) {
        thread_t thread = threads[i];
        if (thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount)) {
            if ((kr = thread_suspend(thread)) != KERN_SUCCESS) {
                // Note the error and keep going.
                FTLOG_ERROR("thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    FTLOG_DEBUG("Suspend complete.");
    return;
failed:
#endif
    if (threadsToSuspend != NULL) {
        *threadsToSuspend = NULL;
    }
    if (threadsToSuspendCount != NULL) {
        *threadsToSuspendCount = 0;
    }
}

void ftcrashmc_resumeEnvironment(thread_act_array_t *threads_inOut, mach_msg_type_number_t *numThreads_inOut)
{
#if FT_HAS_THREADS_API
    if (threads_inOut == NULL || numThreads_inOut == NULL) {
        FTLOG_ERROR("Passed in null pointer");
        goto done;
    }

    FTLOG_DEBUG("Resuming environment.");

    if (*threads_inOut == NULL || *numThreads_inOut == 0) {
        // Idempotent return
        goto done;
    }

    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ftcrashthread_self();

    thread_act_array_t threads = *threads_inOut;
    mach_msg_type_number_t numThreads = *numThreads_inOut;

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        thread_t thread = threads[i];
        if (thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount)) {
            if ((kr = thread_resume(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                FTLOG_ERROR("thread_resume (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);

    FTLOG_DEBUG("Resume complete.");
done:
#endif
    if (threads_inOut != NULL) {
        *threads_inOut = NULL;
    }
    if (numThreads_inOut != NULL) {
        *numThreads_inOut = 0;
    }
}

int ftcrashmc_getThreadCount(const FTCrashMachineContext *const context) { return context->threadCount; }

FTCrashThread ftcrashmc_getThreadAtIndex(const FTCrashMachineContext *const context, int index) { return context->allThreads[index]; }

int ftcrashmc_indexOfThread(const FTCrashMachineContext *const context, FTCrashThread thread)
{
    for (int i = 0; i < (int)context->threadCount; i++) {
        if (context->allThreads[i] == thread) {
            return i;
        }
    }
    return -1;
}

bool ftcrashmc_isCrashedContext(const FTCrashMachineContext *const context) { return context->isCrashedContext; }

static inline bool isContextForCurrentThread(const FTCrashMachineContext *const context) { return context->isCurrentThread; }

static inline bool isSignalContext(const FTCrashMachineContext *const context) { return context->isSignalContext; }

bool ftcrashmc_canHaveCPUState(const FTCrashMachineContext *const context)
{
    return !isContextForCurrentThread(context) || isSignalContext(context);
}

bool ftcrashmc_hasValidExceptionRegisters(const FTCrashMachineContext *const context)
{
    return ftcrashmc_canHaveCPUState(context) && ftcrashmc_isCrashedContext(context);
}
