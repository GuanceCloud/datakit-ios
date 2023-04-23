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
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#import <sys/utsname.h>
#import <UIKit/UIKit.h>

#pragma -mark DEFINE MACRO FOR DIFFERENT CPU ARCHITECTURE
#if defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#define FT_THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define FT_THREAD_STATE ARM_THREAD_STATE64
#define FT_FRAME_POINTER __fp
#define FT_STACK_POINTER __sp
#define FT_INSTRUCTION_ADDRESS __pc

#elif defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#define FT_THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define FT_THREAD_STATE ARM_THREAD_STATE
#define FT_FRAME_POINTER __r[7]
#define FT_STACK_POINTER __sp
#define FT_INSTRUCTION_ADDRESS __pc

#elif defined(__x86_64__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define FT_THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define FT_THREAD_STATE x86_THREAD_STATE64
#define FT_FRAME_POINTER __rbp
#define FT_STACK_POINTER __rsp
#define FT_INSTRUCTION_ADDRESS __rip

#elif defined(__i386__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define FT_THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define FT_THREAD_STATE x86_THREAD_STATE32
#define FT_FRAME_POINTER __ebp
#define FT_STACK_POINTER __esp
#define FT_INSTRUCTION_ADDRESS __eip

#endif

#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

#if defined(__LP64__)
#define TRACE_FMT         "%-4d%-31s 0x%016lx %s + %lu"
#define POINTER_FMT       "0x%016lx"
#define POINTER_SHORT_FMT "0x%lx"
#define FT_NLIST struct nlist_64
#else
#define TRACE_FMT         "%-4d%-31s 0x%08lx %s + %lu"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#define FT_NLIST struct nlist
#endif

typedef struct FTStackFrameEntry{
    const struct FTStackFrameEntry *const previous;///前一个栈帧地址
    const uintptr_t return_address;///栈帧的函数返回地址
} FTStackFrameEntry;
typedef struct FTMachoImage {
        const char *name;  /** The binary image's name/path. */
        uint64_t loadAddress;
        uint64_t loadEndAddress;
        uint8_t    uuid[16];
        uint32_t   cpuType;
} FTMachoImage;
static mach_port_t main_thread_id;

@implementation FTCallStack

+ (void)load {
    main_thread_id = mach_thread_self();
}

#pragma -mark Implementation of interface
+ (NSString *)ft_backtraceOfNSThread:(NSThread *)thread {
    return _ft_backtraceOfThread(ft_machThreadFromNSThread(thread));
}

//+ (NSString *)ft_backtraceOfCurrentThread {
//    return [self ft_backtraceOfNSThread:[NSThread currentThread]];
//}

+ (NSString *)ft_backtraceOfMainThread {
    return [self ft_backtraceOfNSThread:[NSThread mainThread]];
}

//+ (NSString *)ft_backtraceOfAllThread {
//    thread_act_array_t threads;
//    mach_msg_type_number_t thread_count = 0;
//    const task_t this_task = mach_task_self();//获得任务的端口，带有发送权限的名称
//
//    kern_return_t kr = task_threads(this_task, &threads, &thread_count);//将target_task 任务中的所有线程枚举保存在act_list 中
//    if(kr != KERN_SUCCESS) {
//        return @"Fail to get information of all threads";
//    }
//
//    NSMutableString *resultString = [NSMutableString stringWithFormat:@"Call Backtrace of %u threads:\n", thread_count];
//    for(int i = 0; i < thread_count; i++) {
//        [resultString appendString:_ft_backtraceOfThread(threads[i])];
//    }
//    return [resultString copy];
//}

