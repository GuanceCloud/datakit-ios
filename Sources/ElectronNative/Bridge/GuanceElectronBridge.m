//
//  GuanceElectronBridge.m
//  GuanceElectronBridge
//
//  Electron component Objective-C adapter.
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//

#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import "GuanceElectronBridge.h"

#import <AppKit/AppKit.h>
#import "FTElectronWebViewHandler.h"
#import "FTRumSessionReplay.h"
#import "FTExternalDataManager.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTLogger.h"
#import "FTMobileAgent.h"

#include <stdlib.h>
#include <string.h>

static NSString *const GEErrorDomain = @"com.guance.electron.native";

static NSError *GEError(NSString *message) {
    return [NSError errorWithDomain:GEErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL GEFail(NSError **error, NSString *message) {
    if (error) *error = GEError(message);
    return NO;
}

static NSString *GEString(NSDictionary *object, NSString *key, NSError **error) {
    id value = object[key];
    if (![value isKindOfClass:NSString.class] || [value length] == 0) {
        GEFail(error, [NSString stringWithFormat:@"%@ must be a non-empty string", key]);
        return nil;
    }
    return value;
}

static NSNumber *GENumber(NSDictionary *object, NSString *key, NSError **error) {
    id value = object[key];
    if (![value isKindOfClass:NSNumber.class]) {
        GEFail(error, [NSString stringWithFormat:@"%@ must be a number", key]);
        return nil;
    }
    return value;
}

static NSDictionary<NSString *, NSString *> *GEStringContext(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
    [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
        if ([key isKindOfClass:NSString.class] && object != NSNull.null) {
            result[key] = [object description];
        }
    }];
    return result;
}

static NSDictionary *GESnapshotForRemoteConfig(id model) {
    if (!model) return nil;
    NSArray<NSArray<NSString *> *> *properties = @[
        @[@"env", @"env"],
        @[@"serviceName", @"serviceName"],
        @[@"autoSync", @"autoSync"],
        @[@"compressIntakeRequests", @"compressIntakeRequests"],
        @[@"syncPageSize", @"syncPageSize"],
        @[@"syncSleepTime", @"syncSleepTime"],
        @[@"rumSampleRate", @"rumSampleRate"],
        @[@"rumSessionOnErrorSampleRate", @"rumSessionOnErrorSampleRate"],
        @[@"rumEnableTraceUserAction", @"rumEnableTraceUserAction"],
        @[@"rumEnableTraceUserView", @"rumEnableTraceUserView"],
        @[@"rumEnableTraceUserResource", @"rumEnableTraceUserResource"],
        @[@"rumEnableResourceHostIP", @"rumEnableResourceHostIP"],
        @[@"rumEnableTrackAppUIBlock", @"rumEnableTrackAppUIBlock"],
        @[@"rumBlockDurationMs", @"rumBlockDurationMs"],
        @[@"rumEnableTrackAppCrash", @"rumEnableTrackAppCrash"],
        @[@"rumEnableTrackAppANR", @"rumEnableTrackAppANR"],
        @[@"rumEnableTraceWebView", @"rumEnableTraceWebView"],
        @[@"rumAllowWebViewHost", @"rumAllowWebViewHost"],
        @[@"traceSampleRate", @"traceSampleRate"],
        @[@"traceEnableAutoTrace", @"traceEnableAutoTrace"],
        @[@"traceType", @"traceType"],
        @[@"logSampleRate", @"logSampleRate"],
        @[@"logLevelFilters", @"logLevelFilters"],
        @[@"logEnableCustomLog", @"logEnableCustomLog"],
        @[@"sessionReplaySampleRate", @"sessionReplaySampleRate"],
        @[@"sessionReplayOnErrorSampleRate", @"sessionReplayOnErrorSampleRate"],
    ];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSArray<NSString *> *entry in properties) {
        id value = [model valueForKey:entry[1]];
        if (value) result[entry[0]] = value;
    }
    return result;
}

@interface GuanceElectronRuntime : NSObject
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL initialized;
@property (nonatomic, assign) BOOL shutdown;
@property (nonatomic, assign) BOOL rumConfigured;
@property (nonatomic, assign) NSInteger remoteConfigMinimumInterval;
@end

@implementation GuanceElectronRuntime

+ (instancetype)sharedInstance {
    static GuanceElectronRuntime *runtime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        runtime = [[GuanceElectronRuntime alloc] init];
        runtime.lock = [[NSLock alloc] init];
        runtime.remoteConfigMinimumInterval = 12 * 60 * 60;
    });
    return runtime;
}

- (BOOL)requireInitialized:(NSError **)error {
    [self.lock lock];
    BOOL ready = self.initialized && !self.shutdown;
    [self.lock unlock];
    return ready || GEFail(error, @"Native SDK is not initialized");
}

