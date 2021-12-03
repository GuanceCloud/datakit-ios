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
#import "FTBaseInfoHandler.h"
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
        _enableTraceUserView = NO;
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
    options.enableTraceUserView = self.enableTraceUserView;
    options.appid = self.appid;
    options.monitorInfoType = self.monitorInfoType;
    options.globalContext = self.globalContext;
    return options;
}
@end
@implementation FTLoggerConfig
-(instancetype)init{
    self = [super init];
    if (self) {
        _service = FT_DEFAULT_SERVICE_NAME;
        _discardType = FTDiscard;
        _samplerate = 100;
        _enableConsoleLog = NO;
        _enableLinkRumData = NO;
        _enableCustomLog = NO;
        _prefix = @"";
        _logLevelFilter = @[@0,@1,@2,@3,@4];
    }
    return self;
}
- (void)enableConsoleLog:(BOOL)enable prefix:(NSString *)prefix{
    _enableConsoleLog = enable;
    _prefix = prefix;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTLoggerConfig *options = [[[self class] allocWithZone:zone] init];
    options.service = self.service;
    options.samplerate = self.samplerate;
    options.enableConsoleLog = self.enableConsoleLog;
    options.enableLinkRumData = self.enableLinkRumData;
    options.enableCustomLog = self.enableCustomLog;
    options.prefix = self.prefix;
    options.logLevelFilter = self.logLevelFilter;
    options.discardType = self.discardType;
    return options;
}
@end
@implementation FTTraceConfig
-(instancetype)init{
    self = [super init];
    if (self) {
        _samplerate= 100;
        _networkTraceType = FTNetworkTraceTypeZipkin;
        _service = FT_DEFAULT_SERVICE_NAME;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTTraceConfig *options = [[[self class] allocWithZone:zone] init];
    options.samplerate = self.samplerate;
    options.service = self.service;
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
        _XDataKitUUID = [FTBaseInfoHandler XDataKitUUID];
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
