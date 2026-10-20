//
//  FTRumConfig.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/22.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <TargetConditionals.h>
#import "FTRumConfig.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTInternalConstants.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTVisitorIDConfig+Private.h"

@interface FTRumConfig ()
@property (nonatomic, assign) BOOL enableUIKitViewLoadingTime;
@property (nonatomic, copy, nullable) NSArray *allowWebViewHost;
@end

@implementation FTRumConfig
// Keep deprecated sampling accessors for backward compatibility.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (int)sampleRate {
    return (int)_sessionSamplingRate;
}
- (void)setSampleRate:(int)sampleRate {
    self.sessionSamplingRate = (float)sampleRate;
}
- (int)samplerate {
    return (int)_sessionSamplingRate;
}
- (void)setSamplerate:(int)samplerate {
    self.sessionSamplingRate = (float)samplerate;
}
#pragma clang diagnostic pop
- (void)setSessionSamplingRate:(float)sessionSamplingRate {
    if (![FTBaseInfoHandler isValidSamplingRate:sessionSamplingRate]) {
        FTInnerLogWarning(@"[sampling] Ignore invalid sessionSamplingRate: %g", sessionSamplingRate);
        return;
    }
    _sessionSamplingRate = sessionSamplingRate;
}
// Keep deprecated sampling accessors for backward compatibility.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (int)sessionOnErrorSampleRate {
    return (int)_sessionOnErrorSamplingRate;
}
- (void)setSessionOnErrorSampleRate:(int)sessionOnErrorSampleRate {
    self.sessionOnErrorSamplingRate = (float)sessionOnErrorSampleRate;
}
#pragma clang diagnostic pop
- (void)setSessionOnErrorSamplingRate:(float)sessionOnErrorSamplingRate {
    if (![FTBaseInfoHandler isValidSamplingRate:sessionOnErrorSamplingRate]) {
        FTInnerLogWarning(@"[sampling] Ignore invalid sessionOnErrorSamplingRate: %g", sessionOnErrorSamplingRate);
        return;
    }
    _sessionOnErrorSamplingRate = sessionOnErrorSamplingRate;
}
- (instancetype)init{
    return [self initWithAppid:@""];
}
- (instancetype)initWithAppid:(nonnull NSString *)appid{
    self = [super init];
    if (self) {
        _appid = [appid copy];
        _nextViewActionPredicate = [FTRUMTimeBasedNextViewActionPredicate new];
        _networkSettledResourcePredicate = [FTRUMTimeBasedNetworkSettledPredicate new];
        _enableTrackAppCrash= NO;
        _sessionSamplingRate = 100.0f;
        _sessionOnErrorSamplingRate = 0.0f;
        _enableTrackAppFreeze = NO;
        _enableTrackAppANR = NO;
        _enableTraceUserAction = NO;
        _enableTraceUserView = NO;
        _enableTraceUserResource = NO;
        _enableTraceURLConnectionResource = NO;
        _enableResourceHostIP = NO;
        _monitorFrequency = FTMonitorFrequencyDefault;
        _freezeDurationMs = FT_DEFAULT_BLOCK_DURATIONS_MS;
        _rumCacheLimitCount = FT_DB_RUM_MAX_COUNT;
        _rumDiscardType = FTRUMDiscard;
        _enableTraceWebView = YES;
        _enableUIKitViewLoadingTime = YES;
        _crashMonitoring = FTCrashMonitorTypeHighCompatibility;
    }
    return self;
}
- (void)setNetworkSettledResourcePredicate:(id<FTRUMNetworkSettledResourcePredicate>)predicate {
    _networkSettledResourcePredicate = predicate ?: [FTRUMTimeBasedNetworkSettledPredicate new];
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTRumConfig *options = [[[self class] allocWithZone:zone] init];
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options->_sessionSamplingRate = _sessionSamplingRate;
    options.enableTrackAppFreeze = self.enableTrackAppFreeze;
    options.enableTrackAppANR = self.enableTrackAppANR;
    options.enableTraceUserAction = self.enableTraceUserAction;
    options.enableTraceUserView = self.enableTraceUserView;
    options.enableTraceUserResource = self.enableTraceUserResource;
    options.enableTraceURLConnectionResource = self.enableTraceURLConnectionResource;
    options.enableResourceHostIP = self.enableResourceHostIP;
    options.appid = [self.appid copy];
    options.nextViewActionPredicate = self.nextViewActionPredicate;
    options.networkSettledResourcePredicate = self.networkSettledResourcePredicate;
    options.errorMonitorType = self.errorMonitorType;
    options.globalContext = [self.globalContext copy];
    options.deviceMetricsMonitorType = self.deviceMetricsMonitorType;
    options.monitorFrequency = self.monitorFrequency;
    options.resourceUrlHandler = [self.resourceUrlHandler copy];
    options.freezeDurationMs = self.freezeDurationMs;
    options.rumCacheLimitCount = self.rumCacheLimitCount;
    options.rumDiscardType = self.rumDiscardType;
    options.resourcePropertyProvider = [self.resourcePropertyProvider copy];
    options->_sessionOnErrorSamplingRate = _sessionOnErrorSamplingRate;
    options.enableTraceWebView = self.enableTraceWebView;
    options.enableUIKitViewLoadingTime = self.enableUIKitViewLoadingTime;
    options->_allowWebViewHost = [_allowWebViewHost copy];
    options.sessionTaskErrorFilter = [self.sessionTaskErrorFilter copy];
    options.issueDataProvider = [self.issueDataProvider copy];
    options.visitorIDConfig = [self.visitorIDConfig copy];
#if TARGET_OS_IOS || TARGET_OS_TV
    options.viewTrackingHandler = self.viewTrackingHandler;
    options.swiftUIViewTrackingHandler = self.swiftUIViewTrackingHandler;
    options.actionTrackingHandler = self.actionTrackingHandler;
#endif
    options.crashMonitoring = self.crashMonitoring;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [self init]) {
            if ([dict ft_hasValidValueForKey:@"enableTrackAppCrash"]) _enableTrackAppCrash = [dict[@"enableTrackAppCrash"] boolValue];
            if ([dict ft_hasValidValueForKey:@"samplerate"]) self.sessionSamplingRate = (float)[dict[@"samplerate"] intValue];
            if ([dict ft_hasValidValueForKey:@"sampleRate"]) self.sessionSamplingRate = (float)[dict[@"sampleRate"] intValue];
            if ([dict ft_hasValidValueForKey:@"sessionSamplingRate"]) self.sessionSamplingRate = [dict[@"sessionSamplingRate"] floatValue];
            if ([dict ft_hasValidValueForKey:@"enableTrackAppFreeze"]) _enableTrackAppFreeze = [dict[@"enableTrackAppFreeze"] boolValue];
            if ([dict ft_hasValidValueForKey:@"freezeDurationMs"]) self.freezeDurationMs = [dict[@"freezeDurationMs"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableTrackAppANR"]) _enableTrackAppANR = [dict[@"enableTrackAppANR"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceUserAction"]) _enableTraceUserAction = [dict[@"enableTraceUserAction"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceUserView"]) _enableTraceUserView = [dict[@"enableTraceUserView"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceUserResource"]) _enableTraceUserResource = [dict[@"enableTraceUserResource"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceURLConnectionResource"]) _enableTraceURLConnectionResource = [dict[@"enableTraceURLConnectionResource"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableResourceHostIP"]) _enableResourceHostIP = [dict[@"enableResourceHostIP"] boolValue];
            if ([dict ft_hasValidValueForKey:@"appid"]) _appid = [dict[@"appid"] copy];
            if ([dict ft_hasValidValueForKey:@"errorMonitorType"]) _errorMonitorType = (FTErrorMonitorType)[dict[@"errorMonitorType"] intValue];
            if ([dict ft_hasValidValueForKey:@"globalContext"]) _globalContext = [dict[@"globalContext"] copy];
            if ([dict ft_hasValidValueForKey:@"deviceMetricsMonitorType"]) _deviceMetricsMonitorType = (FTDeviceMetricsMonitorType)[dict[@"deviceMetricsMonitorType"] intValue];
            if ([dict ft_hasValidValueForKey:@"monitorFrequency"]) _monitorFrequency = (FTMonitorFrequency)[dict[@"monitorFrequency"] intValue];
            if ([dict ft_hasValidValueForKey:@"resourceUrlHandler"]) _resourceUrlHandler = [[dict valueForKey:@"resourceUrlHandler"] copy];
            if ([dict ft_hasValidValueForKey:@"resourceProvider"]) _resourcePropertyProvider = [[dict valueForKey:@"resourceProvider"] copy];
            if ([dict ft_hasValidValueForKey:@"sessionTaskErrorFilter"]) _sessionTaskErrorFilter = [[dict valueForKey:@"sessionTaskErrorFilter"] copy];
            if ([dict ft_hasValidValueForKey:@"sessionOnErrorSampleRate"]) self.sessionOnErrorSamplingRate = (float)[[dict valueForKey:@"sessionOnErrorSampleRate"] intValue];
            if ([dict ft_hasValidValueForKey:@"sessionOnErrorSamplingRate"]) self.sessionOnErrorSamplingRate = [[dict valueForKey:@"sessionOnErrorSamplingRate"] floatValue];
            if ([dict ft_hasValidValueForKey:@"crashMonitoring"]) _crashMonitoring = (FTCrashMonitorType)[[dict valueForKey:@"crashMonitoring"] intValue];
            if ([dict ft_hasValidValueForKey:@"rumCacheLimitCount"]) self.rumCacheLimitCount = [dict[@"rumCacheLimitCount"] intValue];
            if ([dict ft_hasValidValueForKey:@"rumDiscardType"]) _rumDiscardType = (FTRUMCacheDiscard)[dict[@"rumDiscardType"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableTraceWebView"]) _enableTraceWebView = [dict[@"enableTraceWebView"] boolValue];
            if ([dict ft_hasValidValueForKey:@"allowWebViewHost"]) _allowWebViewHost = [dict[@"allowWebViewHost"] copy];
            if ([dict ft_hasValidValueForKey:@"visitorIDConfig"] && [dict[@"visitorIDConfig"] isKindOfClass:NSDictionary.class]) {
                _visitorIDConfig = [[FTVisitorIDConfig alloc] initWithDictionary:dict[@"visitorIDConfig"]];
            }
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
    [dict setValue:@((int)_sessionSamplingRate) forKey:@"sampleRate"];
    [dict setValue:@(_sessionSamplingRate) forKey:@"sessionSamplingRate"];
    [dict setValue:@(self.enableTrackAppFreeze) forKey:@"enableTrackAppFreeze"];
    [dict setValue:@(self.freezeDurationMs) forKey:@"freezeDurationMs"];
    [dict setValue:@(self.enableTrackAppANR) forKey:@"enableTrackAppANR"];
    [dict setValue:@(self.enableTraceUserAction) forKey:@"enableTraceUserAction"];
    [dict setValue:@(self.enableTraceUserView) forKey:@"enableTraceUserView"];
    [dict setValue:@(self.enableTraceUserResource) forKey:@"enableTraceUserResource"];
    [dict setValue:@(self.enableTraceURLConnectionResource) forKey:@"enableTraceURLConnectionResource"];
    [dict setValue:@(self.enableResourceHostIP) forKey:@"enableResourceHostIP"];
    [dict setValue:@(self.errorMonitorType) forKey:@"errorMonitorType"];
    [dict setValue:self.appid forKey:@"appid"];
    [dict setValue:@(self.deviceMetricsMonitorType) forKey:@"deviceMetricsMonitorType"];
    [dict setValue:@(self.monitorFrequency) forKey:@"monitorFrequency"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:@(self.rumCacheLimitCount) forKey:@"rumCacheLimitCount"];
    [dict setValue:@(self.rumDiscardType) forKey:@"rumDiscardType"];
    [dict setValue:@((int)_sessionOnErrorSamplingRate) forKey:@"sessionOnErrorSampleRate"];
    [dict setValue:@(_sessionOnErrorSamplingRate) forKey:@"sessionOnErrorSamplingRate"];
    [dict setValue:@(self.crashMonitoring) forKey:@"crashMonitoring"];
    [dict setValue:@(self.enableTraceWebView) forKey:@"enableTraceWebView"];
    [dict setValue:_allowWebViewHost forKey:@"allowWebViewHost"];
    [dict setValue:[self.visitorIDConfig convertToDictionary] forKey:@"visitorIDConfig"];
    return dict;
}
-(NSString *)debugDescription{
    NSMutableDictionary *dict = [[self convertToDictionary] mutableCopy];
    [dict setValue:@(self.sessionSamplingRate) forKey:@"sessionSamplingRate"];
    [dict setValue:@(self.sessionOnErrorSamplingRate) forKey:@"sessionOnErrorSamplingRate"];
    [dict setValue:[self.resourceUrlHandler copy] forKey:@"resourceUrlHandler"];
    [dict setValue:[self.resourcePropertyProvider copy] forKey:@"resourcePropertyProvider"];
    [dict setValue:[self.sessionTaskErrorFilter copy] forKey:@"sessionTaskErrorFilter"];
#if TARGET_OS_IOS || TARGET_OS_TV
    [dict setValue:self.viewTrackingHandler forKey:@"viewTrackingHandler"];
    [dict setValue:self.swiftUIViewTrackingHandler forKey:@"swiftUIViewTrackingHandler"];
    [dict setValue:self.actionTrackingHandler forKey:@"actionTrackingHandler"];
#endif
    [dict setValue:@(self.enableTraceWebView) forKey:@"enableTraceWebView"];
    [dict setValue:[_allowWebViewHost copy] forKey:@"allowWebViewHost"];
    [dict setValue:[self.issueDataProvider copy] forKey:@"issueDataProvider"];
    [dict setValue:self.visitorIDConfig.debugDescription forKey:@"visitorIDConfig"];
    return [NSString stringWithFormat:@"%@",dict];
}
@end
