//
//  FTMachException.c
//  FTMobileSDK
//
//  Created by hulilei on 2023/12/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#include "FTMachException.h"
#include "FTSDKCompat.h"
#if FT_HAS_MACH
#include <stdio.h>
#include <stdbool.h>
#include <errno.h>
#include <mach/mach.h>
#include <pthread.h>
#include <sys/sysctl.h>
#include <unistd.h>

#if __LP64__
#define MACH_ERROR_CODE_MASK 0xFFFFFFFFFFFFFFFF
#else
#define MACH_ERROR_CODE_MASK 0xFFFFFFFF
#endif
static FTCrashNotifyCallback g_onCrashNotify;

static mach_port_t g_exceptionPort = MACH_PORT_NULL;

//监听异常端口的主要线程
static pthread_t g_primaryPThread;
static thread_t g_primaryMachThread;

static pthread_t g_secondaryPThread;
static thread_t g_secondaryMachThread;

static const char* kThreadPrimary = "Exception Handler (Primary)";
static const char* kThreadSecondary = "Exception Handler (Secondary)";

static bool g_isHandlingCrash = false;

static struct
{
    exception_mask_t        masks[EXC_TYPES_COUNT];
    exception_handler_t     ports[EXC_TYPES_COUNT];
    exception_behavior_t    behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t   flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t  count;
} g_previousExceptionPorts;
#pragma pack(4)
typedef struct
{
    /** Mach header. */
    mach_msg_header_t          header;

    // Start of the kernel processed data.

    /** Basic message body data. */
    mach_msg_body_t            body;
    
    /** The thread that raised the exception. */
    mach_msg_port_descriptor_t thread;
    
    /** The task that raised the exception. */
    mach_msg_port_descriptor_t task;
    
    // End of the kernel processed data.
    
    /** Network Data Representation. */
    NDR_record_t               NDR;
    
    /** The exception that was raised. */
    exception_type_t           exception;
    
    /** The number of codes. */
    mach_msg_type_number_t     codeCount;
    
    /** Exception code and subcode. */
    // ux_exception.c defines this as mach_exception_data_t for some reason.
    // But it's not actually a pointer; it's an embedded array.
    // On 32-bit systems, only the lower 32 bits of the code and subcode
    // are valid.
    mach_exception_data_type_t code[0];
    
    /** Padding to avoid RCV_TOO_LARGE. */
    char                       padding[512];
} MachExceptionMessage;
#pragma pack()

#pragma pack(4)
typedef struct
{
    /** Mach header. */
    mach_msg_header_t header;
    
    /** Network Data Representation. */
    NDR_record_t      NDR;
    
    /** Return code. */
    kern_return_t     returnCode;
} MachReplyMessage;
#pragma pack()

#pragma mark - Recording

#define EXC_UNIX_BAD_SYSCALL 0x10000 /* SIGSYS */
#define EXC_UNIX_BAD_PIPE    0x10001 /* SIGPIPE */
#define EXC_UNIX_ABORT       0x10002 /* SIGABRT */

