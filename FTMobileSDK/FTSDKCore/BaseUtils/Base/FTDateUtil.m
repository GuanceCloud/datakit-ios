//
//  FTDateUtil.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDateUtil.h"
#import <sys/sysctl.h>

struct timeval ft_processStartTime(void) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc kp;
    size_t len = sizeof(kp);
    int res = sysctl(mib, 4, &kp, &len, NULL, 0);
    struct timeval value = { 0 };
    if (res == 0) {
        value = kp.kp_proc.p_un.__p_starttime;
    }
    return value;
}

@implementation FTDateUtil
+ (NSDate *)date{
    return [NSDate date];
}
+ (uint64_t)systemTime{
    return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}
+ (CFTimeInterval)systemUptime{
    return NSProcessInfo.processInfo.systemUptime;
}
+ (NSDate *)processStartTimestamp{
    struct timeval startTime = ft_processStartTime();
    return [NSDate dateWithTimeIntervalSince1970:startTime.tv_sec + startTime.tv_usec / 1E6];
}
@end
