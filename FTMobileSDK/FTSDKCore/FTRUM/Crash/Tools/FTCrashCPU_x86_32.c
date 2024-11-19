//
//  FTCrashCPU_x86_32.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//
#if defined(__i386__)

#include "FTCrashCPU.h"
#include "FTCrashCPU_Apple.h"
#include "FTCrashMachineContext.h"
#include "FTCrashMachineContext_Apple.h"
#include <stdlib.h>

uintptr_t ftcrashcpu_framePointer(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__ebp; }


uintptr_t ftcrashcpu_instructionAddress(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__eip; }


uintptr_t ftcrashcpu_linkRegister(const FTCrashMachineContext *const context) { return 0; }

void ftcrashcpu_getState(FTCrashMachineContext *context)
{
    thread_t thread = context->thisThread;
    STRUCT_MCONTEXT_L *const machineContext = &context->machineContext;

    ftcrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__ss, x86_THREAD_STATE32, x86_THREAD_STATE32_COUNT);
    ftcrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__es, x86_EXCEPTION_STATE32,
                      x86_EXCEPTION_STATE32_COUNT);
}
uintptr_t ftcrashcpu_normaliseInstructionPointer(uintptr_t ip) { return ip; }


#endif