- (BOOL)requireRUM:(NSError **)error {
    if (![self requireInitialized:error]) return NO;
    [self.lock lock];
    BOOL ready = self.rumConfigured;
    [self.lock unlock];
    return ready || GEFail(error, @"Native RUM is not configured");
}

- (BOOL)initializeSDK:(NSDictionary *)payload error:(NSError **)error {
    [self.lock lock];
    if (self.initialized || self.shutdown) {
        [self.lock unlock];
        return GEFail(error, @"The Native SDK can only be initialized once per process");
    }

    FTSDKConfig *config;
    NSString *datakitURL = [payload[@"datakitUrl"] isKindOfClass:NSString.class]
        ? payload[@"datakitUrl"] : nil;
    if (datakitURL.length > 0) {
        config = [[FTSDKConfig alloc] initWithDatakitUrl:datakitURL];
    } else {
        NSString *datawayURL = GEString(payload, @"datawayUrl", error);
        NSString *clientToken = GEString(payload, @"clientToken", error);
        if (!datawayURL || !clientToken) {
            [self.lock unlock];
            return NO;
        }
        config = [[FTSDKConfig alloc] initWithDatawayUrl:datawayURL clientToken:clientToken];
    }
    if ([payload[@"env"] isKindOfClass:NSString.class]) config.env = payload[@"env"];
    if ([payload[@"debug"] isKindOfClass:NSNumber.class]) config.enableSDKDebugLog = [payload[@"debug"] boolValue];
    if ([payload[@"service"] isKindOfClass:NSString.class]) config.service = payload[@"service"];
    if ([payload[@"autoSync"] isKindOfClass:NSNumber.class]) config.autoSync = [payload[@"autoSync"] boolValue];
    if ([payload[@"syncPageSize"] isKindOfClass:NSNumber.class]) config.syncPageSize = [payload[@"syncPageSize"] intValue];
    if ([payload[@"syncSleepTime"] isKindOfClass:NSNumber.class]) config.syncSleepTime = [payload[@"syncSleepTime"] intValue];
    if ([payload[@"enableDataIntegerCompatible"] isKindOfClass:NSNumber.class]) config.enableDataIntegerCompatible = [payload[@"enableDataIntegerCompatible"] boolValue];
    if ([payload[@"compressIntakeRequests"] isKindOfClass:NSNumber.class]) config.compressIntakeRequests = [payload[@"compressIntakeRequests"] boolValue];
    if ([payload[@"enableLimitWithDbSize"] isKindOfClass:NSNumber.class]) config.enableLimitWithDbSize = [payload[@"enableLimitWithDbSize"] boolValue];
    if ([payload[@"dbCacheLimit"] isKindOfClass:NSNumber.class]) config.dbCacheLimit = [payload[@"dbCacheLimit"] longValue];
    if ([payload[@"dbDiscardStrategy"] isKindOfClass:NSString.class]) {
        config.dbDiscardType = [payload[@"dbDiscardStrategy"] isEqualToString:@"discardOldest"]
            ? FTDBDiscardOldest : FTDBDiscard;
    }
    NSDictionary *globalContext = GEStringContext(payload[@"globalContext"]);
    if (globalContext) config.globalContext = globalContext;
    if ([payload[@"groupIdentifiers"] isKindOfClass:NSArray.class]) config.groupIdentifiers = payload[@"groupIdentifiers"];
    if ([payload[@"enableDataFilter"] isKindOfClass:NSNumber.class]) config.enableDataFilter = [payload[@"enableDataFilter"] boolValue];
    if ([payload[@"dataFilters"] isKindOfClass:NSDictionary.class]) config.dataFilters = payload[@"dataFilters"];
    if ([payload[@"remoteConfiguration"] isKindOfClass:NSNumber.class]) config.remoteConfiguration = [payload[@"remoteConfiguration"] boolValue];
    if ([payload[@"remoteConfigMiniUpdateInterval"] isKindOfClass:NSNumber.class]) {
        config.remoteConfigMiniUpdateInterval = [payload[@"remoteConfigMiniUpdateInterval"] intValue];
    }
    [FTMobileAgent startWithConfigOptions:config];
    self.remoteConfigMinimumInterval = config.remoteConfigMiniUpdateInterval;
    self.initialized = YES;
    [self.lock unlock];
    return YES;
}

