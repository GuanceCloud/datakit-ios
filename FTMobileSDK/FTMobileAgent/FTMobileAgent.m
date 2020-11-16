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
#import <objc/runtime.h>
#import "FTLocationManager.h"
#import "FTNetMonitorFlow.h"
#import "FTTrackBean.h"
#import "FTMonitorManager.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTLog.h"
#import "FTUncaughtExceptionHandler.h"
#import "FTLogHook.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTAdd.h"
#import "FTJSONUtil.h"
#import "FTPresetProperty.h"
@interface FTMobileAgent ()
@property (nonatomic, assign) BOOL isForeground;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t concurrentLabel;
@property (nonatomic, copy) NSString *net;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, assign) CFAbsoluteTime launchTime;
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger flushInterval;
@property (nonatomic, strong) NSDate *lastAddDBDate;

@end
@implementation UIView (FTMobileSdk)
-(NSString *)viewVtpDescID{
    return objc_getAssociatedObject(self, @"FTViewVtpDescID");
}
-(BOOL)vtpAddIndexPath{
    return [objc_getAssociatedObject(self, @"FTVtpAddIndexPath") boolValue];
}
-(void)setViewVtpDescID:(NSString *)viewVtpDescID{
    objc_setAssociatedObject(self, @"FTViewVtpDescID", viewVtpDescID, OBJC_ASSOCIATION_COPY);
}
-(void)setVtpAddIndexPath:(BOOL)vtpAddIndexPath{
    objc_setAssociatedObject(self, @"FTVtpAddIndexPath", [NSNumber numberWithBool:vtpAddIndexPath], OBJC_ASSOCIATION_ASSIGN);
}
@end
@implementation FTMobileAgent

