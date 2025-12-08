//
//  FTThreadInspector.m
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTThreadInspector.h"
#import "FTCrashDefaultMachineContextWrapper.h"
#import "FTThread.h"
#include "FTCrashMachineContext.h"
#import "FTStackTraceBuilder.h"
#include "FTCrashStackCursor.h"
#include "FTCrashStackCursor_MachineContext.h"
#define MAX_STACKTRACE_LENGTH 100

typedef struct {
    FTCrashThread thread;
    FTCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH];
    int stackLength;
} FTThreadInfo;

unsigned int
getStackEntriesFromThread(FTCrashThread thread, struct FTCrashMachineContext *context,
                          FTCrashStackEntry *buffer, unsigned int maxEntries, bool symbolicate)
{
    ftcrashmc_getContextForThread(thread, context, NO);
    FTCrashStackCursor stackCursor;

    ftcrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);

    unsigned int entries = 0;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (entries == maxEntries)
            break;
        if (symbolicate == false || stackCursor.symbolicate(&stackCursor)) {
            buffer[entries] = stackCursor.stackEntry;
            entries++;
        }
    }

    return entries;
}
@interface FTThreadInspector()
@property (nonatomic, strong) FTStackTraceBuilder *stackTraceBuilder;
@property (nonatomic, strong) FTCrashDefaultMachineContextWrapper *machineContextWrapper;
@property (nonatomic, assign) BOOL symbolicate;

@end
@implementation FTThreadInspector

- (NSArray<FTThread *> *)getCurrentThreads{
    NSMutableArray<FTThread *> *threads = [NSMutableArray new];
    FTCrashMachineContext context = {0};
    FTCrashThread currentThread = ftcrashthread_self();
    [self.machineContextWrapper fillContextForCurrentThread:&context];
    int threadCount = [self.machineContextWrapper getThreadCount:&context];
    for (int i = 0; i < threadCount; i++) {
        FTCrashThread thread = [self.machineContextWrapper getThread:&context withIndex:i];
        FTThread *ftThread = [[FTThread alloc] initWithThreadId:@(i)];

        ftThread.isMain =
            [NSNumber numberWithBool:[self.machineContextWrapper isMainThread:thread]];
        ftThread.name = [self getThreadName:thread];

        ftThread.crashed = @NO;
        bool isCurrent = thread == currentThread;
        ftThread.current = @(isCurrent);

        if (isCurrent) {
            ftThread.stackTrace = [self.stackTraceBuilder buildStackTraceForCurrentThread];
        }

        // We need to make sure the main thread is always the first thread in the result
        if ([self.machineContextWrapper isMainThread:thread])
            [threads insertObject:ftThread atIndex:0];
        else
            [threads addObject:ftThread];
    }
    
    return threads;
}

- (NSArray<FTThread *> *)getCurrentThreadsWithStackTrace{
    NSMutableArray<FTThread *> *threads = [NSMutableArray new];

    @synchronized(self) {
        FTCrashMachineContext context = {0};
        FTCrashThread currentThread = ftcrashthread_self();

        thread_act_array_t suspendedThreads = NULL;
        mach_msg_type_number_t numSuspendedThreads = 0;

        bool symbolicate = self.symbolicate;

        // SentryThreadInspector is crashing when there is too many threads.
        // We add a limit of 70 threads because in test with up to 100 threads it seems fine.
        // We are giving it an extra safety margin.
        ftcrashmc_suspendEnvironment(
            &suspendedThreads, &numSuspendedThreads);
        // DANGER: Do not try to allocate memory in the heap or call Objective-C code in this
        // section Doing so when the threads are suspended may lead to deadlocks or crashes.

        // If no threads was suspended we don't need to do anything.
        // This may happen if there is more than max amount of threads (70).
        if (numSuspendedThreads == 0) {
            return threads;
        }

        FTThreadInfo threadsInfos[numSuspendedThreads];

        for (int i = 0; i < numSuspendedThreads; i++) {
            if (suspendedThreads[i] != currentThread) {
                int numberOfEntries = getStackEntriesFromThread(suspendedThreads[i], &context,
                    threadsInfos[i].stackEntries, MAX_STACKTRACE_LENGTH, symbolicate);
                threadsInfos[i].stackLength = numberOfEntries;
            } else {
                // We can't use 'getStackEntriesFromThread' to retrieve stack frames from the
                // current thread. We are using the stackTraceBuilder to retrieve this information
                // later.
                threadsInfos[i].stackLength = 0;
            }
            threadsInfos[i].thread = suspendedThreads[i];
        }

        ftcrashmc_resumeEnvironment(&suspendedThreads, &numSuspendedThreads);
        // DANGER END: You may call Objective-C code again or allocate memory.

        for (int i = 0; i < numSuspendedThreads; i++) {
            FTThread *ftThread = [[FTThread alloc] initWithThreadId:@(i)];

            ftThread.isMain = [NSNumber numberWithBool:i == 0];
            ftThread.name = [self getThreadName:threadsInfos[i].thread];

            ftThread.crashed = @NO;
            bool isCurrent = threadsInfos[i].thread == currentThread;
            ftThread.current = @(isCurrent);

            if (isCurrent) {
                ftThread.stackTrace = [self.stackTraceBuilder buildStackTraceForCurrentThread];
            } else {
                ftThread.stackTrace = [self.stackTraceBuilder
                    buildStackTraceFromStackEntries:threadsInfos[i].stackEntries
                                             amount:threadsInfos[i].stackLength];
            }

            // We need to make sure the main thread is always the first thread in the result
            if ([self.machineContextWrapper isMainThread:threadsInfos[i].thread])
                [threads insertObject:ftThread atIndex:0];
            else
                [threads addObject:ftThread];
        }
    }

    return threads;
}
- (nullable NSString *)getThreadName:(FTCrashThread)thread{
    int bufferLength = 128;
    char buffer[bufferLength];
    char *const pBuffer = buffer;

    BOOL didGetThreadNameSucceed = [self.machineContextWrapper getThreadName:thread
                                                                   andBuffer:pBuffer
                                                                andBufLength:bufferLength];

    if (didGetThreadNameSucceed == YES) {
        NSString *threadName = [NSString stringWithCString:pBuffer encoding:NSUTF8StringEncoding];
        if (threadName.length > 0) {
            return threadName;
        }
    }

    return nil;
}
@end