- (BOOL)configureRUM:(NSDictionary *)payload error:(NSError **)error {
    if (![self requireInitialized:error]) return NO;
    NSString *appID = GEString(payload, @"appId", error);
    if (!appID) return NO;
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:appID];
    if ([payload[@"sampleRate"] isKindOfClass:NSNumber.class]) config.sampleRate = [payload[@"sampleRate"] intValue];
    if ([payload[@"sessionOnErrorSampleRate"] isKindOfClass:NSNumber.class]) config.sessionOnErrorSampleRate = [payload[@"sessionOnErrorSampleRate"] intValue];
    if ([payload[@"enableTraceUserAction"] isKindOfClass:NSNumber.class]) config.enableTraceUserAction = [payload[@"enableTraceUserAction"] boolValue];
    if ([payload[@"enableTraceUserView"] isKindOfClass:NSNumber.class]) config.enableTraceUserView = [payload[@"enableTraceUserView"] boolValue];
    if ([payload[@"enableTraceUserResource"] isKindOfClass:NSNumber.class]) config.enableTraceUserResource = [payload[@"enableTraceUserResource"] boolValue];
    if ([payload[@"enableResourceHostIP"] isKindOfClass:NSNumber.class]) config.enableResourceHostIP = [payload[@"enableResourceHostIP"] boolValue];
    if ([payload[@"enableTrackAppCrash"] isKindOfClass:NSNumber.class]) config.enableTrackAppCrash = [payload[@"enableTrackAppCrash"] boolValue];
    if ([payload[@"crashMonitoring"] isKindOfClass:NSNumber.class]) config.crashMonitoring = (FTCrashMonitorType)[payload[@"crashMonitoring"] unsignedIntegerValue];
    if ([payload[@"enableTrackAppFreeze"] isKindOfClass:NSNumber.class]) config.enableTrackAppFreeze = [payload[@"enableTrackAppFreeze"] boolValue];
    if ([payload[@"freezeDurationMs"] isKindOfClass:NSNumber.class]) config.freezeDurationMs = [payload[@"freezeDurationMs"] longValue];
    if ([payload[@"enableTrackAppANR"] isKindOfClass:NSNumber.class]) config.enableTrackAppANR = [payload[@"enableTrackAppANR"] boolValue];
    if ([payload[@"errorMonitorType"] isKindOfClass:NSNumber.class]) config.errorMonitorType = (FTErrorMonitorType)[payload[@"errorMonitorType"] unsignedIntegerValue];
    if ([payload[@"deviceMetricsMonitorType"] isKindOfClass:NSNumber.class]) config.deviceMetricsMonitorType = (FTDeviceMetricsMonitorType)[payload[@"deviceMetricsMonitorType"] unsignedIntegerValue];
    if ([payload[@"monitorFrequency"] isKindOfClass:NSString.class]) {
        NSString *value = payload[@"monitorFrequency"];
        config.monitorFrequency = [value isEqualToString:@"frequent"]
            ? FTMonitorFrequencyFrequent
            : ([value isEqualToString:@"rare"] ? FTMonitorFrequencyRare : FTMonitorFrequencyDefault);
    }
    NSDictionary *globalContext = GEStringContext(payload[@"globalContext"]);
    if (globalContext) config.globalContext = globalContext;
    if ([payload[@"rumCacheLimitCount"] isKindOfClass:NSNumber.class]) config.rumCacheLimitCount = [payload[@"rumCacheLimitCount"] intValue];
    if ([payload[@"rumDiscardStrategy"] isKindOfClass:NSString.class]) {
        config.rumDiscardType = [payload[@"rumDiscardStrategy"] isEqualToString:@"discardOldest"]
            ? FTRUMDiscardOldest : FTRUMDiscard;
    }
    if ([payload[@"enableTraceWebView"] isKindOfClass:NSNumber.class]) config.enableTraceWebView = [payload[@"enableTraceWebView"] boolValue];
    if (payload[@"allowWebViewHost"]) {
        config.allowWebViewHost = payload[@"allowWebViewHost"] == NSNull.null
            ? nil : payload[@"allowWebViewHost"];
    }
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:config];
    [[FTElectronWebViewHandler sharedInstance] start];
    [self.lock lock];
    self.rumConfigured = YES;
    [self.lock unlock];
    return YES;
}

- (BOOL)configureLogger:(NSDictionary *)payload error:(NSError **)error {
    if (![self requireInitialized:error]) return NO;
    FTLoggerConfig *config = [[FTLoggerConfig alloc] init];
    if ([payload[@"sampleRate"] isKindOfClass:NSNumber.class]) config.sampleRate = [payload[@"sampleRate"] intValue];
    if ([payload[@"enableLinkRumData"] isKindOfClass:NSNumber.class]) config.enableLinkRumData = [payload[@"enableLinkRumData"] boolValue];
    if ([payload[@"enableCustomLog"] isKindOfClass:NSNumber.class]) config.enableCustomLog = [payload[@"enableCustomLog"] boolValue];
    if ([payload[@"printCustomLogToConsole"] isKindOfClass:NSNumber.class]) config.printCustomLogToConsole = [payload[@"printCustomLogToConsole"] boolValue];
    if ([payload[@"logCacheLimitCount"] isKindOfClass:NSNumber.class]) config.logCacheLimitCount = [payload[@"logCacheLimitCount"] intValue];
    if ([payload[@"discardStrategy"] isKindOfClass:NSString.class]) {
        config.discardType = [payload[@"discardStrategy"] isEqualToString:@"discardOldest"]
            ? FTDiscardOldest : FTDiscard;
    }
    if ([payload[@"logLevelFilter"] isKindOfClass:NSArray.class]) config.logLevelFilter = payload[@"logLevelFilter"];
    NSDictionary *globalContext = GEStringContext(payload[@"globalContext"]);
    if (globalContext) config.globalContext = globalContext;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:config];
    return YES;
}

