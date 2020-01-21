//
//  FTGPUUsage.m
//  testdemo
//
//  Created by 胡蕾蕾 on 2020/1/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTGPUUsage.h"
#import "IOKit.h"
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
    
    return dictionary;
}

- (NSString *)fetchCurrentGpuUsage{
    
    return  [NSString stringWithFormat:@"%2zd%%", [_utilizationInfo[GPUDeviceUtilizationKey] integerValue]];
   
}

@end
