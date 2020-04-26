//
//  FTMonitorManager+MoniorUtils.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/22.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTMonitorManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTMonitorManager (MoniorUtils)
+ (NSString *)getLaunchSystemTime;

+ (NSString *)userDeviceName;
+ (NSDictionary *)getDNSInfo;
+ (NSDictionary *)getWifiAndIPAddress;
+ (NSString *)getCurrentWifiSSID;
+ (NSString *)getIPAddress;
+ (CGFloat)screenBrightness;
+ (float)getTorchLevel;
+ (BOOL)getProximityState;
@end

NS_ASSUME_NONNULL_END
