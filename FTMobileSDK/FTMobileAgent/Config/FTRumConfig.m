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
@end
