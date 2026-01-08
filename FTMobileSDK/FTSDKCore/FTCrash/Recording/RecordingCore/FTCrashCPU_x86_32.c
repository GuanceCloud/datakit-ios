//
//  FTCrashCPU_x86_32.c
//
//  Created by Karl Stenerud on 2012-01-29.
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
#if defined(__i386__)

#include "FTCrashCPU.h"
#include "FTCrashCPU_Apple.h"
#include "FTCrashMachineContext.h"
#include "FTCrashMachineContext_Apple.h"
#include <stdlib.h>

#include "FTCrashLogger.h"

static const char *g_registerNames[] = {
    "eax", "ebx", "ecx", "edx", "edi", "esi", "ebp", "esp", "ss", "eflags", "eip", "cs", "ds", "es", "fs", "gs",
};
static const int g_registerNamesCount = sizeof(g_registerNames) / sizeof(*g_registerNames);

static const char *g_exceptionRegisterNames[] = { "trapno", "err", "faultvaddr" };
static const int g_exceptionRegisterNamesCount = sizeof(g_exceptionRegisterNames) / sizeof(*g_exceptionRegisterNames);

uintptr_t ftcrashcpu_framePointer(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__ebp; }

uintptr_t ftcrashcpu_stackPointer(const FTCrashMachineContext *const context) { return context->machineContext.__ss.__esp; }

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

int ftcrashcpu_numRegisters(void) { return g_registerNamesCount; }

const char *ftcrashcpu_registerName(const int regNumber)
{
    if (regNumber < ftcrashcpu_numRegisters()) {
        return g_registerNames[regNumber];
    }
    return NULL;
}

uint64_t ftcrashcpu_registerValue(const FTCrashMachineContext *const context, const int regNumber)
{
    switch (regNumber) {
        case 0:
            return context->machineContext.__ss.__eax;
        case 1:
            return context->machineContext.__ss.__ebx;
        case 2:
            return context->machineContext.__ss.__ecx;
        case 3:
            return context->machineContext.__ss.__edx;
        case 4:
            return context->machineContext.__ss.__edi;
        case 5:
            return context->machineContext.__ss.__esi;
        case 6:
            return context->machineContext.__ss.__ebp;
        case 7:
            return context->machineContext.__ss.__esp;
        case 8:
            return context->machineContext.__ss.__ss;
        case 9:
            return context->machineContext.__ss.__eflags;
        case 10:
            return context->machineContext.__ss.__eip;
        case 11:
            return context->machineContext.__ss.__cs;
        case 12:
            return context->machineContext.__ss.__ds;
        case 13:
            return context->machineContext.__ss.__es;
        case 14:
            return context->machineContext.__ss.__fs;
        case 15:
            return context->machineContext.__ss.__gs;
        default:
            FTLOG_ERROR("Invalid register number: %d", regNumber);
            return 0;
    }
}

int ftcrashcpu_numExceptionRegisters(void) { return g_exceptionRegisterNamesCount; }

const char *ftcrashcpu_exceptionRegisterName(const int regNumber)
{
    if (regNumber < ftcrashcpu_numExceptionRegisters()) {
        return g_exceptionRegisterNames[regNumber];
    }
    FTLOG_ERROR("Invalid register number: %d", regNumber);
    return NULL;
}

uint64_t ftcrashcpu_exceptionRegisterValue(const FTCrashMachineContext *const context, const int regNumber)
{
    switch (regNumber) {
        case 0:
            return context->machineContext.__es.__trapno;
        case 1:
            return context->machineContext.__es.__err;
        case 2:
            return context->machineContext.__es.__faultvaddr;
        default:
            FTLOG_ERROR("Invalid register number: %d", regNumber);
            return 0;
    }
}

uintptr_t ftcrashcpu_faultAddress(const FTCrashMachineContext *const context)
{
    return context->machineContext.__es.__faultvaddr;
}

int ftcrashcpu_stackGrowDirection(void) { return -1; }
uintptr_t ftcrashcpu_normaliseInstructionPointer(uintptr_t ip) { return ip; }


#endif
