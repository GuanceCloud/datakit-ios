//
//  FTRemoteConfigModel.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/12/23.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRemoteConfigModel.h"
#import "FTRemoteConfigModel+Private.h"
#import "FTJSONUtil.h"

#define isNSNumber(obj) (obj && [obj isKindOfClass:[NSNumber class]])
#define isNSString(obj) (obj && [obj isKindOfClass:[NSString class]])

#define SetNumberFromDict(obj, key, prop) do { \
    id val = obj[key]; \
    if (isNSNumber(val)) prop = val; \
} while (0)

#define SetStringFromDict(obj, key, prop) do { \
    id val = obj[key]; \
    if (isNSString(val)) prop = val; \
} while (0)

NSString * const FT_R_ENV = @"env";
NSString * const FT_R_SERVICE_NAME = @"serviceName";
NSString * const FT_R_AUTO_SYNC = @"autoSync";
NSString * const FT_R_COMPRESS_INTAKE_REQUESTS = @"compressIntakeRequests";
NSString * const FT_R_SYNC_PAGE_SIZE = @"syncPageSize";
NSString * const FT_R_SYNC_SLEEP_TIME = @"syncSleepTime";

NSString * const FT_R_RUM_SAMPLERATE = @"rumSampleRate";
NSString * const FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE = @"rumSessionOnErrorSampleRate";
NSString * const FT_R_RUM_ENABLE_TRACE_USER_ACTION = @"rumEnableTraceUserAction";
NSString * const FT_R_RUM_ENABLE_TRACE_USER_VIEW = @"rumEnableTraceUserView";
NSString * const FT_R_RUM_ENABLE_TRACE_USER_RESOURCE = @"rumEnableTraceUserResource";
NSString * const FT_R_RUM_ENABLE_RESOURCE_HOST_IP = @"rumEnableResourceHostIP";
NSString * const FT_R_RUM_ENABLE_TRACE_APP_FREEZE = @"rumEnableTrackAppUIBlock";
NSString * const FT_R_RUM_FREEZE_DURATION_MS = @"rumBlockDurationMs";
NSString * const FT_R_RUM_ENABLE_TRACK_APP_CRASH = @"rumEnableTrackAppCrash";
NSString * const FT_R_RUM_ENABLE_TRACK_APP_ANR = @"rumEnableTrackAppANR";
NSString * const FT_R_RUM_ENABLE_TRACE_WEBVIEW = @"rumEnableTraceWebView";
NSString * const FT_R_RUM_ALLOW_WEBVIEW_HOST = @"rumAllowWebViewHost";

NSString * const FT_R_TRACE_SAMPLERATE = @"traceSampleRate";
NSString * const FT_R_TRACE_ENABLE_AUTO_TRACE = @"traceEnableAutoTrace";
NSString * const FT_R_TRACE_TRACE_TYPE = @"traceType";

NSString * const FT_R_LOG_SAMPLERATE = @"logSampleRate";
NSString * const FT_R_LOG_LEVEL_FILTERS = @"logLevelFilters";
NSString * const FT_R_LOG_ENABLE_CUSTOM_LOG = @"logEnableCustomLog";

NSString * const FT_MD5 = @"MD5";

@interface FTRemoteConfigModel()
@property (nonatomic, copy, readwrite, nullable) NSString *md5Str;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *context;

@end
@implementation FTRemoteConfigModel

