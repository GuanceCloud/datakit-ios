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
#import "FTConstants.h"
@implementation FTRumConfig
- (instancetype)init{
    return [self initWithAppid:@""];
}
- (instancetype)initWithAppid:(nonnull NSString *)appid{
    self = [super init];
    if (self) {
        _appid = appid;
        _enableTrackAppCrash= NO;
        _samplerate = 100;
        _enableTrackAppFreeze = NO;
        _enableTrackAppANR = NO;
        _enableTraceUserAction = NO;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTRumConfig *options = [[[self class] allocWithZone:zone] init];
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.samplerate = self.samplerate;
    options.enableTrackAppFreeze = self.enableTrackAppFreeze;
    options.enableTrackAppANR = self.enableTrackAppANR;
    options.enableTraceUserAction = self.enableTraceUserAction;
    options.appid = self.appid;
    options.monitorInfoType = self.monitorInfoType;
    return options;
}
@end
@implementation FTLoggerConfig
-(instancetype)init{
    self = [super init];
    if (self) {
        _serviceName = FT_LOGGER_SERVICE_NAME;
        _samplerate = 100;
        _traceConsoleLog = NO;
        _enableLinkRumData = NO;
        _enableCustomLog = NO;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTLoggerConfig *options = [[[self class] allocWithZone:zone] init];
    options.serviceName = self.serviceName;
    options.samplerate = self.samplerate;
    options.traceConsoleLog = self.traceConsoleLog;
    options.enableLinkRumData = self.enableLinkRumData;
    options.enableCustomLog = self.enableCustomLog;
    return options;
}
@end
@implementation FTTraceConfig
-(instancetype)init{
    self = [super init];
    if (self) {
        _samplerate= 100;
        _networkTrace = NO;
        _networkTrace = FTNetworkTraceTypeZipkin;
        _serviceName = FT_DEFAULT_SERVICE_NAME;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTTraceConfig *options = [[[self class] allocWithZone:zone] init];
    options.networkTrace = self.networkTrace;
    options.samplerate = self.samplerate;
    options.serviceName = self.serviceName;
    options.enableLinkRumData = self.enableLinkRumData;
    options.networkTraceType = self.networkTraceType;
    return options;
}
@end
@implementation FTMobileConfig
-(instancetype)initWithMetricsUrl:(NSString *)metricsUrl{
    if (self = [super init]) {
        _metricsUrl = metricsUrl;
        _enableSDKDebugLog = NO;
        _XDataKitUUID = [FTBaseInfoHander XDataKitUUID];
        _version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        _env = FTEnvProd;
    }
    return self;
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.metricsUrl = self.metricsUrl;
    options.enableSDKDebugLog = self.enableSDKDebugLog;
    options.XDataKitUUID = self.XDataKitUUID;
    options.env = self.env;
    options.version = self.version;
    return options;
}
@end
