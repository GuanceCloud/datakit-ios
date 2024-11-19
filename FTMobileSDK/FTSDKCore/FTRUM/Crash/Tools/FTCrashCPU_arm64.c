//
//  FTCrashCPU_arm64.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#if defined(__arm64__)
#include "FTCrashCPU.h"
#include "FTCrashCPU_Apple.h"
#include "FTCrashMachineContext.h"
#include "FTCrashMachineContext_Apple.h"
#include <stdlib.h>

#define KSPACStrippingMask_ARM64e 0x0000000fffffffff
uintptr_t ftcrashcpu_framePointer(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__fp; }


uintptr_t ftcrashcpu_instructionAddress(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__pc; }


uintptr_t ftcrashcpu_linkRegister(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__lr; }

void
ftcrashcpu_getState(FTCrashMachineContext *context)
{
    thread_t thread = context->thisThread;
    STRUCT_MCONTEXT_L *const machineContext = &context->machineContext;

    ftcrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__ss, ARM_THREAD_STATE64,
        ARM_THREAD_STATE64_COUNT);
    ftcrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__es, ARM_EXCEPTION_STATE64,
        ARM_EXCEPTION_STATE64_COUNT);
}
uintptr_t ftcrashcpu_normaliseInstructionPointer(uintptr_t ip) { return ip & KSPACStrippingMask_ARM64e; }

#endif
