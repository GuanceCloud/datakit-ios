//
//  FTErrorMonitorInfo.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/9.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTErrorMonitorInfo.h"
#import "FTConstants.h"
#import "FTMonitorUtils.h"
@implementation FTErrorMonitorInfo
+ (NSDictionary *)errorMonitorInfo:(ErrorMonitorType)monitorType{
    NSMutableDictionary *errorTag = [NSMutableDictionary new];
    if (monitorType & ErrorMonitorMemory) {
        errorTag[FT_MEMORY_TOTAL] = [FTMonitorUtils totalMemorySize];
        errorTag[FT_MEMORY_USE] = [NSNumber numberWithFloat:[FTMonitorUtils usedMemory]];
    }
    if (monitorType & ErrorMonitorCpu) {
        errorTag[FT_CPU_USE] = [NSNumber numberWithLong:[FTMonitorUtils cpuUsage]];
    }
    if (monitorType & ErrorMonitorBattery) {
        errorTag[FT_BATTERY_USE] =[NSNumber numberWithDouble:[FTMonitorUtils batteryUse]];
    }
#if FT_IOS
    errorTag[FT_KEY_CARRIER] = [FTBaseInfoHandler telephonyCarrier];
#endif
    NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    errorTag[FT_KEY_LOCALE] = preferredLanguage;
    return errorTag;
}
@end
