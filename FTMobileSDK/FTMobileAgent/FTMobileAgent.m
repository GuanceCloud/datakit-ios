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
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "FTUploadTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import "FTLocationManager.h"
#import "FTMonitorManager.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTLog.h"
#import "FTUncaughtExceptionHandler.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTAdd.h"
#import "FTJSONUtil.h"
#import "FTPresetProperty.h"
#import "FTTrack.h"
#import "FTMonitorUtils.h"
#import "FTLogHook.h"
#import "FTNetworkInfo.h"
#import "FTMonitorUtils.h"
@interface FTMobileAgent ()
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t concurrentLabel;
@property (nonatomic, copy)   NSString *net;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) NSDate *launchTime;
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) NSDate *lastAddDBDate;
@property (nonatomic, strong) FTTrack *track;
@property (nonatomic, assign) BOOL running; //正在运行
@property (nonatomic, copy) NSString *netTraceStr;
@end
@implementation FTMobileAgent{
    BOOL _appRelaunched;          // App 从后台恢复
    //进入非活动状态，比如双击 home、系统授权弹框
    BOOL _applicationWillResignActive;
}

static FTMobileAgent *sharedInstance = nil;
static dispatch_once_t onceToken;
static void ZYReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    
    if (info != NULL && [(__bridge NSObject*)info isKindOfClass:[FTMobileAgent class]]) {
        @autoreleasepool {
            FTMobileAgent *zy = (__bridge FTMobileAgent *)info;
            [zy reachabilityChanged:flags];
        }
    }
}
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
            if (config) {
                self.config = config;
            }
            _net = @"unknown";
            _appRelaunched = NO;
            _running = NO;
            self.launchTime = [NSDate date];
            [FTLog enableLog:config.enableSDKDebugLog];
            _netTraceStr = [FTBaseInfoHander ft_getNetworkTraceTypeStr:config.networkTraceType];
            self.track = [[FTTrack alloc]init];
            [[FTMonitorManager sharedInstance] setMobileConfig:self.config];
            NSString *label = [NSString stringWithFormat:@"io.zy.%p", self];
            self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
            NSString *concurrentLabel = [NSString stringWithFormat:@"io.concurrentLabel.%p", self];
            self.concurrentLabel = dispatch_queue_create([concurrentLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
            [self setUpListeners];
            self.presetProperty = [[FTPresetProperty alloc]initWithAppid:self.config.appid version:self.config.version env:[FTBaseInfoHander ft_getFTEnvStr:self.config.env]];
            [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self];
            self.upTool = [[FTUploadTool alloc]initWithConfig:self.config];
            if (self.config.traceConsoleLog) {
                   [self _traceConsoleLog];
            }
        }
    }@catch(NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
    return self;
}
-(void)resetConfig:(FTMobileConfig *)config{
    if (!_track) {
        self.track = [[FTTrack alloc]init];
    }
    _netTraceStr = [FTBaseInfoHander ft_getNetworkTraceTypeStr:config.networkTraceType];
    [FTLog enableLog:config.enableSDKDebugLog];
    [[FTMonitorManager sharedInstance] setMobileConfig:config];
    self.config = config;
    if (_presetProperty) {
        [self.presetProperty resetWithAppid:self.config.appid version:self.config.version env:[FTBaseInfoHander ft_getFTEnvStr:self.config.env]];
    }else{
        self.presetProperty = [[FTPresetProperty alloc]initWithAppid:self.config.appid version:self.config.version env:[FTBaseInfoHander ft_getFTEnvStr:self.config.env]];
    }
    self.upTool.config = config;
    
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
                            if (![self judgeIsTraceSampling]) {
                                return;
                            }
                            [self rumTrackES:FT_TYPE_CRASH terminal:FT_TERMINAL_MINIPROGRA tags:@{@"crash_type":@"ios_crash"} fields:field tm:tm.longLongValue];
                        }else{
                            NSString *crash_message = field[@"crash_message"];
                            NSString *crash_stack = field[@"crash_stack"];
                            if (crash_stack && crash_message) {
                                NSString *info = [NSString stringWithFormat:@"Exception Reason:%@\n%@",crash_message,crash_stack];
                                [self loggingWithType:FTAddDataNormal status:FTStatusCritical content:info tags:@{FT_APPLICATION_UUID:[FTBaseInfoHander ft_getApplicationUUID]} field:field tm:tm.longLongValue];
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
        [self loggingWithType:FTAddDataNormal status:status content:content tags:nil field:nil tm:[[NSDate date]ft_dateTimestamp]];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark ========== private method ==========
//RUM INFLUXDB
- (void)rumTrack:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self rumTrack:type tags:tags fields:fields tm:[[NSDate date] ft_dateTimestamp]];
}
- (void)rumTrack:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (![self judgeRUMTraceOpen]) {
        return;
    }
    if (![type isKindOfClass:NSString.class] || type.length == 0) {
        return;
    }
    @try {
        NSMutableDictionary *baseTags =[NSMutableDictionary dictionaryWithDictionary:[self.presetProperty getPropertyWithType:type]];
        baseTags[@"network_type"] = self.net;
        if (tags) {
            [baseTags addEntriesFromDictionary:tags];
        }
        [self insertDBWithItemData:[self getModelWithMeasurement:type op:FTDataTypeRUM tags:baseTags field:fields tm:[[NSDate date] ft_dateTimestamp]] type:FTAddDataNormal];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
//RUM  ES
- (void)rumTrackES:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self rumTrackES:type terminal:terminal tags:tags fields:fields tm:[[NSDate date] ft_dateTimestamp]];
}
- (void)rumTrackES:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (![self judgeRUMTraceOpen]) {
        return;
    }
    if (![type isKindOfClass:NSString.class] || type.length == 0 || terminal.length == 0) {
        return;
    }
    @try {
        FTAddDataType dataType = FTAddDataImmediate;
        NSMutableDictionary *baseTags =[NSMutableDictionary dictionaryWithDictionary:[self.presetProperty getESPropertyWithType:type terminal:terminal]];
        baseTags[@"network_type"] = self.net;
        if ([type isEqualToString:FT_TYPE_CRASH]) {
            dataType = FTAddDataImmediate;
            if ([terminal isEqualToString:FT_TERMINAL_APP]) {
                baseTags[@"crash_situation"] = _running?@"run":@"startup";
                if (self.config.monitorInfoType & FTMonitorInfoTypeBluetooth) {
                    baseTags[FT_MONITOR_BT_OPEN] = [NSNumber numberWithBool:[FTMonitorManager sharedInstance].isBlueOn];
                }
                if (self.config.monitorInfoType & FTMonitorInfoTypeMemory) {
                    baseTags[FT_MONITOR_MEMORY_TOTAL] = [FTMonitorUtils ft_getTotalMemorySize];
                }
                baseTags[FT_MONITOR_GPS_OPEN] = [NSNumber numberWithBool:[[FTLocationManager sharedInstance] gpsServicesEnabled]];
                
                if (self.config.monitorInfoType & FTMonitorInfoTypeCpu) {
                    baseTags[FT_MONITOR_CPU_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils ft_cpuUsage]];
                }
                if (self.config.monitorInfoType & FTMonitorInfoTypeMemory) {
                    baseTags[FT_MONITOR_MEM_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils ft_usedMemory]];
                }
                if (self.config.monitorInfoType & FTMonitorInfoTypeBattery) {
                    baseTags[FT_MONITOR_POWER] =[NSNumber numberWithDouble:[FTMonitorUtils ft_getBatteryUse]];
                }
            }else{
                baseTags[@"crash_situation"] = @"run";
            }
        }
        if (tags) {
            [baseTags addEntriesFromDictionary:tags];
        }
        FTRecordModel *model = [self getModelWithMeasurement:type op:FTDataTypeRUM tags:baseTags field:fields tm:[[NSDate date] ft_dateTimestamp]];
        [self insertDBWithItemData:model type:dataType];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