static FTMobileAgent *sharedInstance = nil;
static dispatch_once_t onceToken;
static char FTAutoTrack;
static void ZYReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    
    if (info != NULL && [(__bridge NSObject*)info isKindOfClass:[FTMobileAgent class]]) {
        @autoreleasepool {
            FTMobileAgent *zy = (__bridge FTMobileAgent *)info;
            [zy reachabilityChanged:flags];
        }
    }
}
+ (void)startLocation:(nullable void (^)(NSInteger errorCode,NSString * _Nullable errorMessage))callBack{
    if ([[FTLocationManager sharedInstance].location.country isEqualToString:FT_NULL_VALUE]) {
    [[FTLocationManager sharedInstance] startUpdatingLocation];
    __block BOOL isUpdate = NO;
    [FTLocationManager sharedInstance].updateLocationBlock = ^(FTLocationInfo * _Nonnull locInfo, NSError * _Nullable error) {
        if (error) {
            NSString *message =error.domain;
            if(error.code == 104){
                message = [error.userInfo objectForKey:NSLocalizedDescriptionKey];
            }
            (callBack&&isUpdate==NO)?callBack(UnknownException,message):nil;
            ZYDebug(@"Location Error : %@",error);
        }else{
            ZYDebug(@"Location Success");
            (callBack&&isUpdate==NO)?callBack(0,nil):nil;
        }
        isUpdate = YES;
    };
    }else{
        ZYDebug(@"Location Success");
        callBack?callBack(0,nil):nil;
    }
}
#pragma mark --------- 初始化 config 设置 ----------
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions{
    NSAssert ((strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0),@"SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 lunch 事件）。");
    if (configOptions.enableRequestSigning) {
        NSAssert((configOptions.akSecret.length!=0 && configOptions.akId.length != 0), @"设置需要进行请求签名 必须要填akId与akSecret");
    }
    if (configOptions.autoTrackEventType != FTAutoTrackTypeNone && configOptions.enableAutoTrack) {
        NSAssert((NSClassFromString(@"FTAutoTrack")), @"开启自动采集需导入FTAutoTrackSDK");
    }
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
            [FTLog enableLog:config.enableLog];
            [FTLog enableDescLog:config.enableDescLog];
            [[FTMonitorManager sharedInstance] setMobileConfig:self.config];
            _flushInterval = 10;
            NSString *label = [NSString stringWithFormat:@"io.zy.%p", self];
            self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
            NSString *concurrentLabel = [NSString stringWithFormat:@"io.concurrentLabel.%p", self];
            self.concurrentLabel = dispatch_queue_create([concurrentLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
            [self setupAppNetworkListeners];
            if (self.config.enableAutoTrack) {
                [self startAutoTrack];
            }
            self.presetProperty = [[FTPresetProperty alloc]initWithTrackVersion:[self sdkTrackVersion] traceServiceName:self.config.traceServiceName env:self.config.env];
            [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self];
            self.upTool = [[FTUploadTool alloc]initWithConfig:self.config];
            [self uploadSDKObject];
            if (self.config.traceConsoleLog) {
                [self _traceConsoleLog];
            }
        }
    }@catch(NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
    return self;
}
-(void)startAutoTrack{
    NSString *invokeMethod = @"startWithConfig:";
    Class track =  NSClassFromString(@"FTAutoTrack");
    if (track) {
        id  autoTrack = [[NSClassFromString(@"FTAutoTrack") alloc]init];
        SEL startMethod = NSSelectorFromString(invokeMethod);
        IMP imp = [autoTrack methodForSelector:startMethod];
        void (*func)(id, SEL,id) = (void (*)(id,SEL,id))imp;
        func(autoTrack,startMethod,self.config);
        objc_setAssociatedObject(self, &FTAutoTrack, autoTrack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
-(void)resetConfig:(FTMobileConfig *)config{
    [FTLog enableLog:config.enableLog];
    [FTLog enableDescLog:config.enableDescLog];
    if (config.traceConsoleLog) {
        [self _traceConsoleLog];
    }
    id autotrack = objc_getAssociatedObject(self, &FTAutoTrack);
    self.config = config;
    if (!autotrack) {
        if (self.config.enableAutoTrack) {
            [self startAutoTrack];
        }
    }
    else{
        NSString *invokeMethod = @"startWithConfig:";
        SEL startMethod = NSSelectorFromString(invokeMethod);
        IMP imp = [autotrack methodForSelector:startMethod];
        void (*func)(id, SEL,id) = (void (*)(id,SEL,id))imp;
        func(autotrack,startMethod,self.config);
    }
    [[FTMonitorManager sharedInstance] setMobileConfig:config];
    self.upTool.config = config;
}
#pragma mark ========== publick method ==========
- (void)trackBackground:(NSString *)measurement field:(NSDictionary *)field{
    [self trackBackground:measurement tags:nil field:field withTrackOP:FT_TRACK_OP_CUSTOM];
}
- (void)trackBackground:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field{
    NSParameterAssert(measurement);
    NSParameterAssert(field);
    if (measurement == nil || [measurement ft_removeFrontBackBlank].length == 0  || field == nil || [field allKeys].count == 0) {
        ZYErrorLog(@"文件名 事件名不能为空");
        return;
    }
    [self trackBackground:measurement tags:tags field:field withTrackOP:FT_TRACK_OP_CUSTOM];
}

-(void)trackImmediate:(NSString *)measurement field:(NSDictionary *)field callBack:(void (^)(NSInteger statusCode, id _Nullable responseObject))callBackStatus{
    NSParameterAssert(measurement);
    NSParameterAssert(field);
    [self trackImmediate:measurement tags:nil field:field callBack:callBackStatus];
}
- (void)trackImmediate:(NSString *)measurement tags:(NSDictionary *)tags field:(NSDictionary *)field callBack:(void (^)(NSInteger, id _Nullable))callBackStatus{
    NSParameterAssert(measurement);
    NSParameterAssert(field);
    @try {
        if (measurement == nil || [measurement ft_removeFrontBackBlank].length == 0 || field == nil || [field allKeys].count == 0) {
            ZYDebug(@"文件名 事件名不能为空");
            callBackStatus?callBackStatus(InvalidParamsException,nil):nil;
            return;
        }
        FTRecordModel *model = [self getRecordModelWithMeasurement:measurement tags:tags field:field op:FT_TRACK_OP_CUSTOM netType:FTNetworkingTypeMetrics tm:0];
        [self trackUpload:@[model] callBack:callBackStatus];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)trackImmediateList:(NSArray <FTTrackBean *>*)trackList callBack:(void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus{
    NSParameterAssert(trackList);
    @try {
        __block NSMutableArray *list = [NSMutableArray new];
        [trackList enumerateObjectsUsingBlock:^(FTTrackBean * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.measurement.length>0 && obj.field.allKeys.count>0) {
                FTRecordModel *model = [self getRecordModelWithMeasurement:obj.measurement tags:obj.tags field:obj.field op:FT_TRACK_OP_CUSTOM netType:FTNetworkingTypeMetrics tm:0];
                if(obj.timeMillis && obj.timeMillis>1000000000000){
                    model.tm = obj.timeMillis*1000;
                }
                [list addObject:model];
            }else{
                ZYLog(@"传入的第 %d 个数据格式有误",idx);
            }
        }];
        if (list.count>0) {
            [self trackUpload:list callBack:callBackStatus];
        }else{
            ZYLog(@"传入的数据格式有误");
            callBackStatus?callBackStatus(InvalidParamsException,nil):nil;
        }
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
-(void)startTrackExtensionCrashWithApplicationGroupIdentifier:(NSString *)groupIdentifier{
    @try {
        if (![groupIdentifier isKindOfClass:NSString.class] || (groupIdentifier.length == 0)) {
            ZYLog(@"Group Identifier 数据格式有误");
            return;
        }
        dispatch_block_t block = ^(){
            NSString *pathStr =[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupIdentifier] URLByAppendingPathComponent:@"ft_crash_data.plist"].path;
            NSArray *array = [[NSArray alloc] initWithContentsOfFile:pathStr];
            if (array.count>0) {
                NSData *data= [NSPropertyListSerialization dataWithPropertyList:@[]
                                                                         format:NSPropertyListBinaryFormat_v1_0
                                                                        options:0
                                                                          error:nil];
                if (data.length) {
                    BOOL result = [data  writeToFile:pathStr options:NSDataWritingAtomic error:nil];
                }
                [array enumerateObjectsUsingBlock:^(NSDictionary  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSString *content = [obj valueForKey:@"content"];
                    NSNumber *tm = [obj valueForKey:@"tm"];
                    if (content && content.length>0 && tm) {
                        [self loggingExceptionOrANRInsertWithContent:content tm:tm.longLongValue];
                    }
                }];
            }
        };
        dispatch_async(self.serialQueue, block);
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - logging
-(void)logging:(NSString *)content status:(FTStatus)status{
    NSParameterAssert(content);
    @try {
        [self _loggingBackgroundInsertWithOP:@"logging" status:[FTBaseInfoHander ft_getFTstatueStr:status] content:content tm:[[NSDate date] ft_dateTimestamp] tags:nil field:nil];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - 用户绑定与注销
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(NSDictionary *)exts{
    NSParameterAssert(name);
    NSParameterAssert(Id);
    [[FTTrackerEventDBTool sharedManger] insertUserDataWithName:name Id:Id exts:exts];
}
- (void)logout{
    NSUserDefaults *defatluts = [NSUserDefaults standardUserDefaults];
    [defatluts removeObjectForKey:FT_SESSIONID];
    [defatluts synchronize];
    ZYDebug(@"User logout");
}
- (void)resetInstance{
    [[FTMonitorManager sharedInstance] resetInstance];
    [[FTLocationManager sharedInstance] resetInstance];
    [[FTUncaughtExceptionHandler sharedHandler] removeftSDKInstance:self];
    if (_reachability) {
        SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
    }
    self.config = nil;
    objc_setAssociatedObject(self, &FTAutoTrack, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_removeAssociatedObjects(self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.upTool = nil;
    onceToken = 0;
    sharedInstance =nil;
}
#pragma mark - 调用监控项管理方法
-(void)setMonitorFlushInterval:(NSInteger)interval{
    _flushInterval = interval;
       if(_timer){
           [self stopMonitorFlush];
           [self startMonitorFlush];
       }
}
-(void)startMonitorFlushWithInterval:(NSInteger)interval monitorType:(FTMonitorInfoType)type{
    _config.monitorInfoType = type;
    [self setMonitorFlushInterval:interval];
    [self startMonitorFlush];
}
-(void)startMonitorFlush{
    //如果监控类型为空 直接返回
    if (self.config.monitorInfoType == 0) {
        return;
    }
    if ((self.timer && [self.timer isValid])) {
        return;
    }
    ZYDebug(@"starting monitor flush timer.");
    if (self.flushInterval > 0) {
        [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(monitorFlush)
                                                        userInfo:nil
                                                         repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        }];
    }
}
-(void)stopMonitorFlush{
   if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = nil;
}
-(void)monitorFlush{
    if (self.config.monitorInfoType == 0) {
        return;
    }
    NSDictionary *addDict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *opdata = @{
        FT_AGENT_MEASUREMENT:@"mobile_monitor"}.mutableCopy;
    NSMutableDictionary *tags = [self.presetProperty automaticProperties].mutableCopy;
    if ([addDict objectForKey:FT_AGENT_TAGS]) {
        [tags addEntriesFromDictionary:[addDict objectForKey:FT_AGENT_TAGS]];
    }
    if ([addDict objectForKey:FT_AGENT_FIELD]) {
        [opdata setValue:[addDict objectForKey:FT_AGENT_FIELD] forKey:FT_AGENT_FIELD];
    }
    [opdata setValue:tags forKey:FT_AGENT_TAGS];
    NSDictionary *data =@{
        FT_AGENT_OP:@"monitor",
        FT_AGENT_OPDATA:opdata,
    };
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    model.tm =[[NSDate date] ft_dateTimestamp];
    model.op = FTNetworkingTypeMetrics;
    void (^UploadResultBlock)(NSInteger,id) = ^(NSInteger statusCode,id responseObject){
        ZYDebug(@"statusCode == %d\nresponseObject == %@",statusCode,responseObject);
    };
    [[FTMobileAgent sharedInstance] trackUpload:@[model] callBack:UploadResultBlock];
}
#pragma mark ========== private method==========
#pragma mark - 立即上传
-(void)trackUpload:(NSArray<FTRecordModel *> *)list callBack:(void (^)(NSInteger statusCode, _Nullable id responseObject))callBack{
    if ([self.net isEqualToString:@"-1"]) {
        callBack? callBack(NetWorkException,nil):nil;
    }else{
    dispatch_async(self.concurrentLabel, ^{
        [self.upTool trackImmediateList:list callBack:^(NSInteger statusCode, NSData * _Nonnull response) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callBack? callBack(statusCode,[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]):nil;
            });
        }];
    });
    }
}
#pragma mark - 数据拼接 存储数据库
- (void)trackBackground:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field withTrackOP:(NSString *)trackOP{
    @try {
        FTRecordModel *model = [self getRecordModelWithMeasurement:measurement tags:tags field:field op:trackOP netType:FTNetworkingTypeMetrics tm:0];
        [self insertDBWithItemData:model cache:NO];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
//控制台日志采集
- (void)_traceConsoleLog{
    __weak typeof(self) weakSelf = self;
    [FTLogHook hookWithBlock:^(NSString * _Nonnull logStr,long long tm) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (weakSelf.config.traceConsoleLog) {
                [weakSelf _loggingBackgroundInsertWithOP:FT_TRACK_LOGGING_CONSOLELOG status:[FTBaseInfoHander ft_getFTstatueStr:FTStatusInfo] content:logStr tm:tm];
            }
        });
    }];
}

- (void)_loggingBackgroundInsertWithOP:(NSString *)op status:(NSString *)status content:(NSString *)content tm:(long long)tm{
    [self _loggingBackgroundInsertWithOP:op status:status content:content tm:tm tags:nil field:nil];
}
- (void)_loggingBackgroundInsertWithOP:(NSString *)op status:(NSString *)status content:(NSString *)content tm:(long long)tm tags:(NSDictionary *)tags field:(NSDictionary *)field{
    if (!content || content.length == 0 || [content charactorNumber]>FT_LOGGING_CONTENT_SIZE) {
        ZYErrorLog(@"传入的第数据格式有误，或content超过30kb");
        return;
    }
    NSMutableDictionary *tag = @{FT_KEY_STATUS:status,
    }.mutableCopy;
    if (tags) {
        [tag addEntriesFromDictionary:tags];
    }
    NSMutableDictionary *filedDict = @{FT_KEY_CONTENT:content}.mutableCopy;
    if (field) {
        [filedDict addEntriesFromDictionary:field];
    }
    FTRecordModel *model = [self getRecordModelWithMeasurement:self.config.source tags:tag field:filedDict op:op netType:FTNetworkingTypeLogging tm:tm];
    //用户自定义logging 立即存储
    if([op isEqualToString:@"logging"]){
        [self insertDBWithItemData:model cache:NO];
    }else{
        [self insertDBWithItemData:model cache:YES];
    }
}
- (void)_loggingExceptionInsertWithContent:(NSString *)content tm:(long long)tm{
    if (self.config.enableTrackAppCrash) {
        [self loggingExceptionOrANRInsertWithContent:content tm:tm];
        [self _loggingArrayInsertDBImmediately];
    }
}
- (void)_loggingANRInsertWithContent:(NSString *)content tm:(long long)tm{
    if(self.config.enableTrackAppANR){
        [self loggingExceptionOrANRInsertWithContent:content tm:tm];
    }
}
- (void)loggingExceptionOrANRInsertWithContent:(NSString *)content tm:(long long)tm{
    NSMutableDictionary *tag = @{FT_KEY_STATUS:[FTBaseInfoHander ft_getFTstatueStr:FTStatusCritical],
    }.mutableCopy;
    //崩溃日志、ANR日志  tag 中 添加 dSYM 中的 UUID 用于符号化解析
    [tag setValue:[FTBaseInfoHander ft_getApplicationUUID] forKey:FT_APPLICATION_UUID];
    FTRecordModel *model = [self getRecordModelWithMeasurement:self.config.source tags:tag field:@{FT_KEY_CONTENT:content} op:FT_TRACK_LOGGING_EXCEPTION netType:FTNetworkingTypeLogging tm:tm];
    [self insertDBWithItemData:model cache:YES];
}
- (void)_loggingArrayInsertDBImmediately{
    dispatch_sync(self.serialQueue, ^{
    [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    });
}
- (FTRecordModel *)getRecordModelWithMeasurement:(NSString *)measurement tags:(NSDictionary *)tags field:(NSDictionary *)field op:(NSString *)op netType:(NSString *)type tm:(long long)tm{
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *fieldDict = field.mutableCopy;
    NSMutableDictionary *tagsDict = [NSMutableDictionary new];
    if (tags) {
        [tagsDict addEntriesFromDictionary:tags];
    }
    //METRICS  mobile_tracker 添加监控项 
    if ([type isEqualToString:FTNetworkingTypeMetrics]) {
        if ([measurement isEqualToString:FT_AUTOTRACK_MEASUREMENT]) {
            NSDictionary *addDict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
            if ([addDict objectForKey:FT_AGENT_TAGS]) {
                [tagsDict addEntriesFromDictionary:[addDict objectForKey:FT_AGENT_TAGS]];
            }
            if ([addDict objectForKey:FT_AGENT_FIELD]) {
                [fieldDict addEntriesFromDictionary:[addDict objectForKey:FT_AGENT_FIELD]];
            }
            [tagsDict addEntriesFromDictionary:[self.presetProperty automaticProperties]];
        }else{
            [tagsDict addEntriesFromDictionary:[self.presetProperty noUUIDProperties]];
        }
    }else if([type isEqualToString:FTNetworkingTypeLogging]){
        [tagsDict addEntriesFromDictionary:[self.presetProperty loggingProperties]];
    }
    NSMutableDictionary *opdata = @{
        FT_AGENT_MEASUREMENT:measurement,
        FT_AGENT_FIELD:fieldDict,
    }.mutableCopy;
    [opdata setValue:tagsDict forKey:FT_AGENT_TAGS];
    NSDictionary *data =@{FT_AGENT_OP:op,
                          FT_AGENT_OPDATA:opdata,
    };
    ZYDebug(@"datas == %@",data);
    model.op = type;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    if (tm&&tm>0) {
        model.tm = tm;
    }
    return model;
}
- (void)insertDBWithItemData:(FTRecordModel *)model cache:(BOOL)cache{
    dispatch_async(self.serialQueue, ^{
        if (cache) {
        [[FTTrackerEventDBTool sharedManger] insertItemToCache:model];
        }else{
        [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
        }
    });
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
- (void)uploadSDKObject{
    NSString *deviceUUID = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    NSString *name = [NSString stringWithFormat:@"%@_%@",deviceUUID,[identifier ft_md5HashToUpper16Bit]];
    NSDictionary *dict = @{FT_KEY_NAME:name,
                           FT_KEY_TAGS:[self.presetProperty objectProperties],
    };
    FTRecordModel *model = [FTRecordModel new];
    model.op = FTNetworkingTypeObject;
    model.data = [FTJSONUtil ft_convertToJsonData:dict];
    [self trackUpload:@[model] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        ZYDebug(@"上报对象数据 statusCode == %d",statusCode);
    }];
}
- (NSString *)sdkTrackVersion{
    id autotrack = objc_getAssociatedObject(self, &FTAutoTrack);
    if (!autotrack) {
        return nil;
    }
    else{
        NSString *invokeMethod = @"sdkTrackVersion";
        SEL versionMethod = NSSelectorFromString(invokeMethod);
        IMP imp = [autotrack methodForSelector:versionMethod];
        NSString* (*func)(id, SEL) = (NSString* (*)(id,SEL))imp;
       return func(autotrack,versionMethod);
    }
}
#pragma mark - 网络与App的生命周期
- (void)setupAppNetworkListeners{
    BOOL reachabilityOk = NO;
    if ((_reachability = SCNetworkReachabilityCreateWithName(NULL, "www.baidu.com")) != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(_reachability, ZYReachabilityCallback, &context)) {
            if (SCNetworkReachabilitySetDispatchQueue(_reachability, self.serialQueue)) {
                reachabilityOk = YES;
            } else {
                SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
            }
        }
    }
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // 应用生命周期通知
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self selector:@selector(applicationWillTerminateNotification:) name:UIApplicationWillTerminateNotification object:nil];
}
- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
            self.net = @"0";//2G/3G/4G
        } else {
            self.net = @"4";//WIFI
        }
         [self uploadFlush];
    } else {
        self.net = @"-1";//未知
    }
    ZYDebug(@"联网状态: %@", [@"-1" isEqualToString:self.net]?@"未知":[@"0" isEqualToString:self.net]?@"移动网络":@"WIFI");
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    @try {
        self.isForeground = NO;
        CFAbsoluteTime endDate = CFAbsoluteTimeGetCurrent();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            float duration = (endDate - self.launchTime);
            if(!self.isForeground){
            [self trackMobileClientTimeCost:duration];
            }
        });
        [self _loggingArrayInsertDBImmediately];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"applicationWillResignActive exception %@",exception);
    }
}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    @try {
        self.isForeground = YES;
        [self uploadFlush];
        self.launchTime = CFAbsoluteTimeGetCurrent();
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationWillTerminateNotification:(NSNotification *)notification{
    @try {
        CFAbsoluteTime endDate = CFAbsoluteTimeGetCurrent();
        float duration = (endDate - self.launchTime);
        [self trackMobileClientTimeCost:duration];
        [self _loggingArrayInsertDBImmediately];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
/**
 * 记录 APP打开一次 使用时间
 */
- (void)trackMobileClientTimeCost:(float)duration{
    [self trackBackground:FT_MOBILE_CLIENT_TIMECOST_MEASUREMENT tags:@{
        FT_AUTO_TRACK_EVENT_ID:[FT_EVENT_ACTIVATED ft_md5HashToUpper32Bit]
    } field:@{
        FT_DURATION_TIME:[NSNumber numberWithInt:duration*1000*1000],
        FT_KEY_EVENT:FT_EVENT_ACTIVATED
    } withTrackOP:FT_MOBILE_CLIENT_TIMECOST_MEASUREMENT];
}
#pragma mark - 上报策略
- (void)uploadFlush{
    dispatch_async(self.serialQueue, ^{
        if (![self.net isEqualToString:@"-1"]) {
            [self.upTool upload];
        }
    });
}
@end