- (BOOL)configureTrace:(NSDictionary *)payload error:(NSError **)error {
    if (![self requireInitialized:error]) return NO;
    FTTraceConfig *config = [[FTTraceConfig alloc] init];
    if ([payload[@"sampleRate"] isKindOfClass:NSNumber.class]) config.sampleRate = [payload[@"sampleRate"] intValue];
    if ([payload[@"enableLinkRumData"] isKindOfClass:NSNumber.class]) config.enableLinkRumData = [payload[@"enableLinkRumData"] boolValue];
    if ([payload[@"enableAutoTrace"] isKindOfClass:NSNumber.class]) config.enableAutoTrace = [payload[@"enableAutoTrace"] boolValue];
    NSString *traceType = [payload[@"traceType"] isKindOfClass:NSString.class] ? payload[@"traceType"] : nil;
    NSDictionary<NSString *, NSNumber *> *types = @{
        @"zipkinMulti": @(FTNetworkTraceTypeZipkinMultiHeader),
        @"zipkinSingle": @(FTNetworkTraceTypeZipkinSingleHeader),
        @"traceparent": @(FTNetworkTraceTypeTraceparent),
        @"skywalking": @(FTNetworkTraceTypeSkywalking),
        @"jaeger": @(FTNetworkTraceTypeJaeger),
    };
    config.networkTraceType = types[traceType]
        ? (FTNetworkTraceType)[types[traceType] unsignedIntegerValue]
        : FTNetworkTraceTypeDDtrace;
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:config];
    return YES;
}

- (BOOL)configureSessionReplay:(NSDictionary *)payload error:(NSError **)error {
    if (![self requireRUM:error]) return NO;
    FTSessionReplayConfig *config = [[FTSessionReplayConfig alloc] init];
    if ([payload[@"sampleRate"] isKindOfClass:NSNumber.class]) config.sampleRate = [payload[@"sampleRate"] intValue];
    if ([payload[@"sessionReplayOnErrorSampleRate"] isKindOfClass:NSNumber.class]) config.sessionReplayOnErrorSampleRate = [payload[@"sessionReplayOnErrorSampleRate"] intValue];
    if ([payload[@"touchPrivacy"] isKindOfClass:NSString.class]) {
        config.touchPrivacy = [payload[@"touchPrivacy"] isEqualToString:@"show"]
            ? FTTouchPrivacyLevelShow : FTTouchPrivacyLevelHide;
    }
    if ([payload[@"textAndInputPrivacy"] isKindOfClass:NSString.class]) {
        NSString *value = payload[@"textAndInputPrivacy"];
        config.textAndInputPrivacy = [value isEqualToString:@"maskSensitiveInputs"]
            ? FTTextAndInputPrivacyLevelMaskSensitiveInputs
            : ([value isEqualToString:@"maskAllInputs"]
                ? FTTextAndInputPrivacyLevelMaskAllInputs
                : FTTextAndInputPrivacyLevelMaskAll);
    }
    if ([payload[@"imagePrivacy"] isKindOfClass:NSString.class]) {
        NSString *value = payload[@"imagePrivacy"];
        config.imagePrivacy = [value isEqualToString:@"maskNone"]
            ? FTImagePrivacyLevelMaskNone
            : ([value isEqualToString:@"maskNonBundledOnly"]
                ? FTImagePrivacyLevelMaskNonBundledOnly
                : FTImagePrivacyLevelMaskAll);
    }
    if ([payload[@"enableLinkRumKeys"] isKindOfClass:NSArray.class]) config.enableLinkRUMKeys = payload[@"enableLinkRumKeys"];
    if ([payload[@"enableHeatmap"] isKindOfClass:NSNumber.class]) config.enableHeatmap = [payload[@"enableHeatmap"] boolValue];
    [[FTRumSessionReplay sharedInstance] startWithSessionReplayConfig:config];
    return YES;
}

