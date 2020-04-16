//
//  FTMobileConfig.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTMobileConfig.h"
#import "FTBaseInfoHander.h"
#import "ZYLog.h"
#import "FTMobileAgentVersion.h"

#define setUUID(uuid) [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:@"FTSDKUUID"]
#define getUUID        [[NSUserDefaults standardUserDefaults] valueForKey:@"FTSDKUUID"]
#define FTAPP_DNAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
#define FTAPP_NAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]

@implementation FTMobileConfig

- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning{
     if (self = [super init]) {
         self.metricsUrl = metricsUrl;
         self.akId = akId;
         self.akSecret = akSecret;
         self.enableRequestSigning = enableRequestSigning;
         self.sdkAgentVersion = SDK_VERSION;
         self.appName = FTAPP_DNAME?FTAPP_DNAME:FTAPP_NAME;
         self.enableLog = NO;
         self.autoTrackEventType = FTAutoTrackTypeNone;
         self.enableAutoTrack = NO;
         self.needBindUser = NO;
         self.enableScreenFlow = NO;
         self.XDataKitUUID = [self ft_defaultUUID];
         self.flushInterval = 10 * 1000;
        }
      return self;
}
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl{
    return [self initWithMetricsUrl:metricsUrl akId:nil akSecret:nil enableRequestSigning:NO];
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.metricsUrl = self.metricsUrl;
    options.autoTrackEventType = self.autoTrackEventType;
    options.akId = self.akId;
    options.akSecret = self.akSecret;
    options.enableRequestSigning = self.enableRequestSigning;

    options.sdkAgentVersion = self.sdkAgentVersion;
    options.sdkTrackVersion = self.sdkTrackVersion;
    
    options.appName = self.appName;
    options.enableLog = self.enableLog;
    options.needBindUser = self.needBindUser;
    options.enableScreenFlow = self.enableScreenFlow;
    options.XDataKitUUID = self.XDataKitUUID;
    options.flushInterval = self.flushInterval;

    return options;
}
- (void)setFlushInterval:(NSInteger)flushInterval {
    _flushInterval = flushInterval >= 5000 ? flushInterval : 5000;
}
-(void)setEnableAutoTrack:(BOOL)enableAutoTrack{
    _enableAutoTrack = enableAutoTrack;
}
-(void)setEnableLog:(BOOL)enableLog{
     SETISDEBUG(enableLog);
}
-(void)enableTrackScreenFlow:(BOOL)enable{
    self.enableScreenFlow = enable;
}
-(void)setTrackViewFlowProduct:(NSString *)product{
    self.product = product;
}
-(void)setXDataKitUUID:(NSString *)XDataKitUUID{
    if (XDataKitUUID.length>0) {
        _XDataKitUUID = XDataKitUUID;
        setUUID(XDataKitUUID);
    }else{
        ZYLog(@"setXDatakitUUID fail");
    }
}
- (NSString *)ft_defaultUUID {
    NSString *deviceId;
    deviceId =getUUID;
    if (!deviceId) {
        deviceId = [[NSUUID UUID] UUIDString];
        setUUID(deviceId);
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return deviceId;
}
@end
