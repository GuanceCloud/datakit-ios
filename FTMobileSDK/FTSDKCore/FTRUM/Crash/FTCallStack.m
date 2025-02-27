//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/09.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTCallStack.h"
#import <mach/mach.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/types.h>
#include <limits.h>
#include <string.h>
#import <sys/utsname.h>
#import "FTSDKCompat.h"

#if FT_HAS_UIKIT
    #import <UIKit/UIKit.h>
#endif

#include "FTStackInfo.h"
#include <mach-o/dyld.h>
#include <mach-o/arch.h>
#include <sys/sysctl.h>
#import "FTPresetProperty.h"

static mach_port_t main_thread_id;

@implementation FTCallStack

+ (void)load {
    main_thread_id = mach_thread_self();
}

#pragma -mark Implementation of interface
+ (NSString *)ft_backtraceOfNSThread:(NSThread *)thread {
    return _ft_backtraceOfThread(ft_machThreadFromNSThread(thread));
}
+ (NSString *)ft_backtraceOfMainThread {
    return [self ft_backtraceOfNSThread:[NSThread mainThread]];
}
+ (NSString *)ft_reportOfThread:(thread_t)thread backtrace:(uintptr_t*)backtraceBuffer count:(int)count{
    return ft_backtraceOfThread(thread, backtraceBuffer, count);
}
#pragma -mark Get call backtrace of a mach_thread
NSString *_ft_backtraceOfThread(thread_t thread) {
    //线程上下文信息
    _STRUCT_MCONTEXT machineContext;
    if(!ft_fillThreadStateIntoMachineContext(thread, &machineContext)) {
        return [NSString stringWithFormat:@"Fail to get information about thread: %u", thread];
    }
    int count = 0;
    uintptr_t backtraceBuffer[50];
    ft_backtrace(&machineContext,backtraceBuffer,&count);
    if(backtraceBuffer[0] == 0){
        return @"Fail to get instruction address";
    }
    return ft_backtraceOfThread(thread,backtraceBuffer,count);
}
NSString *ft_backtraceOfThread(thread_t thread,const uintptr_t* const backtraceBuffer,int count){
    NSMutableString *resultString = [[NSMutableString alloc] initWithFormat:@"Thread %d:\n", ft_crashThreadNumber(thread)];
    NSMutableSet *imageSet = [NSMutableSet new];
    int backtraceLength = count;
    //获得函数的实现地址，由于函数地址无法进行阅读，需要通过符号表（nlist）来解析为函数名，从而进行程序定位。
    Dl_info symbolicated[backtraceLength];
    FTMachoImage binaryImages[backtraceLength];
    ft_symbolicate(backtraceBuffer, symbolicated, backtraceLength, 0,binaryImages);
    for (int i = 0; i < backtraceLength; ++i) {
        [resultString appendFormat:@"%d %@",i, ft_logBacktraceEntry(i, backtraceBuffer[i], &symbolicated[i])];
        [imageSet addObject:ft_logBinaryImage(&binaryImages[i])];
    }
    
    [imageSet removeObject:@""];
    NSMutableString *binaryImagesString = [[NSMutableString alloc] initWithString:@"Binary Images:\n"];
    for(NSString *image in imageSet){
        [binaryImagesString appendString:image];
    }
    
    NSString *header = [FTCallStack ft_crashReportHeader];
    [resultString insertString:header atIndex:0];
    [resultString appendFormat:@"\n"];
    [resultString appendString:binaryImagesString];
    return [resultString copy];
}
int ft_crashThreadNumber(thread_t thread){
    mach_msg_type_number_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    for(int i = 0; i < (int)count; i++)
    {
        thread_t cThread = list[i];
        if(cThread == thread){
            return i;
        }
    }
    return -1;
}
NSString* getCurrentCPUArch(void){
    NSString *arch = [FTPresetProperty cpuArch];
    return [FTCallStack CPUType:arch isSystemInfoHeader:YES];
}
#pragma -mark Convert NSThread to Mach thread
thread_t ft_machThreadFromNSThread(NSThread *nsthread) {
    char name[256];
    mach_msg_type_number_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSString *originName = [nsthread name];
    [nsthread setName:[NSString stringWithFormat:@"%f", currentTimestamp]];
    
    if ([nsthread isMainThread]) {
        return (thread_t)main_thread_id;
    }
    
    for (int i = 0; i < count; ++i) {
        if ([nsthread isMainThread]) {
            if (list[i] == main_thread_id) {
                return list[i];
            }
        }
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, [nsthread name].UTF8String)) {
                [nsthread setName:originName];
                return list[i];
            }
        }
    }
    
    [nsthread setName:originName];
    return mach_thread_self();
}

