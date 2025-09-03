//
//  FTDateUtil.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDateUtil.h"

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
@end
