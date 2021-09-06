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
#import <UIKit/UIKit.h>
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import "FTMonitorManager.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTLog.h"
#import "NSString+FTAdd.h"
#import "FTDateUtil.h"
#import "FTJSONUtil.h"
#import "FTPresetProperty.h"
#import "FTMonitorUtils.h"
#import "FTLogHook.h"
#import "FTMonitorUtils.h"
#import "FTRUMManger.h"
#import "FTConstants.h"
#import "FTReachability.h"
#import "FTConfigManager.h"
#import "FTTrackDataManger.h"

@interface FTMobileAgent ()
@property (nonatomic, strong) dispatch_queue_t concurrentLabel;
@property (nonatomic, copy)   NSString *net;
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) NSDate *lastAddDBDate;
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTTraceConfig *traceConfig;
@property (nonatomic, strong) FTRUMManger *rumManger;
@property (nonatomic, copy) NSString *netTraceStr;
@property (nonatomic, strong) NSLock *lock;
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
            _net = @"unknown";
            _lock = [[NSLock alloc]init];
            [FTLog enableLog:config.enableSDKDebugLog];
            NSString *concurrentLabel = [NSString stringWithFormat:@"io.concurrentLabel.%p", self];
            _concurrentLabel = dispatch_queue_create([concurrentLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
            //开启网络监听
            [[FTReachability sharedInstance] startNotifier];
            [self setUpListeners];
            _presetProperty = [[FTPresetProperty alloc]initWithVersion:config.version env:[FTBaseInfoHander envStrWithEnv:config.env]];
            [[FTMonitorManager sharedInstance] setMobileConfig:config];
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
        [self.presetProperty resetWithVersion:config.version env:[FTBaseInfoHander envStrWithEnv:config.env]];
    }else{
        self.presetProperty = [[FTPresetProperty alloc]initWithVersion:config.version env:[FTBaseInfoHander envStrWithEnv:config.env]];
    }
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    if (!_rumConfig) {
        _rumConfig = [rumConfigOptions copy];
        [self.presetProperty setAppid:_rumConfig.appid];
        _rumManger = [[FTRUMManger alloc]initWithRumConfig:_rumConfig];
        [[FTMonitorManager sharedInstance] setRumConfig:_rumConfig delegate:_rumManger];
    }
}
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions{
    if (!_loggerConfig) {
        self.loggerConfig = [loggerConfigOptions copy];
        if(self.loggerConfig.enableConsoleLog){
            [self _traceConsoleLog];
        }
        self.logLevelFilterSet = [NSSet setWithArray:loggerConfigOptions.logLevelFilter];
    }
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    if (!_traceConfig) {
        _traceConfig = [traceConfigOptions copy];
        _netTraceStr = [FTBaseInfoHander networkTraceTypeStrWithType:_traceConfig.networkTraceType];
        [[FTMonitorManager sharedInstance] setTraceConfig:_traceConfig];
    }
}
#pragma mark ========== publick method ==========
-(void)startTrackExtensionCrashWithApplicationGroupIdentifier:(NSString *)groupIdentifier{
    @try {
        if (![groupIdentifier isKindOfClass:NSString.class] || (groupIdentifier.length == 0)) {
            ZYLog(@"Group Identifier 数据格式有误");
            return;
        }
        dispatch_block_t block = ^{
            NSString *pathStr =[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupIdentifier] URLByAppendingPathComponent:@"ft_crash_data.plist"].path;
            NSArray *array = [[NSArray alloc] initWithContentsOfFile:pathStr];
            if (array.count>0) {
                NSData *data= [NSPropertyListSerialization dataWithPropertyList:@[]
                                                                         format:NSPropertyListBinaryFormat_v1_0
                                                                        options:0
                                                                          error:nil];
                if (data.length) {
                    BOOL result = [data  writeToFile:pathStr options:NSDataWritingAtomic error:nil];
                    ZYLog(@"Group file delete success %@",result);
                }
                [array enumerateObjectsUsingBlock:^(NSDictionary  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSDictionary *field = [obj valueForKey:@"field"];
                    NSNumber *tm = [obj valueForKey:@"tm"];
                    if (field && field.allKeys.count>0 && tm) {
                        if ([self judgeRUMTraceOpen]) {
                          
                            [self rumWrite:FT_TYPE_ERROR terminal:FT_TERMINAL_MINIPROGRA tags:@{@"crash_type":@"ios_crash"} fields:field tm:tm.longLongValue];
                        }else{
                            NSString *crash_message = field[@"crash_message"];
                            NSString *crash_stack = field[@"crash_stack"];
                            if (crash_stack && crash_message) {
                                NSString *info = [NSString stringWithFormat:@"Exception Reason:%@\n%@",crash_message,crash_stack];
                                [self loggingWithType:FTAddDataNormal status:FTStatusCritical content:info tags:@{FT_APPLICATION_UUID:[FTBaseInfoHander applicationUUID]} field:field tm:tm.longLongValue];
                            }
                        }
                    }else{
                        ZYLog(@"extension 采集数据格式有误。");
                    }
                }];
            }
        };
        dispatch_async(self.concurrentLabel, block);
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
-(void)logging:(NSString *)content status:(FTStatus)status{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    @try {
        if (!self.loggerConfig.enableCustomLog) {
            ZYLog(@"enableCustomLog 未开启，数据不进行采集");
            return;
        }
        dispatch_async(self.concurrentLabel, ^{
            [self loggingWithType:FTAddDataNormal status:status content:content tags:nil field:nil tm:[FTDateUtil currentTimeNanosecond]];
        });
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
//用户绑定
- (void)bindUserWithUserID:(NSString *)Id{
    NSParameterAssert(Id);
    self.presetProperty.isSignin = YES;
    [FTBaseInfoHander setUserId:Id];
    ZYDebug(@"Bind User ID : %@",Id);
}
//用户注销
- (void)logout{
    self.presetProperty.isSignin = NO;
    [FTBaseInfoHander setUserId:nil];
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
        NSMutableDictionary *baseTags =[NSMutableDictionary dictionaryWithDictionary:tags];
        baseTags[@"network_type"] = self.net;
        [baseTags addEntriesFromDictionary:[self.presetProperty rumPropertyWithType:type terminal:terminal]];
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:type op:FT_DATA_TYPE_RUM tags:baseTags field:fields tm:tm];
        [self insertDBWithItemData:model type:dataType];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

// FT_DATA_TYPE_LOGGING
-(void)loggingWithType:(FTAddDataType)type status:(FTStatus)status content:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    if (!self.loggerConfig) {
        ZYErrorLog(@"请先设置 FTLoggerConfig");
        return;
    }
    if (!content || content.length == 0 || [content ft_charactorNumber]>FT_LOGGING_CONTENT_SIZE) {
        ZYErrorLog(@"传入的第数据格式有误，或content超过30kb");
        return;
    }
    if (![self.logLevelFilterSet containsObject:@(status)]) {
        ZYDebug(@"经过过滤算法判断-此条日志不采集");
        return;
    }
    if (![FTBaseInfoHander randomSampling:self.loggerConfig.samplerate]){
        ZYDebug(@"经过采集算法判断-此条日志不采集");
        return;
    }
    @try {
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[self.presetProperty loggerPropertyWithStatus:status serviceName:self.loggerConfig.service]];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        if (self.loggerConfig.enableLinkRumData) {
            [tagDict addEntriesFromDictionary:[self.presetProperty rumPropertyWithType:@"logging" terminal:@"app"]];
            NSDictionary *rumTag = [self.rumManger getCurrentSessionInfo];
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
-(void)tracing:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    if (!content || content.length == 0 || [content ft_charactorNumber]>FT_LOGGING_CONTENT_SIZE) {
        ZYErrorLog(@"传入的第数据格式有误，或content超过30kb");
        return;
    }
    @try {
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:[self.presetProperty tracePropertyWithServiceName:self.traceConfig.service]];
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
        FTRecordModel *model = [[FTRecordModel alloc]initWithSource:self.netTraceStr op:FT_DATA_TYPE_TRACING tags:tagDict field:filedDict tm:tm];
        [self insertDBWithItemData:model type:FTAddDataNormal];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
//控制台日志采集
- (void)_traceConsoleLog{
    __weak typeof(self) weakSelf = self;
    [FTLogHook hookWithBlock:^(NSString * _Nonnull logStr,long long tm) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (!weakSelf.loggerConfig.enableConsoleLog ) {
                return;
            }
            if (weakSelf.loggerConfig.prefix.length>0) {
                if([logStr containsString:weakSelf.loggerConfig.prefix]){
                    [weakSelf loggingWithType:FTAddDataCache status:FTStatusInfo content:logStr tags:nil field:nil tm:tm];
                }
            }else{
                [weakSelf loggingWithType:FTAddDataCache status:FTStatusInfo content:logStr tags:nil field:nil tm:tm];
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
#pragma mark - 网络与App的生命周期
- (void)setUpListeners{
    self.net = [FTReachability sharedInstance].networkType;
    __weak typeof(self) weakSelf = self;
    [FTReachability sharedInstance].networkChanged = ^(){
        weakSelf.net = [FTReachability sharedInstance].networkType;
        if([FTReachability sharedInstance].isReachable){
            [weakSelf uploadFlush];
        }
    };
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // 应用生命周期通知
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminateNotification:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    @try {
        [self uploadFlush];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationWillResignActive:(NSNotification *)notification {
    @try {
       [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"applicationWillResignActive exception %@",exception);
    }
}

- (void)applicationWillTerminateNotification:(NSNotification *)notification{
    @try {
        [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - 上报策略
- (void)uploadFlush{
    [[FTTrackDataManger sharedInstance] uploadTrackData];
}
#pragma mark - SDK注销
- (void)resetInstance{
    [[FTMonitorManager sharedInstance] resetInstance];
    _presetProperty = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    onceToken = 0;
    sharedInstance =nil;
}
@end
