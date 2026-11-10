//
//  FTSwizzler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/2.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTSwizzler.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/lock.h>
#import "FTInnerLog.h"
#if DEBUG
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <uuid/uuid.h>
#import <stdlib.h>
#import <string.h>
#import <limits.h>
#import <stdatomic.h>
#if __has_feature(ptrauth_calls)
#import <ptrauth.h>
#endif
#endif
#if !__has_feature(objc_arc)
#error This code needs ARC. Use compiler option -fobjc-arc
#endif

#if DEBUG
// Only executable segment ranges and image metadata are cached; symbol tables are never read.
typedef struct {
    uintptr_t loadAddress;
    uintptr_t start;
    uintptr_t end;
    cpu_type_t cpuType;
    cpu_subtype_t cpuSubtype;
    uuid_t uuid;
    BOOL hasUUID;
    char name[256];
} FTSwizzleImageInfo;

typedef struct FTSwizzleImageEntry {
    FTSwizzleImageInfo info;
    struct FTSwizzleImageEntry *_Nullable next;
} FTSwizzleImageEntry;

static os_unfair_lock ftSwizzleImageLock = OS_UNFAIR_LOCK_INIT;
static FTSwizzleImageEntry *ftSwizzleImages;
static atomic_int ftSwizzleImageState = ATOMIC_VAR_INIT(0); // 0: uninitialized, 1: registering, 2: ready

static void FTSwizzleImageAdded(const struct mach_header *header, intptr_t slide) {
    BOOL is64 = header->magic == MH_MAGIC_64;
    if (!is64 && header->magic != MH_MAGIC) return;
    const uint8_t *commands = (const uint8_t *)header + (is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const uint8_t *end = commands + header->sizeofcmds;
    FTSwizzleImageInfo info = {0};
    info.loadAddress = (uintptr_t)header;
    info.cpuType = header->cputype;
    info.cpuSubtype = header->cpusubtype;
    const char *imageName = "<unknown-image>";
    char executablePath[PATH_MAX];
    if (header->filetype == MH_EXECUTE) {
        uint32_t size = sizeof(executablePath);
        if (_NSGetExecutablePath(executablePath, &size) == 0) imageName = executablePath;
    }
    // Copy metadata while dyld guarantees that this image is mapped.
    const uint8_t *cursor = commands;
    for (uint32_t i = 0; i < header->ncmds && (size_t)(end - cursor) >= sizeof(struct load_command); i++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor)) break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command)) {
            memcpy(info.uuid, ((const struct uuid_command *)command)->uuid, sizeof(uuid_t));
            info.hasUUID = YES;
        } else if (command->cmd == LC_ID_DYLIB && command->cmdsize >= sizeof(struct dylib_command)) {
            uint32_t offset = ((const struct dylib_command *)command)->dylib.name.offset;
            if (offset >= sizeof(struct dylib_command) && offset < command->cmdsize &&
                memchr(cursor + offset, '\0', command->cmdsize - offset)) {
                imageName = (const char *)cursor + offset;
            }
        }
        cursor += command->cmdsize;
    }
    const char *basename = strrchr(imageName, '/');
    strlcpy(info.name, basename ? basename + 1 : imageName, sizeof(info.name));
    FTSwizzleImageEntry *entries = NULL;
    cursor = commands;
    for (uint32_t i = 0; i < header->ncmds && (size_t)(end - cursor) >= sizeof(struct load_command); i++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor)) break;
        uint64_t vmaddr = 0, vmsize = 0;
        vm_prot_t protection = 0;
        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            vmaddr = segment->vmaddr; vmsize = segment->vmsize; protection = segment->initprot;
        } else if (command->cmd == LC_SEGMENT && command->cmdsize >= sizeof(struct segment_command)) {
            const struct segment_command *segment = (const struct segment_command *)command;
            vmaddr = segment->vmaddr; vmsize = segment->vmsize; protection = segment->initprot;
        }
        uintptr_t start = (uintptr_t)vmaddr + (uintptr_t)slide;
        if ((protection & VM_PROT_EXECUTE) && vmsize > 0 && vmsize <= UINTPTR_MAX - start) {
            FTSwizzleImageEntry *entry = malloc(sizeof(*entry));
            if (entry) {
                entry->info = info;
                entry->info.start = start;
                entry->info.end = start + (uintptr_t)vmsize;
                entry->next = entries;
                entries = entry;
            }
        }
        cursor += command->cmdsize;
    }
    // Do not call dyld, Objective-C, or logging APIs while holding this lock.
    os_unfair_lock_lock(&ftSwizzleImageLock);
    while (entries) {
        FTSwizzleImageEntry *next = entries->next;
        entries->next = ftSwizzleImages;
        ftSwizzleImages = entries;
        entries = next;
    }
    os_unfair_lock_unlock(&ftSwizzleImageLock);
}

