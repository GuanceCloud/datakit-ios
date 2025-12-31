//
//  FTMonitorUtils.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/28.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTMonitorUtils.h"
#import "FTSDKCompat.h"
#import <mach/mach.h>
#import "FTConstants.h"
#if FT_HOST_MAC
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#else
#import <UIKit/UIKit.h>
#endif
@implementation FTMonitorUtils
#pragma mark ========== Battery ==========
//Battery level
+(double)batteryUse{
#if FT_HOST_MAC
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (info == NULL)
        return 0;
    
    CFArrayRef list = IOPSCopyPowerSourcesList(info);
    // Nothing we care about here...
    if (list == NULL || !CFArrayGetCount(list)) {
        if (list)
            CFRelease(list);
        
        CFRelease(info);
        return 0;
    }
    CFDictionaryRef battery = CFDictionaryCreateCopy(NULL, IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(list, 0)));
    
    // Battery is released by ARC transfer.
    CFRelease(list);
    CFRelease(info);
    NSDictionary *infoDict = (__bridge_transfer NSDictionary* ) battery;
    NSNumber *current_capacity = infoDict[@"Current Capacity"];
    return current_capacity?[current_capacity doubleValue]:0;
#elif TARGET_OS_IOS
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    double deviceLevel = [UIDevice currentDevice].batteryLevel;
    if (deviceLevel == -1) {
        return 0;
    }else{
        return deviceLevel*100;
    }
#endif
    return 0;
}
#pragma mark ========== Memory ==========
+ (uint64_t)totalMemBytes{
    return [NSProcessInfo processInfo].physicalMemory;
}
+ (uint64_t)availMemBytes {
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t count = sizeof(vmStats) / sizeof(natural_t);
    mach_port_t hostPort = mach_host_self();
    
    if (host_statistics(hostPort, HOST_VM_INFO, (host_info_t)&vmStats, &count) != KERN_SUCCESS) {
        return 0;
    }
    
    uint64_t pageSize = (uint64_t)vm_page_size;
    uint64_t freePages = (uint64_t)vmStats.free_count;
    uint64_t inactivePages = (uint64_t)vmStats.inactive_count;
    
    return (freePages + inactivePages) * pageSize;
}
// device memory usage
+ (float)memoryUsage{
    uint64_t total = [self totalMemBytes];
    uint64_t avail = [self availMemBytes];
    if (total <= 0) return 0;
    float usage = (float)(total - avail) / total * 100;
    return MAX(0.0f, MIN(100.0f, usage));
}
// Total memory
+(NSString *)totalMemorySize{
    return [NSString stringWithFormat:@"%.2fG",[NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0/ 1024.0];
}

#pragma mark ========== cpu ==========
+ (NSUInteger)cpuCoreCount {
    NSUInteger count = [NSProcessInfo processInfo].processorCount;
    return count > 0 ? count : 1;
}
+ (float)cpuUsage{
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    kern_return_t kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }

    float tot_cpu = 0;
    
    for (int j = 0; j < (int)thread_count; j++) {
        thread_info_data_t     thinfo;
        mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
        
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count);
        if (kr == KERN_SUCCESS) {
            thread_basic_info_t basic_info_th = (thread_basic_info_t)thinfo;
            if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
                tot_cpu += basic_info_th->cpu_usage / (float)TH_USAGE_SCALE;
            }
        }
    }
    vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));

    return (tot_cpu / [self cpuCoreCount]) * 100.0f;
}
@end