- (FTResourceMetricsModel *)resourceMetrics:(id)value {
    if (![value isKindOfClass:NSDictionary.class] || [value count] == 0) return nil;
    NSDictionary *values = value;
    FTResourceMetricsModel *metrics = [[FTResourceMetricsModel alloc] init];
    NSNumber *duration = [values[@"duration"] isKindOfClass:NSNumber.class] ? values[@"duration"] : nil;
    NSNumber *dns = [values[@"dns"] isKindOfClass:NSNumber.class] ? values[@"dns"] : nil;
    NSNumber *tcp = [values[@"tcp"] isKindOfClass:NSNumber.class] ? values[@"tcp"] : nil;
    NSNumber *ssl = [values[@"ssl"] isKindOfClass:NSNumber.class] ? values[@"ssl"] : nil;
    NSNumber *ttfb = [values[@"ttfb"] isKindOfClass:NSNumber.class] ? values[@"ttfb"] : values[@"firstByte"];
    NSNumber *transfer = [values[@"transfer"] isKindOfClass:NSNumber.class] ? values[@"transfer"] : nil;
    if (duration) { metrics.fetchStartNsTimeInterval = 0; metrics.fetchEndNsTimeInterval = duration.longLongValue; }
    if (dns) { metrics.dnsStartNsTimeInterval = 0; metrics.dnsEndNsTimeInterval = dns.longLongValue; }
    if (tcp) { metrics.connectStartNsTimeInterval = 0; metrics.connectEndNsTimeInterval = tcp.longLongValue; }
    if (ssl) { metrics.sslStartNsTimeInterval = 0; metrics.sslEndNsTimeInterval = ssl.longLongValue; }
    if (ttfb) { metrics.requestStartNsTimeInterval = 0; metrics.responseStartNsTimeInterval = ttfb.longLongValue; }
    if (transfer) { metrics.requestStartNsTimeInterval = 0; metrics.requestEndNsTimeInterval = transfer.longLongValue; }
    return metrics;
}

- (BOOL)addResource:(NSDictionary *)payload error:(NSError **)error {
    NSDictionary *content = [payload[@"content"] isKindOfClass:NSDictionary.class]
        ? payload[@"content"] : nil;
    NSString *urlString = content ? GEString(content, @"url", error) : nil;
    NSURL *url = urlString ? [NSURL URLWithString:urlString] : nil;
    if (!content || !url) return GEFail(error, @"content.url is invalid");
    NSString *method = GEString(content, @"httpMethod", error);
    NSString *key = GEString(payload, @"key", error);
    if (!method || !key) return NO;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    if ([content[@"requestHeaders"] isKindOfClass:NSDictionary.class]) request.allHTTPHeaderFields = content[@"requestHeaders"];
    NSInteger status = [content[@"statusCode"] isKindOfClass:NSNumber.class]
        ? [content[@"statusCode"] integerValue] : 0;
    NSHTTPURLResponse *response = status > 0
        ? [[NSHTTPURLResponse alloc] initWithURL:url
                                     statusCode:status
                                    HTTPVersion:nil
                                   headerFields:[content[@"responseHeaders"] isKindOfClass:NSDictionary.class]
                                       ? content[@"responseHeaders"] : nil]
        : nil;
    NSData *body = [content[@"responseBody"] isKindOfClass:NSString.class]
        ? [content[@"responseBody"] dataUsingEncoding:NSUTF8StringEncoding] : nil;
    FTResourceContentModel *model = [[FTResourceContentModel alloc]
        initWithRequest:request response:response data:body error:nil];
    [[FTExternalDataManager sharedManager] addResourceWithKey:key
                                                    metrics:[self resourceMetrics:payload[@"metrics"]]
                                                    content:model];
    return YES;
}

- (NSDictionary *)traceHeaders:(NSDictionary *)payload error:(NSError **)error {
    if (![self requireInitialized:error]) return nil;
    NSString *urlString = GEString(payload, @"url", error);
    NSURL *url = urlString ? [NSURL URLWithString:urlString] : nil;
    if (!url) {
        GEFail(error, @"url is invalid");
        return nil;
    }
    NSDictionary *headers;
    if ([payload[@"resourceKey"] isKindOfClass:NSString.class]) {
        headers = [[FTExternalDataManager sharedManager]
            getTraceHeaderWithKey:payload[@"resourceKey"] url:url];
    } else {
        headers = [[FTExternalDataManager sharedManager] getTraceHeaderWithUrl:url];
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        result[[key description]] = [value description];
    }];
    return result;
}

- (NSArray *)trackExtensionEvents:(NSString *)groupIdentifier {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSArray *events = @[];
    [[FTMobileAgent sharedInstance]
        trackEventFromExtensionWithGroupIdentifier:groupIdentifier
        completion:^(NSString *identifier, NSArray *value) {
            events = value ?: @[];
            dispatch_semaphore_signal(semaphore);
        }];
    dispatch_semaphore_wait(semaphore,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)));
    return events;
}

