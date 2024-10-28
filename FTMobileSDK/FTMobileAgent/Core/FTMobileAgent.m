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
#import "FTWKWebViewHandler.h"
#import "FTMobileAgentVersion.h"
#import "FTNetworkInfoManager.h"
#import "FTURLSessionInstrumentation.h"
#import "FTEnumConstant.h"
#import "FTMobileConfig+Private.h"
#import "FTLogger+Private.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTTrackerEventDBTool.h"
@interface FTMobileAgent ()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTTraceConfig *traceConfig;

@property (nonatomic, copy) NSString *netTraceStr;
@end
@implementation FTMobileAgent

static FTMobileAgent *sharedInstance = nil;
static dispatch_once_t onceToken;
#pragma mark --------- 初始化 config 设置 ----------
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions{
    NSAssert ((strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0),@"SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 launch 事件）。");
    
    NSAssert((configOptions.datakitUrl.length!=0||(configOptions.datawayUrl.length!=0&&configOptions.clientToken.length!=0)), @"请正确配置 datakit  或 dataway 写入地址");
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
            [FTLog enableLog:config.enableSDKDebugLog];
            [FTExtensionDataManager sharedInstance].groupIdentifierArray = config.groupIdentifiers;
            //开启数据处理管理器
            [FTTrackDataManager startWithAutoSync:config.autoSync syncPageSize:config.syncPageSize syncSleepTime:config.syncSleepTime];
            NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            [[FTPresetProperty sharedInstance] startWithVersion:version
                                                     sdkVersion:SDK_VERSION
                                                            env:config.env
                                                        service:config.service
                                                  globalContext:config.globalContext];
            [FTNetworkInfoManager sharedInstance]
                .setDatakitUrl(config.datakitUrl)
                .setDatawayUrl(config.datawayUrl)
                .setClientToken(config.clientToken)
                .setSdkVersion(SDK_VERSION)
                .setCompression((HttpRequestCompression)config.compressionForUpload)
                .setEnableDataIntegerCompatible(config.enableDataIntegerCompatible);
            [[FTURLSessionInstrumentation sharedInstance] setSdkUrlStr:config.datakitUrl.length>0?config.datakitUrl:config.datawayUrl
                                                           serviceName:config.service];
        }
    }@catch(NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return self;
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    if(!_rumConfig){
        NSAssert((rumConfigOptions.appid.length!=0 ), @"请设置 appid 用户访问监测应用ID");
        FTInnerLogInfo(@"[RUM] APPID:%@",rumConfigOptions.appid);
        _rumConfig = [rumConfigOptions copy];
        [[FTPresetProperty sharedInstance] setAppID:_rumConfig.appid];
        [FTPresetProperty sharedInstance].rumGlobalContext = _rumConfig.globalContext;
        [[FTGlobalRumManager sharedInstance] setRumConfig:_rumConfig writer:self];
        [[FTURLSessionInstrumentation sharedInstance] setEnableAutoRumTrace:_rumConfig.enableTraceUserResource resourceUrlHandler:_rumConfig.resourceUrlHandler];
        [[FTURLSessionInstrumentation sharedInstance] setRumResourceHandler:[FTGlobalRumManager sharedInstance].rumManager];
        [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
        [[FTExtensionDataManager sharedInstance] writeRumConfig:[_rumConfig convertToDictionary]];
        if (_loggerConfig) {
            [FTLogger sharedInstance].linkRumDataProvider = [FTGlobalRumManager sharedInstance].rumManager;
        }
    }
}
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions{
    if (!_loggerConfig) {
        _loggerConfig = [loggerConfigOptions copy];
        [FTPresetProperty sharedInstance].logGlobalContext = _loggerConfig.globalContext;
        [[FTTrackDataManager sharedInstance] setLogCacheLimitCount:_loggerConfig.logCacheLimitCount logDiscardNew:_loggerConfig.discardType == FTDiscard];
        [[FTExtensionDataManager sharedInstance] writeLoggerConfig:[_loggerConfig convertToDictionary]];
        [FTLogger startWithEnablePrintLogsToConsole:_loggerConfig.printCustomLogToConsole
                                    enableCustomLog:_loggerConfig.enableCustomLog
                                  enableLinkRumData:_loggerConfig.enableLinkRumData
                                     logLevelFilter:_loggerConfig.logLevelFilter sampleRate:_loggerConfig.samplerate writer:self];
        [FTLogger sharedInstance].linkRumDataProvider = [FTGlobalRumManager sharedInstance].rumManager;
    }
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    if(!_traceConfig){
        _traceConfig = [traceConfigOptions copy];
        _netTraceStr = FTNetworkTraceStringMap[_traceConfig.networkTraceType];
        [FTWKWebViewHandler sharedInstance].enableTrace = _traceConfig.enableAutoTrace;
        [FTWKWebViewHandler sharedInstance].interceptor = [FTURLSessionInstrumentation sharedInstance].interceptor;
        [[FTURLSessionInstrumentation sharedInstance] setTraceEnableAutoTrace:_traceConfig.enableAutoTrace
                                                            enableLinkRumData:_traceConfig.enableLinkRumData
                                                                   sampleRate:_traceConfig.samplerate
                                                                    traceType:_traceConfig.networkTraceType];
        [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
        [[FTExtensionDataManager sharedInstance] writeTraceConfig:[_traceConfig convertToDictionary]];
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
        if (!self.loggerConfig) {
            FTInnerLogError(@"[Logging] 请先设置 FTLoggerConfig");
            return;
        }
        if (!content || content.length == 0 ) {
            FTInnerLogError(@"[Logging] 传入的第数据格式有误");
            return;
        }
        [[FTLogger sharedInstance] log:content statusType:(LogStatus)status property:property];
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
    [[FTPresetProperty sharedInstance].userHelper concurrentWrite:^(FTUserInfo * _Nonnull value) {
        [value updateUser:Id name:userName email:userEmail extra:safeExtra];
    }];
    FTInnerLogInfo(@"Bind User ID : %@ , Name : %@ , Email : %@ , Extra : %@",Id,userName,userEmail,safeExtra);
}
+ (void)appendGlobalContext:(NSDictionary <NSString*,id>*)context{
    if (onceToken == 0 && sharedInstance == nil) {
        return;
    }
    if(!context){
        FTInnerLogWarning(@"appendGlobalContext: context is nil");
    }
    NSDictionary *safeDict = [context ft_deepCopy];
    [[FTPresetProperty sharedInstance] appendGlobalContext:safeDict];
    FTInnerLogInfo(@"appendGlobalContext : %@",safeDict);
}
+ (void)appendRUMGlobalContext:(NSDictionary <NSString*,id>*)context{
    if (onceToken == 0 && sharedInstance == nil) {
        return;
    }
    if(!context){
        FTInnerLogWarning(@"appendRUMGlobalContext: context is nil");
    }
    NSDictionary *safeDict = [context ft_deepCopy];
    [[FTPresetProperty sharedInstance] appendRUMGlobalContext:safeDict];
    FTInnerLogInfo(@"appendRUMGlobalContext : %@",safeDict);
   
}
+ (void)appendLogGlobalContext:(NSDictionary <NSString*,id>*)context{
    if (onceToken == 0 && sharedInstance == nil) {
        return;
    }
    if(!context){
        FTInnerLogWarning(@"appendLogGlobalContext: context is nil");
    }
    NSDictionary *safeDict = [context ft_deepCopy];
    [[FTPresetProperty sharedInstance] appendLogGlobalContext:safeDict];
    FTInnerLogInfo(@"appendLogGlobalContext : %@",safeDict);
}
//用户注销
- (void)logout{
    [self unbindUser];
}
- (void)unbindUser{
    [[FTPresetProperty sharedInstance].userHelper concurrentWrite:^(FTUserInfo * _Nonnull value) {
        [value clearUser];
    }];
    FTInnerLogInfo(@"Unbind User");
}
#pragma mark ========== private method ==========
- (void)rumWrite:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    if (![type isKindOfClass:NSString.class] || type.length == 0) {
        return;
    }
    @try {
        FTAddDataType dataType = [type isEqualToString:FT_RUM_SOURCE_ERROR]?FTAddDataImmediate:FTAddDataNormal;
        NSMutableDictionary *baseTags =[NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:tags];
        NSDictionary *rumProperty;
        // webView 打进的数据
        if([tags.allKeys containsObject:FT_IS_WEBVIEW]){
            rumProperty = [[FTPresetProperty sharedInstance] rumWebViewProperty];
        }else{
            rumProperty = [[FTPresetProperty sharedInstance] rumProperty];
        }
        [baseTags addEntriesFromDictionary:rumProperty];
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:type op:FT_DATA_TYPE_RUM tags:baseTags fields:fields tm:time];
        [self insertDBWithItemData:model type:dataType];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}

// FT_DATA_TYPE_LOGGING
-(void)logging:(NSString *)content status:(NSString *)status tags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time{
    @try {
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[[FTPresetProperty sharedInstance] loggerProperty]];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        [tagDict setValue:status forKey:FT_KEY_STATUS];
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_LOGGER_SOURCE op:FT_DATA_TYPE_LOGGING tags:tagDict fields:filedDict tm:time];
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
                NSNumber *time = dict[@"tm"];
                if([dataType isEqualToString:FT_DATA_TYPE_LOGGING]){
                    id status = dict[@"status"];
                    NSString *statusStr;
                    if([status isKindOfClass:NSNumber.class]){
                        statusStr = FTStatusStringMap[[status intValue]];
                    }else{
                        statusStr = status;
                    }
                    NSDictionary *dynamicTags = [[FTPresetProperty sharedInstance] loggerDynamicProperty];
                    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
                    [tags addEntriesFromDictionary:dynamicTags];
                    if (self.loggerConfig.enableLinkRumData) {
                        [tags addEntriesFromDictionary:[[FTPresetProperty sharedInstance] rumDynamicProperty]];
                        [tags addEntriesFromDictionary:[[FTPresetProperty sharedInstance] rumProperty]];
                    }
                    [tags addEntriesFromDictionary:dict[@"tags"]];
                    [self logging:dict[@"content"] status:statusStr tags:tags field:dict[@"fields"] time:time.longLongValue];
                }else if([dataType isEqualToString:FT_DATA_TYPE_RUM]){
                    NSString *eventType = dict[@"eventType"];
                    NSDictionary *dynamicTags = [[FTPresetProperty sharedInstance] rumDynamicProperty];
                    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
                    [tags addEntriesFromDictionary:dict[@"tags"]];
                    [tags addEntriesFromDictionary:dynamicTags];
                    [self rumWrite:eventType tags:tags fields:dict[@"fields"] time:time.longLongValue];
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
- (void)flushSyncData{
    [[FTTrackDataManager sharedInstance] uploadTrackData];
}
#pragma mark - SDK注销
- (void)shutDown{
    [FTNetworkInfoManager shutDown];
    [[FTGlobalRumManager sharedInstance] shutDown];
    [[FTLogger sharedInstance] shutDown];
    [[FTURLSessionInstrumentation sharedInstance] shutDown];
    [[FTPresetProperty sharedInstance] shutDown];
    onceToken = 0;
    sharedInstance = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[FTTrackDataManager sharedInstance] shutDown];
    FTInnerLogInfo(@"[SDK] SHUT DOWN");
    [[FTLog sharedInstance] shutDown];
}
+ (void)shutDown{
    if (onceToken == 0 && sharedInstance == nil) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [sharedInstance shutDown];
#pragma clang diagnostic pop
}
+ (void)clearAllData{
    if([[FTTrackerEventDBTool sharedManger] deleteAllDatas]){
        FTInnerLogInfo(@"[SDK] Clear All Data Success!!!");
    }else{
        FTInnerLogInfo(@"[SDK] Clear All Data Error!!!");
    }
}
- (void)syncProcess{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTLogger sharedInstance] syncProcess];
}
@end