- (instancetype)initWithDict:(NSDictionary *)dict md5:(NSString *)md5{
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    [context setValue:md5 forKey:FT_MD5];
    [context addEntriesFromDictionary:dict];
    return [self initWithDict:context];
}
- (instancetype)initWithDict:(NSDictionary *)dict{
    self = [super init];
    if (self) {
        if (dict) {
            [self paras:dict];
        }else{
            return nil;
        }
    }
    return self;
}
- (void)paras:(NSDictionary *)dict{
    self.context = [dict copy];
    // ---- CORE ----
    SetStringFromDict(dict,FT_R_ENV,self.env);
    SetStringFromDict(dict,FT_R_SERVICE_NAME,self.serviceName);
    SetNumberFromDict(dict,FT_R_AUTO_SYNC,self.autoSync);
    SetNumberFromDict(dict,FT_R_COMPRESS_INTAKE_REQUESTS,self.compressIntakeRequests);
    SetNumberFromDict(dict,FT_R_SYNC_PAGE_SIZE,self.syncPageSize);
    SetNumberFromDict(dict,FT_R_SYNC_SLEEP_TIME,self.syncSleepTime);

    // ---- RUM ----
    SetNumberFromDict(dict,FT_R_RUM_SAMPLERATE,self.rumSampleRate);
    SetNumberFromDict(dict,FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE,self.rumSessionOnErrorSampleRate);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACE_USER_ACTION,self.rumEnableTraceUserAction);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACE_USER_VIEW,self.rumEnableTraceUserView);    
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACE_USER_RESOURCE,self.rumEnableTraceUserResource);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_RESOURCE_HOST_IP,self.rumEnableResourceHostIP);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACE_APP_FREEZE,self.rumEnableTrackAppUIBlock);
    SetNumberFromDict(dict,FT_R_RUM_FREEZE_DURATION_MS,self.rumBlockDurationMs);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACK_APP_CRASH,self.rumEnableTrackAppCrash);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACK_APP_ANR,self.rumEnableTrackAppANR);
    SetNumberFromDict(dict,FT_R_RUM_ENABLE_TRACE_WEBVIEW,self.rumEnableTraceWebView);
    
    NSString *rumAllowWebViewHost;
    SetStringFromDict(dict,FT_R_RUM_ALLOW_WEBVIEW_HOST,rumAllowWebViewHost);
    
    if (rumAllowWebViewHost) {
        NSArray *hosts = [FTJSONUtil arrayWithJsonString:rumAllowWebViewHost];
        if (hosts.count > 0) {
            self.rumAllowWebViewHost = hosts;
        }
    }
    // ---- Trace ----
    SetNumberFromDict(dict,FT_R_TRACE_SAMPLERATE,self.traceSampleRate);
    SetNumberFromDict(dict,FT_R_TRACE_ENABLE_AUTO_TRACE,self.traceEnableAutoTrace);
    SetStringFromDict(dict,FT_R_TRACE_TRACE_TYPE,self.traceType);

    // ---- Log ----
    SetNumberFromDict(dict,FT_R_LOG_SAMPLERATE,self.logSampleRate);
    NSString *logLevelFilters;
    SetStringFromDict(dict,FT_R_LOG_LEVEL_FILTERS,logLevelFilters);
    NSArray *filters = [FTJSONUtil arrayWithJsonString:logLevelFilters];
    if (filters.count>0) {
        self.logLevelFilters = filters;
    }
    SetNumberFromDict(dict,FT_R_LOG_ENABLE_CUSTOM_LOG,self.logEnableCustomLog);

    // ---- MD5 ----
    SetStringFromDict(dict, FT_MD5, self.md5Str);
}
- (NSString *)md5Str{
    return _md5Str;
}