- (NSDictionary *)updateRemoteConfig:(NSDictionary *)payload error:(NSError **)error {
    NSInteger interval = [payload[@"minimumInterval"] isKindOfClass:NSNumber.class]
        ? [payload[@"minimumInterval"] integerValue]
        : self.remoteConfigMinimumInterval;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSDictionary *result = @{@"content": NSNull.null, @"config": NSNull.null};
    __block NSError *callbackError;
    [FTMobileAgent updateRemoteConfigWithMiniUpdateInterval:interval
        completion:^FTRemoteConfigModel *(BOOL success, NSError *nativeError,
                                          FTRemoteConfigModel *model,
                                          NSDictionary<NSString *, id> *content) {
            if (success) {
                result = @{
                    @"content": content ?: NSNull.null,
                    @"config": GESnapshotForRemoteConfig(model) ?: NSNull.null,
                };
            } else {
                callbackError = nativeError ?: GEError(@"Remote configuration update failed");
            }
            dispatch_semaphore_signal(semaphore);
            return model;
        }];
    if (dispatch_semaphore_wait(semaphore,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC))) != 0) {
        GEFail(error, @"Remote configuration update timed out");
        return nil;
    }
    if (callbackError) {
        if (error) *error = callbackError;
        return nil;
    }
    return result;
}

