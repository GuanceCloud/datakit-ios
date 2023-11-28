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
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHandler.h"
#import "FTGlobalRumManager.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTInternalLog.h"
#import "NSString+FTAdd.h"
#import "FTDateUtil.h"
#import "FTPresetProperty.h"
#import "FTReachability.h"
#import "FTTrackDataManager.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTJSONUtil.h"
#import "FTUserInfo.h"
#import "FTExtensionDataManager.h"
#import "FTExternalDataManager+Private.h"
#import "FTWKWebViewHandler.h"
#import "FTMobileAgentVersion.h"
#import "FTNetworkInfoManager.h"
#import "FTURLSessionInstrumentation.h"
#import "FTEnumConstant.h"
#import "FTMobileConfig+Private.h"
#import "FTLogger+Private.h"
@interface FTMobileAgent ()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, copy) NSString *netTraceStr;
@end
@implementation FTMobileAgent

static FTMobileAgent *sharedInstance = nil;
static dispatch_once_t onceToken;
#pragma mark --------- 初始化 config 设置 ----------
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions{
    NSAssert ((strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0),@"SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 launch 事件）。");
    
    NSAssert((configOptions.metricsUrl.length!=0 ), @"请设置 datakit metrics 写入地址");
    if (sharedInstance) {
        [[FTMobileAgent sharedInstance] resetConfig:configOptions];
    }
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTMobileAgent alloc] initWithConfig:configOptions];
    });
}
// 单例
+ (instancetype)sharedInstance {
    NSAssert(sharedInstance, @"请先使用 startWithConfigOptions: 初始化 SDK");
    return sharedInstance;
}
- (instancetype)initWithConfig:(FTMobileConfig *)config{
    @try {
        self = [super init];
        if (self) {
            //基础类型的记录
            [FTInternalLog enableLog:config.enableSDKDebugLog];
            [FTExtensionDataManager sharedInstance].groupIdentifierArray = config.groupIdentifiers;

            //开启数据处理管理器
            [FTTrackDataManager sharedInstance];
            _presetProperty = [[FTPresetProperty alloc] initWithVersion:config.version env:config.env service:config.service globalContext:config.globalContext];
            _presetProperty.sdkVersion = SDK_VERSION;
            [FTNetworkInfoManager sharedInstance].setMetricsUrl(config.metricsUrl)
                .setSdkVersion(SDK_VERSION);
            [[FTURLSessionInstrumentation sharedInstance] setSdkUrlStr:config.metricsUrl];
        }
    }@catch(NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return self;
}
-(void)resetConfig:(FTMobileConfig *)config{
    [FTInternalLog enableLog:config.enableSDKDebugLog];
    if (_presetProperty) {
        [self.presetProperty resetWithVersion:config.version env:config.env service:config.service globalContext:config.globalContext];
    }else{
        _presetProperty = [[FTPresetProperty alloc] initWithVersion:config.version env:config.env service:config.service globalContext:config.globalContext];
    }
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    NSAssert((rumConfigOptions.appid.length!=0 ), @"请设置 appid 用户访问监测应用ID");
    FTInnerLogInfo(@"[RUM] APPID:%@",rumConfigOptions.appid);
    [self.presetProperty setAppid:rumConfigOptions.appid];
    self.presetProperty.rumContext = [rumConfigOptions.globalContext copy];
    [[FTGlobalRumManager sharedInstance] setRumConfig:rumConfigOptions];
    [[FTURLSessionInstrumentation sharedInstance] setEnableAutoRumTrack:rumConfigOptions.enableTraceUserResource];
    [[FTURLSessionInstrumentation sharedInstance] setRumResourceHandler:[FTGlobalRumManager sharedInstance].rumManager];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
    [[FTExtensionDataManager sharedInstance] writeRumConfig:[rumConfigOptions convertToDictionary]];
}
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions{
    if (!_loggerConfig) {
        self.loggerConfig = [loggerConfigOptions copy];
        self.presetProperty.logContext = [self.loggerConfig.globalContext copy];
        [FTTrackerEventDBTool sharedManger].discardNew = (loggerConfigOptions.discardType == FTDiscard);
        [[FTExtensionDataManager sharedInstance] writeLoggerConfig:[loggerConfigOptions convertToDictionary]];
        [FTLogger startWithEablePrintLogsToConsole:loggerConfigOptions.printCustomLogToConsole enableCustomLog:loggerConfigOptions.enableCustomLog logLevelFilter:loggerConfigOptions.logLevelFilter sampleRate:loggerConfigOptions.samplerate writer:self];
    }
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    _netTraceStr = FTNetworkTraceStringMap[traceConfigOptions.networkTraceType];
    [FTWKWebViewHandler sharedInstance].enableTrace = traceConfigOptions.enableAutoTrace;
    [FTWKWebViewHandler sharedInstance].interceptor = [FTURLSessionInstrumentation sharedInstance].interceptor;
    [[FTURLSessionInstrumentation sharedInstance] setTraceEnableAutoTrace:traceConfigOptions.enableAutoTrace enableLinkRumData:traceConfigOptions.enableLinkRumData sampleRate:traceConfigOptions.samplerate traceType:(NetworkTraceType)traceConfigOptions.networkTraceType];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
    [[FTExtensionDataManager sharedInstance] writeTraceConfig:[traceConfigOptions convertToDictionary]];

}
#pragma mark ========== publick method ==========
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
        if (!self.loggerConfig) {
            FTInnerLogError(@"[Logging] 请先设置 FTLoggerConfig");
            return;
        }
        if (!content || content.length == 0 ) {
            FTInnerLogError(@"[Logging] 传入的第数据格式有误");
            return;
        }
        [[FTLogger sharedInstance] log:content status:(LogStatus)status property:property];
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
    NSParameterAssert(Id);
    [self.presetProperty.userHelper concurrentWrite:^(FTUserInfo * _Nonnull value) {
        [value updateUser:Id name:userName email:userEmail extra:extra];
    }];
    FTInnerLogInfo(@"Bind User ID : %@ , Name : %@ , Email : %@ , Extra : %@",Id,userName,userEmail,extra);
}
//用户注销
- (void)logout{
    [self unbindUser];
}
- (void)unbindUser{
    [self.presetProperty.userHelper concurrentWrite:^(FTUserInfo * _Nonnull value) {
        [value clearUser];
    }];
    FTInnerLogInfo(@"Unbind User");
}
#pragma mark ========== private method ==========
//RUM  ES
- (void)rumWrite:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self rumWrite:type tags:tags fields:fields tm:[FTDateUtil currentTimeNanosecond]];
}
- (void)rumWrite:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (![type isKindOfClass:NSString.class] || type.length == 0) {
        return;
    }
    @try {
        FTAddDataType dataType = [type isEqualToString:FT_RUM_SOURCE_ERROR]?FTAddDataImmediate:FTAddDataNormal;
        NSMutableDictionary *baseTags =[NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:[self.presetProperty rumDynamicProperty]];
        baseTags[@"network_type"] = [FTReachability sharedInstance].net;
        [baseTags addEntriesFromDictionary:tags];
        NSMutableDictionary *rumProperty = [self.presetProperty rumProperty];
        // webview 打进的数据
        if([tags.allKeys containsObject:FT_IS_WEBVIEW]){
            [baseTags setValue:SDK_VERSION forKey:@"package_native"];
            [rumProperty removeObjectForKey:FT_KEY_SERVICE];
            [rumProperty removeObjectForKey:FT_SDK_VERSION];
            [rumProperty removeObjectForKey:FT_SDK_NAME];
        }
        [baseTags addEntriesFromDictionary:rumProperty];
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:type op:FT_DATA_TYPE_RUM tags:baseTags fields:fields tm:tm];
        [self insertDBWithItemData:model type:dataType];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}

