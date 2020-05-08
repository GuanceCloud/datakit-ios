//
//  FTGPUUsage.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTGPUUsage.h"
#include <stdint.h>
#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>
typedef char io_name_t[128];
typedef char io_string_t[512];
typedef char io_struct_inband_t[4096];
typedef mach_port_t io_object_t;
typedef io_object_t io_registry_entry_t;
typedef io_object_t io_service_t;
typedef io_object_t io_connect_t;
typedef io_object_t io_iterator_t;

enum
{
    kIOCFSerializeToBinary          = 0x00000001U,
};

enum
{
    kIOReturnSuccess                = 0,
};

enum
{
    kIORegistryIterateRecursively   = 0x00000001U,
    kIORegistryIterateParents       = 0x00000002U,
};

enum
{
    kOSSerializeDictionary          = 0x01000000U,
    kOSSerializeArray               = 0x02000000U,
    kOSSerializeSet                 = 0x03000000U,
    kOSSerializeNumber              = 0x04000000U,
    kOSSerializeSymbol              = 0x08000000U,
    kOSSerializeString              = 0x09000000U,
    kOSSerializeData                = 0x0a000000U,
    kOSSerializeBoolean             = 0x0b000000U,
    kOSSerializeObject              = 0x0c000000U,
    
    kOSSerializeTypeMask            = 0x7F000000U,
    kOSSerializeDataMask            = 0x00FFFFFFU,
    
    kOSSerializeEndCollection       = 0x80000000U,
    
    kOSSerializeMagic               = 0x000000d3U,
};

extern const mach_port_t kIOMasterPortDefault;

CF_RETURNS_RETAINED CFDataRef IOCFSerialize(CFTypeRef object, CFOptionFlags options);
CFTypeRef IOCFUnserializeWithSize(const char *buf, size_t len, CFAllocatorRef allocator, CFOptionFlags options, CFStringRef *err);

kern_return_t IOObjectRetain(io_object_t object);
kern_return_t IOObjectRelease(io_object_t object);
boolean_t IOObjectConformsTo(io_object_t object, const io_name_t name);
uint32_t IOObjectGetKernelRetainCount(io_object_t object);
kern_return_t IOObjectGetClass(io_object_t object, io_name_t name);
CFStringRef IOObjectCopyClass(io_object_t object);
CFStringRef IOObjectCopySuperclassForClass(CFStringRef name);
CFStringRef IOObjectCopyBundleIdentifierForClass(CFStringRef name);

io_registry_entry_t IORegistryGetRootEntry(mach_port_t master);
kern_return_t IORegistryEntryGetName(io_registry_entry_t entry, io_name_t name);
kern_return_t IORegistryEntryGetRegistryEntryID(io_registry_entry_t entry, uint64_t *entryID);
kern_return_t IORegistryEntryGetPath(io_registry_entry_t entry, const io_name_t plane, io_string_t path);
kern_return_t IORegistryEntryGetProperty(io_registry_entry_t entry, const io_name_t name, io_struct_inband_t buffer, uint32_t *size);
kern_return_t IORegistryEntryCreateCFProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, uint32_t options);
CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, uint32_t options);
kern_return_t IORegistryEntrySetCFProperties(io_registry_entry_t entry, CFTypeRef properties);

kern_return_t IORegistryCreateIterator(mach_port_t master, const io_name_t plane, uint32_t options, io_iterator_t *it);
kern_return_t IORegistryEntryCreateIterator(io_registry_entry_t entry, const io_name_t plane, uint32_t options, io_iterator_t *it);
kern_return_t IORegistryEntryGetChildIterator(io_registry_entry_t entry, const io_name_t plane, io_iterator_t *it);
kern_return_t IORegistryEntryGetParentIterator(io_registry_entry_t entry, const io_name_t plane, io_iterator_t *it);
io_object_t IOIteratorNext(io_iterator_t it);
boolean_t IOIteratorIsValid(io_iterator_t it);
void IOIteratorReset(io_iterator_t it);

