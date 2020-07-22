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
#import "FTConstants.h"
#define setUUID(uuid) [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:@"FTSDKUUID"]
#define getUUID        [[NSUserDefaults standardUserDefaults] valueForKey:@"FTSDKUUID"]
#define FTAPP_DNAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
#define FTAPP_NAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]

@implementation FTMobileConfig

- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl datawayToken:(nullable NSString *)token akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning{
    if (self = [super init]) {
        _metricsUrl = metricsUrl;
        _datawayToken = token;
        _akId = akId;
        _akSecret = akSecret;
        _enableRequestSigning = enableRequestSigning;
        _sdkAgentVersion = SDK_VERSION;
        _appName = FTAPP_DNAME?FTAPP_DNAME:FTAPP_NAME;
        _enableLog = NO;
        _autoTrackEventType = FTAutoTrackTypeNone;
        _enableAutoTrack = NO;
        _needBindUser = NO;
        _XDataKitUUID = [self ft_defaultUUID];
        _enableDescLog = NO;
        _enableTrackAppCrash= NO;
        _traceSamplingRate = 1;
        _traceServiceName = FT_DEFAULT_SERVICE_NAME;
        _networkTrace = NO;
        _traceConsoleLog = NO;
        _eventFlowLog = NO;
        _networkTrace = FTNetworkTrackTypeZipkin;
        _enabledPageVtpDesc = NO;
    }
      return self;
}
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl datawayToken:(nullable NSString *)token{
    return [self initWithMetricsUrl:metricsUrl datawayToken:token akId:nil akSecret:nil enableRequestSigning:NO];
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.metricsUrl = self.metricsUrl;
    options.datawayToken = self.datawayToken;
    options.autoTrackEventType = self.autoTrackEventType;
    options.akId = self.akId;
    options.akSecret = self.akSecret;
    options.enableRequestSigning = self.enableRequestSigning;

    options.sdkAgentVersion = self.sdkAgentVersion;
    options.sdkTrackVersion = self.sdkTrackVersion;
    
    options.appName = self.appName;
    options.enableLog = self.enableLog;
    options.needBindUser = self.needBindUser;
    options.XDataKitUUID = self.XDataKitUUID;
    options.enableDescLog = self.enableDescLog;
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.traceSamplingRate = self.traceSamplingRate;
    options.traceServiceName = self.traceServiceName;
    options.traceConsoleLog = self.traceConsoleLog;
    options.networkTrace = self.networkTrace;
    options.eventFlowLog = self.eventFlowLog;
    options.networkTraceType = self.networkTraceType;
    options.networkContentType = self.networkContentType;
    options.enabledPageVtpDesc = self.enabledPageVtpDesc;
    return options;
}
-(void)setEnableAutoTrack:(BOOL)enableAutoTrack{
    _enableAutoTrack = enableAutoTrack;
}
-(void)setEnableLog:(BOOL)enableLog{
    _enableLog = enableLog;
}
-(void)setEnableDescLog:(BOOL)enableDescLog{
    _enableDescLog = enableDescLog;
}

-(void)setEnableTrackAppCrash:(BOOL)enableTrackAppCrash{
    _enableTrackAppCrash = enableTrackAppCrash;
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
-(void)networkTraceWithTraceType:(FTNetworkTrackType)type{
    self.networkTrace = YES;
    self.networkTraceType = type;
}
@end
