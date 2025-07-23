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
#if FT_MAC
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#else
#import <UIKit/UIKit.h>
#endif
@implementation FTMonitorUtils
#pragma mark ========== Battery ==========
//Battery level
+(double)batteryUse{
#if FT_MAC
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
//Memory occupied by current task
+ (float)usedMemory{
    int64_t memoryUsageInByte = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = (int64_t) vmInfo.phys_footprint;
    } else {
        return 0;
    }
    double total = [NSProcessInfo processInfo].physicalMemory ;
    return memoryUsageInByte/total*100.00;
}
//Total memory
+(NSString *)totalMemorySize{
    return [NSString stringWithFormat:@"%.2fG",[NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0/ 1024.0];
    
}

#pragma mark ========== cpu ==========
+ (long )cpuUsage{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    
    // mach_task_self(), means get the current Mach task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }

    float tot_cpu = 0;
    for (int j = 0; j < (int)thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
        
    } // for each thread
    
    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);
    
    return tot_cpu;
}

@end
