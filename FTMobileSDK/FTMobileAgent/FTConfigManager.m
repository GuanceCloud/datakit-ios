//
//  FTConfigManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/6.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTConfigManager.h"
#import "FTMobileAgentVersion.h"
#import "FTNetworkInfoManager.h"
@implementation FTConfigManager
static dispatch_once_t onceToken;
static FTConfigManager *sharedInstance = nil;

+ (instancetype)sharedInstance{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(void)setTrackConfig:(FTMobileConfig *)trackConfig{
    _trackConfig = [trackConfig copy];
    [FTNetworkInfoManager sharedInstance].setMetricsUrl(trackConfig.metricsUrl)
    .setSdkVersion(SDK_VERSION)
    .setXDataKitUUID(trackConfig.XDataKitUUID);
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = [rumConfig copy];
}
-(void)setTraceConfig:(FTTraceConfig *)traceConfig{
    _traceConfig = [traceConfig copy];
}
- (void)resetInstance{
    onceToken = 0;
    sharedInstance =nil;
}
@end
