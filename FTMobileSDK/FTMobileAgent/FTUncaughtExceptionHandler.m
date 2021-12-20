//
//  FTUncaughtExceptionHandler.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTUncaughtExceptionHandler.h"
#include <execinfo.h>
#import "FTGlobalRumManager.h"
#import <mach-o/ldsyms.h>
#include <mach-o/dyld.h>
#import "FTRUMManager.h"

//NSException错误名称
NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
//signal错误堆栈的条数
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
//错误堆栈信息
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

void HandleException(NSException *exception);

typedef void(*SignalHandler)(int signal, siginfo_t *info, void *context);

static SignalHandler previousABRTSignalHandler = NULL;
static SignalHandler previousBUSSignalHandler = NULL;
static SignalHandler previousFPESignalHandler = NULL;
static SignalHandler previousILLSignalHandler = NULL;
static SignalHandler previousPIPESignalHandler = NULL;
static SignalHandler previousSEGVSignalHandler = NULL;
static SignalHandler previousSYSSignalHandler = NULL;
static SignalHandler previousTRAPSignalHandler = NULL;

static NSUncaughtExceptionHandler *previousUncaughtExceptionHandler;

@interface FTUncaughtExceptionHandler()
@end
@implementation FTUncaughtExceptionHandler

void HandleException(NSException *exception) {
 
    //获取调用堆栈
    NSString *exceptionStack = [[exception callStackSymbols] componentsJoinedByString:@"\n"];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:exceptionStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    //在主线程中，执行制定的方法, withObject是执行方法传入的参数
    [[FTUncaughtExceptionHandler sharedHandler]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:
     [NSException exceptionWithName:@"ios_crash"
                             reason:[exception reason]
                           userInfo:userInfo]
     waitUntilDone:YES];
    
    if (previousUncaughtExceptionHandler) {
        previousUncaughtExceptionHandler(exception);
    }
}
////2.2、signal报错处理
static void FTSignalHandler(int signal, siginfo_t* info, void* context) {
    
    NSString* description = nil;
    NSString *name = @"ios_crash";
    switch (signal) {
        case SIGABRT:
            name = @"abort";
            description = [NSString stringWithFormat:@"Signal SIGABRT was raised!\n"];
            break;
        case SIGILL:
            description = [NSString stringWithFormat:@"Signal SIGILL was raised!\n"];
            break;
        case SIGSEGV:
            description = [NSString stringWithFormat:@"Signal SIGSEGV was raised!\n"];
            break;
        case SIGFPE:
            description = [NSString stringWithFormat:@"Signal SIGFPE was raised!\n"];
            break;
        case SIGBUS:
            description = [NSString stringWithFormat:@"Signal SIGBUS was raised!\n"];
            break;
        case SIGPIPE:
            description = [NSString stringWithFormat:@"Signal SIGPIPE was raised!\n"];
            break;
        default:
            description = [NSString stringWithFormat:@"Signal %d was raised!",signal];
    }
    // 保存崩溃日志
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    NSArray *callStack = [FTUncaughtExceptionHandler backtrace];
    NSString *exceptionStack = [callStack componentsJoinedByString:@"\n"];
    [userInfo setObject:exceptionStack forKey:UncaughtExceptionHandlerAddressesKey];
    [userInfo setObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    @try {
        [[FTUncaughtExceptionHandler sharedHandler]
         performSelectorOnMainThread:@selector(handleException:) withObject:
         [NSException exceptionWithName:name reason:description userInfo:userInfo]
         waitUntilDone:YES];
    } @catch (NSException *exception) {
    }
    
    
    // 调用之前崩溃的回调函数
    // 在自己handler处理完后自觉把别人的handler注册回去，规规矩矩的传递
    previousSignalHandler(signal, info, context);
    
    kill(getpid(), SIGKILL);
}
+ (instancetype)sharedHandler {
    static FTUncaughtExceptionHandler *sharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHandler = [[FTUncaughtExceptionHandler alloc] init];
    });
    return sharedHandler;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        // Install our handler
        [self installUncaughtExceptionHandler];
        [self installSignalHandler];
    }
    return self;
}
- (void)installUncaughtExceptionHandler{
    previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&HandleException);
}
- (void)installSignalHandler{
    struct sigaction old_action_abrt;
    sigaction(SIGABRT, NULL, &old_action_abrt);
    if (old_action_abrt.sa_sigaction) {
        previousABRTSignalHandler = old_action_abrt.sa_sigaction;
    }
    
    struct sigaction old_action_bus;
    sigaction(SIGBUS, NULL, &old_action_bus);
    if (old_action_bus.sa_sigaction) {
        previousBUSSignalHandler = old_action_bus.sa_sigaction;
    }
    
    struct sigaction old_action_fpe;
    sigaction(SIGFPE, NULL, &old_action_fpe);
    if (old_action_fpe.sa_sigaction) {
        previousFPESignalHandler = old_action_fpe.sa_sigaction;
    }
    struct sigaction old_action_ill;
    sigaction(SIGILL, NULL, &old_action_ill);
    if (old_action_ill.sa_sigaction) {
        previousILLSignalHandler = old_action_ill.sa_sigaction;
    }
    
    struct sigaction old_action_pipe;
    sigaction(SIGPIPE, NULL, &old_action_pipe);
    if (old_action_pipe.sa_sigaction) {
        previousPIPESignalHandler = old_action_pipe.sa_sigaction;
    }
    
    struct sigaction old_action_segv;
    sigaction(SIGSEGV, NULL, &old_action_segv);
    if (old_action_segv.sa_sigaction) {
        previousSEGVSignalHandler = old_action_segv.sa_sigaction;
    }
    
    struct sigaction old_action_sys;
    sigaction(SIGSYS, NULL, &old_action_sys);
    if (old_action_sys.sa_sigaction) {
        previousSYSSignalHandler = old_action_sys.sa_sigaction;
    }
    struct sigaction old_action_trap;
    sigaction(SIGTRAP, NULL, &old_action_trap);
    if (old_action_trap.sa_sigaction) {
        previousTRAPSignalHandler = old_action_trap.sa_sigaction;
    }
    struct sigaction action;
    action.sa_sigaction = FTSignalHandler;
    action.sa_flags = SA_NODEFER | SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    int signals[] = {SIGABRT,SIGBUS, SIGFPE, SIGILL, SIGPIPE, SIGSEGV,SIGSYS,SIGTRAP};
    for (int i = 0; i < sizeof(signals) / sizeof(int); i++) {
        sigaction(signals[i], &action, 0);
    }
}
static void FTClearSignalRegister() {
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGTRAP,SIG_DFL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    signal(SIGSYS,SIG_DFL);
}
static void previousSignalHandler(int signal, siginfo_t *info, void *context) {
    SignalHandler previousSignalHandler = NULL;
    switch (signal) {
        case SIGABRT:
            previousSignalHandler = previousABRTSignalHandler;
            break;
        case SIGBUS:
            previousSignalHandler = previousBUSSignalHandler;
            break;
        case SIGFPE:
            previousSignalHandler = previousFPESignalHandler;
            break;
        case SIGILL:
            previousSignalHandler = previousILLSignalHandler;
            break;
        case SIGPIPE:
            previousSignalHandler = previousPIPESignalHandler;
            break;
        case SIGSEGV:
            previousSignalHandler = previousSEGVSignalHandler;
            break;
        case SIGSYS:
            previousSignalHandler = previousSYSSignalHandler;
            break;
        case SIGTRAP:
            previousSignalHandler = previousTRAPSignalHandler;
            break;
        default:
            break;
    }
    
    if (previousSignalHandler) {
        previousSignalHandler(signal, info, context);
    }
}