#pragma -mark Get call backtrace of a mach_thread
NSString *_ft_backtraceOfThread(thread_t thread) {
    uintptr_t backtraceBuffer[50];
    int i = 0;
    NSMutableString *header = [[NSMutableString alloc]initWithString:[FTCallStack ft_crashReportHeader]];
    NSMutableString *resultString = [[NSMutableString alloc] initWithFormat:@"Last Exception Backtrace %u:\n", thread];
    NSMutableString *binaryImagesString = [[NSMutableString alloc] initWithString:@"Binary Images:\n"];
    //线程上下文信息
    _STRUCT_MCONTEXT machineContext;
    if(!ft_fillThreadStateIntoMachineContext(thread, &machineContext)) {
        return [NSString stringWithFormat:@"Fail to get information about thread: %u", thread];
    }
    //.获取指针栈帧结构体_STRUCT_CONTEXT._ss，解析得到对应指令指针_STRUCT_CONTEXT._ss.ip;首次个栈帧指针_STRUCT_CONTEXT._ss.bp；栈顶指针_STRUCT_CONTEXT._ss.sp
    const uintptr_t instructionAddress = ft_mach_instructionAddress(&machineContext);
    backtraceBuffer[i] = instructionAddress;
    ++i;
    
    uintptr_t linkRegister = ft_mach_linkRegister(&machineContext);
    if (linkRegister) {
        backtraceBuffer[i] = linkRegister;
        i++;
    }
    
    if(instructionAddress == 0) {
        return @"Fail to get instruction address";
    }
    
    FTStackFrameEntry frame = {0};
    const uintptr_t framePtr = ft_mach_framePointer(&machineContext);
    if(framePtr == 0 ||
       ft_mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS) {
        return @"Fail to get frame pointer";
    }
    //遍历StackFrameEntry获取所有栈帧及对应的函数地址
    for(; i < 50; i++) {
        backtraceBuffer[i] = frame.return_address;
        if(backtraceBuffer[i] == 0 ||
           frame.previous == 0 ||
           ft_mach_copyMem(frame.previous, &frame, sizeof(frame)) != KERN_SUCCESS) {
            break;
        }
    }
    //获得函数的实现地址，由于函数地址无法进行阅读，需要通过符号表（nlist）来解析为函数名，从而进行程序定位。
    int backtraceLength = i;
    Dl_info symbolicated[backtraceLength];
    FTMachoImage binaryImages[backtraceLength];
    ft_symbolicate(backtraceBuffer, symbolicated, backtraceLength, 0,binaryImages);
    NSMutableSet *imageSet = [NSMutableSet new];
    FTMachoImage *image = &binaryImages[0];
    [header appendFormat:@"Code Type:   %@\n",[FTCallStack getMachine:image->cpuType]];
    for (int i = 0; i < backtraceLength; ++i) {
        [resultString appendFormat:@"%d %@",i, ft_logBacktraceEntry(i, backtraceBuffer[i], &symbolicated[i])];
        [imageSet addObject:ft_logBinaryImage(&binaryImages[i])];
    }
    [imageSet removeObject:@""];
    for(NSString *image in imageSet){
        [binaryImagesString appendString:image];
    }
    [resultString insertString:header atIndex:0];
    [resultString appendFormat:@"\n"];
    [resultString appendString:binaryImagesString];
    return [resultString copy];
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
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if ([nsthread isMainThread]) {
            if (list[i] == main_thread_id) {
                return list[i];
            }
        }
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
    NSString *cpuType = [FTCallStack getMachine:image->cpuType];
    NSString *imagestr = [NSString stringWithFormat:@"       0x%llx -        0x%llx %@ %@ <%@> %@\n",image->loadAddress,image->loadEndAddress,[NSString stringWithCString:fname encoding:NSUTF8StringEncoding],[cpuType lowercaseString],uuid,[NSString stringWithCString:image-> name encoding:NSUTF8StringEncoding]];
    return imagestr;

}
const char* ft_lastPathEntry(const char* const path) {
    if(path == NULL) {
        return NULL;
    }
    
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

#pragma -mark HandleMachineContext
bool ft_fillThreadStateIntoMachineContext(thread_t thread, _STRUCT_MCONTEXT *machineContext) {
    mach_msg_type_number_t state_count = FT_THREAD_STATE_COUNT;
    kern_return_t kr = thread_get_state(thread, FT_THREAD_STATE, (thread_state_t)&machineContext->__ss, &state_count);//获得线程上下文
    return (kr == KERN_SUCCESS);
}

uintptr_t ft_mach_framePointer(mcontext_t const machineContext){
    return machineContext->__ss.FT_FRAME_POINTER; ///rbp 栈帧指针
}

uintptr_t ft_mach_stackPointer(mcontext_t const machineContext){
    return machineContext->__ss.FT_STACK_POINTER;////bsp 栈顶指针
}

uintptr_t ft_mach_instructionAddress(mcontext_t const machineContext){
    return machineContext->__ss.FT_INSTRUCTION_ADDRESS; ///rip 指令指针
}

uintptr_t ft_mach_linkRegister(mcontext_t const machineContext){
#if defined(__i386__) || defined(__x86_64__)
    return 0;
#else
    return machineContext->__ss.__lr;
#endif
}
/**
 * 参数src：栈帧指针
 * 参数dst：StackFrameEntry实例指针
 * 参数numBytes：StackFrameEntry结构体大小
 */
kern_return_t ft_mach_copyMem(const void *const src, void *const dst, const size_t numBytes){
    vm_size_t bytesCopied = 0;
    ///   调用api函数，根据栈帧指针获取该栈帧对应的函数地址
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}

#pragma -mark Symbolicate
void ft_symbolicate(const uintptr_t* const backtraceBuffer,
                    Dl_info* const symbolsBuffer,
                    const int numEntries,
                    const int skippedEntries,
                    FTMachoImage* const binaryImages){
    int i = 0;
    
    if(!skippedEntries && i < numEntries) {
        ft_dladdr(backtraceBuffer[i], &symbolsBuffer[i],&binaryImages[i]);
        i++;
    }
    
    for(; i < numEntries; i++) {
        ft_dladdr(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(backtraceBuffer[i]), &symbolsBuffer[i],&binaryImages[i]);
    }
}

bool ft_dladdr(const uintptr_t address, Dl_info* const info,FTMachoImage* const binaryImages) {
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;
    binaryImages->name = NULL;
    binaryImages->cpuType = NULL;
    binaryImages->loadEndAddress = NULL;
    const uint32_t idx = ft_imageIndexContainingAddress(address);
    if(idx == UINT_MAX) {
        return false;
    }
    const struct mach_header* header = _dyld_get_image_header(idx);
    const uintptr_t imageVMAddrSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(idx);
    const uintptr_t addressWithSlide = address - imageVMAddrSlide;
    const uintptr_t segmentBase = ft_segmentBaseOfImageIndex(idx,binaryImages) + imageVMAddrSlide;
    if(segmentBase == 0) {
        return false;
    }
    binaryImages->loadAddress = (uintptr_t)(void*)header;
    info->dli_fname = _dyld_get_image_name(idx);
    binaryImages->name = info->dli_fname;
    binaryImages->cpuType = header->cputype;
    binaryImages->loadEndAddress = binaryImages->loadEndAddress+binaryImages->loadAddress-1;
    info->dli_fbase = (void*)header;
    // Find symbol tables and get whichever symbol is closest to the address.
    const FT_NLIST* bestMatch = NULL;
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = ft_firstCmdAfterHeader(header);
    if(cmdPtr == 0) {
        return false;
    }
    for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        if(loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command* symtabCmd = (struct symtab_command*)cmdPtr;
            const FT_NLIST* symbolTable = (FT_NLIST*)(segmentBase + symtabCmd->symoff);
            const uintptr_t stringTable = segmentBase + symtabCmd->stroff;
            
            for(uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym++) {
                // If n_value is 0, the symbol refers to an external object.
                if(symbolTable[iSym].n_value != 0) {
                    uintptr_t symbolBase = symbolTable[iSym].n_value;
                    uintptr_t currentDistance = addressWithSlide - symbolBase;
                    if((addressWithSlide >= symbolBase) &&
                       (currentDistance <= bestDistance)) {
                        bestMatch = symbolTable + iSym;
                        bestDistance = currentDistance;
                    }
                }
            }
            if(bestMatch != NULL) {
                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddrSlide);
                info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                if(*info->dli_sname == '_') {
                    info->dli_sname++;
                }
                // This happens if all symbols have been stripped.
                if(info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                    info->dli_sname = NULL;
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return true;
}

uintptr_t ft_firstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            return 0;  // Header is corrupt
    }
}

uint32_t ft_imageIndexContainingAddress(const uintptr_t address) {
    // 调用API函数_dyld_image_count(void) ，获取images文件总数，即mach-o文件总数
    const uint32_t imageCount = _dyld_image_count();
    const struct mach_header* header = 0;
    for(uint32_t iImg = 0; iImg < imageCount; iImg++) {
        header = _dyld_get_image_header(iImg);
        if(header != NULL) {
            // Look for a segment command with this address within its range.
            uintptr_t addressWSlide = address - (uintptr_t)_dyld_get_image_vmaddr_slide(iImg);
            uintptr_t cmdPtr = ft_firstCmdAfterHeader(header);
            if(cmdPtr == 0) {
                continue;
            }
            for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
                const struct load_command* loadCmd = (struct load_command*)cmdPtr;
                if(loadCmd->cmd == LC_SEGMENT) {
                    const struct segment_command* segCmd = (struct segment_command*)cmdPtr;
                    if(addressWSlide >= segCmd->vmaddr &&
                       addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                else if(loadCmd->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64* segCmd = (struct segment_command_64*)cmdPtr;
                    if(addressWSlide >= segCmd->vmaddr &&
                       addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                cmdPtr += loadCmd->cmdsize;
            }
        }
    }
    return UINT_MAX;
}

uintptr_t ft_segmentBaseOfImageIndex(const uint32_t idx,FTMachoImage* const binaryImages) {
    const struct mach_header* header = _dyld_get_image_header(idx);
    
    // Look for a segment command and return the file image address.
    uintptr_t cmdPtr = ft_firstCmdAfterHeader(header);
    if(cmdPtr == 0) {
        return 0;
    }
    uintptr_t imageIndex = 0;
    for(uint32_t i = 0;i < header->ncmds; i++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        if(loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command* segmentCmd = (struct segment_command*)cmdPtr;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                imageIndex = segmentCmd->vmaddr - segmentCmd->fileoff;
            }else if(strcmp(segmentCmd->segname, SEG_TEXT) == 0) {
                binaryImages->loadEndAddress = segmentCmd->vmsize;
            }
        }
        else if(loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64* segmentCmd = (struct segment_command_64*)cmdPtr;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                imageIndex = (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }else if(strcmp(segmentCmd->segname, SEG_TEXT) == 0) {
                binaryImages->loadEndAddress = segmentCmd->vmsize;
            }
        }
        else if (loadCmd->cmd == LC_UUID) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)loadCmd;
            memcpy(binaryImages->uuid,uuidCommand->uuid,sizeof(uuidCommand->uuid));
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return imageIndex;
}
+ (NSString *)ft_crashReportHeader{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSMutableString *header = [NSMutableString new];
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    [header appendFormat:@"Hardware Model:  %@\n",deviceString];
    [header appendFormat:@"OS Version:   iPhone OS %@\n",[UIDevice currentDevice].systemVersion];
    [header appendString:@"Report Version:  104\n"];
    return header;
}
+(NSString *)getMachine:(cpu_type_t)cputype
{
    switch (cputype)
    {
        default:                  return @"???";
        case CPU_TYPE_I386:       return @"X86";
        case CPU_TYPE_POWERPC:    return @"PPC";
        case CPU_TYPE_X86_64:     return @"X86_64";
        case CPU_TYPE_POWERPC64:  return @"PPC64";
        case CPU_TYPE_ARM:        return @"ARM";
        case CPU_TYPE_ARM64:      return @"ARM64";
    }
}
@end