#pragma -mark GenerateBacbsrackEnrty
NSString* ft_logBacktraceEntry(const int entryNum,
                               const uintptr_t address,
                               const Dl_info* const dlInfo) {
    char faddrBuff[20];
    char saddrBuff[20];
    
    const char* fname = ft_lastPathEntry(dlInfo->dli_fname);
    if(fname == NULL) {
        sprintf(faddrBuff, POINTER_FMT, (uintptr_t)dlInfo->dli_fbase);
        fname = faddrBuff;
    }
    
    uintptr_t offset = address - (uintptr_t)dlInfo->dli_saddr;
    const char* sname = dlInfo->dli_sname;
    //_mh_execute_header 未成功进行符号化，替换为 load address
    if(sname == NULL || strcmp( sname, "_mh_execute_header") == 0 || strcmp(sname, "<redacted>") == 0) {
        sprintf(saddrBuff, POINTER_SHORT_FMT, (uintptr_t)dlInfo->dli_fbase);
        sname = saddrBuff;
        offset = address - (uintptr_t)dlInfo->dli_fbase;
    }
    return [NSString stringWithFormat:@"%-30s  0x%08" PRIxPTR " %s + %lu\n" ,fname, (uintptr_t)address, sname, offset];
}
NSString* ft_logBinaryImage(const FTMachoImage* const image) {
    if(image->name == NULL || strcmp(image->name,"") == 0) {
        return @"";
    }
    const char* fname = ft_lastPathEntry(image->name);

    NSString *uuid = [[[NSUUID alloc] initWithUUIDBytes:image->uuid] UUIDString];
    uuid = [[uuid stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    NSString *cpuType = [FTPresetProperty CPUArchForMajor:image->cpuType minor:image->cpuSubType];
    NSString *imagestr = [NSString stringWithFormat:@"       0x%llx -        0x%llx %@ %@ <%@> %@\n",image->loadAddress,image->loadEndAddress,[NSString stringWithCString:fname encoding:NSUTF8StringEncoding],[cpuType lowercaseString],uuid,[NSString stringWithCString:image->name encoding:NSUTF8StringEncoding]];
    return imagestr;

}
const char* ft_lastPathEntry(const char* const path) {
    if(path == NULL) {
        return "???";
    }
    
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

#pragma -mark HandleMachineContext
+ (NSString *)ft_crashReportHeader{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSMutableString *header = [NSMutableString new];
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    [header appendFormat:@"Hardware Model:  %@\n",deviceString];
#if FT_IOS
    [header appendFormat:@"OS Version:   iPhone OS %@\n",[UIDevice currentDevice].systemVersion];
#endif
    [header appendString:@"Report Version:  104\n"];
    [header appendFormat:@"Code Type:   %@\n",getCurrentCPUArch()];
    return header;
}

+ (NSString*)CPUType:(NSString*) CPUArch isSystemInfoHeader:(BOOL) isSystemInfoHeader
{
    if(isSystemInfoHeader && [CPUArch rangeOfString:@"arm64e"].location == 0)
    {
        return @"ARM-64 (Native)";
    }
    if([CPUArch rangeOfString:@"arm64"].location == 0)
    {
        return @"ARM-64";
    }
    if([CPUArch rangeOfString:@"arm"].location == 0)
    {
        return @"ARM";
    }
    if([CPUArch isEqualToString:@"x86"])
    {
        return @"X86";
    }
    if([CPUArch isEqualToString:@"x86_64"])
    {
        return @"X86_64";
    }
    return @"Unknown";
}

@end
