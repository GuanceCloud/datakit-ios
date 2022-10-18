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
#import <mach-o/ldsyms.h>
#include <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/arch.h>
#import <sys/utsname.h>
#import "FTCallStack.h"
#import <os/log.h>
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
@property (nonatomic, strong) NSHashTable *ftSDKInstances;
@end
@implementation FTUncaughtExceptionHandler

void HandleException(NSException *exception) {
    
    //获取调用堆栈
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:[exception callStackSymbols] forKey:UncaughtExceptionHandlerAddressesKey];
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
    [userInfo setObject:[NSThread callStackSymbols] forKey:UncaughtExceptionHandlerAddressesKey];
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
        _ftSDKInstances = [NSHashTable weakObjectsHashTable];
        // Install our handler
        [self installUncaughtExceptionHandler];
        [self installSignalHandler];
    }
    return self;
}
- (void)addftSDKInstance:(id <FTErrorDataDelegate>)instance{
    NSParameterAssert(instance != nil);
    if (![self.ftSDKInstances containsObject:instance]) {
        [self.ftSDKInstances addObject:instance];
    }
}
- (void)removeftSDKInstance:(id <FTErrorDataDelegate>)instance{
    NSParameterAssert(instance != nil);
    if ([self.ftSDKInstances containsObject:instance]) {
        [self.ftSDKInstances removeObject:instance];
    }
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

//med 2、所有错误异常处理
- (void)handleException:(NSException *)exception {
    NSString *info = [self handleExceptionInfo:exception];
    for (id instance in self.ftSDKInstances) {
        if ([instance respondsToSelector:@selector(addErrorWithType:message:stack:)]) {
            [instance addErrorWithType:[exception name] message:[exception reason] stack:info];
        }
    }
    NSSetUncaughtExceptionHandler(NULL);
    FTClearSignalRegister();
}
/**
 * 替换无符号
 *
 */
+ (NSSet *)dealCallStack:(NSMutableArray *)stack{
    NSMutableSet *set = [NSMutableSet new];
    for (int i=0; i<stack.count; i++) {
        NSString *str = stack[i];
        NSMutableArray *arr = [str componentsSeparatedByString:@" "].mutableCopy;
        [arr removeObject:@""];
        if ([arr[1] isEqualToString:arr[3]]) {
            NSRange range = [str rangeOfString:arr[1] options:NSBackwardsSearch];
            NSMutableString *newStr = [NSMutableString stringWithString:str];
            [newStr insertString:@"_" atIndex:range.location+range.length];
            stack[i] = newStr;
        }
        [set addObject:arr[1]];
    }
    return set;
}
- (NSString *)handleExceptionInfo:(NSException *)exception{
    NSString *header = [FTCallStack ft_crashReportHeader];
    NSString *codeType = @"";
    NSMutableArray *stack = [NSMutableArray arrayWithArray:exception.userInfo[UncaughtExceptionHandlerAddressesKey]];
    NSSet *nameSet =[FTUncaughtExceptionHandler dealCallStack:stack];
    NSString *address = [stack componentsJoinedByString:@"\n"];
    NSMutableArray *images = [NSMutableArray new];
    [images addObject:@"Binary Images:"];
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        uint64_t vmbase = 0;
        uint64_t vmslide = 0;
        uint64_t vmsize = 0;
        
        uint64_t loadAddress = 0;
        uint64_t loadEndAddress = 0;
        NSString *imageName = @"";
        NSString *imagePath = @"";
        NSString *uuid;
        
        const struct mach_header *header = _dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        vmslide = _dyld_get_image_vmaddr_slide(i);
        imagePath = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        char* lastFile = strrchr(name, '/') + 1;
        imageName = [NSString stringWithCString:lastFile encoding:NSUTF8StringEncoding];
        if ([nameSet containsObject:imageName]){
            BOOL is64bit = header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64;
            uintptr_t cursor = (uintptr_t)header + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
            struct load_command *loadCommand = NULL;
            for (uint32_t i = 0; i < header->ncmds; i++, cursor += loadCommand->cmdsize) {
                loadCommand = (struct load_command *)cursor;
                if(loadCommand->cmd == LC_SEGMENT) {
                    const struct segment_command* segmentCommand = (struct segment_command*)loadCommand;
                    if (strcmp(segmentCommand->segname, SEG_TEXT) == 0) {
                        vmsize = segmentCommand->vmsize;
                        vmbase = segmentCommand->vmaddr;
                    }
                } else if(loadCommand->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64* segmentCommand = (struct segment_command_64*)loadCommand;
                    if (strcmp(segmentCommand->segname, SEG_TEXT) == 0) {
                        vmsize = segmentCommand->vmsize;
                        vmbase = (uintptr_t)(segmentCommand->vmaddr);
                    }
                }
                else if (loadCommand->cmd == LC_UUID) {
                    const struct uuid_command *uuidCommand = (const struct uuid_command *)loadCommand;
                    uuid = [[[NSUUID alloc] initWithUUIDBytes:uuidCommand->uuid] UUIDString];
                }
            }
            loadAddress = vmbase + vmslide;
            loadEndAddress = loadAddress + vmsize - 1;
            NSString *loadAddressStr = [NSString stringWithFormat:@"0x%llx",loadAddress];
            address = [address stringByReplacingOccurrencesOfString:uuid withString:loadAddressStr];
            address = [address stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@_",imageName] withString:loadAddressStr];
            uuid = [[uuid stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
            NSString *cpuType = [FTCallStack getMachine:header->cputype];
            NSString *image = [NSString stringWithFormat:@"       %@ -        0x%llx %@ %@ <%@> %@",loadAddressStr,loadEndAddress,imageName,[cpuType lowercaseString],uuid,imagePath];
            [images addObject:image];
            if (header->filetype == MH_EXECUTE) {
                codeType =[NSString stringWithFormat:@"Code Type:   %@",cpuType];
            }
        }
    }
    return [NSString stringWithFormat:@"%@Last Exception Backtrace:\n%@\n\n%@", [NSString stringWithFormat:@"%@\n%@\n\n",header,codeType],address,[images componentsJoinedByString:@"\n"]];
}
@end