//med 1、专门针对Signal类型的错误获取堆栈信息
+ (NSArray *)backtrace {
    //指针列表
    void* callstack[128];
    //backtrace用来获取当前线程的调用堆栈，获取的信息存放在这里的callstack中
    //128用来指定当前的buffer中可以保存多少个void*元素
    //返回值是实际获取的指针个数
    int frames = backtrace(callstack, 128);
    //backtrace_symbols将从backtrace函数获取的信息转化为一个字符串数组
    //返回一个指向字符串数组的指针
    //每个字符串包含了一个相对于callstack中对应元素的可打印信息，包括函数名、偏移地址、实际返回地址
    char **strs = backtrace_symbols(callstack, frames);
    
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = 0; i < frames; i++) {
        
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return backtrace;
}

//med 2、所有错误异常处理
- (void)handleException:(NSException *)exception {
    long slide_address = [FTUncaughtExceptionHandler ft_calculateImageSlide];
    NSString *info =[NSString stringWithFormat:@"Slide_Address:%ld\nException Stack:\n%@", slide_address,exception.userInfo[UncaughtExceptionHandlerAddressesKey]];
 
  
    [[FTGlobalRumManager sharedInstance].rumManger addErrorWithType:[exception name] situation:[FTGlobalRumManager sharedInstance].appState message:[exception reason] stack:info];
    NSSetUncaughtExceptionHandler(NULL);
    FTClearSignalRegister();
    
}
+ (long)ft_calculateImageSlide{
    long slide = -1;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i)->filetype == MH_EXECUTE) {
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    return slide;
}
@end
