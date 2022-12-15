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
#import "FTLog.h"
#import "NSString+FTAdd.h"
#import "FTDateUtil.h"
#import "FTPresetProperty.h"
#import "FTLogHook.h"
#import "FTReachability.h"
#import "FTTrackDataManger.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTJSONUtil.h"
#import "FTURLProtocol.h"
#import "FTUserInfo.h"
#import "FTExtensionDataManager.h"
#import "FTExternalDataManager+Private.h"
#import "FTWKWebViewHandler.h"
#import "FTMobileAgentVersion.h"
#import "FTNetworkInfoManager.h"
#import "FTURLSessionAutoInstrumentation.h"
#import "FTMobileConfig+Private.h"
@interface FTMobileAgent ()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, copy) NSString *netTraceStr;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@end
@implementation FTMobileAgent

static FTMobileAgent *sharedInstance = nil;
static dispatch_once_t onceToken;
#pragma mark --------- 初始化 config 设置 ----------
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions{
    NSAssert ((strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0),@"SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 launch 事件）。");
    
    NSAssert((configOptions.metricsUrl.length!=0 ), @"请设置FT-GateWay metrics 写入地址");
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
            [FTLog enableLog:config.enableSDKDebugLog];
            NSString *serialLabel = [NSString stringWithFormat:@"ft.serialLabel.%p", self];
            _serialQueue = dispatch_queue_create([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL);
            [FTExtensionDataManager sharedInstance].groupIdentifierArray = config.groupIdentifiers;

            //开启数据处理管理器
            [FTTrackDataManger sharedInstance];
            _presetProperty = [[FTPresetProperty alloc] initWithMobileConfig:config];
            [FTNetworkInfoManager sharedInstance].setMetricsUrl(config.metricsUrl)
            .setSdkVersion(SDK_VERSION)
            .setXDataKitUUID(config.XDataKitUUID);
            [FTURLSessionAutoInstrumentation sharedInstance].sdkUrlStr = config.metricsUrl;
        }
    }@catch(NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
    return self;
}
-(void)resetConfig:(FTMobileConfig *)config{
    [FTLog enableLog:config.enableSDKDebugLog];
    if (_presetProperty) {
        [self.presetProperty resetWithMobileConfig:config];
    }else{
        self.presetProperty = [[FTPresetProperty alloc] initWithMobileConfig:config];
    }
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    if(rumConfigOptions.appid == nil || rumConfigOptions.appid.length == 0){
        ZYErrorLog(@"FTRumConfig appid 设置格式错误");
        return;
    }
    [self.presetProperty setAppid:rumConfigOptions.appid];
    self.presetProperty.rumContext = [rumConfigOptions.globalContext copy];
    [[FTGlobalRumManager sharedInstance] setRumConfig:rumConfigOptions];
    [[FTURLSessionAutoInstrumentation sharedInstance] setRUMConfig:rumConfigOptions];
    [FTURLSessionAutoInstrumentation sharedInstance].interceptor.innerResourceHandeler = [FTGlobalRumManager sharedInstance].rumManger;
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionAutoInstrumentation sharedInstance].rumResourceHandler;
    [[FTExtensionDataManager sharedInstance] writeRumConfig:[rumConfigOptions convertToDictionary]];
}
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions{
    if (!_loggerConfig) {
        self.loggerConfig = [loggerConfigOptions copy];
        self.presetProperty.logContext = [self.loggerConfig.globalContext copy];
        self.logLevelFilterSet = [NSSet setWithArray:self.loggerConfig.logLevelFilter];
        [FTTrackerEventDBTool sharedManger].discardNew = (loggerConfigOptions.discardType == FTDiscard);
        [FTTrackerEventDBTool sharedManger].dbLoggingMaxCount = FT_DB_CONTENT_MAX_COUNT;
        if(self.loggerConfig.enableConsoleLog){
            [self _traceConsoleLog];
        }
        [[FTExtensionDataManager sharedInstance] writeLoggerConfig:[loggerConfigOptions convertToDictionary]];
    }
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    _netTraceStr = FTNetworkTraceStringMap[traceConfigOptions.networkTraceType];
    [FTWKWebViewHandler sharedInstance].enableTrace = traceConfigOptions.enableAutoTrace;
    [FTWKWebViewHandler sharedInstance].interceptor = [FTURLSessionAutoInstrumentation sharedInstance].interceptor;
    [[FTURLSessionAutoInstrumentation sharedInstance] setTraceConfig:traceConfigOptions];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionAutoInstrumentation sharedInstance].rumResourceHandler;
    [[FTExtensionDataManager sharedInstance] writeTraceConfig:[traceConfigOptions convertToDictionary]];

}
#pragma mark ========== publick method ==========
- (void)isIntakeUrl:(BOOL(^)(NSURL *url))handler{
    if(handler){
        [FTTraceManager sharedInstance].intakeUrl = handler;
    }
}
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    [self logging:content status:status property:nil];
}
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(NSDictionary *)property{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    @try {
        if (!self.loggerConfig.enableCustomLog) {
            ZYLog(@"enableCustomLog 未开启，数据不进行采集");
            return;
        }
        [self logging:content status:status tags:nil field:nil tm:[FTDateUtil currentTimeNanosecond]];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
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
    ZYDebug(@"Bind User ID : %@",Id);
    if (userName) {
        ZYDebug(@"Bind User Name : %@",userName);
    }
    if (userEmail) {
        ZYDebug(@"Bind User Email : %@",userEmail);
    }
    if (extra) {
        ZYDebug(@"Bind User Extra : %@",extra);
    }
}
//用户注销
- (void)logout{
    [self.presetProperty.userHelper concurrentWrite:^(FTUserInfo * _Nonnull value) {
        [value clearUser];
    }];
    ZYDebug(@"User Logout");
}
#pragma mark ========== private method ==========
//RUM  ES
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self rumWrite:type terminal:terminal tags:tags fields:fields tm:[FTDateUtil currentTimeNanosecond]];
}
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (![type isKindOfClass:NSString.class] || type.length == 0 || terminal.length == 0) {
        return;
    }
    @try {
        FTAddDataType dataType = FTAddDataImmediate;
        NSMutableDictionary *baseTags =[NSMutableDictionary new];
        [baseTags addEntriesFromDictionary:[self.presetProperty rumPropertyWithTerminal:terminal]];
        baseTags[@"network_type"] = [FTReachability sharedInstance].net;
        [baseTags addEntriesFromDictionary:tags];
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:type op:FT_DATA_TYPE_RUM tags:baseTags field:fields tm:tm];
        [self insertDBWithItemData:model type:dataType];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

