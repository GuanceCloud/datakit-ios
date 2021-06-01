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

@implementation FTMobileConfig
-(instancetype)initWithMetricsUrl:(NSString *)metricsUrl{
    if (self = [super init]) {
        _metricsUrl = metricsUrl;
        _enableSDKDebugLog = NO;
        _XDataKitUUID = [FTBaseInfoHander XDataKitUUID];
        _enableTrackAppCrash= NO;
        _samplerate = 100;
        _serviceName = FT_DEFAULT_SERVICE_NAME;
        _source = FT_USER_AGENT;
        _networkTrace = NO;
        _networkTrace = FTNetworkTraceTypeZipkin;
        _enableTrackAppFreeze = NO;
        _enableTrackAppANR = NO;
        _traceConsoleLog = NO;
        _version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        _env = FTEnvProd;
        _enableTraceUserAction = NO;
    }
      return self;
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.metricsUrl = self.metricsUrl;
    options.enableSDKDebugLog = self.enableSDKDebugLog;
    options.XDataKitUUID = self.XDataKitUUID;
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.samplerate = self.samplerate;
    options.serviceName = self.serviceName;
    options.source = self.source;
    options.networkTrace = self.networkTrace;
    options.networkTraceType = self.networkTraceType;
    options.env = self.env;
    options.enableTrackAppFreeze = self.enableTrackAppFreeze;
    options.enableTrackAppANR = self.enableTrackAppANR;
    options.version = self.version;
    options.traceConsoleLog = self.traceConsoleLog;
    options.appid = self.appid;
    options.monitorInfoType = self.monitorInfoType;
    options.enableTraceUserAction = self.enableTraceUserAction;
    return options;
}
-(void)networkTraceWithTraceType:(FTNetworkTraceType)type{
    self.networkTrace = YES;
    self.networkTraceType = type;
}
@end
