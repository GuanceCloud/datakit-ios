//
//  FTMobileConfig.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTMobileConfig.h"
#import "FTBaseInfoHander.h"
#import "FTLog.h"
#import "FTMobileAgentVersion.h"

#define setUUID(uuid) [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:@"FTSDKUUID"]
#define getUUID        [[NSUserDefaults standardUserDefaults] valueForKey:@"FTSDKUUID"]
#define FTAPP_DNAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
#define FTAPP_NAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]

@implementation FTMobileConfig

- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning{
     if (self = [super init]) {
         _metricsUrl = metricsUrl;
         _akId = akId;
         _akSecret = akSecret;
         _enableRequestSigning = enableRequestSigning;
         _sdkAgentVersion = SDK_VERSION;
         _appName = FTAPP_DNAME?FTAPP_DNAME:FTAPP_NAME;
         _enableLog = NO;
         _autoTrackEventType = FTAutoTrackTypeNone;
         _enableAutoTrack = NO;
         _needBindUser = NO;
         _enableScreenFlow = NO;
         _XDataKitUUID = [self ft_defaultUUID];
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
    return options;
}
-(void)setEnableAutoTrack:(BOOL)enableAutoTrack{
    _enableAutoTrack = enableAutoTrack;
}
-(void)setEnableLog:(BOOL)enableLog{
    _enableLog = enableLog;
}
-(void)enableTrackScreenFlow:(BOOL)enable{
    _enableScreenFlow = enable;
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
