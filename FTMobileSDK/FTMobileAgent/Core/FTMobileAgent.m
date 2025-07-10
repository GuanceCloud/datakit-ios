//
//  FTMobileAgent.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTMobileAgent.h"
#import "FTLoggerConfig.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHandler.h"
#import "FTGlobalRumManager.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTLog+Private.h"
#import "NSString+FTAdd.h"
#import "FTPresetProperty.h"
#import "FTTrackDataManager.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTJSONUtil.h"
#import "FTUserInfo.h"
#import "FTExtensionDataManager.h"
#import "FTExternalDataManager+Private.h"
#import "FTMobileAgentVersion.h"
#import "FTNetworkInfoManager.h"
#import "FTURLSessionInstrumentation.h"
#import "FTEnumConstant.h"
#import "FTMobileConfig+Private.h"
#import "FTLogger+Private.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTTrackerEventDBTool.h"
#import "FTDataWriterWorker.h"
#import "FTRemoteConfigManager.h"
#import "FTRemoteConfigurationProtocol.h"
@interface FTMobileAgent ()<FTAppLifeCycleDelegate,FTRemoteConfigurationProtocol>
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTTraceConfig *traceConfig;
@property (nonatomic, strong) FTMobileConfig *sdkConfig;
@end
@implementation FTMobileAgent
static NSObject *sharedInstanceLock;
static FTMobileAgent *sharedInstance = nil;
+ (void)initialize{
    if (self == [FTMobileAgent class]) {
        sharedInstanceLock = [[NSObject alloc] init];
    }
}
#pragma mark --------- 初始化 config 设置 ----------
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions{
    NSAssert ((strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0),@"SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 launch 事件）。");
    
    NSAssert((configOptions.datakitUrl.length!=0||(configOptions.datawayUrl.length!=0&&configOptions.clientToken.length!=0)), @"请正确配置 datakit  或 dataway 写入地址");
    @synchronized(sharedInstanceLock) {
        if (!sharedInstance) {
            sharedInstance = [[FTMobileAgent alloc] initWithConfig:configOptions];
        }
    }
}
// 单例
+ (instancetype)sharedInstance {
    @synchronized(sharedInstanceLock) {
        NSAssert(sharedInstance, @"请先使用 startWithConfigOptions: 初始化 SDK");
        return sharedInstance;
    }
}
+ (void)setSharedInstance:(nullable FTMobileAgent *)agent block:(void(^)(void))block{
    @synchronized(sharedInstanceLock) {
        if(block) block();
        sharedInstance = agent;
    }
}
- (instancetype)initWithConfig:(FTMobileConfig *)config{
    @try {
        self = [super init];
        if (self) {
            _sdkConfig = [config copy];
            if (_sdkConfig.remoteConfiguration) {
                [[FTRemoteConfigManager sharedInstance] enable:YES updateInterval:_sdkConfig.remoteConfigMiniUpdateInterval];
                [FTRemoteConfigManager sharedInstance].delegate = self;
                [_sdkConfig mergeWithRemoteConfigDict:[[FTRemoteConfigManager sharedInstance] getLocalRemoteConfig]];
            }
            [self applyBaseConfig:_sdkConfig];
        }
    }@catch(NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return self;
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    NSAssert((rumConfigOptions.appid.length!=0 ), @"请设置 appid 用户访问监测应用ID");
    @try {
        if(!_rumConfig){
            _rumConfig = [rumConfigOptions copy];
            [FTNetworkInfoManager sharedInstance].setAppId(_rumConfig.appid);
            if (_sdkConfig.remoteConfiguration) {
                [[FTRemoteConfigManager sharedInstance] updateRemoteConfig];
                [_rumConfig mergeWithRemoteConfigDict:[[FTRemoteConfigManager sharedInstance] getLocalRemoteConfig]];
            }
            [self applyRUMConfig:_rumConfig];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions{
    @try {
        if (!_loggerConfig) {
            _loggerConfig = [loggerConfigOptions copy];
            if (_sdkConfig.remoteConfiguration) {
                [_loggerConfig mergeWithRemoteConfigDict:[[FTRemoteConfigManager sharedInstance] getLocalRemoteConfig]];
            }
            [self applyLogConfig:_loggerConfig];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    @try {
        if(!_traceConfig){
            _traceConfig = [traceConfigOptions copy];
            if (_sdkConfig.remoteConfiguration) {
                [_traceConfig mergeWithRemoteConfigDict:[[FTRemoteConfigManager sharedInstance] getLocalRemoteConfig]];
            }else{
                [self applyTraceConfig:_traceConfig];
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
#pragma mark ========== remote ==========
- (void)updateRemoteConfiguration:(NSDictionary *)configuration{
    [self.sdkConfig mergeWithRemoteConfigDict:configuration];
    [FTNetworkInfoManager sharedInstance].setCompressionIntakeRequests(self.sdkConfig.compressIntakeRequests);
    [[FTTrackDataManager sharedInstance] updateAutoSync:self.sdkConfig.autoSync syncPageSize:self.sdkConfig.syncPageSize syncSleepTime:self.sdkConfig.syncSleepTime];
    [[FTLogger sharedInstance] updateWithRemoteConfiguration:configuration];
}
+ (void)updateRemoteConfig{
    if (![self checkInstallState]) {
        return;
    }
    [[FTRemoteConfigManager sharedInstance] updateRemoteConfig];
}
+ (void)updateRemoteConfigWithMiniUpdateInterval:(int)miniUpdateInterval callback:(void (^)(BOOL, NSDictionary<NSString *,id> * _Nullable))callback{
    if (![self checkInstallState]) {
        callback(NO,nil);
        return;
    }
    [[FTRemoteConfigManager sharedInstance] updateRemoteConfigWithMiniUpdateInterval:miniUpdateInterval callback:callback];
}
#pragma mark ========== real sdk init ==========
- (void)applyBaseConfig:(FTMobileConfig *)config{
    //基础类型的记录
    [FTLog enableLog:config.enableSDKDebugLog];
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    [[FTPresetProperty sharedInstance] setDataModifier:config.dataModifier lineDataModifier:config.lineDataModifier];
    [[FTPresetProperty sharedInstance] startWithVersion:version
                                             sdkVersion:SDK_VERSION
                                                    env:config.env
                                                service:config.service
                                          globalContext:config.globalContext
                                                pkgInfo:config.pkgInfo
    ];
    [FTExtensionDataManager sharedInstance].groupIdentifierArray = config.groupIdentifiers;
    //开启数据处理管理器
    [FTTrackDataManager startWithAutoSync:config.autoSync syncPageSize:config.syncPageSize syncSleepTime:config.syncSleepTime];
    [[FTTrackDataManager sharedInstance] setEnableLimitWithDb:config.enableLimitWithDbSize size:config.dbCacheLimit discardNew:config.dbDiscardType == FTDBDiscard];
    
    [FTNetworkInfoManager sharedInstance]
        .setDatakitUrl(config.datakitUrl)
        .setDatawayUrl(config.datawayUrl)
        .setClientToken(config.clientToken)
        .setSdkVersion(SDK_VERSION)
        .setCompressionIntakeRequests(config.compressIntakeRequests)
        .setEnableDataIntegerCompatible(config.enableDataIntegerCompatible);
    [[FTURLSessionInstrumentation sharedInstance] setSdkUrlStr:config.datakitUrl.length>0?config.datakitUrl:config.datawayUrl
                                                   serviceName:config.service];
    [[FTExtensionDataManager sharedInstance] writeMobileConfig:[config convertToDictionary]];
    FTInnerLogInfo(@"Init Mobile Config Success: \n%@",config.debugDescription);
}
- (void)applyRUMConfig:(FTRumConfig *)rumConfig{
    FTInnerLogInfo(@"[RUM] APPID:%@",rumConfig.appid);
    [[FTPresetProperty sharedInstance] setRUMAppID:rumConfig.appid sampleRate:rumConfig.samplerate sessionOnErrorSampleRate:rumConfig.sessionOnErrorSampleRate rumGlobalContext:rumConfig.globalContext];
    [[FTTrackDataManager sharedInstance] setRUMCacheLimitCount:rumConfig.rumCacheLimitCount discardNew:rumConfig.rumDiscardType == FTRUMDiscard];
    [[FTGlobalRumManager sharedInstance] setRumConfig:rumConfig writer:[FTTrackDataManager sharedInstance].dataWriterWorker];
    [[FTURLSessionInstrumentation sharedInstance]setEnableAutoRumTrace:rumConfig.enableTraceUserResource
                                                    resourceUrlHandler:rumConfig.resourceUrlHandler
                                              resourcePropertyProvider:rumConfig.resourcePropertyProvider
                                                sessionTaskErrorFilter:rumConfig.sessionTaskErrorFilter
    ];
    [[FTURLSessionInstrumentation sharedInstance] setRumResourceHandler:[FTGlobalRumManager sharedInstance].rumManager];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
    [[FTExtensionDataManager sharedInstance] writeRumConfig:[rumConfig convertToDictionary]];
    if (_loggerConfig) {
        [FTLogger sharedInstance].linkRumDataProvider = [FTGlobalRumManager sharedInstance].rumManager;
    }
    FTInnerLogInfo(@"Init RUM Config Success: \n%@",rumConfig.debugDescription);
}
- (void)applyLogConfig:(FTLoggerConfig *)loggerConfig{
    [[FTPresetProperty sharedInstance] setLogGlobalContext:loggerConfig.globalContext];
    [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:loggerConfig.logCacheLimitCount discardNew:loggerConfig.discardType == FTDiscard];
    [[FTExtensionDataManager sharedInstance] writeLoggerConfig:[loggerConfig convertToDictionary]];
    [[FTLogger sharedInstance] startWithLoggerConfig:loggerConfig writer:[FTTrackDataManager sharedInstance].dataWriterWorker];
    [FTLogger sharedInstance].linkRumDataProvider = [FTGlobalRumManager sharedInstance].rumManager;
    FTInnerLogInfo(@"Init Logger Config Success: \n%@",loggerConfig.debugDescription);
}
- (void)applyTraceConfig:(FTTraceConfig *)traceConfig{
    [[FTURLSessionInstrumentation sharedInstance] setTraceEnableAutoTrace:traceConfig.enableAutoTrace
                                                        enableLinkRumData:traceConfig.enableLinkRumData
                                                               sampleRate:traceConfig.samplerate
                                                                traceType:traceConfig.networkTraceType
                                                         traceInterceptor:traceConfig.traceInterceptor
    ];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
    [[FTExtensionDataManager sharedInstance] writeTraceConfig:[traceConfig convertToDictionary]];
    FTInnerLogInfo(@"Init Trace Config Success: \n%@",traceConfig.debugDescription);
}
#pragma mark ==
+ (BOOL)checkInstallState{
    @synchronized(sharedInstanceLock) {
        return sharedInstance != nil;
    }
}
#pragma mark ========== public method ==========
- (void)isIntakeUrl:(BOOL(^)(NSURL *url))handler{
    if(handler){
        [[FTURLSessionInstrumentation sharedInstance] setIntakeUrlHandler:handler];
    }
}
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    [self logging:content status:status property:nil];
}
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(NSDictionary *)property{
    @try {
        [[FTLogger sharedInstance] log:content statusType:status property:property];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
//用户绑定
- (void)bindUserWithUserID:(NSString *)Id{
    [self bindUserWithUserID:Id userName:nil userEmail:nil extra:nil];
}
-(void)bindUserWithUserID:(NSString *)Id userName:(NSString *)userName userEmail:(nullable NSString *)userEmail{
    [self bindUserWithUserID:Id userName:userName userEmail:userEmail extra:nil];
}
-(void)bindUserWithUserID:(NSString *)Id userName:(NSString *)userName userEmail:(nullable NSString *)userEmail extra:(NSDictionary *)extra{
    if(Id == nil || Id.length==0){
        FTInnerLogError(@"Failed to bind user ! User ID can't be empty");
        return;
    }
    NSDictionary *safeExtra = [extra ft_deepCopy];
    [[FTPresetProperty sharedInstance] updateUser:Id name:userName email:userEmail extra:safeExtra];
    FTInnerLogInfo(@"Bind User ID : %@ , Name : %@ , Email : %@ , Extra : %@",Id,userName,userEmail,safeExtra);
}
+ (void)appendGlobalContext:(NSDictionary <NSString*,id>*)context{
    @try {
        if (![self checkInstallState]) {
            return;
        }
        if(!context){
            FTInnerLogWarning(@"appendGlobalContext: context is nil");
        }
        NSDictionary *safeDict = [context ft_deepCopy];
        [[FTPresetProperty sharedInstance] appendGlobalContext:safeDict];
        FTInnerLogInfo(@"appendGlobalContext : %@",safeDict);
    } @catch (NSException *exception) {
        FTInnerLogError(@"appendGlobalContext exception: %@",exception);
    }
}
+ (void)appendRUMGlobalContext:(NSDictionary <NSString*,id>*)context{
    @try {
        if (![self checkInstallState]) {
            return;
        }
        if(!context){
            FTInnerLogWarning(@"appendRUMGlobalContext: context is nil");
        }
        NSDictionary *safeDict = [context ft_deepCopy];
        [[FTPresetProperty sharedInstance] appendRUMGlobalContext:safeDict];
        FTInnerLogInfo(@"appendRUMGlobalContext : %@",safeDict);
    } @catch (NSException *exception) {
        FTInnerLogError(@"appendRUMGlobalContext exception: %@",exception);
    }
}
+ (void)appendLogGlobalContext:(NSDictionary <NSString*,id>*)context{
    @try {
        if (![self checkInstallState]) {
            return;
        }
        if(!context){
            FTInnerLogWarning(@"appendLogGlobalContext: context is nil");
        }
        NSDictionary *safeDict = [context ft_deepCopy];
        [[FTPresetProperty sharedInstance] appendLogGlobalContext:safeDict];
        FTInnerLogInfo(@"appendLogGlobalContext : %@",safeDict);
    } @catch (NSException *exception) {
        FTInnerLogError(@"appendLogGlobalContext exception: %@",exception);
    }
}
//用户注销
- (void)logout{
    [self unbindUser];
}
- (void)unbindUser{
    [[FTPresetProperty sharedInstance] clearUser];
    FTInnerLogInfo(@"Unbind User");
}
- (void)trackEventFromExtensionWithGroupIdentifier:(NSString *)groupIdentifier completion:(void (^)(NSString *groupIdentifier, NSArray *events)) completion{
    @try {
        if (groupIdentifier == nil || [groupIdentifier isEqualToString:@""]) {
            return;
        }
        NSArray *eventArray = [[FTExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:groupIdentifier];
        if (eventArray) {
            for (NSDictionary *dict in eventArray) {
                NSString *dataType = dict[@"dataType"];
                NSNumber *time = dict[@"tm"];
                if([dataType isEqualToString:FT_DATA_TYPE_LOGGING]){
                    id status = dict[@"status"];
                    NSString *statusStr;
                    if([status isKindOfClass:NSNumber.class]){
                        statusStr = FTStatusStringMap[[status intValue]];
                    }else{
                        statusStr = status;
                    }
                    NSDictionary *dynamicTags = [[FTPresetProperty sharedInstance] loggerDynamicTags];
                    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
                    [tags addEntriesFromDictionary:dynamicTags];
                    if (self.loggerConfig.enableLinkRumData) {
                        [tags addEntriesFromDictionary:[[FTPresetProperty sharedInstance] rumDynamicTags]];
                        [tags addEntriesFromDictionary:[[FTPresetProperty sharedInstance] rumTags]];
                    }
                    [tags addEntriesFromDictionary:dict[@"tags"]];
                    [[FTTrackDataManager sharedInstance].dataWriterWorker logging:dict[@"content"] status:statusStr tags:tags field:dict[@"fields"] time:time.longLongValue];
                }else if([dataType isEqualToString:FT_DATA_TYPE_RUM]){
                    NSString *eventType = dict[@"eventType"];
                    NSDictionary *dynamicTags = [[FTPresetProperty sharedInstance] rumDynamicTags];
                    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
                    [tags addEntriesFromDictionary:dict[@"tags"]];
                    [tags addEntriesFromDictionary:dynamicTags];
                    [[FTTrackDataManager sharedInstance].dataWriterWorker extensionRumWrite:eventType tags:tags fields:dict[@"fields"] time:time.longLongValue];
                }
            }
            [[FTExtensionDataManager sharedInstance] deleteEventsWithGroupIdentifier:groupIdentifier];
            if (completion) {
                completion(groupIdentifier, eventArray);
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
- (void)flushSyncData{
    @try {
        [[FTTrackDataManager sharedInstance] flushSyncData];
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
#pragma mark - SDK注销
- (void)shutDown{
    [FTMobileAgent setSharedInstance:nil block:^{
        [[FTLogger sharedInstance] shutDown];
        [[FTGlobalRumManager sharedInstance] shutDown];
        [[FTURLSessionInstrumentation sharedInstance] shutDown];
        [[FTRemoteConfigManager sharedInstance] shutDown];
        [FTTrackDataManager shutDown];
        [[FTPresetProperty sharedInstance] shutDown];
        FTInnerLogInfo(@"[SDK] SHUT DOWN");
        [[FTLog sharedInstance] shutDown];
    }];
}
+ (void)shutDown{
    if (sharedInstance == nil) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [sharedInstance shutDown];
#pragma clang diagnostic pop
}
+ (void)clearAllData{
    @try {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if([[FTTrackerEventDBTool sharedManger] deleteAllDatas]){
                FTInnerLogInfo(@"[SDK] Clear All Data Success!!!");
            }else{
                FTInnerLogInfo(@"[SDK] Clear All Data Error!!!");
            }
        });
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
- (void)syncProcess{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTLogger sharedInstance] syncProcess];
}
@end