- (id)invoke:(NSString *)method payload:(NSDictionary *)payload error:(NSError **)error {
    if ([method isEqualToString:@"sdk.initialize"]) {
        return [self initializeSDK:payload error:error] ? @{} : nil;
    }
    if ([method isEqualToString:@"sdk.setDatakitUrl"]) {
        if (![self requireInitialized:error]) return nil;
        NSString *url = GEString(payload, @"url", error);
        if (!url) return nil;
        [FTMobileAgent setDatakitURL:url];
    } else if ([method isEqualToString:@"sdk.setDataway"]) {
        if (![self requireInitialized:error]) return nil;
        NSString *url = GEString(payload, @"url", error);
        NSString *token = GEString(payload, @"clientToken", error);
        if (!url || !token) return nil;
        [FTMobileAgent setDatawayURL:url clientToken:token];
    } else if ([method isEqualToString:@"sdk.bindUser"]) {
        if (![self requireInitialized:error]) return nil;
        NSString *identifier = GEString(payload, @"id", error);
        if (!identifier) return nil;
        [[FTMobileAgent sharedInstance] bindUserWithUserID:identifier
                                                 userName:[payload[@"name"] isKindOfClass:NSString.class] ? payload[@"name"] : nil
                                                userEmail:[payload[@"email"] isKindOfClass:NSString.class] ? payload[@"email"] : nil
                                                    extra:[payload[@"extra"] isKindOfClass:NSDictionary.class] ? payload[@"extra"] : nil];
    } else if ([method isEqualToString:@"sdk.unbindUser"]) {
        if (![self requireInitialized:error]) return nil;
        [[FTMobileAgent sharedInstance] unbindUser];
    } else if ([method isEqualToString:@"sdk.addGlobalContext"] ||
               [method isEqualToString:@"sdk.addRumGlobalContext"] ||
               [method isEqualToString:@"sdk.addLogGlobalContext"]) {
        if (![self requireInitialized:error]) return nil;
        if ([method isEqualToString:@"sdk.addGlobalContext"]) [FTMobileAgent appendGlobalContext:payload];
        if ([method isEqualToString:@"sdk.addRumGlobalContext"]) [FTMobileAgent appendRUMGlobalContext:payload];
        if ([method isEqualToString:@"sdk.addLogGlobalContext"]) [FTMobileAgent appendLogGlobalContext:payload];
    } else if ([method isEqualToString:@"sdk.trackExtensionEvents"]) {
        if (![self requireInitialized:error]) return nil;
        NSString *group = GEString(payload, @"groupIdentifier", error);
        return group ? [self trackExtensionEvents:group] : nil;
    } else if ([method isEqualToString:@"sdk.flush"]) {
        if (![self requireInitialized:error]) return nil;
        [[FTMobileAgent sharedInstance] flushSyncData];
    } else if ([method isEqualToString:@"sdk.clearData"]) {
        if (![self requireInitialized:error]) return nil;
        [FTMobileAgent clearAllData];
    } else if ([method isEqualToString:@"sdk.updateRemoteConfig"]) {
        if (![self requireInitialized:error]) return nil;
        return [self updateRemoteConfig:payload error:error];
    } else if ([method isEqualToString:@"sdk.shutdown"]) {
        if (![self requireInitialized:error]) return nil;
        [FTMobileAgent shutDown];
        [self.lock lock]; self.shutdown = YES; [self.lock unlock];
    } else if ([method isEqualToString:@"rum.configure"]) {
        return [self configureRUM:payload error:error] ? @{} : nil;
    } else if ([method isEqualToString:@"rum.onCreateView"]) {
        if (![self requireRUM:error]) return nil;
        NSString *name = GEString(payload, @"name", error);
        NSNumber *loadTime = GENumber(payload, @"loadTime", error);
        if (!name || !loadTime) return nil;
        [[FTExternalDataManager sharedManager] onCreateView:name loadTime:loadTime];
    } else if ([method isEqualToString:@"rum.startView"]) {
        if (![self requireRUM:error]) return nil;
        NSString *name = GEString(payload, @"name", error);
        if (!name) return nil;
        [[FTExternalDataManager sharedManager] startViewWithName:name property:payload[@"attributes"]];
    } else if ([method isEqualToString:@"rum.updateViewLoadingTime"]) {
        if (![self requireRUM:error]) return nil;
        NSNumber *duration = GENumber(payload, @"duration", error);
        if (!duration) return nil;
        [[FTExternalDataManager sharedManager] updateViewLoadingTime:duration];
    } else if ([method isEqualToString:@"rum.stopView"]) {
        if (![self requireRUM:error]) return nil;
        [[FTExternalDataManager sharedManager] stopViewWithProperty:payload[@"attributes"]];
    } else if ([method isEqualToString:@"rum.startAction"] || [method isEqualToString:@"rum.addAction"]) {
        if (![self requireRUM:error]) return nil;
        NSString *name = GEString(payload, @"name", error);
        NSString *type = GEString(payload, @"type", error);
        if (!name || !type) return nil;
        if ([method isEqualToString:@"rum.startAction"]) {
            [[FTExternalDataManager sharedManager] startAction:name actionType:type property:payload[@"attributes"]];
        } else {
            [[FTExternalDataManager sharedManager] addAction:name actionType:type property:payload[@"attributes"]];
        }
    } else if ([method isEqualToString:@"rum.addError"]) {
        if (![self requireRUM:error]) return nil;
        NSString *type = GEString(payload, @"type", error);
        NSString *message = GEString(payload, @"message", error);
        NSString *stack = GEString(payload, @"stack", error);
        if (!type || !message || !stack) return nil;
        NSDictionary *states = @{@"unknown": @0, @"startup": @1, @"start_up": @1,
                                 @"run": @2, @"running": @2, @"background": @3};
        NSNumber *state = [payload[@"state"] isKindOfClass:NSString.class]
            ? states[[payload[@"state"] lowercaseString]] : nil;
        if (state) {
            [[FTExternalDataManager sharedManager] addErrorWithType:type
                                                              state:(FTAppState)state.unsignedIntegerValue
                                                            message:message stack:stack
                                                           property:payload[@"attributes"]];
        } else {
            [[FTExternalDataManager sharedManager] addErrorWithType:type message:message
                                                              stack:stack property:payload[@"attributes"]];
        }
    } else if ([method isEqualToString:@"rum.addLongTask"]) {
        if (![self requireRUM:error]) return nil;
        NSString *stack = GEString(payload, @"stack", error);
        NSNumber *duration = GENumber(payload, @"duration", error);
        if (!stack || !duration) return nil;
        [[FTExternalDataManager sharedManager] addLongTaskWithStack:stack duration:duration
                                                          property:payload[@"attributes"]];
    } else if ([method isEqualToString:@"rum.startResource"] || [method isEqualToString:@"rum.stopResource"]) {
        if (![self requireRUM:error]) return nil;
        NSString *key = GEString(payload, @"key", error);
        if (!key) return nil;
        if ([method isEqualToString:@"rum.startResource"]) {
            [[FTExternalDataManager sharedManager] startResourceWithKey:key property:payload[@"attributes"]];
        } else {
            [[FTExternalDataManager sharedManager] stopResourceWithKey:key property:payload[@"attributes"]];
        }
    } else if ([method isEqualToString:@"rum.addResource"]) {
        if (![self requireRUM:error] || ![self addResource:payload error:error]) return nil;
    } else if ([method isEqualToString:@"logger.configure"]) {
        return [self configureLogger:payload error:error] ? @{} : nil;
    } else if ([method isEqualToString:@"logger.log"]) {
        if (![self requireInitialized:error]) return nil;
        NSString *content = GEString(payload, @"content", error);
        NSString *status = GEString(payload, @"status", error);
        if (!content || !status) return nil;
        [[FTLogger sharedInstance] log:content status:status property:payload[@"attributes"]];
    } else if ([method isEqualToString:@"trace.configure"]) {
        return [self configureTrace:payload error:error] ? @{} : nil;
    } else if ([method isEqualToString:@"trace.getHeaders"]) {
        return [self traceHeaders:payload error:error];
    } else if ([method isEqualToString:@"sessionReplay.configure"]) {
        return [self configureSessionReplay:payload error:error] ? @{} : nil;
    } else {
        GEFail(error, [NSString stringWithFormat:@"Unsupported Native method: %@", method]);
        return nil;
    }
    return @{};
}