static void FTMachExceptionNameLookup(exception_type_t exception,
                               mach_exception_data_type_t code,
                               const char** name,
                               const char** codeName,
                               const char** signalName
                               ) {
    if (!name || !codeName) {
        return;
    }
    *name = NULL;
    *codeName = NULL;
    *signalName = NULL;
    switch (exception) {
        case EXC_BAD_ACCESS:
            *name = "EXC_BAD_ACCESS";
            switch (code) {
                case KERN_INVALID_ADDRESS:
                    *codeName = "KERN_INVALID_ADDRESS";
                    *signalName = "SIGSEGV";
                    break;
                case KERN_PROTECTION_FAILURE:
                    *codeName = "KERN_PROTECTION_FAILURE";
                    *signalName = "SIGBUS";
                    break;
            }
            
            break;
        case EXC_BAD_INSTRUCTION:
            *name = "EXC_BAD_INSTRUCTION";
            *signalName = "SIGFPE";
#if CLS_CPU_X86
            *codeName = "EXC_I386_INVOP";
#endif
            break;
        case EXC_EMULATION:
            *name = "EXC_EMULATION";
            *signalName = "SIGEMT";
            break;
        case EXC_SOFTWARE:
            *name = "EXC_SOFTWARE";
            switch (code)
            {
                case EXC_UNIX_BAD_SYSCALL:
                    *codeName = "EXC_UNIX_BAD_SYSCALL";
                    *signalName = "SIGSYS";
                    break;
                case EXC_UNIX_BAD_PIPE:
                    *codeName = "EXC_UNIX_BAD_PIPE";
                    *signalName = "SIGPIPE";
                    break;
                case EXC_UNIX_ABORT:
                    *codeName = "EXC_UNIX_ABORT";
                    *signalName = "SIGABRT";
                    break;
                case EXC_SOFT_SIGNAL:
                    *codeName = "EXC_SOFT_SIGNAL";
                    *signalName = "SIGKILL";
                    break;
            }
            break;
        case EXC_ARITHMETIC:
            *name = "EXC_ARITHMETIC";
            *signalName = "SIGFPE";
#if CLS_CPU_X86
            switch (code) {
                case EXC_I386_DIV:
                    *codeName = "EXC_I386_DIV";
                    break;
                case EXC_I386_INTO:
                    *codeName = "EXC_I386_INTO";
                    break;
                case EXC_I386_NOEXT:
                    *codeName = "EXC_I386_NOEXT";
                    break;
                case EXC_I386_EXTOVR:
                    *codeName = "EXC_I386_EXTOVR";
                    break;
                case EXC_I386_EXTERR:
                    *codeName = "EXC_I386_EXTERR";
                    break;
                case EXC_I386_EMERR:
                    *codeName = "EXC_I386_EMERR";
                    break;
                case EXC_I386_BOUND:
                    *codeName = "EXC_I386_BOUND";
                    break;
                case EXC_I386_SSEEXTERR:
                    *codeName = "EXC_I386_SSEEXTERR";
                    break;
            }
#endif
            break;
        case EXC_BREAKPOINT:
            *name = "EXC_BREAKPOINT";
            *signalName = "SIGTRAP";
#if CLS_CPU_X86
            switch (code) {
                case EXC_I386_DIVERR:
                    *codeName = "EXC_I386_DIVERR";
                    break;
                case EXC_I386_SGLSTP:
                    *codeName = "EXC_I386_SGLSTP";
                    break;
                case EXC_I386_NMIFLT:
                    *codeName = "EXC_I386_NMIFLT";
                    break;
                case EXC_I386_BPTFLT:
                    *codeName = "EXC_I386_BPTFLT";
                    break;
                case EXC_I386_INTOFLT:
                    *codeName = "EXC_I386_INTOFLT";
                    break;
                case EXC_I386_BOUNDFLT:
                    *codeName = "EXC_I386_BOUNDFLT";
                    break;
                case EXC_I386_INVOPFLT:
                    *codeName = "EXC_I386_INVOPFLT";
                    break;
                case EXC_I386_NOEXTFLT:
                    *codeName = "EXC_I386_NOEXTFLT";
                    break;
                case EXC_I386_EXTOVRFLT:
                    *codeName = "EXC_I386_EXTOVRFLT";
                    break;
                case EXC_I386_INVTSSFLT:
                    *codeName = "EXC_I386_INVTSSFLT";
                    break;
                case EXC_I386_SEGNPFLT:
                    *codeName = "EXC_I386_SEGNPFLT";
                    break;
                case EXC_I386_STKFLT:
                    *codeName = "EXC_I386_STKFLT";
                    break;
                case EXC_I386_GPFLT:
                    *codeName = "EXC_I386_GPFLT";
                    break;
                case EXC_I386_PGFLT:
                    *codeName = "EXC_I386_PGFLT";
                    break;
                case EXC_I386_EXTERRFLT:
                    *codeName = "EXC_I386_EXTERRFLT";
                    break;
                case EXC_I386_ALIGNFLT:
                    *codeName = "EXC_I386_ALIGNFLT";
                    break;
                case EXC_I386_ENDPERR:
                    *codeName = "EXC_I386_ENDPERR";
                    break;
                case EXC_I386_ENOEXTFLT:
                    *codeName = "EXC_I386_ENOEXTFLT";
                    break;
            }
#endif
            break;
        case EXC_GUARD:
            *name = "EXC_GUARD";
            break;
    }
}
static bool ftdebug_isBeingTraced(void)
{
    struct kinfo_proc procInfo;
    size_t structSize = sizeof(procInfo);
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    
    if(sysctl(mib, sizeof(mib)/sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0)
    {
        return false;
    }
    
    return (procInfo.kp_proc.p_flag & P_TRACED) != 0;
}
static void restoreExceptionPorts(void)
{
    if(g_previousExceptionPorts.count == 0)
    {
        return;
    }
    
    const task_t thisTask = mach_task_self();
    kern_return_t kr;
    
    // Reinstall old exception ports.
    for(mach_msg_type_number_t i = 0; i < g_previousExceptionPorts.count; i++)
    {
        kr = task_set_exception_ports(thisTask,
                                      g_previousExceptionPorts.masks[i],
                                      g_previousExceptionPorts.ports[i],
                                      g_previousExceptionPorts.behaviors[i],
                                      g_previousExceptionPorts.flavors[i]);
        if (kr != KERN_SUCCESS) {
        }
    }
    g_previousExceptionPorts.count = 0;
}

#pragma mark ========== Handler ==========
static void* handleExceptions(void* const userData){
    
    MachExceptionMessage exceptionMessage = {{0}};
    MachReplyMessage replyMessage = {{0}};
    
    const char* threadName = (const char*) userData;
    pthread_setname_np(threadName);
    if(threadName == kThreadSecondary)
    {
        thread_suspend((thread_t)mach_thread_self());
    }
    for(;;){
        kern_return_t kr = mach_msg(&exceptionMessage.header,
                                    MACH_RCV_MSG,
                                    0,
                                    sizeof(exceptionMessage),
                                    g_exceptionPort,
                                    MACH_MSG_TIMEOUT_NONE,
                                    MACH_PORT_NULL);
        if (kr == KERN_SUCCESS) {
            break;
        }
    }
    if (g_onCrashNotify != NULL) {
        g_isHandlingCrash = true;
        
        if(mach_thread_self() == g_primaryMachThread)
        {
            restoreExceptionPorts();
            thread_resume(g_secondaryMachThread);
        }
        thread_t crashThread = exceptionMessage.thread.name;
        thread_suspend(crashThread);

        _STRUCT_MCONTEXT machineContext;
        if(ft_fillThreadStateIntoMachineContext(crashThread, &machineContext)) {
            const char *machExceptionName = NULL;
            const char *machExceptionCodeName = NULL;
            const char *signalName = NULL;
            exception_type_t code = exceptionMessage.exception;
            exception_type_t subcode =(exception_type_t)( exceptionMessage.code[0] & (int64_t)MACH_ERROR_CODE_MASK);
            FTMachExceptionNameLookup(code, subcode, &machExceptionName, &machExceptionCodeName,&signalName);
            uintptr_t faultAddress;
            if(code == EXC_BAD_ACCESS){
                faultAddress = ft_faultAddress(&machineContext);
            }else{
                faultAddress = ft_mach_instructionAddress(&machineContext);
            }
            char reason[200];
            snprintf(reason,sizeof(reason),"Exception Type: %s (%s)\n Exception Codes: %s at 0x%016lx", machExceptionName,signalName,machExceptionCodeName,faultAddress);
            int count = 0;
            uintptr_t backtrace[50] ;
            ft_backtrace(&machineContext,backtrace,&count);
            g_onCrashNotify(crashThread,backtrace,count,reason);
        }
        g_isHandlingCrash = false;
        thread_resume(crashThread);
    }
    
    // Send a reply saying "I didn't handle this exception".
    replyMessage.header = exceptionMessage.header;
    replyMessage.NDR = exceptionMessage.NDR;
    replyMessage.returnCode = KERN_FAILURE;
    
    mach_msg(&replyMessage.header,
             MACH_SEND_MSG,
             sizeof(replyMessage),
             0,
             MACH_PORT_NULL,
             MACH_MSG_TIMEOUT_NONE,
             MACH_PORT_NULL);
    
    return NULL;
}
#pragma mark ========== API ==========
static void uninstallMachException(void){
    // NOTE: Do not deallocate the exception port. If a secondary crash occurs
    // it will hang the process.
    
    restoreExceptionPorts();
    
    thread_t thread_self = (thread_t)mach_thread_self();
    
    if(g_primaryPThread != 0 && g_primaryMachThread != thread_self)
    {
        if(g_isHandlingCrash)
        {
            thread_terminate(g_primaryMachThread);
        }
        else
        {
            pthread_cancel(g_primaryPThread);
        }
        g_primaryMachThread = 0;
        g_primaryPThread = 0;
    }
    if(g_secondaryPThread != 0 && g_secondaryMachThread != thread_self)
    {
        if(g_isHandlingCrash)
        {
            thread_terminate(g_secondaryMachThread);
        }
        else
        {
            pthread_cancel(g_secondaryPThread);
        }
        g_secondaryMachThread = 0;
        g_secondaryPThread = 0;
    }
    
    g_exceptionPort = MACH_PORT_NULL;
}

static bool installMachException(void){
    bool attributes_created = false;
    pthread_attr_t attr;
    kern_return_t kr;
    int error;
    const task_t thisTask = mach_task_self();
    exception_mask_t mask = EXC_MASK_BAD_ACCESS |
    EXC_MASK_BAD_INSTRUCTION |
    EXC_MASK_ARITHMETIC |
    EXC_MASK_SOFTWARE |
    EXC_MASK_BREAKPOINT;
    
    kr = task_get_exception_ports(thisTask,
                                  mask,
                                  g_previousExceptionPorts.masks,
                                  &g_previousExceptionPorts.count,
                                  g_previousExceptionPorts.ports,
                                  g_previousExceptionPorts.behaviors,
                                  g_previousExceptionPorts.flavors);
    if(kr != KERN_SUCCESS)
    {
        goto failed;
    }
    
    if(g_exceptionPort == MACH_PORT_NULL)
    {
        kr = mach_port_allocate(thisTask,
                                MACH_PORT_RIGHT_RECEIVE,
                                &g_exceptionPort);
        if(kr != KERN_SUCCESS)
        {
            goto failed;
        }
        
        kr = mach_port_insert_right(thisTask,
                                    g_exceptionPort,
                                    g_exceptionPort,
                                    MACH_MSG_TYPE_MAKE_SEND);
        if(kr != KERN_SUCCESS)
        {
            goto failed;
        }
    }
    kr = task_set_exception_ports(thisTask,
                                  mask,
                                  g_exceptionPort,
                                  (int)(EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES),
                                  THREAD_STATE_NONE);
    if(kr != KERN_SUCCESS)
    {
        goto failed;
    }
    pthread_attr_init(&attr);
    attributes_created = true;
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    error = pthread_create(&g_secondaryPThread,
                           &attr,
                           &handleExceptions,
                           (void*)kThreadSecondary);
    if(error != 0)
    {
        goto failed;
    }
    g_secondaryMachThread = pthread_mach_thread_np(g_secondaryPThread);

    error = pthread_create(&g_primaryPThread,
                           &attr,
                           &handleExceptions,
                           (void*)kThreadPrimary);
    if(error != 0)
    {
        goto failed;
    }
    pthread_attr_destroy(&attr);
    g_primaryMachThread = pthread_mach_thread_np(g_primaryPThread);

    return true;

failed:
    if(attributes_created)
    {
        pthread_attr_destroy(&attr);
    }
    uninstallMachException();
    return false;
}
#endif

void FTUninstallMachException(void){
#if FT_HAS_MACH
    if(ftdebug_isBeingTraced()){
        return;
    }
    uninstallMachException();
#endif
}
void FTInstallMachException(const FTCrashNotifyCallback onCrashNotify){
#if FT_HAS_MACH
    if(ftdebug_isBeingTraced()){
        return;
    }
    g_onCrashNotify = onCrashNotify;
    installMachException();
#endif
}
