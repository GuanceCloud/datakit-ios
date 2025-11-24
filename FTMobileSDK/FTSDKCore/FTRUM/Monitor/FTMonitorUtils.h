//
//  FTMonitorUtils.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// Monitoring item related data acquisition tool
@interface FTMonitorUtils : NSObject
/// Get current app CPU usage
+ (float)cpuUsage;
/// Get current battery usage
+ (double)batteryUse;
/// Get device total memory
+ (NSString *)totalMemorySize;
/// Get current device memory usage
+ (float)memoryUsage;
@end

NS_ASSUME_NONNULL_END
