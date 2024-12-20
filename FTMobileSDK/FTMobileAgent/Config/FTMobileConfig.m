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
        _enableTraceUserResource = NO;
        _enableResourceHostIP = NO;
        _monitorFrequency = FTMonitorFrequencyDefault;
        _freezeDurationMs = FT_DEFAULT_BLOCK_DURATIONS_MS;
        _rumCacheLimitCount = FT_DB_RUM_MAX_COUNT;
        _rumDiscardType = FTRUMDiscard;
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
    _freezeDurationMs = MAX(FT_MINI_DEFAULT_BLOCK_DURATIONS_MS,freezeDurationMs);
}
-(void)setGlobalContext:(NSDictionary<NSString *,NSString *> *)globalContext{
    _globalContext = [globalContext ft_deepCopy];
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
    [dict setValue:self.resourceUrlHandler forKey:@"resourceUrlHandler"];
    [dict setValue:@(self.rumCacheLimitCount) forKey:@"rumCacheLimitCount"];
    [dict setValue:@(self.rumDiscardType) forKey:@"rumDiscardType"];
    return dict;
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"%@",[self convertToDictionary]];
}
@end
@implementation FTLoggerConfig
-(instancetype)init{
    self = [super init];
    if (self) {
        _discardType = FTDiscard;
        _samplerate = 100;
        _enableLinkRumData = NO;
        _enableCustomLog = NO;
        _logLevelFilter = @[@0,@1,@2,@3,@4];
        _logCacheLimitCount = FT_DB_CONTENT_MAX_COUNT;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTLoggerConfig *options = [[[self class] allocWithZone:zone] init];
    options.samplerate = self.samplerate;
    options.enableLinkRumData = self.enableLinkRumData;
    options.enableCustomLog = self.enableCustomLog;
    options.logLevelFilter = self.logLevelFilter;
    options.discardType = self.discardType;
    options.globalContext = self.globalContext;
    options.printCustomLogToConsole = self.printCustomLogToConsole;
    options.logCacheLimitCount = self.logCacheLimitCount;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [super init]) {
            _samplerate = [dict[@"samplerate"] intValue];
            _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            _enableCustomLog = [dict[@"enableCustomLog"] boolValue];
            _logLevelFilter = dict[@"logLevelFilter"];
            _discardType = (FTLogCacheDiscard)[dict[@"discardType"] intValue];
            _globalContext = dict[@"globalContext"];
            _printCustomLogToConsole = [dict[@"printCustomLogToConsole"] boolValue];
        }
        return self;
    }else{
        return nil;
    }
}
-(void)setLogCacheLimitCount:(int)logCacheLimitCount{
    _logCacheLimitCount = MAX(1000, logCacheLimitCount);
}
-(void)setGlobalContext:(NSDictionary<NSString *,NSString *> *)globalContext{
    _globalContext = [globalContext ft_deepCopy];
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:@(self.samplerate) forKey:@"samplerate"];
    [dict setValue:@(self.enableLinkRumData) forKey:@"enableLinkRumData"];
    [dict setValue:@(self.enableCustomLog) forKey:@"enableCustomLog"];
    [dict setValue:self.logLevelFilter forKey:@"logLevelFilter"];
    [dict setValue:@(self.discardType) forKey:@"discardType"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:@(self.logCacheLimitCount) forKey:@"logCacheLimitCount"];
    [dict setValue:@(self.printCustomLogToConsole) forKey:@"printCustomLogToConsole"];
    return dict;
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"%@",[self convertToDictionary]];
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
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [super init]) {
            _samplerate = [dict[@"samplerate"] intValue];
            _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            _networkTraceType =(FTNetworkTraceType)[dict[@"networkTraceType"] intValue];
            _enableAutoTrace = [dict[@"enableAutoTrace"] boolValue];
        }
        return self;
    }else{
        return nil;
    }
}
-(NSDictionary *)convertToDictionary{
    return @{@"samplerate":@(self.samplerate),
             @"enableLinkRumData":@(self.enableLinkRumData),
             @"networkTraceType":@(self.networkTraceType),
             @"enableAutoTrace":@(self.enableAutoTrace),
    };
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"%@",[self convertToDictionary]];
}
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
        _service = FT_DEFAULT_SERVICE_NAME;
        _env = FTEnvStringMap[FTEnvProd];
        _autoSync = YES;
        _syncPageSize = 10;
        _syncSleepTime = 0;
        _compressIntakeRequests = NO;
        _dbDiscardType = FTDBDiscard;
        _dbCacheLimit = FT_DEFAULT_DB_SIZE_LIMIT;
        _enableLimitWithDbSize = NO;
    }
    return self;
}
-(void)setGlobalContext:(NSDictionary<NSString *,NSString *> *)globalContext{
    _globalContext = [globalContext ft_deepCopy];
}
- (void)setEnvWithType:(FTEnv)envType{
    _env = FTEnvStringMap[envType];
}
-(void)setEnv:(NSString *)env{
    if(env!=nil && env.length>0){
        _env = env;
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
    options.enableDataIntegerCompatible = self.enableLimitWithDbSize;
    options.dbCacheLimit = self.dbCacheLimit;
    options.dbDiscardType = self.dbDiscardType;
    return options;
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
    return [NSString stringWithFormat:@"%@",dict];
}
@end
