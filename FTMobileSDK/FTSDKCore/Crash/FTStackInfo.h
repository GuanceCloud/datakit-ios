//
//  FTStackInfo.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/8.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTStackInfo_h
#define FTStackInfo_h

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stdbool.h>
#include <mach/mach.h>
#include <dlfcn.h>

#ifdef __LP64__
#define TRACE_FMT         "%-4d%-31s 0x%016lx %s + %lu"
#define POINTER_FMT       "0x%016lx"
#define POINTER_SHORT_FMT "0x%lx"
#define FT_NLIST struct nlist_64
#else
#define TRACE_FMT         "%-4d%-31s 0x%08lx %s + %lu"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#define FT_NLIST struct nlist
#endif
#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

typedef void (*FTCrashNotifyCallback)(thread_t thread,uintptr_t*   backtrace,int count, const char *  crashMessage);

typedef struct FTStackFrameEntry{
    const struct FTStackFrameEntry *const previous;///前一个栈帧地址
    const uintptr_t return_address;///栈帧的函数返回地址
} FTStackFrameEntry;

typedef struct FTMachoImage {
        const char *name;  /** The binary image's name/path. */
        uint64_t loadAddress;
        uint64_t loadEndAddress;
        uint8_t    uuid[16];
        int cpuType;
        int cpuSubType;
} FTMachoImage;
uintptr_t ft_faultAddress(mcontext_t const machineContext);
uintptr_t ft_mach_instructionAddress(mcontext_t const machineContext);
bool ft_fillThreadStateIntoMachineContext(thread_t thread, _STRUCT_MCONTEXT *machineContext);

void ft_backtrace(mcontext_t const machineContext,uintptr_t *backtrace,int* count);

void ft_symbolicate(const uintptr_t* const backtraceBuffer,
                    Dl_info* const symbolsBuffer,
                    const int numEntries,
                    const int skippedEntries,
                    FTMachoImage* const binaryImages);
#ifdef __cplusplus
}
#endif
#endif /* FTStackInfo_h */
