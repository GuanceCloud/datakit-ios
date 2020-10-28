//
//  FTMobileConfig.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTMobileConfig.h"
#import "FTBaseInfoHander.h"
#import "FTLog.h"
#import "FTConstants.h"
#define setUUID(uuid) [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:@"FTSDKUUID"]
#define getUUID        [[NSUserDefaults standardUserDefaults] valueForKey:@"FTSDKUUID"]

@implementation FTMobileConfig

- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl datawayToken:(nullable NSString *)token akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning{
    if (self = [super init]) {
        _metricsUrl = metricsUrl;
        _datawayToken = token;
        _akId = akId;
        _akSecret = akSecret;
        _enableRequestSigning = enableRequestSigning;
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
        _networkTrace = FTNetworkTraceTypeZipkin;
        _enabledPageVtpDesc = NO;
        _source = FT_USER_AGENT;
        _enableTrackAppUIBlock = NO;
        _enableTrackAppANR = NO;

#if DEBUG
        _env = @"dev";
#else
        _env = @"release";
#endif
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
    options.source = self.source;
    options.env = self.env;
    options.enableTrackAppUIBlock = self.enableTrackAppUIBlock;
    options.enableTrackAppANR = self.enableTrackAppANR;
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
-(void)networkTraceWithTraceType:(FTNetworkTraceType)type{
    self.networkTrace = YES;
    self.networkTraceType = type;
}
@end
