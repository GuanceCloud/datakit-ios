//
//  FTMobileAgent.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

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
@interface FTMobileAgent ()
@property (nonatomic, assign) BOOL isForeground;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t concurrentLabel;
@property (nonatomic, copy) NSString *net;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) NSMutableArray *loggingArray;
@property (nonatomic, strong) dispatch_queue_t serialLoggingQueue;
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
            NSString *label = [NSString stringWithFormat:@"io.zy.%p", self];
            self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
            NSString *concurrentLabel = [NSString stringWithFormat:@"io.concurrentLabel.%p", self];
            self.concurrentLabel = dispatch_queue_create([concurrentLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
            [self setupAppNetworkListeners];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFlush) name:@"FTUploadNotification" object:nil];
            if (self.config.enableAutoTrack) {
                [self startAutoTrack];
            }
            [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self];
            self.upTool = [[FTUploadTool alloc]initWithConfig:self.config];
            [self uploadSDKObject];
            self.serialLoggingQueue =dispatch_queue_create("ft.logging", DISPATCH_QUEUE_SERIAL);
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
    config.sdkTrackVersion = self.config.sdkTrackVersion;
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
-(NSMutableArray *)loggingArray{
    if (!_loggingArray) {
        _loggingArray = [NSMutableArray new];
    }
    return _loggingArray;
}
#pragma mark ========== publick method ==========
- (void)trackBackground:(NSString *)measurement field:(NSDictionary *)field{
    [self trackBackground:measurement tags:nil field:field withTrackType:FTTrackTypeCode];
}
- (void)trackBackground:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field{
    [self trackBackground:measurement tags:tags field:field withTrackType:FTTrackTypeCode];
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
-(void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(NSString *)parent duration:(long)duration{
    [self flowTrack:product traceId:traceId name:name parent:parent tags:nil duration:duration field:nil withTrackType:FTTrackTypeCode];
}

- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(nonnull NSString *)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration field:(nullable NSDictionary *)field{
    NSParameterAssert(product);
    NSParameterAssert(traceId);
    NSParameterAssert(name);
    [self flowTrack:product traceId:traceId name:name parent:parent tags:tags duration:duration field:field withTrackType:FTTrackTypeCode];
}
#pragma mark - logging
-(void)logging:(NSString *)content status:(FTStatus)status{
    NSParameterAssert(content);
    @try {
        [self _loggingBackgroundInsertWithOP:@"logging" status:[FTBaseInfoHander ft_getFTstatueStr:status] content:content tm:[[NSDate date] ft_dateTimestamp]];
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
    [[FTMonitorManager sharedInstance] setFlushInterval:interval];
}
-(void)startMonitorFlush{
    [[FTMonitorManager sharedInstance] startFlush];
}
-(void)startMonitorFlushWithInterval:(NSInteger)interval monitorType:(FTMonitorInfoType)type{
    _config.monitorInfoType = type;
    [[FTMonitorManager sharedInstance] setMonitorType:type];
    [[FTMonitorManager sharedInstance] setFlushInterval:interval];
    [[FTMonitorManager sharedInstance] startFlush];
}
-(void)stopMonitorFlush{
    [[FTMonitorManager sharedInstance] stopFlush];
}
#pragma mark ========== private method==========
#pragma mark - 数据拼接 存储数据库
- (void)trackBackground:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field withTrackType:(FTTrackType)trackType{
    NSParameterAssert(measurement);
    NSParameterAssert(field);
    @try {
        if (measurement == nil || [measurement ft_removeFrontBackBlank].length == 0  || field == nil || [field allKeys].count == 0) {
            ZYErrorLog(@"文件名 事件名不能为空");
            return;
        }
        NSString *op;
        if (trackType == FTTrackTypeCode) {
            op = FT_TRACK_OP_CUSTOM;
        }else{
            op = [field valueForKey:FT_AUTO_TRACK_EVENT];
        }
        FTRecordModel *model = [self getRecordModelWithMeasurement:measurement tags:tags field:field op:op netType:FTNetworkingTypeMetrics tm:0];
        [self insertDBWithItemData:model];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration field:(nullable NSDictionary *)field withTrackType:(FTTrackType)trackType{
    @try {
        NSString *op,*productStr;
        if(trackType == FTTrackTypeCode){
            if ([product ft_removeFrontBackBlank].length == 0 || [traceId ft_removeFrontBackBlank].length== 0||[name ft_removeFrontBackBlank].length==0) {
                ZYErrorLog(@"产品名、跟踪ID、name、parent 不能为空");
                return;
            }
            if (![[NSString stringWithFormat:@"flow_%@",product] ft_verifyProductStr]) {
                return;
            }
            productStr =[NSString stringWithFormat:@"__flow_%@",product];
            op = FT_TRACK_OP_FLOWCUSTOM;
        }else{
            productStr = product;
            op = FT_AUTO_TRACK_OP_VIEW;
        }
        NSMutableDictionary *fieldDict = @{FT_KEY_DURATION:[NSNumber numberWithLong:duration]}.mutableCopy;
        NSMutableDictionary *tagsDict =@{FT_FLOW_TRACEID:traceId,
                                         FT_KEY_NAME:name,
        }.mutableCopy;
        
        [tagsDict setValue:parent forKey:FT_FLOW_PARENT];
        if (field.allKeys.count>0) {
            [fieldDict addEntriesFromDictionary:field];
        }
        if (tags) {
            [tagsDict addEntriesFromDictionary:tags];
        }
        FTRecordModel *model = [self getRecordModelWithMeasurement:[NSString stringWithFormat:@"%@",productStr] tags:tagsDict field:fieldDict op:op netType:FTNetworkingTypeMetrics tm:0];
        [self insertDBWithItemData:model];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
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
                                 FT_KEY_SERVICENAME:self.config.traceServiceName,
                                 FT_COMMON_PROPERTY_DEVICE_UUID:[[UIDevice currentDevice] identifierForVendor].UUIDString,
                                 FT_COMMON_PROPERTY_APPLICATION_IDENTIFIER:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
                                 FT_KEY_ENV:self.config.env,
    }.mutableCopy;
    if (tags) {
        [tag addEntriesFromDictionary:tags];
    }
    NSMutableDictionary *filedDict = @{FT_KEY_CONTENT:content}.mutableCopy;
    if (field) {
        [filedDict addEntriesFromDictionary:field];
    }
    FTRecordModel *model = [self getRecordModelWithMeasurement:self.config.source tags:tag field:filedDict op:op netType:FTNetworkingTypeLogging tm:tm];
    if([op isEqualToString:@"logging"]){
        [self insertDBWithItemData:model];
    }else{
    [self insertDBArrayWithItemData:model];
    }
}
- (void)_loggingExceptionInsertWithContent:(NSString *)content tm:(long long)tm{
    if (self.config.enableTrackAppCrash) {
        NSMutableDictionary *tag = @{FT_KEY_STATUS:[FTBaseInfoHander ft_getFTstatueStr:FTStatusCritical],
                                     FT_KEY_SERVICENAME:self.config.traceServiceName,
                                     FT_COMMON_PROPERTY_DEVICE_UUID:[[UIDevice currentDevice] identifierForVendor].UUIDString,
                                     FT_COMMON_PROPERTY_APPLICATION_IDENTIFIER:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
                                     FT_KEY_ENV:self.config.env,
        }.mutableCopy;
        
        NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        NSString *app_version_name = [NSString stringWithFormat:@"%@(%@)",version,build];
        [tag setValue:app_version_name forKey:FT_APP_VERSION_NAME];
        FTRecordModel *model = [self getRecordModelWithMeasurement:self.config.source tags:tag field:@{FT_KEY_CONTENT:content} op:FT_TRACK_LOGGING_EXCEPTION netType:FTNetworkingTypeLogging tm:tm];
        [self.loggingArray addObject:model];
    }
    [self _loggingArrayInsertDBImmediately];
}
- (void)_loggingArrayInsertDBImmediately{
    dispatch_sync(self.serialLoggingQueue, ^{
        if (self.loggingArray.count>0) {
            [[FTTrackerEventDBTool sharedManger] insertItemWithItemDatas:self.loggingArray];
            self.loggingArray = nil;
        }
    });
}
- (FTRecordModel *)getRecordModelWithMeasurement:(NSString *)measurement tags:(NSDictionary *)tags field:(NSDictionary *)field op:(NSString *)op netType:(NSString *)type tm:(long long)tm{
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *fieldDict = field.mutableCopy;
    NSMutableDictionary *tagsDict = [NSMutableDictionary new];
    if (tags) {
        [tagsDict addEntriesFromDictionary:tags];
    }
    //METRICS 中流程图不添加监控项
    if (![op isEqualToString:FT_TRACK_OP_FLOWCUSTOM] && ![op isEqualToString:FT_AUTO_TRACK_OP_VIEW] && [type isEqualToString:FTNetworkingTypeMetrics]) {
        NSDictionary *addDict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
        if ([addDict objectForKey:FT_AGENT_TAGS]) {
            [tagsDict addEntriesFromDictionary:[addDict objectForKey:FT_AGENT_TAGS]];
        }
        if ([addDict objectForKey:FT_AGENT_FIELD]) {
            [fieldDict addEntriesFromDictionary:[addDict objectForKey:FT_AGENT_FIELD]];
        }
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
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    if (tm&&tm>0) {
        model.tm = tm;
    }
    return model;
}
- (void)insertDBArrayWithItemData:(FTRecordModel *)model{
    dispatch_async(self.serialLoggingQueue, ^{
        [self.loggingArray addObject:model];
        if (self.loggingArray.count>20) {
            NSArray *array = [self.loggingArray subarrayWithRange:NSMakeRange(0, 20)];
            [[FTTrackerEventDBTool sharedManger] insertItemWithItemDatas:array];
            [self.loggingArray removeObjectsInArray:array];
        }
    });
}
- (void)insertDBWithItemData:(FTRecordModel *)model{
    dispatch_async(self.concurrentLabel, ^{
     [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    });
}
- (void)uploadSDKObject{
    NSString *deviceUUID = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    NSString *name = [NSString stringWithFormat:@"%@_%@",deviceUUID,[identifier ft_md5HashToUpper16Bit]];
    NSDictionary *tag = @{FT_KEY_CLASS:FT_DEFAULT_CLASS,
                          FT_COMMON_PROPERTY_DEVICE_UUID:deviceUUID,
    };
    NSDictionary *dict = @{FT_KEY_NAME:name,
                           FT_KEY_TAGS:tag,
                           FT_AGENT_OP:FTNetworkingTypeObject
    };
    FTRecordModel *model = [FTRecordModel new];
    model.op = FTNetworkingTypeObject;
    model.data = [FTBaseInfoHander ft_convertToJsonData:dict];
    [self trackUpload:@[model] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        ZYDebug(@"上报对象数据 statusCode == %d",statusCode);
    }];
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
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
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