@end

static NSDictionary *GEJSONPayload(const char *pointer, NSError **error) {
    if (!pointer) return @{};
    NSData *data = [[NSString stringWithUTF8String:pointer] dataUsingEncoding:NSUTF8StringEncoding];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:error] : nil;
    if (![object isKindOfClass:NSDictionary.class]) {
        if (error && !*error) *error = GEError(@"payload must be a JSON object");
        return nil;
    }
    return object;
}

static char *GEEncodedResult(id object, BOOL isError) {
    id value = isError ? @{@"message": [object description]} : (object ?: @{});
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!json) json = @"{\"message\":\"Native result serialization failed\"}";
    NSString *framed = [NSString stringWithFormat:@"%c%@", isError ? '1' : '0', json];
    return strdup(framed.UTF8String);
}

char *guance_electron_invoke(const char *method, const char *payload_json) {
    @autoreleasepool {
        if (!method) return GEEncodedResult(@"method is required", YES);
        NSError *error;
        NSDictionary *payload = GEJSONPayload(payload_json, &error);
        if (!payload) return GEEncodedResult(error.localizedDescription, YES);
        id result = [[GuanceElectronRuntime sharedInstance]
            invoke:[NSString stringWithUTF8String:method] payload:payload error:&error];
        return error ? GEEncodedResult(error.localizedDescription, YES)
                     : GEEncodedResult(result, NO);
    }
}

void guance_electron_free_string(char *value) {
    free(value);
}

static int32_t GEWriteJSON(id object, char *output, int32_t capacity) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (!data) return -1;
    NSUInteger required = data.length + 1;
    if (!output || capacity < required) return (int32_t)required;
    memcpy(output, data.bytes, data.length);
    output[data.length] = '\0';
    return (int32_t)data.length;
}

int32_t guance_electron_bridge_configuration(char *output, int32_t capacity) {
    @autoreleasepool {
        return GEWriteJSON([[FTElectronWebViewHandler sharedInstance] bridgeConfiguration],
                           output, capacity);
    }
}

static NSView *GEHostView(void *pointer) {
    if (!pointer) return nil;
    NSView *electronView = (__bridge NSView *)pointer;
    return electronView.window.contentView;
}

static int32_t GEOnMain(int32_t (^work)(void)) {
    if (NSThread.isMainThread) return work();
    __block int32_t result;
    dispatch_sync(dispatch_get_main_queue(), ^{ result = work(); });
    return result;
}

int32_t guance_electron_register_web_contents(
    void *electron_view, int64_t web_contents_id, int64_t slot_id,
    int32_t visible, int32_t z_index, int32_t has_bounds,
    double x, double y, double width, double height
) {
    return GEOnMain(^int32_t{
        NSView *view = GEHostView(electron_view);
        if (!view) return 0;
        CGRect bounds = has_bounds ? CGRectMake(x, y, width, height) : view.bounds;
        return [[FTElectronWebViewHandler sharedInstance]
            registerWebContentsID:web_contents_id slotID:slot_id hostView:view
            bounds:bounds visible:visible != 0 zIndex:z_index] ? 1 : 0;
    });
}

int32_t guance_electron_update_web_contents(
    void *electron_view, int64_t web_contents_id,
    int32_t visible, int32_t z_index, int32_t has_bounds,
    double x, double y, double width, double height
) {
    return GEOnMain(^int32_t{
        NSView *view = GEHostView(electron_view);
        if (!view) return 0;
        CGRect bounds = has_bounds ? CGRectMake(x, y, width, height) : view.bounds;
        return [[FTElectronWebViewHandler sharedInstance]
            updateWebContentsID:web_contents_id bounds:bounds
            visible:visible != 0 zIndex:z_index] ? 1 : 0;
    });
}

int32_t guance_electron_receive_web_contents_message(
    int64_t web_contents_id, const char *message_queue
) {
    @autoreleasepool {
        if (!message_queue) return 0;
        return [[FTElectronWebViewHandler sharedInstance]
            receiveMessageQueue:[NSString stringWithUTF8String:message_queue]
            webContentsID:web_contents_id] ? 1 : 0;
    }
}

void guance_electron_unregister_web_contents(int64_t web_contents_id) {
    [[FTElectronWebViewHandler sharedInstance] unregisterWebContentsID:web_contents_id];
}

void guance_electron_set_command_handler(
    guance_electron_command_callback callback, void *context
) {
    FTElectronWebViewCommandHandler handler = callback
        ? ^(int64_t webContentsID, NSString *command) {
            callback(webContentsID, command.UTF8String, context);
        }
        : nil;
    [[FTElectronWebViewHandler sharedInstance] startWithCommandHandler:handler];
}

#endif // TARGET_OS_OSX
