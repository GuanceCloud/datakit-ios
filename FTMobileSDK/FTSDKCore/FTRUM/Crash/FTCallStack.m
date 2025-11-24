//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/09.
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
    main_thread_id = (thread_t)ftthread_self();
}

#pragma -mark Implementation of interface

+ (NSString *)ft_backtraceOfMainThread {
    return _ft_backtraceOfThread(main_thread_id);
}
+ (NSString *)ft_reportOfThread:(thread_t)thread backtrace:(uintptr_t*)backtraceBuffer count:(int)count{
    return ft_backtraceOfThread(thread, backtraceBuffer, count);
}
#pragma -mark Get call backtrace of a mach_thread
NSString *_ft_backtraceOfThread(thread_t thread) {
    //Thread context information
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
    //Get the implementation address of the function, since the function address cannot be read, it needs to be resolved to a function name through the symbol table (nlist) for program positioning.
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
    const task_t thisTask = mach_task_self();
    task_threads(thisTask, &list, &count);
    int num = -1;
    for(int i = 0; i < (int)count; i++)
    {
        thread_t cThread = list[i];
        if(cThread == thread){
            num = i;
            break;
        }
    }
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        mach_port_deallocate(thisTask, list[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)list, sizeof(thread_t) * count);
    return num;
}
NSString* getCurrentCPUArch(void){
    NSString *arch = [FTPresetProperty cpuArch];
    return [FTCallStack CPUType:arch isSystemInfoHeader:YES];
}
#pragma -mark GenerateBacktraceEntry
NSString* ft_logBacktraceEntry(const int entryNum,
                               const uintptr_t address,
                               const Dl_info* const dlInfo) {
    const char* fname = ft_lastPathEntry(dlInfo->dli_fname);
    NSString *fnameStr = nil;
    if(fname == NULL) {
        fnameStr = [NSString stringWithFormat:@(POINTER_FMT), (uintptr_t)dlInfo->dli_fbase];
    }else{
        fnameStr = [NSString stringWithUTF8String:fname];
    }
    
    uintptr_t offset = address - (uintptr_t)dlInfo->dli_saddr;
    const char* sname = dlInfo->dli_sname;
    NSString *snameStr = nil;
    //_mh_execute_header failed to symbolize, replace with load address
    if(sname == NULL || strcmp( sname, "_mh_execute_header") == 0 || strcmp(sname, "<redacted>") == 0) {
        snameStr = [NSString stringWithFormat:@(POINTER_SHORT_FMT), (uintptr_t)dlInfo->dli_fbase];
        offset = address - (uintptr_t)dlInfo->dli_fbase;
    }else{
        snameStr = [NSString stringWithUTF8String:sname];
    }
    return [NSString stringWithFormat:@"%-30@  0x%08" PRIxPTR " %@ + %lu\n",
                fnameStr, (uintptr_t)address, snameStr, offset];
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