// FT_DATA_TYPE_LOGGING
-(void)logging:(NSString *)content status:(FTLogStatus)status tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    if (!self.loggerConfig) {
        ZYErrorLog(@"请先设置 FTLoggerConfig");
        return;
    }
    if (!content || content.length == 0 || [content ft_characterNumber]>FT_LOGGING_CONTENT_SIZE) {
        ZYErrorLog(@"传入的第数据格式有误，或content超过30kb");
        return;
    }
    if (![self.logLevelFilterSet containsObject:@(status)]) {
        ZYDebug(@"经过过滤算法判断-此条日志不采集");
        return;
    }
    if (![FTBaseInfoHandler randomSampling:self.loggerConfig.samplerate]){
        ZYDebug(@"经过采集算法判断-此条日志不采集");
        return;
    }
    @try {
        dispatch_async(self.serialQueue, ^{
            NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[self.presetProperty loggerPropertyWithStatus:status serviceName:self.loggerConfig.service]];
            if (tags) {
                [tagDict addEntriesFromDictionary:tags];
            }
            if (self.loggerConfig.enableLinkRumData) {
                [tagDict addEntriesFromDictionary:[self.presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP]];
                if(![tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]){
                    NSDictionary *rumTag = [[FTGlobalRumManager sharedInstance].rumManger getCurrentSessionInfo];
                    [tagDict addEntriesFromDictionary:rumTag];
                }
            }
            NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
            }.mutableCopy;
            if (field) {
                [filedDict addEntriesFromDictionary:field];
            }
            FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_LOGGER_SOURCE op:FT_DATA_TYPE_LOGGING tags:tagDict field:filedDict tm:tm];
            [self insertDBWithItemData:model type:FTAddDataLogging];
        });
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
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
                    FTLogStatus status = [dict[@"status"] intValue];
                    [self logging:dict[@"content"] status:status tags:dict[@"tags"] field:dict[@"fields"] tm:tm.longLongValue];
                }else if([dataType isEqualToString:FT_DATA_TYPE_RUM]){
                    NSString *eventType = dict[@"eventType"];
                    [self rumWrite:eventType terminal:FT_TERMINAL_APP tags:dict[@"tags"] fields:dict[@"fields"] tm:tm.longLongValue];
                }
               
            }
            [[FTExtensionDataManager sharedInstance] deleteEventsWithGroupIdentifier:groupIdentifier];
            if (completion) {
                completion(groupIdentifier, eventArray);
            }
        }
    } @catch (NSException *exception) {
        ZYErrorLog(@"%@ error: %@", self, exception);
    }
}

//控制台日志采集
- (void)_traceConsoleLog{
    __weak typeof(self) weakSelf = self;
    [FTLogHook hookWithBlock:^(NSString * _Nonnull logStr,long long tm) {
            if (!weakSelf.loggerConfig.enableConsoleLog ) {
                return;
            }
            if (weakSelf.loggerConfig.prefix.length>0) {
                if([logStr containsString:weakSelf.loggerConfig.prefix]){
                    [weakSelf logging:logStr status:FTStatusInfo tags:nil field:nil tm:tm];
                }
            }else{
                [weakSelf logging:logStr status:FTStatusInfo tags:nil field:nil tm:tm];
            }
    }];
}
- (void)insertDBWithItemData:(FTRecordModel *)model type:(FTAddDataType)type{
    [[FTTrackDataManger sharedInstance] addTrackData:model type:type];
}
- (BOOL)judgeRUMTrackOpen{
    if (self.rumConfig.appid.length>0) {
        return YES;
    }
    return NO;
}
#pragma mark - SDK注销
- (void)resetInstance{
    [[FTGlobalRumManager sharedInstance] resetInstance];
    [[FTURLSessionAutoInstrumentation sharedInstance] resetInstance];
    _presetProperty = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [FTURLProtocol stopMonitor];
    [FTTraceManager sharedInstance].intakeUrl = nil;
    onceToken = 0;
    sharedInstance =nil;
}
- (void)syncProcess{
    dispatch_sync(self.serialQueue, ^{
        
    });
}
@end
