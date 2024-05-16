//
//  FTStackInfo.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/8.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTStackInfo.h"
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <limits.h>
#include <string.h>
#include <pthread.h>
#include <sys/types.h>

#pragma -mark DEFINE MACRO FOR DIFFERENT CPU ARCHITECTURE
#if defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#define FT_THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define FT_THREAD_STATE ARM_THREAD_STATE64
#define FT_EXCEPTION_STATE_COUNT ARM_EXCEPTION_STATE64_COUNT
#define FT_EXCEPTION_STATE  ARM_EXCEPTION_STATE64
#define FT_FRAME_POINTER __fp
#define FT_STACK_POINTER __sp
#define FT_INSTRUCTION_ADDRESS __pc

#elif defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#define FT_THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define FT_THREAD_STATE ARM_THREAD_STATE
#define FT_EXCEPTION_STATE_COUNT ARM_EXCEPTION_STATE_COUNT
#define FT_EXCEPTION_STATE  ARM_EXCEPTION_STATE
#define FT_FRAME_POINTER __r[7]
#define FT_STACK_POINTER __sp
#define FT_INSTRUCTION_ADDRESS __pc

#elif defined(__x86_64__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define FT_THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define FT_THREAD_STATE x86_THREAD_STATE64
#define FT_EXCEPTION_STATE_COUNT x86_EXCEPTION_STATE64_COUNT
#define FT_EXCEPTION_STATE  x86_EXCEPTION_STATE64
#define FT_FRAME_POINTER __rbp
#define FT_STACK_POINTER __rsp
#define FT_INSTRUCTION_ADDRESS __rip

#elif defined(__i386__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define FT_THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define FT_THREAD_STATE x86_THREAD_STATE32
#define FT_EXCEPTION_STATE_COUNT x86_EXCEPTION_STATE32_COUNT
#define FT_EXCEPTION_STATE  x86_EXCEPTION_STATE32
#define FT_FRAME_POINTER __ebp
#define FT_STACK_POINTER __esp
#define FT_INSTRUCTION_ADDRESS __eip

#endif
#define FTPACStrippingMask_ARM64e 0x0000000fffffffff

kern_return_t ft_mach_copyMem(const void *const src, void *const dst, const size_t numBytes){
    vm_size_t bytesCopied = 0;
    ///   调用api函数，根据栈帧指针获取该栈帧对应的函数地址
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}
uintptr_t ft_faultAddress(mcontext_t const machineContext){
#if defined(__i386__) || defined(__x86_64__)
    return 0;
#else
    return machineContext->__es.__far;
#endif
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
uintptr_t ft_mach_framePointer(mcontext_t const machineContext){
    return machineContext->__ss.FT_FRAME_POINTER; ///rbp 栈帧指针
}

void ft_backtrace(mcontext_t const machineContext,uintptr_t *backtrace,int* count){
    int i = 0;
    //.获取指针栈帧结构体_STRUCT_CONTEXT._ss，解析得到对应指令指针_STRUCT_CONTEXT._ss.ip;首次个栈帧指针_STRUCT_CONTEXT._ss.bp；栈顶指针_STRUCT_CONTEXT._ss.sp
    const uintptr_t instructionAddress = ft_mach_instructionAddress(machineContext);
    *backtrace = instructionAddress & FTPACStrippingMask_ARM64e;
    ++i;

    uintptr_t linkRegister = ft_mach_linkRegister(machineContext);
    if (linkRegister) {
        *(backtrace+i) = linkRegister & FTPACStrippingMask_ARM64e;
        i++;
    }
    
    if(instructionAddress == 0) {
        return;
    }
    FTStackFrameEntry frame = {0};
    const uintptr_t framePtr = ft_mach_framePointer(machineContext);
    if(framePtr == 0 ||
       ft_mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS) {
        return;
    }
    //遍历StackFrameEntry获取所有栈帧及对应的函数地址
    for(; i < 50; i++) {
        if(frame.return_address == 0 ){
            break;
        }
        *(backtrace+i) = frame.return_address & FTPACStrippingMask_ARM64e;
        if(frame.previous == 0 ||
           ft_mach_copyMem(frame.previous, &frame, sizeof(frame)) != KERN_SUCCESS) {
            i++;
            break;
        }
    }
    *count = i;
}
bool ft_fillThreadStateIntoMachineContext(thread_t thread, _STRUCT_MCONTEXT *machineContext) {
    mach_msg_type_number_t state_count = FT_THREAD_STATE_COUNT;
    mach_msg_type_number_t exception_state_count = FT_EXCEPTION_STATE_COUNT;

    kern_return_t kr = thread_get_state(thread, FT_THREAD_STATE, (thread_state_t)&machineContext->__ss, &state_count);//获得线程上下文
    thread_get_state(thread, FT_EXCEPTION_STATE, (thread_state_t)&machineContext->__es, &exception_state_count);
    return (kr == KERN_SUCCESS);
}
#pragma -mark Symbolicate
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
bool ft_dladdr(const uintptr_t address, Dl_info* const info,FTMachoImage* const binaryImages) {
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;
    binaryImages->name = NULL;
    binaryImages->cpuType = 0;
    binaryImages->cpuSubType = 0;
    binaryImages->loadEndAddress = 0;
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
    info->dli_fname = _dyld_get_image_name((unsigned)idx);
    info->dli_fbase = (void*)header;
    binaryImages->loadAddress = (uintptr_t)(void*)header;
    binaryImages->name = info->dli_fname;
    binaryImages->cpuType = header->cputype;
    binaryImages->cpuSubType = header->cpusubtype;
    binaryImages->loadEndAddress = binaryImages->loadEndAddress+binaryImages->loadAddress-1;
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
                if ((symbolTable[iSym].n_type & N_STAB) != 0)
                {
                    continue;
                }
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
                if(bestMatch->n_desc == 16)
                {
                    // This image has been stripped. The name is meaningless, and
                    // almost certainly resolves to "_mh_execute_header"
                    info->dli_sname = NULL;
                }else
                {
                    info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                    if(*info->dli_sname == '_')
                    {
                        info->dli_sname++;
                    }
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return true;
}

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
