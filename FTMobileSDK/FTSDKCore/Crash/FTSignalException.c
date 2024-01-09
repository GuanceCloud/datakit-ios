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
#include "FTStackInfo.h"

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
#ifdef _KSCRASH_CONTEXT_64
#define UC_MCONTEXT uc_mcontext64
typedef ucontext64_t SignalUserContext;
#undef _KSCRASH_CONTEXT_64
#else
#define UC_MCONTEXT uc_mcontext
typedef ucontext_t SignalUserContext;
#endif
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

static void signalHandler(int signal, siginfo_t* info, void* signalUserContext) {

    _STRUCT_MCONTEXT* sourceContext = ((SignalUserContext*)signalUserContext)->UC_MCONTEXT;
    _STRUCT_MCONTEXT64 context;
    memcpy(&context, sourceContext, sizeof(context));
    
    int count = 0;
    char name_buf[10];
    const char *name;
    if ((name = ft_async_signal_signame(info->si_signo)) == NULL) {
        snprintf(name_buf, sizeof(name_buf), "#%d", info->si_signo);
        name = name_buf;
    }
    
    /* Fetch the signal code string */
    char code_buf[10];
    const char *code;
    if ((code = ft_async_signal_sigcode(info->si_signo, info->si_code)) == NULL) {
        snprintf(code_buf, sizeof(code_buf), "#%d", info->si_code);
        code = code_buf;
    }

    char reason[50] = "Signal Name:";
    strcat(reason, name);
    strcat(reason, ", Signal Code:");
    strcat(reason, code);
    uintptr_t* callStack = ft_backtrace(&context,&count);
    uintptr_t backtrace[count];
    for(int i = 0; i <= count; i++){
        backtrace[i] = callStack[i];
    }
    if (g_onCrashNotify != NULL) {
        thread_t thread_self = mach_thread_self();
        g_onCrashNotify(thread_self,backtrace,count,reason);
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

void uninstallSignalException(void){
    g_onCrashNotify = NULL;
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
    
    g_signalStack = (stack_t){0};

}

