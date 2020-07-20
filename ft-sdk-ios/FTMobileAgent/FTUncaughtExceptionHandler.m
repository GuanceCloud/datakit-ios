//
//  FTUncaughtExceptionHandler.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTUncaughtExceptionHandler.h"
#import "FTLog.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#import <FTMobileAgent.h>
#import "FTMobileAgent+Private.h"
#import "FTBaseInfoHander.h"
#import <mach-o/ldsyms.h>
#import "FTConstants.h"
#import "FTBaseInfoHander.h"
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <string.h>
//NSException错误名称
NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
//signal错误堆栈的条数
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
//错误堆栈信息
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

void HandleException(NSException *exception);
//Signal类型错误信号处理
void SignalHandler(int signal);
//初始化的错误条数
volatile int32_t UncaughtExceptionCount = 0;
//错误最大的条数
const int32_t UncaughtExceptionMaximum = 10;
static NSUncaughtExceptionHandler *previousUncaughtExceptionHandler;

@interface FTUncaughtExceptionHandler()

@end
@implementation FTUncaughtExceptionHandler

void HandleException(NSException *exception) {
    
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    // 如果太多不用处理
    if (exceptionCount <= UncaughtExceptionMaximum) {
        //获取调用堆栈
        NSString *exceptionStack = [[exception callStackSymbols] componentsJoinedByString:@"\n"];
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
        [userInfo setObject:exceptionStack forKey:UncaughtExceptionHandlerAddressesKey];
        
        //在主线程中，执行制定的方法, withObject是执行方法传入的参数
        [[[FTUncaughtExceptionHandler alloc] init]
         performSelectorOnMainThread:@selector(handleException:)
         withObject:
         [NSException exceptionWithName:[exception name]
                                 reason:[exception reason]
                               userInfo:userInfo]
         waitUntilDone:YES];
    }
    if (previousUncaughtExceptionHandler) {
        previousUncaughtExceptionHandler(exception);
    }
}

//2.2、signal报错处理
void SignalHandler(int signal) {

    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    // 如果太多不用处理
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }

    NSString* description = nil;
    switch (signal) {
        case SIGABRT:
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

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    NSArray *callStack = [FTUncaughtExceptionHandler backtrace];
    NSString *exceptionStack = [callStack componentsJoinedByString:@"\n"];
    [userInfo setObject:exceptionStack forKey:UncaughtExceptionHandlerAddressesKey];
    [userInfo setObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
}
+ (void)installUncaughtExceptionHandler{
    previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT, SignalHandler);
    signal(SIGILL,  SignalHandler);
    signal(SIGSEGV, SignalHandler);
    signal(SIGFPE,  SignalHandler);
    signal(SIGBUS,  SignalHandler);
    signal(SIGPIPE, SignalHandler);
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
   
    NSString *info =[NSString stringWithFormat:@"Exception Reason:%@\nException Stack:\n%@\ndSYMUUID:%@", [exception reason], exception.userInfo[UncaughtExceptionHandlerAddressesKey],[self getUUIDDictionary]];
    [[FTMobileAgent sharedInstance] _loggingBackgroundInsertWithOP:FT_TRACK_LOGGING_EXCEPTION status:[FTBaseInfoHander ft_getFTstatueStr:FTStatusCritical] content:info tm:[FTBaseInfoHander ft_getCurrentTimestamp]];
}

- (NSString *)getUUIDDictionary {
    // 获取 image 的 index
    const uint32_t imageCount = _dyld_image_count();

    uint32_t mainImg = 0;
    NSString *path =getExecutablePath();
    for(uint32_t iImg = 0; iImg < imageCount; iImg++) {
        const char* name = _dyld_get_image_name(iImg);
        NSString *imagePath = [NSString stringWithUTF8String:name];
        if ([imagePath isEqualToString:path]){
            mainImg = iImg;
        // 根据 index 获取 header
           const struct mach_header* header = _dyld_get_image_header(mainImg);
           uintptr_t cmdPtr = firstCmdAfterHeader(header);
           if(cmdPtr == 0) {
               return @"NULL";
           }
           
           uint8_t* uuid = NULL;
           
           for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++)
           {
               struct load_command* loadCmd = (struct load_command*)cmdPtr;
               
               if (loadCmd->cmd == LC_UUID) {
                   struct uuid_command* uuidCmd = (struct uuid_command*)cmdPtr;
                   uuid = uuidCmd->uuid;
                   break;
               }
               cmdPtr += loadCmd->cmdsize;
           }
           const char* result = nil;
           if(uuid != NULL)
              {
                  result = uuidBytesToString(uuid);
                  NSString *lduuid = [NSString stringWithUTF8String:result];
                  return lduuid;
              }
        }
    }
    
    return @"NULL";
}
static NSString* getExecutablePath()
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSDictionary* infoDict = [mainBundle infoDictionary];
    NSString* bundlePath = [mainBundle bundlePath];
    NSString* executableName = infoDict[@"CFBundleExecutable"];
    return [bundlePath stringByAppendingPathComponent:executableName];
}
static const char* uuidBytesToString(const uint8_t* uuidBytes) {
    CFUUIDRef uuidRef = CFUUIDCreateFromUUIDBytes(NULL, *((CFUUIDBytes*)uuidBytes));
    NSString* str = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    
    return cString(str);
}
const char* cString(NSString* str) {
    return str == NULL ? NULL : strdup(str.UTF8String);
}
//// 获取 Load Command
static uintptr_t firstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic)
    {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            // Header is corrupt
            return 0;
    }
}
@end
