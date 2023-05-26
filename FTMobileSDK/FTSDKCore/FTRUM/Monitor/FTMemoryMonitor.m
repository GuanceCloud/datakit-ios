//
//  FTMemoryMonitor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/1.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMemoryMonitor.h"
#import <mach/mach.h>
#import "FTInternalLog.h"

@implementation FTMemoryMonitor
- (double)memoryUsage {
    int64_t memoryUsageInByte = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = (int64_t) vmInfo.phys_footprint;
    } else {
        ZYLogError(@"Error with task_info(): %s", mach_error_string(kernelReturn));
    }
    return memoryUsageInByte;
}
@end