// FT_DATA_TYPE_LOGGING
-(void)logging:(NSString *)content status:(LogStatus)status tags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field tm:(long long)tm{
    @try {
        NSString *newContent = [content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[self.presetProperty loggerPropertyWithStatus:(LogStatus)status]];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        if (self.loggerConfig.enableLinkRumData) {
            [tagDict addEntriesFromDictionary:[self.presetProperty rumDynamicProperty]];
            [tagDict addEntriesFromDictionary:[self.presetProperty rumProperty]];
            if(![tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]){
                NSDictionary *rumTag = [[FTGlobalRumManager sharedInstance].rumManager getCurrentSessionInfo];
                [tagDict addEntriesFromDictionary:rumTag];
            }
        }
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:newContent,
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_LOGGER_SOURCE op:FT_DATA_TYPE_LOGGING tags:tagDict fields:filedDict tm:tm];
        [self insertDBWithItemData:model type:FTAddDataLogging];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
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
                NSNumber *tm = dict[@"tm"];
                if([dataType isEqualToString:FT_DATA_TYPE_LOGGING]){
                    LogStatus status = [dict[@"status"] intValue];
                    [self logging:dict[@"content"] status:status tags:dict[@"tags"] field:dict[@"fields"] tm:tm.longLongValue];
                }else if([dataType isEqualToString:FT_DATA_TYPE_RUM]){
                    NSString *eventType = dict[@"eventType"];
                    [self rumWrite:eventType tags:dict[@"tags"] fields:dict[@"fields"] tm:tm.longLongValue];
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
- (void)insertDBWithItemData:(FTRecordModel *)model type:(FTAddDataType)type{
    [[FTTrackDataManager sharedInstance] addTrackData:model type:type];
}
#pragma mark - SDK注销
- (void)shutDown{
    [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    [[FTGlobalRumManager sharedInstance] resetInstance];
    [[FTLogger sharedInstance] shutDown];
    [[FTURLSessionInstrumentation sharedInstance] resetInstance];
    onceToken = 0;
    sharedInstance =nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    FTInnerLogInfo(@"[SDK] SHUT DOWN");
}
- (void)syncProcess{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTLogger sharedInstance] syncProcess];
}
@end
