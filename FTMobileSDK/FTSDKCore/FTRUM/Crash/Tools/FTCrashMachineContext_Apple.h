//
//  FTCrashMachineContext_Apple.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashMachineContext_Apple_h
#define FTCrashMachineContext_Apple_h
#ifdef __cplusplus
extern "C" {
#endif

#include <mach/mach_types.h>
#include <stdbool.h>
#include <sys/ucontext.h>

#ifdef __arm64__
#    define STRUCT_MCONTEXT_L _STRUCT_MCONTEXT64
#else
#    define STRUCT_MCONTEXT_L _STRUCT_MCONTEXT
#endif

typedef struct FTCrashMachineContext {
    thread_t thisThread;
    thread_t allThreads[100];
    int threadCount;
    bool isCrashedContext;
    bool isCurrentThread;
    bool isStackOverflow;
    bool isSignalContext;
    STRUCT_MCONTEXT_L machineContext;
} FTCrashMachineContext;

#ifdef __cplusplus
}
#endif

#endif /* FTCrashMachineContext_Apple_h */
