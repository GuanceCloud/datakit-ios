//
//  FTMonitorUtils.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/28.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTMonitorUtils.h"
#import <mach/mach.h>
#import "FTConstants.h"
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
@implementation FTMonitorUtils
#pragma mark ========== 电池 ==========
#if !TARGET_OS_OSX
//电池电量
+(double)batteryUse{
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    double deviceLevel = [UIDevice currentDevice].batteryLevel;
    if (deviceLevel == -1) {
        return 0;
    }else{
        return deviceLevel*100;
    }
}
#endif
#pragma mark ========== 内存 ==========
//当前任务所占用的内存
+ (double)usedMemory
{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(),
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return 0;
    }
    
    double availableMemory = ((vm_page_size * vmStats.free_count) / 1024.0) / 1024.0;
    double total = [NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0;
    double numFloat =(total-availableMemory)/total;
    return numFloat*100;
}
//总内存
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
    
    // mach_task_self()，表示获取当前的 Mach task
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
