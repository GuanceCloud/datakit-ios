//
//  FTRumConfig.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/22.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRumConfig.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTEnumConstant.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTJSONUtil.h"
#import "FTLog+Private.h"
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
        _sessionOnErrorSampleRate = 0;
        _enableTrackAppFreeze = NO;
        _enableTrackAppANR = NO;
        _enableTraceUserAction = NO;
        _enableTraceUserView = NO;
        _enableTraceUserResource = NO;
        _enableResourceHostIP = NO;
        _monitorFrequency = FTMonitorFrequencyDefault;
        _freezeDurationMs = FT_DEFAULT_BLOCK_DURATIONS_MS;
        _rumCacheLimitCount = FT_DB_RUM_MAX_COUNT;
        _rumDiscardType = FTRUMDiscard;
        _enableTraceWebView = YES;
        _crashMonitoring = FTCrashMonitorTypeHighCompatibility;
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
    options.enableTraceUserResource = self.enableTraceUserResource;
    options.enableResourceHostIP = self.enableResourceHostIP;
    options.appid = self.appid;
    options.errorMonitorType = self.errorMonitorType;
    options.globalContext = self.globalContext;
    options.deviceMetricsMonitorType = self.deviceMetricsMonitorType;
    options.monitorFrequency = self.monitorFrequency;
    options.resourceUrlHandler = self.resourceUrlHandler;
    options.freezeDurationMs = self.freezeDurationMs;
    options.rumCacheLimitCount = self.rumCacheLimitCount;
    options.rumDiscardType = self.rumDiscardType;
    options.resourcePropertyProvider = self.resourcePropertyProvider;
    options.sessionOnErrorSampleRate = self.sessionOnErrorSampleRate;
    options.enableTraceWebView = self.enableTraceWebView;
    options.allowWebViewHost = self.allowWebViewHost;
    options.sessionTaskErrorFilter = self.sessionTaskErrorFilter;
    options.viewTrackingHandler = self.viewTrackingHandler;
    options.actionTrackingHandler = self.actionTrackingHandler;
    options.crashMonitoring = self.crashMonitoring;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [super init]) {
            _enableTrackAppCrash = [dict[@"enableTrackAppCrash"] boolValue];
            _samplerate = [dict[@"samplerate"] intValue];
            _enableTrackAppFreeze = [dict[@"enableTrackAppFreeze"] boolValue];
            _freezeDurationMs = [dict[@"freezeDurationMs"] intValue];
            _enableTrackAppANR = [dict[@"enableTrackAppANR"] boolValue];
            _enableTraceUserAction = [dict[@"enableTraceUserAction"] boolValue];
            _enableTraceUserView = [dict[@"enableTraceUserView"] boolValue];
            _enableTraceUserResource = [dict[@"enableTraceUserResource"] boolValue];
            _enableResourceHostIP = [dict[@"enableResourceHostIP"] boolValue];
            _appid = dict[@"appid"];
            _errorMonitorType = (FTErrorMonitorType)[dict[@"errorMonitorType"] intValue];
            _globalContext = dict[@"globalContext"];
            _deviceMetricsMonitorType = (FTDeviceMetricsMonitorType)[dict[@"deviceMetricsMonitorType"] intValue];
            _monitorFrequency = (FTMonitorFrequency)[dict[@"monitorFrequency"] intValue];
            _resourceUrlHandler = [dict valueForKey:@"resourceUrlHandler"];
            _resourcePropertyProvider = [dict valueForKey:@"resourceProvider"];
            _sessionTaskErrorFilter = [dict valueForKey:@"sessionTaskErrorFilter"];
            _sessionOnErrorSampleRate = [[dict valueForKey:@"sessionOnErrorSampleRate"] intValue];
        }
        return self;
    }else{
        return nil;
    }
}
-(void)setEnableTrackAppFreeze:(BOOL)enableTrackAppFreeze freezeDurationMs:(long)freezeDurationMs{
    _enableTrackAppFreeze = enableTrackAppFreeze;
    self.freezeDurationMs = freezeDurationMs;
}
-(void)setFreezeDurationMs:(long)freezeDurationMs{
    _freezeDurationMs = MAX(FT_MIN_DEFAULT_BLOCK_DURATIONS_MS,freezeDurationMs);
}
-(void)setRumCacheLimitCount:(int)rumCacheLimitCount{
    _rumCacheLimitCount = MAX(FT_DB_RUM_MIN_COUNT,rumCacheLimitCount);
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:@(self.enableTrackAppCrash) forKey:@"enableTrackAppCrash"];
    [dict setValue:@(self.samplerate) forKey:@"samplerate"];
    [dict setValue:@(self.enableTrackAppFreeze) forKey:@"enableTrackAppFreeze"];
    [dict setValue:@(self.freezeDurationMs) forKey:@"freezeDurationMs"];
    [dict setValue:@(self.enableTrackAppANR) forKey:@"enableTrackAppANR"];
    [dict setValue:@(self.enableTraceUserAction) forKey:@"enableTraceUserAction"];
    [dict setValue:@(self.enableTraceUserView) forKey:@"enableTraceUserView"];
    [dict setValue:@(self.enableTraceUserResource) forKey:@"enableTraceUserResource"];
    [dict setValue:@(self.enableResourceHostIP) forKey:@"enableResourceHostIP"];
    [dict setValue:@(self.errorMonitorType) forKey:@"errorMonitorType"];
    [dict setValue:self.appid forKey:@"appid"];
    [dict setValue:@(self.deviceMetricsMonitorType) forKey:@"deviceMetricsMonitorType"];
    [dict setValue:@(self.monitorFrequency) forKey:@"monitorFrequency"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:@(self.rumCacheLimitCount) forKey:@"rumCacheLimitCount"];
    [dict setValue:@(self.rumDiscardType) forKey:@"rumDiscardType"];
    [dict setValue:@(self.sessionOnErrorSampleRate) forKey:@"sessionOnErrorSampleRate"];
    return dict;
}
-(NSString *)debugDescription{
    NSMutableDictionary *dict = [[self convertToDictionary] mutableCopy];
    [dict setValue:[self.resourceUrlHandler copy] forKey:@"resourceUrlHandler"];
    [dict setValue:[self.resourcePropertyProvider copy] forKey:@"resourcePropertyProvider"];
    [dict setValue:[self.sessionTaskErrorFilter copy] forKey:@"sessionTaskErrorFilter"];
    [dict setValue:self.viewTrackingHandler forKey:@"viewTrackingHandler"];
    [dict setValue:self.actionTrackingHandler forKey:@"actionTrackingHandler"];
    return [NSString stringWithFormat:@"%@",dict];
}
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict{
    @try {
        if (!dict || dict.count == 0) {
            return;
        }
        NSNumber *sampleRate = dict[FT_R_RUM_SAMPLERATE];
        NSNumber *sessionOnErrorSampleRate = dict[FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE];
        NSNumber *enableTraceUserAction = dict[FT_R_RUM_ENABLE_TRACE_USER_ACTION];
        NSNumber *enableTraceUserView = dict[FT_R_RUM_ENABLE_TRACE_USER_VIEW];
        NSNumber *enableTraceUserResource = dict[FT_R_RUM_ENABLE_TRACE_USER_RESOURCE];
        NSNumber *enableResourceHostIP = dict[FT_R_RUM_ENABLE_RESOURCE_HOST_IP];
        NSNumber *enableTrackAppFreeze = dict[FT_R_RUM_ENABLE_TRACE_APP_FREEZE];
        NSNumber *freezeDurationMs = dict[FT_R_RUM_FREEZE_DURATION_MS];
        NSNumber *enableTrackAppCrash = dict[FT_R_RUM_ENABLE_TRACK_APP_CRASH];
        NSNumber *enableTrackAppANR = dict[FT_R_RUM_ENABLE_TRACK_APP_ANR];
        NSNumber *enableTraceWebView = dict[FT_R_RUM_ENABLE_TRACE_WEBVIEW];
        NSString *allowWebViewHost = dict[FT_R_RUM_ALLOW_WEBVIEW_HOST];
        if (sampleRate != nil && [sampleRate isKindOfClass:NSNumber.class]) {
            self.samplerate = [sampleRate doubleValue] * 100;
        }
        if (sessionOnErrorSampleRate != nil && [sessionOnErrorSampleRate isKindOfClass:NSNumber.class]) {
            self.sessionOnErrorSampleRate = [sessionOnErrorSampleRate doubleValue] * 100;
        }
        if (enableTraceUserAction != nil && [enableTraceUserAction isKindOfClass:NSNumber.class]) {
            self.enableTraceUserAction = [enableTraceUserAction boolValue];
        }
        if (enableTraceUserView != nil && [enableTraceUserView isKindOfClass:NSNumber.class]) {
            self.enableTraceUserView = [enableTraceUserView boolValue];
        }
        if (enableTraceUserResource != nil && [enableTraceUserResource isKindOfClass:NSNumber.class]) {
            self.enableTraceUserResource = [enableTraceUserResource boolValue];
        }
        if (enableResourceHostIP != nil && [enableResourceHostIP isKindOfClass:NSNumber.class]) {
            self.enableResourceHostIP = [enableResourceHostIP boolValue];
        }
        if (enableTrackAppFreeze != nil && [enableTrackAppFreeze isKindOfClass:NSNumber.class]) {
            self.enableTrackAppFreeze = [enableTrackAppFreeze boolValue];
        }
        if (freezeDurationMs != nil && [freezeDurationMs isKindOfClass:NSNumber.class]) {
            self.freezeDurationMs = [freezeDurationMs longValue];
        }
        if (enableTrackAppCrash != nil && [enableTrackAppCrash isKindOfClass:NSNumber.class]) {
            self.enableTrackAppCrash = [enableTrackAppCrash boolValue];
        }
        if (enableTrackAppANR != nil && [enableTrackAppANR isKindOfClass:NSNumber.class]) {
            self.enableTrackAppANR = [enableTrackAppANR boolValue];
        }
        if (enableTraceWebView != nil && [enableTrackAppANR isKindOfClass:NSNumber.class]) {
            self.enableTraceWebView = [enableTraceWebView boolValue];
        }
        if (allowWebViewHost && [allowWebViewHost isKindOfClass:NSString.class] && allowWebViewHost.length>0) {
            NSArray *hosts = [FTJSONUtil arrayWithJsonString:allowWebViewHost];
            if (hosts.count>0) {
                self.allowWebViewHost = hosts;
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
@end
