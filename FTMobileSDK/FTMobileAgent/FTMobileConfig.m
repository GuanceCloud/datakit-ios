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
-(instancetype)initWithDatawayUrl:(NSString *)datawayUrl datawayToken:(NSString *)token akId:(NSString *)akId akSecret:(NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning{
    if (self = [super init]) {
        _datawayUrl = datawayUrl;
        _datawayToken = token;
        _akId = akId;
        _akSecret = akSecret;
        _enableRequestSigning = enableRequestSigning;
        _enableLog = NO;
        _needBindUser = NO;
        _XDataKitUUID = [self ft_defaultUUID];
        _enableTrackAppCrash= NO;
        _samplerate = 100;
        _traceServiceName = FT_DEFAULT_SERVICE_NAME;
        _source = FT_USER_AGENT;
        _networkTrace = NO;
        _networkTrace = FTNetworkTraceTypeZipkin;
        _enableTrackAppUIBlock = NO;
        _enableTrackAppANR = NO;
        _version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    }
      return self;
}
-(instancetype)initWithDatawayUrl:(NSString *)datawayUrl datawayToken:(NSString *)token{
  return [self initWithDatawayUrl:datawayUrl datawayToken:token akId:nil akSecret:nil enableRequestSigning:NO];
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.datawayUrl = self.datawayUrl;
    options.datawayToken = self.datawayToken;
    options.akId = self.akId;
    options.akSecret = self.akSecret;
    options.enableRequestSigning = self.enableRequestSigning;
    options.enableLog = self.enableLog;
    options.needBindUser = self.needBindUser;
    options.XDataKitUUID = self.XDataKitUUID;
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.samplerate = self.samplerate;
    options.traceServiceName = self.traceServiceName;
    options.source = self.source;
    options.networkTrace = self.networkTrace;
    options.networkTraceType = self.networkTraceType;
    options.networkContentType = self.networkContentType;
    options.env = self.env;
    options.enableTrackAppUIBlock = self.enableTrackAppUIBlock;
    options.enableTrackAppANR = self.enableTrackAppANR;
    options.version = self.version;
    return options;
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