- (NSDictionary *)toDictionary{
    if (!self.context) {
            return @{};
        }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // ===== 1. CORE  =====
    if (self.env) {
        dict[FT_R_ENV] = self.env;
    }
    if (self.serviceName) {
        dict[FT_R_SERVICE_NAME] = self.serviceName;
    }
    if (self.autoSync) {
        dict[FT_R_AUTO_SYNC] = self.autoSync;
    }
    if (self.compressIntakeRequests) {
        dict[FT_R_COMPRESS_INTAKE_REQUESTS] = self.compressIntakeRequests;
    }
    if (self.syncPageSize) {
        dict[FT_R_SYNC_PAGE_SIZE] = self.syncPageSize;
    }
    if (self.syncSleepTime) {
        dict[FT_R_SYNC_SLEEP_TIME] = self.syncSleepTime;
    }
    
    // ===== 2. RUM  =====
    if (self.rumSampleRate) {
        dict[FT_R_RUM_SAMPLERATE] = self.rumSampleRate;
    }
    if (self.rumSessionOnErrorSampleRate) {
        dict[FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE] = self.rumSessionOnErrorSampleRate;
    }
    if (self.rumEnableTraceUserAction) {
        dict[FT_R_RUM_ENABLE_TRACE_USER_ACTION] = self.rumEnableTraceUserAction;
    }
    if (self.rumEnableTraceUserView) {
        dict[FT_R_RUM_ENABLE_TRACE_USER_VIEW] = self.rumEnableTraceUserView;
    }
    if (self.rumEnableTraceUserResource) {
        dict[FT_R_RUM_ENABLE_TRACE_USER_RESOURCE] = self.rumEnableTraceUserResource;
    }
    if (self.rumEnableResourceHostIP) {
        dict[FT_R_RUM_ENABLE_RESOURCE_HOST_IP] = self.rumEnableResourceHostIP;
    }
    if (self.rumEnableTrackAppUIBlock) {
        dict[FT_R_RUM_ENABLE_TRACE_APP_FREEZE] = self.rumEnableTrackAppUIBlock;
    }
    if (self.rumBlockDurationMs) {
        dict[FT_R_RUM_FREEZE_DURATION_MS] = self.rumBlockDurationMs;
    }
    if (self.rumEnableTrackAppCrash) {
        dict[FT_R_RUM_ENABLE_TRACK_APP_CRASH] = self.rumEnableTrackAppCrash;
    }
    if (self.rumEnableTrackAppANR) {
        dict[FT_R_RUM_ENABLE_TRACK_APP_ANR] = self.rumEnableTrackAppANR;
    }
    if (self.rumEnableTraceWebView) {
        dict[FT_R_RUM_ENABLE_TRACE_WEBVIEW] = self.rumEnableTraceWebView;
    }

    if (self.rumAllowWebViewHost && self.rumAllowWebViewHost.count > 0) {
        NSString *hostJson = [FTJSONUtil convertToJsonDataWithObject:self.rumAllowWebViewHost];
        if (hostJson) {
            dict[FT_R_RUM_ALLOW_WEBVIEW_HOST] = hostJson;
        }
    }
    
    // ===== 3. Trace  =====
    if (self.traceSampleRate) {
        dict[FT_R_TRACE_SAMPLERATE] = self.traceSampleRate;
    }
    if (self.traceEnableAutoTrace) {
        dict[FT_R_TRACE_ENABLE_AUTO_TRACE] = self.traceEnableAutoTrace;
    }
    if (self.traceType) {
        dict[FT_R_TRACE_TRACE_TYPE] = self.traceType;
    }
    
    // ===== 4. Log  =====
    if (self.logSampleRate) {
        dict[FT_R_LOG_SAMPLERATE] = self.logSampleRate;
    }

    if (self.logLevelFilters && self.logLevelFilters.count > 0) {
        NSString *filterJson = [FTJSONUtil convertToJsonDataWithObject:self.logLevelFilters];
        if (filterJson) {
            dict[FT_R_LOG_LEVEL_FILTERS] = filterJson;
        }
    }
    if (self.logEnableCustomLog) {
        dict[FT_R_LOG_ENABLE_CUSTOM_LOG] = self.logEnableCustomLog;
    }
    
    // ===== 5. MD5  =====
    if (self.md5Str) {
        dict[FT_MD5] = self.md5Str;
    }
    
    static NSSet<NSString *> *s_knownKeys = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            s_knownKeys = [NSSet setWithObjects:
                            // CORE
                            FT_R_ENV, FT_R_SERVICE_NAME, FT_R_AUTO_SYNC, FT_R_COMPRESS_INTAKE_REQUESTS, FT_R_SYNC_PAGE_SIZE, FT_R_SYNC_SLEEP_TIME,
                            // RUM
                            FT_R_RUM_SAMPLERATE, FT_R_RUM_SESSION_ON_ERROR_SAMPLE_RATE, FT_R_RUM_ENABLE_TRACE_USER_ACTION, FT_R_RUM_ENABLE_TRACE_USER_VIEW,
                            FT_R_RUM_ENABLE_TRACE_USER_RESOURCE, FT_R_RUM_ENABLE_RESOURCE_HOST_IP, FT_R_RUM_ENABLE_TRACE_APP_FREEZE, FT_R_RUM_FREEZE_DURATION_MS,
                            FT_R_RUM_ENABLE_TRACK_APP_CRASH, FT_R_RUM_ENABLE_TRACK_APP_ANR, FT_R_RUM_ENABLE_TRACE_WEBVIEW, FT_R_RUM_ALLOW_WEBVIEW_HOST,
                            // Trace
                            FT_R_TRACE_SAMPLERATE, FT_R_TRACE_ENABLE_AUTO_TRACE, FT_R_TRACE_TRACE_TYPE,
                            // Log
                            FT_R_LOG_SAMPLERATE, FT_R_LOG_LEVEL_FILTERS, FT_R_LOG_ENABLE_CUSTOM_LOG,
                            // MD5
                            FT_MD5,
                            nil];
        });
    
    for (NSString *key in self.context.allKeys) {
        id value = self.context[key];
        if (![s_knownKeys containsObject:key] && value != nil) {
            dict[key] = value;
        }
    }
    
    return [dict copy];
}
#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone {
    FTRemoteConfigModel *copyModel = [[[self class] allocWithZone:zone] init];
    
    // ---- CORE ----
    copyModel.env = [self.env copy];
    copyModel.serviceName = [self.serviceName copy];
    copyModel.autoSync = self.autoSync;
    copyModel.compressIntakeRequests = self.compressIntakeRequests;
    copyModel.syncPageSize = self.syncPageSize;
    copyModel.syncSleepTime = self.syncSleepTime;
    
    // ---- RUM ----
    copyModel.rumSampleRate = self.rumSampleRate;
    copyModel.rumSessionOnErrorSampleRate = self.rumSessionOnErrorSampleRate;
    copyModel.rumEnableTraceUserAction = self.rumEnableTraceUserAction;
    copyModel.rumEnableTraceUserView = self.rumEnableTraceUserView;
    copyModel.rumEnableTraceUserResource = self.rumEnableTraceUserResource;
    copyModel.rumEnableResourceHostIP = self.rumEnableResourceHostIP;
    copyModel.rumEnableTrackAppUIBlock = self.rumEnableTrackAppUIBlock;
    copyModel.rumBlockDurationMs = self.rumBlockDurationMs;
    copyModel.rumEnableTrackAppCrash = self.rumEnableTrackAppCrash;
    copyModel.rumEnableTrackAppANR = self.rumEnableTrackAppANR;
    copyModel.rumEnableTraceWebView = self.rumEnableTraceWebView;
    copyModel.rumAllowWebViewHost = [self.rumAllowWebViewHost copy];
    
    // ---- Trace ----
    copyModel.traceSampleRate = self.traceSampleRate;
    copyModel.traceEnableAutoTrace = self.traceEnableAutoTrace;
    copyModel.traceType = [self.traceType copy];
    
    // ---- Log ----
    copyModel.logSampleRate = self.logSampleRate;
    copyModel.logLevelFilters = [self.logLevelFilters copy];
    copyModel.logEnableCustomLog = self.logEnableCustomLog;
    
    copyModel.context = [self.context copy];
    copyModel.md5Str = [self.md5Str copy];
    return copyModel;
}
@end