static void FTSwizzleImageRemoved(const struct mach_header *header, intptr_t slide) {
    os_unfair_lock_lock(&ftSwizzleImageLock);
    FTSwizzleImageEntry **entry = &ftSwizzleImages;
    while (*entry) {
        if ((*entry)->info.loadAddress == (uintptr_t)header) {
            FTSwizzleImageEntry *removed = *entry;
            *entry = removed->next;
            free(removed);
        } else {
            entry = &(*entry)->next;
        }
    }
    os_unfair_lock_unlock(&ftSwizzleImageLock);
}

static NSString *FTSwizzleDescribeIMP(IMP imp) {
    int expected = 0;
    if (atomic_compare_exchange_strong_explicit(&ftSwizzleImageState, &expected, 1,
                                                memory_order_relaxed, memory_order_relaxed)) {
        _dyld_register_func_for_remove_image(FTSwizzleImageRemoved);
        _dyld_register_func_for_add_image(FTSwizzleImageAdded);
        atomic_store_explicit(&ftSwizzleImageState, 2, memory_order_release);
    }
    // Never wait for another thread's registration: this caller may hold dyld's +load lock.
#if __has_feature(ptrauth_calls)
    uintptr_t address = (uintptr_t)ptrauth_strip(imp, ptrauth_key_function_pointer);
#else
    uintptr_t address = (uintptr_t)imp;
#endif
    FTSwizzleImageInfo info = {0};
    BOOL found = NO;
    os_unfair_lock_lock(&ftSwizzleImageLock);
    for (FTSwizzleImageEntry *entry = ftSwizzleImages; entry; entry = entry->next) {
        if (address >= entry->info.start && address < entry->info.end) {
            info = entry->info;
            found = YES;
            break;
        }
    }
    os_unfair_lock_unlock(&ftSwizzleImageLock);
    if (!found) {
        // Block IMP trampolines may live outside dyld images; never guess an image or offset.
        const char *state = atomic_load_explicit(&ftSwizzleImageState, memory_order_acquire) == 2 ? "unmapped" : "lookup-pending";
        return [NSString stringWithFormat:@"{address:%p image:<%s>}", (void *)address, state];
    }
    uuid_string_t uuid = "<unavailable>";
    if (info.hasUUID) uuid_unparse_upper(info.uuid, uuid);
    const char *arch = "unknown";
    if (info.cpuType == CPU_TYPE_ARM64) {
        arch = (info.cpuSubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E ? "arm64e" : "arm64";
    } else if (info.cpuType == CPU_TYPE_X86_64) {
        arch = "x86_64";
    } else if (info.cpuType == CPU_TYPE_ARM) {
        arch = "arm";
    } else if (info.cpuType == CPU_TYPE_X86) {
        arch = "i386";
    }
    return [NSString stringWithFormat:@"{address:%p image:%s uuid:%s arch:%s load:%p offset:0x%llx}",
            (void *)address, info.name, uuid, arch, (void *)info.loadAddress,
            (unsigned long long)(address - info.loadAddress)];
}

typedef struct {
    BOOL enabled;
    BOOL inherited;
    IMP before;
    IMP after;
} FTSwizzleLogContext;
#endif

#pragma mark - Swizzling

#pragma mark └ FTSwizzlerInfo
typedef IMP (^FTSwizzlerImpProvider)(void);

@interface FTSwizzlerInfo()
@property (nonatomic,copy) FTSwizzlerImpProvider impProviderBlock;
@property (nonatomic, readwrite) SEL selector;
@end

@implementation FTSwizzlerInfo

-(FTSwizzlerOriginalIMP)getOriginalImplementation{
    NSAssert(_impProviderBlock,nil);
    if (!_impProviderBlock) {
        NSLog(@"_impProviderBlock can't be missing");
        return NULL;
    }
    // Casting IMP to FTSwizzlerOriginalIMP to force user casting.
    return (FTSwizzlerOriginalIMP)_impProviderBlock();
}

@end


#pragma mark └ FTSwizzler
@implementation FTSwizzler

// The original-IMP provider captures a runtime Class; copying it must not retain
// the target and send it a message before the application first uses that class.
static void swizzle(__unsafe_unretained Class classToSwizzle,
                    SEL selector,
                    FTSwizzlerImpFactoryBlock factoryBlock
#if DEBUG
                    , FTSwizzleLogContext *logContext
#endif
                    )
{
    Method method = class_getInstanceMethod(classToSwizzle, selector);
    
    NSCAssert(NULL != method,
              @"Selector %@ not found in %@ methods of class %@.",
              NSStringFromSelector(selector),
              class_isMetaClass(classToSwizzle) ? @"class" : @"instance",
              classToSwizzle);
    
    __block os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    // To keep things thread-safe, we fill in the originalIMP later,
    // with the result of the class_replaceMethod call below.
    __block IMP originalIMP = NULL;
    
    // This block will be called by the client to get original implementation and call it.
    FTSwizzlerImpProvider originalImpProvider = ^IMP{
        // It's possible that another thread can call the method between the call to
        // class_replaceMethod and its return value being set.
        // So to be sure originalIMP has the right value, we need a lock.
        os_unfair_lock_lock(&lock);
        IMP imp = originalIMP;
        os_unfair_lock_unlock(&lock);
        
        if (NULL == imp){
            // If the class does not implement the method
            // we need to find an implementation in one of the superclasses.
            Class superclass = class_getSuperclass(classToSwizzle);
            imp = method_getImplementation(class_getInstanceMethod(superclass,selector));
        }
        return imp;
    };
    
    FTSwizzlerInfo *swizzleInfo = [FTSwizzlerInfo new];
    swizzleInfo.selector = selector;
    swizzleInfo.impProviderBlock = originalImpProvider;
    
    // We ask the client for the new implementation block.
    // We pass swizzleInfo as an argument to factory block, so the client can
    // call original implementation from the new implementation.
    id newIMPBlock = factoryBlock(swizzleInfo);
    
    const char *methodType = method_getTypeEncoding(method);

    IMP newIMP = imp_implementationWithBlock(newIMPBlock);
    
    // Atomically replace the original method with our new implementation.
    // This will ensure that if someone else's code on another thread is messing
    // with the class' method list too, we always have a valid method at all times.
    //
    // If the class does not implement the method itself then
    // class_replaceMethod returns NULL and superclasses's implementation will be used.
    //
    // We need a lock to be sure that originalIMP has the right value in the
    // originalImpProvider block above.
#if DEBUG
    BOOL shouldLogSwizzle = [FTLog isSwizzleLogEnabled];
    // Adding an override returns NULL, so snapshot the inherited IMP before replacement.
    IMP inheritedIMPBeforeSwizzle = shouldLogSwizzle ? method_getImplementation(method) : NULL;
#endif
    os_unfair_lock_lock(&lock);
    originalIMP = class_replaceMethod(classToSwizzle, selector, newIMP, methodType);
    os_unfair_lock_unlock(&lock);
#if DEBUG
    if (shouldLogSwizzle) {
        logContext->enabled = YES;
        logContext->before = originalIMP ?: inheritedIMPBeforeSwizzle;
        logContext->after = newIMP;
        logContext->inherited = originalIMP == NULL;
    }
#endif
}
// These internal helpers receive runtime Class objects. ARC's strong id parameter
// would send retain/release messages and can trigger +initialize during scanning.
+ (void)setFTAssociatedObject:(__unsafe_unretained id)object
                          key:(const void *)key
                        value:(nullable id)value
                  association:(objc_AssociationPolicy)association {
    objc_setAssociatedObject(object, key, value, association);
}
+ (nullable id)getFTAssociatedObject:(__unsafe_unretained id)object key:(const void *)key {
    return objc_getAssociatedObject(object, key);
}
+(BOOL)swizzleInstanceMethod:(SEL)selector
                     inClass:(Class)classToSwizzle
               newImpFactory:(FTSwizzlerImpFactoryBlock)factoryBlock
                        mode:(FTSwizzlerMode)mode
                         key:(const void *)key
{
    NSAssert(!(NULL == key && FTSwizzlerModeAlways != mode),
             @"Key may not be NULL if mode is not FTSwizzlerModeAlways.");
    if (NULL == key && FTSwizzlerModeAlways != mode){
        FTInnerLogWarning(@"Key may not be NULL if mode is not FTSwizzlerModeAlways.");
        return NO;
    }
#if DEBUG
    FTSwizzleLogContext logContext = {0};
#endif
    @synchronized (self) {
        if (key){
            if (mode == FTSwizzlerModeOncePerClass) {
                if ([self getFTAssociatedObject:classToSwizzle key:key]){
                    return NO;
                }
            }else if (mode == FTSwizzlerModeOncePerClassAndSuperclasses){
                for (Class currentClass = classToSwizzle;
                     nil != currentClass;
                     currentClass = class_getSuperclass(currentClass))
                {
                    if ([self getFTAssociatedObject:currentClass key:key]) {
                        return NO;
                    }
                }
            }
        }
        swizzle(classToSwizzle, selector, factoryBlock
#if DEBUG
                , &logContext
#endif
                );
        if (key){
            [self setFTAssociatedObject:classToSwizzle key:key value:@(YES) association:OBJC_ASSOCIATION_RETAIN_NONATOMIC];
        }
    }
#if DEBUG
    if (logContext.enabled) {
        // Registering dyld callbacks must happen outside the swizzle lock to avoid
        // lock inversion with a concurrent image's +load calling this swizzler.
        FTInnerLogInfo(@"[SWIZZLE] %c[%s %s] beforeIMP:%@ afterIMP:%@ inherited:%@",
                       class_isMetaClass(classToSwizzle) ? '+' : '-',
                       class_getName(classToSwizzle),
                       sel_getName(selector),
                       FTSwizzleDescribeIMP(logContext.before),
                       FTSwizzleDescribeIMP(logContext.after),
                       logContext.inherited ? @"YES" : @"NO");
    }
#endif
    return YES;
}

+(void)swizzleClassMethod:(SEL)selector
                  inClass:(Class)classToSwizzle
            newImpFactory:(FTSwizzlerImpFactoryBlock)factoryBlock
{
    [self swizzleInstanceMethod:selector
                        inClass:object_getClass(classToSwizzle)
                  newImpFactory:factoryBlock
                           mode:FTSwizzlerModeAlways
                            key:NULL];
}
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy {
    if (!proxy) {
        return nil;
    }
    
    id realDelegate = proxy;
    id obj = nil;
    do {
        //Avoid proxy itself implementing the method or adding method implementation through resolveInstanceMethod
        if (class_getInstanceMethod(object_getClass(realDelegate), selector)) {
            break;
        }
        
        //If NSProxy is used or fast forwarding, check if forwardingTargetForSelector is implemented
        //By default, forwardingTargetForSelector has implementation, just returns nil
        obj = ((id(*)(id, SEL, SEL))objc_msgSend)(realDelegate, @selector(forwardingTargetForSelector:), selector);
        if (!obj) break;
        realDelegate = obj;
    } while (obj);
    return object_getClass(realDelegate);
}

+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel {
    //If cls inherits from NSProxy, using respondsToSelector to judge will crash
    //Because NSProxy itself does not implement respondsToSelector
    return class_respondsToSelector(cls, sel);
}

@end
