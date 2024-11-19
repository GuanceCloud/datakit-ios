//
//  FTCrashMachineContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashMachineContext_h
#define FTCrashMachineContext_h

#include <mach/mach.h>
#include <stdbool.h>
#include "FTCrashThread.h"

#ifdef __cplusplus
extern "C" {
#endif


#define FTCrashMC_NEW_CONTEXT(NAME)                                                            \
    char ftcrashmc_##NAME##_storage[ftCrashmc_contextSize()];                              \
    struct FTCrashMachineContext *NAME                                                         \
        = (struct FTCrashMachineContext *)ftcrashmc_##NAME##_storage
struct FTCrashMachineContext;

int ftCrashmc_contextSize(void);

bool ftcrashmc_getContextForThread(
                                   FTCrashThread thread,struct FTCrashMachineContext *destinationContext, bool isCrashedContext);

int ftcrashmc_getThreadCount(const struct FTCrashMachineContext *const context);
bool ftcrashmc_isCrashedContext(const struct FTCrashMachineContext *const context);
bool ftcrashmc_canHaveCPUState(const struct FTCrashMachineContext *const context);
void ftmc_suspendEnvironment(__unused thread_act_array_t *suspendedThreads,
                             __unused mach_msg_type_number_t *numSuspendedThreads);
void ftmc_resumeEnvironment(__unused thread_act_array_t threads, __unused mach_msg_type_number_t numThreads);
FTCrashThread
ftcrashmc_getThreadAtIndex(const struct FTCrashMachineContext *const context, int index);

void ftmc_addReservedThread(FTCrashThread thread);
#ifdef __cplusplus
}
#endif
#endif /* FTCrashMachineContext_h */
