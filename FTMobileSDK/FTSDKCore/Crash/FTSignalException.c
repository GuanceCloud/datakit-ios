//
//  FTSignalException.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTSignalException.h"
#include <signal.h>
#include <stdlib.h>

static FTCrashNotifyCallback g_onCrashNotify;
static stack_t g_signalStack = {0};
static struct sigaction* g_previousSignalHandlers = NULL;
static const int g_fatalSignals[] =
{
    SIGABRT,
    SIGBUS,
    SIGFPE,
    SIGILL,
    SIGPIPE,
    SIGSEGV,
    SIGSYS,
    SIGTRAP,
};
struct signal_name {
    const int signal;
    const char *name;
};

struct signal_code {
    const int signal;
    const int si_code;
    const char *name;
};
static struct signal_name signal_names[] = {
    { SIGILL,   "SIGILL" },
    { SIGTRAP,  "SIGTRAP" },
    { SIGABRT,  "SIGABRT" },
    { SIGFPE,   "SIGFPE" },
    { SIGBUS,   "SIGBUS" },
    { SIGSEGV,  "SIGSEGV" },
    { SIGSYS,   "SIGSYS" },
    { SIGPIPE,  "SIGPIPE" },
    { 0, NULL }
};
static struct signal_code signal_codes[] = {
    /* SIGILL */
    { SIGILL,   ILL_NOOP,       "ILL_NOOP"    },
    { SIGILL,   ILL_ILLOPC,     "ILL_ILLOPC"  },
    { SIGILL,   ILL_ILLTRP,     "ILL_ILLTRP"  },
    { SIGILL,   ILL_PRVOPC,     "ILL_PRVOPC"  },
    { SIGILL,   ILL_ILLOPN,     "ILL_ILLOPN"  },
    { SIGILL,   ILL_ILLADR,     "ILL_ILLADR"  },
    { SIGILL,   ILL_PRVREG,     "ILL_PRVREG"  },
    { SIGILL,   ILL_COPROC,     "ILL_COPROC"  },
    { SIGILL,   ILL_BADSTK,     "ILL_BADSTK"  },
    
    /* SIGFPE */
    { SIGFPE,   FPE_NOOP,       "FPE_NOOP"    },
    { SIGFPE,   FPE_FLTDIV,     "FPE_FLTDIV"  },
    { SIGFPE,   FPE_FLTOVF,     "FPE_FLTOVF"  },
    { SIGFPE,   FPE_FLTUND,     "FPE_FLTUND"  },
    { SIGFPE,   FPE_FLTRES,     "FPE_FLTRES"  },
    { SIGFPE,   FPE_FLTINV,     "FPE_FLTINV"  },
    { SIGFPE,   FPE_FLTSUB,     "FPE_FLTSUB"  },
    { SIGFPE,   FPE_INTDIV,     "FPE_INTDIV"  },
    { SIGFPE,   FPE_INTOVF,     "FPE_INTOVF"  },
    
    /* SIGTRAP */
    { SIGTRAP,  0,              "#0"          },
    { SIGTRAP,  TRAP_BRKPT,     "TRAP_BRKPT"  },
    { SIGTRAP,  TRAP_TRACE,     "TRAP_TRACE"  },
    /* SIGABRT */
    { SIGABRT,  0,              "#0"          },
    /* SIGBUS */
    { SIGBUS,   BUS_NOOP,       "BUS_NOOP"    },
    { SIGBUS,   BUS_ADRALN,     "BUS_ADRALN"  },
    { SIGBUS,   BUS_ADRERR,     "BUS_ADRERR"  },
    { SIGBUS,   BUS_OBJERR,     "BUS_OBJERR"  },
    /* SIGSEGV */
    { SIGSEGV,  SEGV_NOOP,      "SEGV_NOOP"   },
    { SIGSEGV,  SEGV_MAPERR,    "SEGV_MAPERR" },
    { SIGSEGV,  SEGV_ACCERR,    "SEGV_ACCERR" },
    { 0, 0, NULL }
};

const char *ft_async_signal_sigcode (int signal, int si_code) {
    for (int i = 0; signal_codes[i].name != NULL; i++) {
        /* Check for match */
        if (signal_codes[i].signal == signal && signal_codes[i].si_code == si_code)
            return signal_codes[i].name;
    }

    /* No match */
    return NULL;
}

const char *ft_async_signal_signame (int signal) {
    for (int i = 0; signal_names[i].name != NULL; i++) {
        /* Check for match */
        if (signal_names[i].signal == signal)
            return signal_names[i].name;
    }

    /* No match */
    return NULL;
}

static void signalHandler(int signal, siginfo_t* info, void* context) {
    
    _STRUCT_MCONTEXT* sourceContext = ((_STRUCT_UCONTEXT64 *)context)->uc_mcontext64;
//    uintptr_t* callStack = ft_backtrace(sourceContext);
    if (g_onCrashNotify != NULL) {
        thread_t thread_self = mach_thread_self();
//        g_onCrashNotify(thread_self,callStack,"aa");
    }
    
    raise(signal);
}

void installSignalException(const FTCrashNotifyCallback onCrashNotify){
    g_onCrashNotify = onCrashNotify;
    if(g_signalStack.ss_size == 0){
        g_signalStack.ss_size = SIGSTKSZ;
        g_signalStack.ss_sp = malloc(g_signalStack.ss_size);
    }
    
    if(sigaltstack(&g_signalStack, NULL) != 0){
        return;
    }
    const int* signals = g_fatalSignals;
    int fatalSignalsCount = sizeof(&signals)/sizeof(int);

    if(g_previousSignalHandlers == NULL){
        g_previousSignalHandlers = malloc(sizeof(*g_previousSignalHandlers)
                                          * (unsigned)fatalSignalsCount);
    }
    struct sigaction action = {{0}};
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
    action.sa_flags |= SA_64REGSET;
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

void uninstallSignalException(void){
    g_onCrashNotify = NULL;
    const int* signals = g_fatalSignals;

    for(int i = 0; i < sizeof(&signals)/sizeof(int); i++)
    {
        sigaction(signals[i], &g_previousSignalHandlers[i], NULL);
    }
    
    g_signalStack = (stack_t){0};
}

