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
#import "FTConfigManager.h"
#import "FTTrackDataManger.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTJSONUtil.h"
#import "FTTraceHeaderManager.h"
#import "FTURLProtocol.h"
#import "FTUserInfo.h"
@interface FTMobileAgent ()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) dispatch_queue_t concurrentLabel;
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
            [[FTConfigManager sharedInstance] setTrackConfig:config];
            [FTLog enableLog:config.enableSDKDebugLog];
            NSString *concurrentLabel = [NSString stringWithFormat:@"io.concurrentLabel.%p", self];
            _concurrentLabel = dispatch_queue_create([concurrentLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
            //开启数据处理管理器
            [FTTrackDataManger sharedInstance];
            _presetProperty = [[FTPresetProperty alloc] initWithMobileConfig:config];
        }
    }@catch(NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
    return self;
}
-(void)resetConfig:(FTMobileConfig *)config{
    [FTLog enableLog:config.enableSDKDebugLog];
    [[FTConfigManager sharedInstance] setTrackConfig:config];
    if (_presetProperty) {
        [self.presetProperty resetWithMobileConfig:config];
    }else{
        self.presetProperty = [[FTPresetProperty alloc] initWithMobileConfig:config];
    }
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    if (!_rumConfig) {
        _rumConfig = [rumConfigOptions copy];
        [FTConfigManager sharedInstance].rumConfig = _rumConfig;
        [self.presetProperty setAppid:_rumConfig.appid];
        self.presetProperty.rumContext = [rumConfigOptions.globalContext copy];
        [[FTGlobalRumManager sharedInstance] setRumConfig:_rumConfig];
    }
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
    }
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    _netTraceStr = FTNetworkTraceStringMap[traceConfigOptions.networkTraceType];
    [FTConfigManager sharedInstance].traceConfig = traceConfigOptions;
    [[FTTraceHeaderManager sharedInstance] setNetworkTrace:traceConfigOptions];
}
#pragma mark ========== publick method ==========
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    @try {
        if (!self.loggerConfig.enableCustomLog) {
            ZYLog(@"enableCustomLog 未开启，数据不进行采集");
            return;
        }
        dispatch_async(self.concurrentLabel, ^{
            [self loggingWithType:FTAddDataLogging status:status content:content tags:nil field:nil tm:[FTDateUtil currentTimeNanosecond]];
        });
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
    if (![self judgeRUMTraceOpen]) {
        return;
    }
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
-(void)loggingWithType:(FTAddDataType)type status:(FTLogStatus)status content:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
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
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[self.presetProperty loggerPropertyWithStatus:status serviceName:self.loggerConfig.service]];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        if (self.loggerConfig.enableLinkRumData) {
            [tagDict addEntriesFromDictionary:[self.presetProperty rumPropertyWithTerminal:FT_TERMINAL_APP]];
            NSDictionary *rumTag = [[FTGlobalRumManager sharedInstance].rumManger getCurrentSessionInfo];
            [tagDict addEntriesFromDictionary:rumTag];
        }
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_LOGGER_SOURCE op:FT_DATA_TYPE_LOGGING tags:tagDict field:filedDict tm:tm];
        [self insertDBWithItemData:model type:type];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
//控制台日志采集
- (void)_traceConsoleLog{
    __weak typeof(self) weakSelf = self;
    [FTLogHook hookWithBlock:^(NSString * _Nonnull logStr,long long tm) {
        dispatch_async(self.concurrentLabel, ^{
            if (!weakSelf.loggerConfig.enableConsoleLog ) {
                return;
            }
            if (weakSelf.loggerConfig.prefix.length>0) {
                if([logStr containsString:weakSelf.loggerConfig.prefix]){
                    [weakSelf loggingWithType:FTAddDataLogging status:FTStatusInfo content:logStr tags:nil field:nil tm:tm];
                }
            }else{
                [weakSelf loggingWithType:FTAddDataLogging status:FTStatusInfo content:logStr tags:nil field:nil tm:tm];
            }
        });
    }];
}
- (void)insertDBWithItemData:(FTRecordModel *)model type:(FTAddDataType)type{
    [[FTTrackDataManger sharedInstance] addTrackData:model type:type];
}
- (BOOL)judgeRUMTraceOpen{
    if (self.rumConfig.appid.length>0) {
        return YES;
    }
    return NO;
}
#pragma mark - SDK注销
- (void)resetInstance{
    [[FTGlobalRumManager sharedInstance] resetInstance];
    _presetProperty = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [FTURLProtocol stopMonitor];
    [[FTConfigManager sharedInstance] resetInstance];
    onceToken = 0;
    sharedInstance =nil;
}
@end
