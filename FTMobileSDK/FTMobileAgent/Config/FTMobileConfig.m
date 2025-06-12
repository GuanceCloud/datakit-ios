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
@implementation FTTraceConfig
-(instancetype)init{
    self = [super init];
    if (self) {
        _samplerate= 100;
        _networkTraceType = FTNetworkTraceTypeDDtrace;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTTraceConfig *options = [[[self class] allocWithZone:zone] init];
    options.samplerate = self.samplerate;
    options.enableLinkRumData = self.enableLinkRumData;
    options.networkTraceType = self.networkTraceType;
    options.enableAutoTrace = self.enableAutoTrace;
    options.traceInterceptor = self.traceInterceptor;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [super init]) {
            _samplerate = [dict[@"samplerate"] intValue];
            _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            _networkTraceType =(FTNetworkTraceType)[dict[@"networkTraceType"] intValue];
            _enableAutoTrace = [dict[@"enableAutoTrace"] boolValue];
            _traceInterceptor = dict[@"traceInterceptor"];
        }
        return self;
    }else{
        return nil;
    }
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:@(self.samplerate) forKey:@"samplerate"];
    [dict setValue:@(self.enableLinkRumData) forKey:@"enableLinkRumData"];
    [dict setValue:@(self.networkTraceType) forKey:@"networkTraceType"];
    [dict setValue:@(self.enableAutoTrace) forKey:@"enableAutoTrace"];
    return dict;
}
-(NSString *)debugDescription{
    NSMutableDictionary *dict = [[self convertToDictionary] mutableCopy];
    [dict setValue:[self.traceInterceptor copy] forKey:@"traceInterceptor"];
    return [NSString stringWithFormat:@"%@",dict];
}
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict{
    @try {
        if (!dict || dict.count == 0) {
            return;
        }
        NSNumber *sampleRate = dict[FT_R_TRACE_SAMPLERATE];
        NSNumber *enableAutoTrace = dict[FT_R_TRACE_ENABLE_AUTO_TRACE];
        NSString *traceType = dict[FT_R_TRACE_TRACE_TYPE];
        if (sampleRate != nil && [sampleRate isKindOfClass:NSNumber.class]) {
            self.samplerate = [sampleRate doubleValue] * 100;
        }
        if (enableAutoTrace != nil && [enableAutoTrace isKindOfClass:NSNumber.class]) {
            self.enableAutoTrace = [enableAutoTrace boolValue];
        }
        if (traceType && [traceType isKindOfClass:NSString.class] &&traceType.length>0) {
            NSString *trace = [traceType lowercaseString];
            if ([trace isEqualToString:@"ddtrace"]) {
                self.networkTraceType = FTNetworkTraceTypeDDtrace;
            }else if ([trace isEqualToString:@"zipkinmutiheader"]){
                self.networkTraceType = FTNetworkTraceTypeZipkinMultiHeader;
            }else if ([trace isEqualToString:@"zipkinsingleheader"]){
                self.networkTraceType = FTNetworkTraceTypeZipkinSingleHeader;
            }else if ([trace isEqualToString:@"traceparent"]){
                self.networkTraceType = FTNetworkTraceTypeTraceparent;
            }else if ([trace isEqualToString:@"skywalking"]){
                self.networkTraceType = FTNetworkTraceTypeSkywalking;
            }else if ([trace isEqualToString:@"jaeger"]){
                self.networkTraceType = FTNetworkTraceTypeJaeger;
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
@end
@interface FTMobileConfig()
@property (nonatomic, strong) NSMutableDictionary *sdkPkgInfo;
@end
@implementation FTMobileConfig
-(instancetype)initWithMetricsUrl:(NSString *)metricsUrl{
    self = [self initWithDatakitUrl:metricsUrl];
    self->_metricsUrl = metricsUrl;
    return self;
}
-(instancetype)initWithDatakitUrl:(NSString *)datakitUrl{
    if (self = [self init]) {
        _datakitUrl = datakitUrl;
    }
    return self;
}
- (nonnull instancetype)initWithDatawayUrl:(nonnull NSString *)datawayUrl clientToken:(nonnull NSString *)clientToken{
    if (self = [self init]) {
        _datawayUrl = datawayUrl;
        _clientToken = clientToken;
    }
    return self;
}
-(instancetype)init{
    if (self = [super init]) {
        _enableSDKDebugLog = NO;
#if TARGET_OS_TV
        _service = FT_TVOS_SERVICE_NAME;
#else
        _service = FT_DEFAULT_SERVICE_NAME;
#endif
        _env = FTEnvStringMap[FTEnvProd];
        _autoSync = YES;
        _syncPageSize = 10;
        _syncSleepTime = 0;
        _compressIntakeRequests = NO;
        _dbDiscardType = FTDBDiscard;
        _dbCacheLimit = FT_DEFAULT_DB_SIZE_LIMIT;
        _enableDataIntegerCompatible = YES;
        _enableLimitWithDbSize = NO;
        _remoteConfiguration = NO;
        _remoteConfigMiniUpdateInterval = 12*60*60;
    }
    return self;
}
-(void)setDbCacheLimit:(long)dbCacheLimit{
    _dbCacheLimit = MAX(FT_MIN_DB_SIZE_LIMIT, dbCacheLimit);
}
- (void)setEnvWithType:(FTEnv)envType{
    _env = FTEnvStringMap[envType];
}
-(void)setEnv:(NSString *)env{
    if(env!=nil && env.length>0){
        _env = env;
    }
}
-(void)setService:(NSString *)service{
    if(service!=nil && service.length>0){
        _service = service;
    }
}
-(void)setSyncSleepTime:(int)syncSleepTime{
    _syncSleepTime = MAX(0, MIN(syncSleepTime, 5000));
}
-(void)setSyncPageSize:(int)syncPageSize{
    _syncPageSize = MAX(5, syncPageSize);
}
- (void)setSyncPageSizeWithType:(FTSyncPageSize)pageSize {
    switch (pageSize) {
        case FTSyncPageSizeMini:
            _syncPageSize = 5;
            break;
        case FTSyncPageSizeMedium:
            _syncPageSize = 10;
            break;
        case FTSyncPageSizeMax:
            _syncPageSize = 50;
            break;
    }
}
-(void)setRemoteConfigMiniUpdateInterval:(int)remoteConfigMiniUpdateInterval{
    _remoteConfigMiniUpdateInterval = MAX(0, remoteConfigMiniUpdateInterval);
}
-(NSDictionary *)pkgInfo{
    NSDictionary *dict = nil;
    @synchronized (self) {
        dict = [_sdkPkgInfo copy];
    }
    return dict;
}
- (void)addPkgInfo:(NSString *)key value:(NSString *)value{
    @synchronized (self) {
        if(!_sdkPkgInfo){
            _sdkPkgInfo = [NSMutableDictionary dictionary];
        }
        [_sdkPkgInfo setValue:value forKey:key];
    }
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.datakitUrl = self.datakitUrl;
    options.datawayUrl = self.datawayUrl;
    options.clientToken = self.clientToken;
    options.enableSDKDebugLog = self.enableSDKDebugLog;
    options.env = self.env;
    options.globalContext = self.globalContext;
    options.groupIdentifiers = self.groupIdentifiers;
    options.service = self.service;
    options.autoSync = self.autoSync;
    options.syncPageSize = self.syncPageSize;
    options.syncSleepTime = self.syncSleepTime;
    options.enableDataIntegerCompatible = self.enableDataIntegerCompatible;
    options.compressIntakeRequests = self.compressIntakeRequests;
    options.enableLimitWithDbSize = self.enableLimitWithDbSize;
    options.dbCacheLimit = self.dbCacheLimit;
    options.dbDiscardType = self.dbDiscardType;
    options.sdkPkgInfo = [self.sdkPkgInfo copy];
    options.dataModifier = [self.dataModifier copy];
    options.lineDataModifier = [self.lineDataModifier copy];
    options.remoteConfiguration = self.remoteConfiguration;
    options.remoteConfigMiniUpdateInterval = self.remoteConfigMiniUpdateInterval;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [super init]) {
            _service = [dict valueForKey:@"service"];
            _datakitUrl = [dict valueForKey:@"datakitUrl"];
            _datawayUrl = [dict valueForKey:@"datawayUrl"];
            _clientToken = [dict valueForKey:@"clientToken"];
            _env = [dict valueForKey:@"env"];
        }
        return self;
    }else{
        return nil;
    }
}
/// 将 config 转化成字典
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:self.service forKey:@"service"];
    [dict setValue:self.datawayUrl forKey:@"datawayUrl"];
    [dict setValue:self.clientToken forKey:@"clientToken"];
    [dict setValue:self.datakitUrl forKey:@"datakitUrl"];
    [dict setValue:self.env forKey:@"env"];
    return dict;
}
-(NSString *)debugDescription{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if(self.datakitUrl){
        [dict setValue:self.datakitUrl forKey:@"datakitUrl"];
    }
    if(self.datawayUrl){
        [dict setValue:self.datawayUrl forKey:@"datawayUrl"];
        [dict setValue:self.clientToken.length>0?[NSString stringWithFormat:@"%@*****",[self.clientToken substringWithRange:NSMakeRange(0, self.clientToken.length/2)]]:nil forKey:@"clientToken"];
    }
    [dict setValue:@(self.enableSDKDebugLog) forKey:@"enableSDKDebugLog"];
    [dict setValue:self.env forKey:@"env"];
    [dict setValue:self.groupIdentifiers forKey:@"groupIdentifiers"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:self.service forKey:@"service"];
    [dict setValue:@(self.autoSync) forKey:@"autoSync"];
    [dict setValue:@(self.syncPageSize) forKey:@"syncPageSize"];
    [dict setValue:@(self.syncSleepTime) forKey:@"syncSleepTime"];
    [dict setValue:@(self.enableDataIntegerCompatible) forKey:@"enableDataIntegerCompatible"];
    [dict setValue:@(self.compressIntakeRequests) forKey:@"compressIntakeRequests"];
    [dict setValue:@(self.dbDiscardType) forKey:@"dbDiscardType"];
    [dict setValue:@(self.enableLimitWithDbSize) forKey:@"enableLimitWithDbSize"];
    [dict setValue:@(self.dbCacheLimit) forKey:@"dbCacheLimit"];
    [dict setValue:self.dataModifier forKey:@"dataModifier"];
    [dict setValue:self.lineDataModifier forKey:@"lineDataModifier"];
    [dict setValue:@(self.remoteConfiguration) forKey:@"remoteConfiguration"];
    [dict setValue:@(self.remoteConfigMiniUpdateInterval) forKey:@"remoteConfigMiniUpdateInterval"];
    return [NSString stringWithFormat:@"%@",dict];
}
#pragma mark remote
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict{
    @try {
        if (!dict || dict.count == 0) {
            return;
        }
        NSString *env = dict[FT_ENV];
        NSString *serviceName = dict[FT_R_SERVICE_NAME];
        NSNumber *autoSync = dict[FT_R_AUTO_SYNC];
        NSNumber *compressIntakeRequests = dict[FT_R_COMPRESS_INTAKE_REQUESTS];
        NSNumber *syncPageSize = dict[FT_R_SYNC_PAGE_SIZE];
        NSNumber *syncSleepTime = dict[FT_R_SYNC_SLEEP_TIME];
        if (env && env.length>0) {
            self.env = env;
        }
        if (serviceName && serviceName.length>0) {
            self.service = serviceName;
        }
        if (autoSync != nil) {
            self.autoSync = [autoSync boolValue];
        }
        if (compressIntakeRequests != nil) {
            self.compressIntakeRequests = [compressIntakeRequests boolValue];
        }
        if (syncPageSize != nil) {
            self.syncPageSize = [syncPageSize intValue];
        }
        if (syncSleepTime != nil) {
            self.syncSleepTime = [syncSleepTime intValue];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
@end