CFMutableDictionaryRef IOServiceMatching(const char *name) CF_RETURNS_RETAINED;
CFMutableDictionaryRef IOServiceNameMatching(const char *name) CF_RETURNS_RETAINED;
io_service_t IOServiceGetMatchingService(mach_port_t master, CFDictionaryRef matching CF_RELEASES_ARGUMENT);
kern_return_t IOServiceGetMatchingServices(mach_port_t master, CFDictionaryRef matching CF_RELEASES_ARGUMENT, io_iterator_t *it);
kern_return_t _IOServiceGetAuthorizationID(io_service_t service, uint64_t *authID);
kern_return_t _IOServiceSetAuthorizationID(io_service_t service, uint64_t authID);
kern_return_t IOServiceOpen(io_service_t service, task_t task, uint32_t type, io_connect_t *client);
kern_return_t IOServiceClose(io_connect_t client);
kern_return_t IOCloseConnection(io_connect_t client);
kern_return_t IOConnectAddRef(io_connect_t client);
kern_return_t IOConnectRelease(io_connect_t client);
kern_return_t IOConnectGetService(io_connect_t client, io_service_t *service);
kern_return_t IOConnectAddClient(io_connect_t client, io_connect_t other);
kern_return_t IOConnectSetNotificationPort(io_connect_t client, uint32_t type, mach_port_t port, uintptr_t ref);
kern_return_t IOConnectMapMemory64(io_connect_t client, uint32_t type, task_t task, mach_vm_address_t *addr, mach_vm_size_t *size, uint32_t options);
kern_return_t IOConnectUnmapMemory64(io_connect_t client, uint32_t type, task_t task, mach_vm_address_t addr);
kern_return_t IOConnectSetCFProperties(io_connect_t client, CFTypeRef properties);
kern_return_t IOConnectCallMethod(io_connect_t client, uint32_t selector, const uint64_t *in, uint32_t inCnt, const void *inStruct, size_t inStructCnt, uint64_t *out, uint32_t *outCnt, void *outStruct, size_t *outStructCnt);
kern_return_t IOConnectCallScalarMethod(io_connect_t client, uint32_t selector, const uint64_t *in, uint32_t inCnt, uint64_t *out, uint32_t *outCnt);
kern_return_t IOConnectCallStructMethod(io_connect_t client, uint32_t selector, const void *inStruct, size_t inStructCnt, void *outStruct, size_t *outStructCnt);
kern_return_t IOConnectCallAsyncMethod(io_connect_t client, uint32_t selector, mach_port_t wake_port, uint64_t *ref, uint32_t refCnt, const uint64_t *in, uint32_t inCnt, const void *inStruct, size_t inStructCnt, uint64_t *out, uint32_t *outCnt, void *outStruct, size_t *outStructCnt);
kern_return_t IOConnectCallAsyncScalarMethod(io_connect_t client, uint32_t selector, mach_port_t wake_port, uint64_t *ref, uint32_t refCnt, const uint64_t *in, uint32_t inCnt, uint64_t *out, uint32_t *outCnt);
kern_return_t IOConnectCallAsyncStructMethod(io_connect_t client, uint32_t selector, mach_port_t wake_port, uint64_t *ref, uint32_t refCnt, const void *inStruct, size_t inStructCnt, void *outStruct, size_t *outStructCnt);
kern_return_t IOConnectTrap6(io_connect_t client, uint32_t index, uintptr_t a, uintptr_t b, uintptr_t c, uintptr_t d, uintptr_t e, uintptr_t f);

const char *kIOServicePlane = "IOService";
#define GPU_UTILI_KEY(key, value)   static NSString * const GPU ## key ##Key = @#value;

GPU_UTILI_KEY(DeviceUtilization, Device Utilization %)
GPU_UTILI_KEY(RendererUtilization, Renderer Utilization %)
GPU_UTILI_KEY(TilerUtilization, Tiler Utilization %)
GPU_UTILI_KEY(HardwareWaitTime, hardwareWaitTime)
GPU_UTILI_KEY(FinishGLWaitTime, finishGLWaitTime)
GPU_UTILI_KEY(FreeToAllocGPUAddressWaitTime, freeToAllocGPUAddressWaitTime)
GPU_UTILI_KEY(ContextGLCount, contextGLCount)
GPU_UTILI_KEY(RenderCount, CommandBufferRenderCount)
GPU_UTILI_KEY(RecoveryCount, recoveryCount)
GPU_UTILI_KEY(TextureCount, textureCount)

@implementation FTGPUUsage{
    NSDictionary        * _utilizationInfo;
}
-(instancetype)init{
    self = [super init];
    if (self) {
      _utilizationInfo =  [self utilizeDictionary];
    }
    return self;
}
- (NSDictionary *)utilizeDictionary
{
    NSDictionary *dictionary = nil;
#if FT_TRACK_GPUUSAGE

    io_iterator_t iterator;
#if TARGET_IPHONE_SIMULATOR
    
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("IntelAccelerator"), &iterator) == kIOReturnSuccess) {
        
        for (io_registry_entry_t regEntry = IOIteratorNext(iterator); regEntry; regEntry = IOIteratorNext(iterator)) {
            CFMutableDictionaryRef serviceDictionary;
            if (IORegistryEntryCreateCFProperties(regEntry, &serviceDictionary, kCFAllocatorDefault, kNilOptions) != kIOReturnSuccess) {
                IOObjectRelease(regEntry);
                continue;
            }
            
            dictionary = ((__bridge NSDictionary *)serviceDictionary)[@"PerformanceStatistics"];
            
            CFRelease(serviceDictionary);
            IOObjectRelease(regEntry);
            break;
        }
        IOObjectRelease(iterator);
    }
    
#elif TARGET_OS_IOS
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("sgx"), &iterator) == kIOReturnSuccess) {
        
        for (io_registry_entry_t regEntry = IOIteratorNext(iterator); regEntry; regEntry = IOIteratorNext(iterator)) {
            
            io_iterator_t innerIterator;
            if (IORegistryEntryGetChildIterator(regEntry, kIOServicePlane, &innerIterator) == kIOReturnSuccess) {
                
                for (io_registry_entry_t gpuEntry = IOIteratorNext(innerIterator); gpuEntry ; gpuEntry = IOIteratorNext(innerIterator)) {
                    CFMutableDictionaryRef serviceDictionary;
                    if (IORegistryEntryCreateCFProperties(gpuEntry, &serviceDictionary, kCFAllocatorDefault, kNilOptions) != kIOReturnSuccess) {
                        IOObjectRelease(gpuEntry);
                        continue;
                    }
                    else {
                        dictionary = ((__bridge NSDictionary *)serviceDictionary)[@"PerformanceStatistics"];
                        
                        CFRelease(serviceDictionary);
                        IOObjectRelease(gpuEntry);
                        break;
                    }
                }
                IOObjectRelease(innerIterator);
                IOObjectRelease(regEntry);
                break;
            }
            IOObjectRelease(regEntry);
        }
        IOObjectRelease(iterator);
    }
#endif
#endif

    return dictionary;
}

- (double)fetchCurrentGpuUsage{
#if FT_TRACK_GPUUSAGE

    return   [_utilizationInfo[GPUDeviceUtilizationKey] doubleValue];
#endif
    return 0;
}

@end
