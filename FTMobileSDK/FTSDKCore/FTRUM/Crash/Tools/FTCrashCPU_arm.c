//
//  FTCrashCPU_arm.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#if defined(__arm__)

#include "FTCrashCPU.h"
#include "FTCrashCPU_Apple.h"
#include "FTCrashMachineContext.h"
#include "FTCrashMachineContext_Apple.h"
#include <stdlib.h>

uintptr_t ftcrashcpu_framePointer(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__r[7]; }

uintptr_t ftcrashcpu_instructionAddress(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__pc; }


uintptr_t ftcrashcpu_linkRegister(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__lr; }

void
ftcrashcpu_getState(FTCrashMachineContext *context)
{
    thread_t thread = context->thisThread;
    STRUCT_MCONTEXT_L *const machineContext = &context->machineContext;

    ftcrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__ss, ARM_THREAD_STATE,
                           ARM_THREAD_STATE_COUNT);
    ftcrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__es, ARM_EXCEPTION_STATE,
                           ARM_EXCEPTION_STATE_COUNT);
}
uintptr_t ftcrashcpu_normaliseInstructionPointer(uintptr_t ip) { return ip; }

#endif
