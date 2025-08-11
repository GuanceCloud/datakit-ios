//
//  FTSignalException.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTSignalException.h"
#include <stdio.h>
#include <mach/mach.h>
#include <signal.h>
#include <stdlib.h>
#include "FTStackInfo.h"
#include <string.h>
#include "FTSDKCompat.h"
#include <os/log.h>
#include <QuartzCore/QuartzCore.h>
#include "FTCrashLogger.h"
#include "FTCrashMonitor.h"
//static volatile bool g_isEnabled = false;

#if FT_HAS_SIGNAL_STACK
static stack_t g_signalStack = {0};
#endif
static struct sigaction* g_previousSignalHandlers = NULL;
 
#ifdef __arm64__
#include <sys/_types/_ucontext64.h>
typedef ucontext64_t SignalUserContext;
#define UC_MCONTEXT uc_mcontext64
#else
typedef ucontext_t SignalUserContext;
#define UC_MCONTEXT uc_mcontext
#endif

void FTSignalMachExceptionNameLookup(int sigNum,
                                     int sigCode,
                                     const char** machType,
                                     const char** signalName,
                                     const char** signalCodeName) {
    *machType = NULL;
    *signalName = NULL;
    *signalCodeName = NULL;
    switch(sigNum)
    {
        case SIGFPE:
            *machType = "EXC_ARITHMETIC";
            *signalName = "SIGFPE";
            switch (sigCode) {
                case FPE_NOOP:
                    *signalCodeName = "FPE_NOOP";
                    break;
                case FPE_FLTDIV:
                    *signalCodeName = "FPE_FLTDIV";
                    break;
                case FPE_FLTOVF:
                    *signalCodeName = "FPE_FLTOVF";
                    break;
                case FPE_FLTUND:
                    *signalCodeName = "FPE_FLTUND";
                    break;
                case FPE_FLTRES:
                    *signalCodeName = "FPE_FLTRES";
                    break;
                case FPE_FLTINV:
                    *signalCodeName = "FPE_FLTINV";
                    break;
                case FPE_FLTSUB:
                    *signalCodeName = "FPE_FLTSUB";
                    break;
                case FPE_INTDIV:
                    *signalCodeName = "FPE_INTDIV";
                    break;
                case FPE_INTOVF:
                    *signalCodeName = "FPE_INTOVF";
                    break;
                default:
                    break;
            }
            break;
        case SIGSEGV:
            *machType = "EXC_BAD_ACCESS";
            *signalName = "SIGSEGV";
            switch (sigCode) {
                case SEGV_NOOP:
                    *signalCodeName = "SEGV_NOOP";
                    break;
                case SEGV_MAPERR:
                    *signalCodeName = "SEGV_MAPERR";
                    break;
                case SEGV_ACCERR:
                    *signalCodeName = "SEGV_ACCERR";
                    break;
                default:
                    break;
            }
            break;
      
        case SIGBUS:
            *machType = "EXC_BAD_ACCESS";
            *signalName = "SIGBUS";
            switch (sigCode) {
                case BUS_NOOP:
                    *signalCodeName = "BUS_NOOP";
                    break;
                case BUS_ADRALN:
                    *signalCodeName = "BUS_ADRALN";
                    break;
                case BUS_ADRERR:
                    *signalCodeName = "BUS_ADRERR";
                    break;
                case BUS_OBJERR:
                    *signalName = "BUS_OBJERR";
                    break;
                default:
                    break;
            }
            break;
        case SIGILL:
            *machType = "EXC_BAD_INSTRUCTION";
            *signalName = "SIGILL";
            switch (sigCode) {
                case ILL_NOOP:
                    *signalCodeName = "ILL_NOOP";
                    break;
                case ILL_ILLOPC:
                    *signalCodeName = "ILL_ILLOPC";
                    break;
                case ILL_ILLTRP:
                    *signalCodeName = "ILL_ILLTRP";
                    break;
                case ILL_PRVOPC:
                    *signalCodeName = "ILL_PRVOPC";
                    break;
                case ILL_ILLOPN:
                    *signalCodeName = "ILL_ILLOPN";
                    break;
                case ILL_ILLADR:
                    *signalCodeName = "ILL_ILLADR";
                    break;
                case ILL_PRVREG:
                    *signalCodeName = "ILL_PRVREG";
                    break;
                case ILL_COPROC:
                    *signalCodeName = "ILL_COPROC";
                    break;
                case ILL_BADSTK:
                    *signalCodeName = "ILL_BADSTK";
                    break;
                default:
                    break;
            }
            break;
      
        case SIGTRAP:
            *machType = "EXC_BREAKPOINT";
            *signalName = "SIGTRAP";
            switch (sigCode) {
                case TRAP_BRKPT:
                    *signalCodeName = "TRAP_BRKPT";
                    break;
                case TRAP_TRACE:
                    *signalCodeName = "TRAP_TRACE";
                    break;
                default:
                    break;
            }
            break;
        case SIGSYS:
            *machType = "EXC_UNIX_BAD_SYSCALL";
            *signalName = "SIGSYS";
            *signalCodeName = "0";
            break;
        case SIGPIPE:
            *machType = "EXC_UNIX_BAD_PIPE";
            *signalName = "SIGPIPE";
            break;
        case SIGABRT:
            // The Apple reporter uses EXC_CRASH instead of EXC_UNIX_ABORT
            *machType = "EXC_CRASH";
            *signalName = "SIGABRT";
            *signalCodeName = "0";
            break;
    }
}
#pragma mark ========== Handler ==========
static void signalHandler(int signal, siginfo_t* info, void* signalUserContext) {
    FTLOG_INFO("Fatal signal(%d) raised.",signal);
    if (!ftcm_setCrashHandling(true)) {
        _STRUCT_MCONTEXT* sourceContext = ((SignalUserContext*)signalUserContext)->UC_MCONTEXT;
        _STRUCT_MCONTEXT context;
        memcpy(&context, sourceContext, sizeof(context));
       
        uintptr_t faultAddress = (uintptr_t)info->si_addr;
        char reason[200];
        const char *machExceptionName = NULL;
        const char *signalName = NULL;
        const char *signalCodeName = NULL;
        FTSignalMachExceptionNameLookup(info->si_signo,
                                        info->si_code,
                                        &machExceptionName,
                                        &signalName,
                                        &signalCodeName
                                        );
        snprintf(reason,sizeof(reason),"Exception Type: %s (%s)\n Signal Codes: %s at 0x%016lx", machExceptionName,signalName,signalCodeName,faultAddress);
        int count = 0;
        uintptr_t callStack[50] ;
        ft_backtrace(&context,callStack,&count);
        FTThread thread_self = ftthread_self();
        ftcm_handleException(thread_self,callStack,count,reason);
        raise(signal);
    }else{
        FTLOG_INFO("‌An unhandled crash occurred, and it might be a second crash or signal.");
    }
}
#pragma mark ========== API ==========
void FTInstallSignalException(void){
#if FT_HAS_SIGNAL_STACK
    if(g_signalStack.ss_size == 0){
        g_signalStack.ss_size = SIGSTKSZ;
        g_signalStack.ss_sp = malloc(g_signalStack.ss_size);
    }
    if(sigaltstack(&g_signalStack, NULL) != 0){
        return;
    }
#endif
    int signals[] = {
        SIGABRT,
        SIGBUS,
        SIGFPE,
        SIGILL,
        SIGPIPE,
        SIGSEGV,
        SIGSYS,
        SIGTRAP,
    };
    int fatalSignalsCount = sizeof(signals)/sizeof(int);

    if(g_previousSignalHandlers == NULL){
        g_previousSignalHandlers = malloc(sizeof(*g_previousSignalHandlers)
                                          * (unsigned)fatalSignalsCount);
    }
    struct sigaction action = {{0}};
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#if defined(__LP64__)
    action.sa_flags |= SA_64REGSET;
#endif
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = &signalHandler;
    for(int i = 0; i < fatalSignalsCount; i++){
        if(sigaction(signals[i], &action, &g_previousSignalHandlers[i]) != 0){
            // Try to reverse the damage
            for(i--;i >= 0; i--){
                sigaction(signals[i], &g_previousSignalHandlers[i], NULL);
            }
            break;
        }
    }
}

void FTUninstallSignalException(void){
    int signals[] = {
        SIGABRT,
        SIGBUS,
        SIGFPE,
        SIGILL,
        SIGPIPE,
        SIGSEGV,
        SIGSYS,
        SIGTRAP,
    };
    int fatalSignalsCount = sizeof(signals)/sizeof(int);

    for(int i = 0; i < fatalSignalsCount; i++)
    {
        sigaction(signals[i], &g_previousSignalHandlers[i], NULL);
    }
#if FT_HAS_SIGNAL_STACK
    g_signalStack = (stack_t){0};
#endif
}