// FT_DATA_TYPE_LOGGING
-(void)loggingWithType:(FTAddDataType)type status:(FTStatus)status content:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    if (!content || content.length == 0 || [content ft_charactorNumber]>FT_LOGGING_CONTENT_SIZE) {
        ZYErrorLog(@"传入的第数据格式有误，或content超过30kb");
        return;
    }
    @try {
        NSMutableDictionary *tagDict = @{FT_KEY_STATUS:[FTBaseInfoHander ft_getFTstatueStr:status],
                                         FT_KEY_SERVICENAME:self.config.serviceName,
                                         @"app_identifier":[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
                                         @"__env":[FTBaseInfoHander ft_getFTEnvStr: self.config.env],
                                         @"device_uuid":[[UIDevice currentDevice] identifierForVendor].UUIDString,
                                         @"version":self.config.version
        }.mutableCopy;
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
        FTRecordModel *model = [self getModelWithMeasurement:self.config.source op:FTDataTypeLOGGING tags:tagDict field:filedDict tm:tm];
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
        NSMutableDictionary *tagDict = @{
            FT_KEY_SERVICE:self.config.serviceName,
            @"app_identifier":[FTPresetProperty appIdentifier],
            @"env":[FTBaseInfoHander ft_getFTEnvStr: self.config.env],
            @"device_uuid":[FTPresetProperty deviceUUID],
            @"version":self.config.version
        }.mutableCopy;
        if (tags) {
            [tagDict addEntriesFromDictionary:tags];
        }
        NSMutableDictionary *filedDict = @{FT_KEY_MESSAGE:content,
        }.mutableCopy;
        if (field) {
            [filedDict addEntriesFromDictionary:field];
        }
        FTRecordModel *model = [self getModelWithMeasurement:self.netTraceStr op:FTDataTypeTRACING tags:tagDict field:filedDict tm:tm];
        [self insertDBWithItemData:model type:FTAddDataNormal];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
    
}
-(void)trackStartWithViewLoadTime:(NSDate *)time{
    self.running = YES;
    if ([self judgeIsTraceSampling]) {
        NSString *startType = _appRelaunched?@"hot":@"cold";
        NSTimeInterval duration = [time timeIntervalSinceDate:self.launchTime];
        NSNumber *durationTime = [time ft_nanotimeIntervalSinceDate:self.launchTime];
        if (duration>9) {
            duration = 9;
        }
        NSDictionary *tags = @{@"app_startup_type":startType,
                               @"app_apdex_level":[NSNumber numberWithInt:duration],
        };
        NSDictionary *fields = @{
            @"app_startup_duration":durationTime,
        };
        [self rumTrack:FT_RUM_APP_STARTUP tags:tags fields:fields];
    }
    _appRelaunched = YES;
    if (self.config.eventFlowLog) {
        NSDictionary *tag =@{FT_KEY_OPERATIONNAME:[NSString stringWithFormat:@"%@/%@",FT_AUTO_TRACK_OP_LAUNCH,FT_KEY_EVENT]};
        [self loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil ft_convertToJsonData:@{FT_KEY_EVENT:FT_AUTO_TRACK_OP_LAUNCH}] tags:tag field:nil tm:[[NSDate date] ft_dateTimestamp]];
    }
}
//控制台日志采集
- (void)_traceConsoleLog{
    __weak typeof(self) weakSelf = self;
    [FTLogHook hookWithBlock:^(NSString * _Nonnull logStr,long long tm) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (weakSelf.config.traceConsoleLog) {
                [weakSelf loggingWithType:FTAddDataCache status:FTStatusInfo content:logStr tags:nil field:nil tm:tm];
            }
        });
    }];
}

