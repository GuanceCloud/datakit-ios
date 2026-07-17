//
//  FTSDKConfig.m
//  FTMobileAgent
//
//  Created by hulilei on 2019/12/6.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTSDKConfig.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTInternalConstants.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "NSDictionary+FTCopyProperties.h"

@implementation FTTraceConfig
- (int)sampleRate {
    return _samplerate;
}
- (void)setSampleRate:(int)sampleRate {
    _samplerate = sampleRate;
}
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
    options.sampleRate = self.sampleRate;
    options.enableLinkRumData = self.enableLinkRumData;
    options.networkTraceType = self.networkTraceType;
    options.enableAutoTrace = self.enableAutoTrace;
    options.traceInterceptor = [self.traceInterceptor copy];
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [self init]) {
            if ([dict ft_hasValidValueForKey:@"samplerate"]) _samplerate = [dict[@"samplerate"] intValue];
            if ([dict ft_hasValidValueForKey:@"sampleRate"]) _samplerate = [dict[@"sampleRate"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableLinkRumData"]) _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            if ([dict ft_hasValidValueForKey:@"networkTraceType"]) _networkTraceType =(FTNetworkTraceType)[dict[@"networkTraceType"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableAutoTrace"]) _enableAutoTrace = [dict[@"enableAutoTrace"] boolValue];
            if ([dict ft_hasValidValueForKey:@"traceInterceptor"]) _traceInterceptor = [dict[@"traceInterceptor"] copy];
        }
        return self;
    }else{
        return nil;
    }
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:@(self.sampleRate) forKey:@"sampleRate"];
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
@end
@interface FTSDKConfig()
@property (nonatomic, strong) NSMutableDictionary *sdkPkgInfo;
@end
@implementation FTSDKConfig
-(instancetype)initWithMetricsUrl:(NSString *)metricsUrl{
    self = [self initWithDatakitUrl:metricsUrl];
    self->_metricsUrl = [metricsUrl copy];
    return self;
}
-(instancetype)initWithDatakitUrl:(NSString *)datakitUrl{
    if (self = [self init]) {
        _datakitUrl = [datakitUrl copy];
    }
    return self;
}
- (nonnull instancetype)initWithDatawayUrl:(nonnull NSString *)datawayUrl clientToken:(nonnull NSString *)clientToken{
    if (self = [self init]) {
        _datawayUrl = [datawayUrl copy];
        _clientToken = [clientToken copy];
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
        _env = FTStringFromEnv(Prod);
        _autoSync = YES;
        _syncPageSize = 10;
        _syncSleepTime = 0;
        _compressIntakeRequests = YES;
        _dbDiscardType = FTDBDiscard;
        _dbCacheLimit = FT_DEFAULT_DB_SIZE_LIMIT;
        _enableDataIntegerCompatible = YES;
        _enableLimitWithDbSize = NO;
        _enableDataFilter = YES;
        _dataFilters = @{};
        _remoteConfiguration = NO;
        _remoteConfigMiniUpdateInterval = 12*60*60;
    }
    return self;
}
-(void)setDbCacheLimit:(long)dbCacheLimit{
    _dbCacheLimit = MAX(FT_MIN_DB_SIZE_LIMIT, dbCacheLimit);
}
- (void)setEnvWithType:(FTEnv)envType{
    _env = FTStringFromEnv((Env)envType);
}
-(void)setEnv:(NSString *)env{
    if(env!=nil && env.length>0){
        _env = [env copy];
    }
}
-(void)setService:(NSString *)service{
    if(service!=nil && service.length>0){
        _service = [service copy];
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
    FTSDKConfig *options = [[[self class] allocWithZone:zone] init];
    options.datakitUrl = self.datakitUrl;
    options.datawayUrl = self.datawayUrl;
    options.clientToken = self.clientToken;
    options.enableSDKDebugLog = self.enableSDKDebugLog;
    options.env = self.env;
    options.globalContext = [self.globalContext copy];
    options.groupIdentifiers = [self.groupIdentifiers copy];
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
    options.enableDataFilter = self.enableDataFilter;
    options.dataFilters = [self.dataFilters copy];
    options.remoteConfiguration = self.remoteConfiguration;
    options.remoteConfigMiniUpdateInterval = self.remoteConfigMiniUpdateInterval;
    options.remoteConfigFetchCompletionBlock = [self.remoteConfigFetchCompletionBlock copy];
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [self init]) {
            if ([dict ft_hasValidValueForKey:@"service"]) self.service = [dict valueForKey:@"service"];
            if ([dict ft_hasValidValueForKey:@"datakitUrl"]) self.datakitUrl = [dict valueForKey:@"datakitUrl"];
            if ([dict ft_hasValidValueForKey:@"datawayUrl"]) self.datawayUrl = [dict valueForKey:@"datawayUrl"];
            if ([dict ft_hasValidValueForKey:@"clientToken"]) self.clientToken = [dict valueForKey:@"clientToken"];
            if ([dict ft_hasValidValueForKey:@"env"]) self.env = [dict valueForKey:@"env"];
            if ([dict ft_hasValidValueForKey:@"enableDataFilter"]) self.enableDataFilter = [[dict valueForKey:@"enableDataFilter"] boolValue];
            if ([dict ft_hasValidValueForKey:@"dataFilters"]) self.dataFilters = [dict valueForKey:@"dataFilters"];
        }
        return self;
    }else{
        return nil;
    }
}
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:self.service forKey:@"service"];
    [dict setValue:self.datawayUrl forKey:@"datawayUrl"];
    [dict setValue:self.clientToken forKey:@"clientToken"];
    [dict setValue:self.datakitUrl forKey:@"datakitUrl"];
    [dict setValue:self.env forKey:@"env"];
    [dict setValue:@(self.enableDataFilter) forKey:@"enableDataFilter"];
    [dict setValue:self.dataFilters forKey:@"dataFilters"];
    return dict;
}
-(NSString *)debugDescription{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if(self.datakitUrl){
        [dict setValue:self.datakitUrl forKey:@"datakitUrl"];
    }
    if(self.datawayUrl){
        [dict setValue:self.datawayUrl forKey:@"datawayUrl"];
        [dict setValue:self.clientToken.length>0?[NSString stringWithFormat:@"*****%@",[self.clientToken substringFromIndex:self.clientToken.length/2]]:nil forKey:@"clientToken"];
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
    [dict setValue:@(self.enableDataFilter) forKey:@"enableDataFilter"];
    [dict setValue:self.dataFilters forKey:@"dataFilters"];
    [dict setValue:@(self.remoteConfiguration) forKey:@"remoteConfiguration"];
    [dict setValue:@(self.remoteConfigMiniUpdateInterval) forKey:@"remoteConfigMiniUpdateInterval"];
    [dict setValue:self.remoteConfigFetchCompletionBlock forKey:@"remoteConfigFetchCompletionBlock"];
    [dict setValue:self.pkgInfo forKey:@"sdkPkgInfo"];
    return [NSString stringWithFormat:@"%@",dict];
}

@end
