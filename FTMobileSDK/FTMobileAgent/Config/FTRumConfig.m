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
#import "FTInternalConstants.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "NSDictionary+FTCopyProperties.h"

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
    options.appid = [self.appid copy];
    options.errorMonitorType = self.errorMonitorType;
    options.globalContext = [self.globalContext copy];
    options.deviceMetricsMonitorType = self.deviceMetricsMonitorType;
    options.monitorFrequency = self.monitorFrequency;
    options.resourceUrlHandler = [self.resourceUrlHandler copy];
    options.freezeDurationMs = self.freezeDurationMs;
    options.rumCacheLimitCount = self.rumCacheLimitCount;
    options.rumDiscardType = self.rumDiscardType;
    options.resourcePropertyProvider = [self.resourcePropertyProvider copy];
    options.sessionOnErrorSampleRate = self.sessionOnErrorSampleRate;
    options.enableTraceWebView = self.enableTraceWebView;
    options.allowWebViewHost = [self.allowWebViewHost copy];
    options.sessionTaskErrorFilter = [self.sessionTaskErrorFilter copy];
    options.viewTrackingHandler = self.viewTrackingHandler;
    options.swiftUIViewTrackingHandler = self.swiftUIViewTrackingHandler;
    options.actionTrackingHandler = self.actionTrackingHandler;
    options.crashMonitoring = self.crashMonitoring;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [self init]) {
            if ([dict ft_hasValidValueForKey:@"enableTrackAppCrash"]) _enableTrackAppCrash = [dict[@"enableTrackAppCrash"] boolValue];
            if ([dict ft_hasValidValueForKey:@"samplerate"]) _samplerate = [dict[@"samplerate"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableTrackAppFreeze"]) _enableTrackAppFreeze = [dict[@"enableTrackAppFreeze"] boolValue];
            if ([dict ft_hasValidValueForKey:@"freezeDurationMs"]) self.freezeDurationMs = [dict[@"freezeDurationMs"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableTrackAppANR"]) _enableTrackAppANR = [dict[@"enableTrackAppANR"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceUserAction"]) _enableTraceUserAction = [dict[@"enableTraceUserAction"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceUserView"]) _enableTraceUserView = [dict[@"enableTraceUserView"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceUserResource"]) _enableTraceUserResource = [dict[@"enableTraceUserResource"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableResourceHostIP"]) _enableResourceHostIP = [dict[@"enableResourceHostIP"] boolValue];
            if ([dict ft_hasValidValueForKey:@"appid"]) _appid = [dict[@"appid"] copy];
            if ([dict ft_hasValidValueForKey:@"errorMonitorType"]) _errorMonitorType = (FTErrorMonitorType)[dict[@"errorMonitorType"] intValue];
            if ([dict ft_hasValidValueForKey:@"globalContext"]) _globalContext = [dict[@"globalContext"] copy];
            if ([dict ft_hasValidValueForKey:@"deviceMetricsMonitorType"]) _deviceMetricsMonitorType = (FTDeviceMetricsMonitorType)[dict[@"deviceMetricsMonitorType"] intValue];
            if ([dict ft_hasValidValueForKey:@"monitorFrequency"]) _monitorFrequency = (FTMonitorFrequency)[dict[@"monitorFrequency"] intValue];
            if ([dict ft_hasValidValueForKey:@"resourceUrlHandler"]) _resourceUrlHandler = [dict valueForKey:@"resourceUrlHandler"];
            if ([dict ft_hasValidValueForKey:@"resourceProvider"]) _resourcePropertyProvider = [dict valueForKey:@"resourceProvider"];
            if ([dict ft_hasValidValueForKey:@"sessionTaskErrorFilter"]) _sessionTaskErrorFilter = [dict valueForKey:@"sessionTaskErrorFilter"];
            if ([dict ft_hasValidValueForKey:@"sessionOnErrorSampleRate"]) _sessionOnErrorSampleRate = [[dict valueForKey:@"sessionOnErrorSampleRate"] intValue];
            if ([dict ft_hasValidValueForKey:@"crashMonitoring"]) _crashMonitoring = (FTCrashMonitorType)[[dict valueForKey:@"crashMonitoring"] intValue];
            if ([dict ft_hasValidValueForKey:@"rumCacheLimitCount"]) self.rumCacheLimitCount = [dict[@"rumCacheLimitCount"] intValue];
            if ([dict ft_hasValidValueForKey:@"rumDiscardType"]) _rumDiscardType = (FTRUMCacheDiscard)[dict[@"rumDiscardType"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceWebView"]) _enableTraceWebView = [dict[@"enableTraceWebView"] boolValue];
            if ([dict ft_hasValidValueForKey:@"allowWebViewHost"]) _allowWebViewHost = [dict[@"allowWebViewHost"] copy];
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
    [dict setValue:@(self.crashMonitoring) forKey:@"crashMonitoring"];
    [dict setValue:@(self.enableTraceWebView) forKey:@"enableTraceWebView"];
    [dict setValue:self.allowWebViewHost forKey:@"allowWebViewHost"];
    return dict;
}
-(NSString *)debugDescription{
    NSMutableDictionary *dict = [[self convertToDictionary] mutableCopy];
    [dict setValue:[self.resourceUrlHandler copy] forKey:@"resourceUrlHandler"];
    [dict setValue:[self.resourcePropertyProvider copy] forKey:@"resourcePropertyProvider"];
    [dict setValue:[self.sessionTaskErrorFilter copy] forKey:@"sessionTaskErrorFilter"];
    [dict setValue:self.viewTrackingHandler forKey:@"viewTrackingHandler"];
    [dict setValue:self.swiftUIViewTrackingHandler forKey:@"swiftUIViewTrackingHandler"];
    [dict setValue:self.actionTrackingHandler forKey:@"actionTrackingHandler"];
    [dict setValue:@(self.enableTraceWebView) forKey:@"enableTraceWebView"];
    [dict setValue:[self.allowWebViewHost copy] forKey:@"allowWebViewHost"];
    return [NSString stringWithFormat:@"%@",dict];
}
@end