#pragma mark - 用户绑定与注销
- (void)bindUserWithUserID:(NSString *)Id{
    NSParameterAssert(Id);
    self.presetProperty.isSignin = YES;
    [FTBaseInfoHander ft_setUserid:Id];
}
- (void)logout{
    self.presetProperty.isSignin = NO;
    [FTBaseInfoHander ft_setUserid:nil];
    ZYDebug(@"User logout");
}
- (FTRecordModel *)getModelWithMeasurement:(NSString *)measurement op:(FTDataType )op tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *fieldDict = field.mutableCopy;
    NSMutableDictionary *tagsDict = [NSMutableDictionary new];
    if (tags) {
        [tagsDict addEntriesFromDictionary:tags];
    }
    NSString *opStr,*key;
    switch (op) {
        case FTDataTypeRUM:
            opStr = FT_DATA_TYPE_RUM;
            key = FT_AGENT_MEASUREMENT;
            break;
        case FTDataTypeINFLUXDB:
            opStr = FT_DATA_TYPE_INFLUXDB;
            key = FT_AGENT_MEASUREMENT;
            break;
        case FTDataTypeLOGGING:
            key = FT_KEY_SOURCE;
            opStr = FT_DATA_TYPE_LOGGING;
            break;
        case FTDataTypeTRACING:
            key = FT_KEY_SOURCE;
            opStr = FT_DATA_TYPE_TRACING;
            break;
    }
    NSMutableDictionary *opdata = @{
        key:measurement,
        FT_AGENT_FIELD:fieldDict,
    }.mutableCopy;
    [opdata setValue:tagsDict forKey:FT_AGENT_TAGS];
    NSDictionary *data =@{@"op":opStr,
                          FT_AGENT_OPDATA:opdata,
    };
    ZYDebug(@"datas == %@",data);
    model.op = opStr;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    if (tm&&tm>0) {
        model.tm = tm;
    }
    return model;
}
- (void)insertDBWithItemData:(FTRecordModel *)model type:(FTAddDataType)type{
    switch (type) {
        case FTAddDataNormal:{
            dispatch_async(self.concurrentLabel, ^{
                [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
            });
        }
            break;
        case FTAddDataCache:{
            dispatch_async(self.concurrentLabel, ^{
                [[FTTrackerEventDBTool sharedManger] insertItemToCache:model];
            });
        }
            break;
        case FTAddDataImmediate:{
            [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
            [[FTTrackerEventDBTool sharedManger] insertCacheToDB];

        }
            break;
     
    }
    //上传逻辑 数据库写入 距第一次写入间隔10秒以上 启动上传
    if (self.lastAddDBDate) {
        NSDate* now = [NSDate date];
        NSTimeInterval time = [now timeIntervalSinceDate:self.lastAddDBDate];
        if (time>10) {
            self.lastAddDBDate = [NSDate date];
            [self uploadFlush];
        }
    }else{
        self.lastAddDBDate = [NSDate date];
    }
}
/**
 * 采集率判断 判断当前数据是否被采集
 */
- (BOOL)judgeIsTraceSampling{
    int rate = self.config.samplerate;
    if(rate<=0){
        return NO;
    }
    if(rate<100){
        int x = arc4random() % 100;
        return x <= rate ? YES:NO;
    }
    return YES;
}
- (BOOL)judgeRUMTraceOpen{
    if (self.config.appid.length>0) {
        return YES;
    }
    return NO;
}
#pragma mark - 网络与App的生命周期
- (void)setUpListeners{
    BOOL reachabilityOk = NO;
    if ((_reachability = SCNetworkReachabilityCreateWithName(NULL, "www.baidu.com")) != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(_reachability, ZYReachabilityCallback, &context)) {
            if (SCNetworkReachabilitySetDispatchQueue(_reachability, self.concurrentLabel)) {
                reachabilityOk = YES;
            } else {
                SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
            }
        }
    }
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // 应用生命周期通知
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidFinishLaunching:)
                               name:UIApplicationDidFinishLaunchingNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminateNotification:) name:UIApplicationWillTerminateNotification object:nil];
}
- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
            self.net = [FTNetworkInfo getNetworkType];//2G/3G/4G/5G
        } else {
            self.net = @"wifi";//WIFI
        }
         [self uploadFlush];
    } else {
        self.net = @"unreachable";//未知
    }
    ZYDebug(@"联网状态: %@", [@"unreachable" isEqualToString:self.net]?@"未知":[@"wifi" isEqualToString:self.net]?@"WIFI":@"移动网络");
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
}
- (void)applicationWillEnterForeground:(NSNotification *)notification{
    if (_appRelaunched){
         self.launchTime = [NSDate date];
    }
    _running = NO;
}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    @try {
        if (_applicationWillResignActive) {
            _applicationWillResignActive = NO;
            return;
        }
        [self uploadFlush];
        if (_appRelaunched) {
            [self trackStartWithViewLoadTime:[NSDate date]];
        }
        if (self.config.monitorInfoType & FTMonitorInfoTypeFPS || self.config.enableTrackAppUIBlock) {
            [[FTMonitorManager sharedInstance] startMonitorFPS];
        }
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationWillResignActive:(NSNotification *)notification {
    @try {
       _applicationWillResignActive = YES;
       [[FTMonitorManager sharedInstance] pauseMonitorFPS];
       [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"applicationWillResignActive exception %@",exception);
    }
}
- (void)applicationDidEnterBackground:(NSNotification *)notification{
    if (!_applicationWillResignActive) {
           return;
       }
       _applicationWillResignActive = NO;
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
    dispatch_async(self.serialQueue, ^{
        if (![self.net isEqualToString:@"unreachable"]) {
            [self.upTool upload];
        }
    });
}
- (void)resetInstance{
    [[FTMonitorManager sharedInstance] resetInstance];
    [[FTUncaughtExceptionHandler sharedHandler] removeftSDKInstance:self];
    if (_reachability) {
        SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
    }
    _presetProperty = nil;
    self.config = nil;
    self.track = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.upTool = nil;
    onceToken = 0;
    sharedInstance =nil;
}
@end
