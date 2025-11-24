//
//  FTCrashDebug.c
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/4.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#include "FTCrashDebug.h"
#include <errno.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>

#include "FTCrashLogger.h"

bool ftdebug_isBeingTraced(void)
{
    struct kinfo_proc procInfo;
    size_t structSize = sizeof(procInfo);
    int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };

    if (sysctl(mib, sizeof(mib) / sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0) {
        FTLOG_ERROR("sysctl: %s", strerror(errno));
        return false;
    }

    return (procInfo.kp_proc.p_flag & P_TRACED) != 0;
}
