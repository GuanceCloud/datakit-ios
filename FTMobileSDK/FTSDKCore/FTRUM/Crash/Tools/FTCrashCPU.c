//
//  FTCrashCPU.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTCrashCPU.h"
#include <mach-o/arch.h>
#include <mach/mach.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 160000  // Xcode 14
#include <mach-o/utils.h>
#define _HAS_MACH_O_UTILS 1
#else
#define _HAS_MACH_O_UTILS 0
#endif
static inline const char *currentArch_nx(void)
{
    const NXArchInfo *archInfo = NXGetLocalArchInfo();
    return archInfo == NULL ? NULL : archInfo->name;
}

const char *ftcpu_currentArch(void){
#if _HAS_MACH_O_UTILS
    if (__builtin_available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 8.0, *))
    {
        return macho_arch_name_for_mach_header(NULL);
    }
    else {
        return currentArch_nx();
    }
#else   // _HAS_MACH_O_UTILS
    return currentArch_nx();
#endif  // _HAS_MACH_O_UTILS
}

bool
ftcrashcpu_i_fillState(const thread_t thread, const thread_state_t state,
    const thread_state_flavor_t flavor, const mach_msg_type_number_t stateCount)
{
    //("Filling thread state with flavor %x.", flavor);
    mach_msg_type_number_t stateCountBuff = stateCount;
    kern_return_t kr;

    kr = thread_get_state(thread, flavor, state, &stateCountBuff);
    if (kr != KERN_SUCCESS) {
        //("thread_get_state: %s", mach_error_string(kr));
        return false;
    }
    return true;
}
