//
//  FTMachException.c
//  FTMobileSDK
//
//  Created by hulilei on 2023/12/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#include "FTMachException.h"
#include <errno.h>
#include <mach/mach.h>
#include <pthread.h>
#include <unistd.h>
static mach_port_t ft_exceptionPort = MACH_PORT_NULL;

//监听异常端口的主要线程
static pthread_t ft_primaryPThread;
static thread_t ft_primaryMachThread;
static pthread_t ft_secondaryPThread;
static thread_t ft_secondaryMachThread;

static const char* kThreadPrimary = "Exception Handler (Primary)";
static bool ft_isHandlingCrash = false;

static struct
{
    exception_mask_t        masks[EXC_TYPES_COUNT];
    exception_handler_t     ports[EXC_TYPES_COUNT];
    exception_behavior_t    behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t   flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t  count;
} ft_mach_exception_port_set_t;
#pragma pack(4)
typedef struct {
  mach_msg_header_t header;
  /* start of the kernel processed data */
  mach_msg_body_t msgh_body;
  mach_msg_port_descriptor_t thread;
  mach_msg_port_descriptor_t task;
  /* end of the kernel processed data */
  NDR_record_t NDR;
  exception_type_t exception;
  mach_msg_type_number_t codeCnt;
  mach_exception_data_type_t code[EXCEPTION_CODE_MAX];
  mach_msg_trailer_t trailer;
} ft_mach_exception_message;
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
} ft_mach_replay_message;
#pragma pack()

#pragma mark - Recording
void FTMachExceptionNameLookup(exception_type_t number,
                                          mach_exception_data_type_t code,
                                          const char** name,
                                          const char** codeName) {
  if (!name || !codeName) {
    return;
  }

  *name = NULL;
  *codeName = NULL;

  switch (number) {
    case EXC_BAD_ACCESS:
      *name = "EXC_BAD_ACCESS";
      switch (code) {
        case KERN_INVALID_ADDRESS:
          *codeName = "KERN_INVALID_ADDRESS";
          break;
        case KERN_PROTECTION_FAILURE:
          *codeName = "KERN_PROTECTION_FAILURE";
          break;
      }

      break;
    case EXC_BAD_INSTRUCTION:
      *name = "EXC_BAD_INSTRUCTION";
#if CLS_CPU_X86
      *codeName = "EXC_I386_INVOP";
#endif
      break;
    case EXC_ARITHMETIC:
      *name = "EXC_ARITHMETIC";
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
static void restoreExceptionPorts(void){
    if(ft_mach_exception_port_set_t.count == 0){
        return;
    }
    const task_t thisTask = mach_task_self();
    for(mach_msg_type_number_t i = 0; i < ft_mach_exception_port_set_t.count; i++){
        task_set_exception_ports(thisTask,
                                 ft_mach_exception_port_set_t.masks[i],
                                 ft_mach_exception_port_set_t.ports[i],
                                 ft_mach_exception_port_set_t.behaviors[i],
                                 ft_mach_exception_port_set_t.flavors[i]);
        
    }
    ft_mach_exception_port_set_t.count = 0;
}
static void* handleExceptions(void* const userData){
    const char* threadName = (const char*) userData;
    pthread_setname_np(threadName);
    ft_mach_exception_message message = {{0}};
    ft_mach_replay_message replyMessage = {{0}};

    while (1) {
        
        mach_msg_return_t r;
        r = mach_msg(&message.header, MACH_RCV_MSG | MACH_RCV_LARGE, 0, sizeof(ft_mach_exception_message),
                     ft_exceptionPort, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if (r == MACH_MSG_SUCCESS) {
            break;
        }
    }
    thread_t crashThread = (thread_t)message.task.name;
    thread_suspend(crashThread);
    ft_isHandlingCrash = true;
    
    // crash reason:
    
    
    
    ft_isHandlingCrash = false;
    thread_resume(crashThread);
    //重新发送异常信息
    replyMessage.header = message.header;
    replyMessage.NDR = message.NDR;
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

void uninstallMachException(void){
    restoreExceptionPorts();
    thread_t thread_self = mach_thread_self();
    if(ft_primaryPThread != 0 && ft_primaryMachThread != thread_self){
        if(ft_isHandlingCrash){
            thread_terminate(ft_primaryMachThread);
        }else{
            pthread_cancel(ft_primaryPThread);
        }
        ft_primaryMachThread = 0;
        ft_primaryPThread = 0;
    }
    if(ft_secondaryPThread != 0 && ft_secondaryMachThread != thread_self){
        if(ft_isHandlingCrash){
            thread_terminate(ft_secondaryMachThread);
        }else{
            pthread_cancel(ft_secondaryPThread);
        }
        ft_secondaryMachThread = 0;
        ft_secondaryPThread = 0;
    }
    ft_exceptionPort = MACH_PORT_NULL;
}

void installMachException(void){
    bool attributes_created = false;
    pthread_attr_t attr;
    if(pthread_attr_init(&attr) != 0)
        return;
    attributes_created = true;
    kern_return_t kr;
    int error;
    const task_t thisTask = mach_task_self();
    exception_mask_t mask = EXC_MASK_BAD_ACCESS |
    EXC_MASK_BAD_INSTRUCTION |
    EXC_MASK_ARITHMETIC |
    EXC_MASK_SOFTWARE |
    EXC_MASK_BREAKPOINT|
    EXC_GUARD; //EXC_GUARD was added in xnu 13.x (iOS 6.0, Mac OS X 10.9)
    //获取当前异常端口
    kr = task_get_exception_ports(thisTask,
                                  mask,
                                  ft_mach_exception_port_set_t.masks,
                                  &ft_mach_exception_port_set_t.count,
                                  ft_mach_exception_port_set_t.ports,
                                  ft_mach_exception_port_set_t.behaviors,
                                  ft_mach_exception_port_set_t.flavors);
    if(kr != KERN_SUCCESS)
    {
        goto failed;
    }
    
    if(ft_exceptionPort == MACH_PORT_NULL){
        // 分配异常端口并设置接收权限
        kr = mach_port_allocate(thisTask, MACH_PORT_RIGHT_RECEIVE, &ft_exceptionPort);
        if(kr != KERN_SUCCESS){
            goto failed;
        }
        // 设置发送权限
        kr = mach_port_insert_right(thisTask, ft_exceptionPort, ft_exceptionPort, MACH_MSG_TYPE_MAKE_SEND);
        if(kr != KERN_SUCCESS){
            goto failed;
        }
    }
    // 设置为当前异常端口
    kr = task_set_exception_ports(thisTask,
                                  mask,
                                  ft_exceptionPort,
                                  (int)(EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES),
                                  THREAD_STATE_NONE);
    if(kr != KERN_SUCCESS){
        goto failed;
    }
    error = pthread_create(&ft_primaryPThread,
                           &attr,
                           &handleExceptions,
                           (void*)kThreadPrimary);
    if(error != 0)
    {
        goto failed;
    }
    pthread_attr_destroy(&attr);
    ft_primaryMachThread = pthread_mach_thread_np(ft_primaryPThread);
    
    
failed:
    if(attributes_created){
        pthread_attr_destroy(&attr);
    }
    uninstallMachException();
}


