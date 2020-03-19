//
//  FTMobileAgent.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTMobileAgent.h"
#import <UIKit/UIKit.h>
#import "ZYLog.h"
#import "FTTrackerEventDBTool.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "FTUploadTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import <objc/runtime.h>
#import "FTLocationManager.h"
#import "FTNetMonitorFlow.h"
#import "FTNetworkInfo.h"
#import "FTGPUUsage.h"
#import "FTTrackBean.h"
@interface FTMobileAgent ()
@property (nonatomic, assign) BOOL isForeground;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t timerQueue;
@property (nonatomic, strong) dispatch_queue_t immediateLabel;
@property (nonatomic, copy) NSString *net;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) FTLocationManager *locationManger;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, strong) FTLocationManager *manger;
@property (nonatomic, copy)  NSString *province;
@property (nonatomic, copy)  NSString *city;
@property (nonatomic, assign) int preFlowTime;
@end
@implementation FTMobileAgent

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


+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions{
    NSAssert ((strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0),@"SDK 必须在主线程里进行初始化，否则会引发无法预料的问题（比如丢失 lunch 事件）。");
    if (configOptions.enableRequestSigning) {
        NSAssert((configOptions.akSecret.length!=0 && configOptions.akId.length != 0), @"设置需要进行请求签名 必须要填akId与akSecret");
    }
    if (configOptions.autoTrackEventType != FTAutoTrackTypeNone && configOptions.enableAutoTrack) {
        NSAssert((NSClassFromString(@"FTAutoTrack")), @"开启自动采集需导入FTAutoTrackSDK");
    }
    NSAssert((configOptions.metricsUrl.length!=0 ), @"请设置FT-GateWay metrics 写入地址");
    if (configOptions.enableScreenFlow) {
        NSAssert((configOptions.product.length!=0 ), @"请设置上报流程行为指标集名称 product");
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
    if ([super init]) {
        //基础类型的记录
        if (config) {
            self.config = config;
        }
        NSString *label = [NSString stringWithFormat:@"io.zy.%p", self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        NSString *timerLabel = [NSString stringWithFormat:@"io.zytimer.%p", self];
        self.timerQueue = dispatch_queue_create([timerLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        NSString *immediateLabel = [NSString stringWithFormat:@"io.immediateLabel.%p", self];
        self.immediateLabel = dispatch_queue_create([immediateLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            self.netFlow = [FTNetMonitorFlow new];
            [self startFlushTimer];
        }
        if(self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll){
            self.manger = [[FTLocationManager alloc]init];
            __weak typeof(self) weakSelf = self;
            self.manger.updateLocationBlock = ^(NSString * _Nonnull province, NSString * _Nonnull city, NSError * _Nonnull error) {
              weakSelf.city = city;
              weakSelf.province = province;
            };
            [self.manger startUpdatingLocation];
            
        }
        [self setupAppNetworkListeners];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFlush) name:@"FTUploadNotification" object:nil];
        if (self.config.enableAutoTrack) {
            NSString *invokeMethod = @"startWithConfig:";
            Class track =  NSClassFromString(@"FTAutoTrack");
            if (track) {
                id  autoTrack = [[NSClassFromString(@"FTAutoTrack") alloc]init];
                
                SEL startMethod = NSSelectorFromString(invokeMethod);
                unsigned int methCount = 0;
                Method *meths = class_copyMethodList(track, &methCount);
                BOOL ishas = NO;
                for(int i = 0; i < methCount; i++) {
                    Method meth = meths[i];
                    SEL sel = method_getName(meth);
                    const char *name = sel_getName(sel);
                    NSString *str=[NSString stringWithCString:name encoding:NSUTF8StringEncoding];
                    if ([str isEqualToString:invokeMethod]) {
                        ishas = YES;
                        break;
                    }
                }
                free(meths);
                if (ishas) {
                    IMP imp = [autoTrack methodForSelector:startMethod];
                    void (*func)(id, SEL,id) = (void (*)(id,SEL,id))imp;
                    func(autoTrack,startMethod,self.config);
                }
            }
        }
        self.upTool = [[FTUploadTool alloc]initWithConfig:self.config];
        
    }
    return self;
}

#pragma mark ========== 网络与App的生命周期 ==========
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
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    
    
}
- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
            self.net = @"0";//2G/3G/4G
            [self uploadFlush];
        } else {
            self.net = @"4";//WIFI
            [self uploadFlush];
        }
    } else {
        self.net = @"-1";//未知
    }
    ZYDebug(@"联网状态: %@", [@"-1" isEqualToString:self.net]?@"未知":[@"0" isEqualToString:self.net]?@"移动网络":@"WIFI");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    ZYDebug(@"applicationWillTerminate ");
    
}
- (void)applicationWillResignActive:(NSNotification *)notification {
    @try {
        self.isForeground = NO;
    }
    @catch (NSException *exception) {
        ZYDebug(@"applicationWillResignActive exception %@",exception);
    }
    
}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    @try {
        self.isForeground = YES;
        [self uploadFlush];
        [self startFlushTimer];
    }
    @catch (NSException *exception) {
        ZYDebug(@"applicationDidBecomeActive exception %@",exception);
    }
}
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    ZYDebug(@"applicationDidEnterBackground ");
}
- (void)trackBackgroud:(NSString *)measurement field:(NSDictionary *)field{
    [self trackBackgroud:measurement tags:nil field:field];
}
- (void)trackBackgroud:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field{
    @try {
        NSParameterAssert(measurement);
        NSParameterAssert(field);
        if (measurement == nil || [FTBaseInfoHander removeFrontBackBlank:measurement].length == 0  || field == nil || [field allKeys].count == 0) {
            ZYDebug(@"文件名 事件名不能为空");
            return;
        }
        NSMutableDictionary *opdata =  [NSMutableDictionary dictionaryWithDictionary:@{
            @"measurement":measurement,
            @"field":field
        }];
        NSMutableDictionary *tag = [NSMutableDictionary new];
        if (tags) {
            [tag addEntriesFromDictionary:tags];
        }
        if ([self getMonitorInfoTag].allKeys.count>0) {
            [tag addEntriesFromDictionary:[self getMonitorInfoTag]];
        }
        [opdata addEntriesFromDictionary:@{@"tags":tag}];
        [self insertDBWithOpdata:opdata op:@"cstm"];
        
    }
    @catch (NSException *exception) {
        ZYDebug(@"track measurement tags field exception %@",exception);
    }
}
-(void)trackImmediate:(NSString *)measurement field:(NSDictionary *)field callBack:(void (^)(NSInteger statusCode, id responseObject))callBackStatus{
    [self trackImmediate:measurement tags:nil field:field callBack:^(NSInteger statusCode, id  _Nonnull responseObject) {
        callBackStatus? callBackStatus(statusCode,responseObject):nil;

    }];
}
- (void)trackImmediate:(NSString *)measurement tags:(NSDictionary *)tags field:(NSDictionary *)field callBack:(void (^)(NSInteger statusCode, id responseObject))callBackStatus{
    @try {
        NSParameterAssert(measurement);
        NSParameterAssert(field);
        if (measurement == nil || [FTBaseInfoHander removeFrontBackBlank:measurement].length == 0 || field == nil || [field allKeys].count == 0) {
            ZYDebug(@"文件名 事件名不能为空");
            callBackStatus?callBackStatus(InvalidParamsException,nil):nil;
        }
        FTRecordModel *model = [FTRecordModel new];
        NSMutableDictionary *opdata =  [NSMutableDictionary dictionaryWithDictionary:@{
            @"measurement":measurement,
            @"field":field
        }];
        NSMutableDictionary *tag = [NSMutableDictionary new];
        if (tags) {
            [tag addEntriesFromDictionary:tags];
        }
        if ([self getMonitorInfoTag].allKeys.count>0) {
            [tag addEntriesFromDictionary:[self getMonitorInfoTag]];
        }
        [opdata addEntriesFromDictionary:@{@"tags":tag}];
        NSDictionary *data =@{
            @"op":@"cstm",
            @"opdata":opdata,
        };
        model.data =[FTBaseInfoHander ft_convertToJsonData:data];
        ZYDebug(@"trackImmediateData == %@",data);
        dispatch_async(self.immediateLabel, ^{
            [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, id responseObject) {
                callBackStatus? callBackStatus(statusCode,responseObject):nil;
            }];
        });
    }
    @catch (NSException *exception) {
        ZYDebug(@"track measurement tags field exception %@",exception);
    }
}
- (void)trackImmediateList:(NSArray <FTTrackBean *>*)trackList callBack:(void (^)(NSInteger statusCode, id responseObject))callBackStatus{
    NSParameterAssert(trackList);
    __block NSMutableArray *list = [NSMutableArray new];
    [trackList enumerateObjectsUsingBlock:^(FTTrackBean * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.measurement.length>0 && obj.field.allKeys.count>0) {
            FTRecordModel *model = [FTRecordModel new];
            NSMutableDictionary *opdata =  [NSMutableDictionary dictionaryWithDictionary:@{
                @"measurement":obj.measurement,
                @"field":obj.field
            }];
            NSMutableDictionary *tag = [NSMutableDictionary new];
            if (obj.tags) {
                [tag addEntriesFromDictionary:obj.tags];
            }
            if ([self getMonitorInfoTag].allKeys.count>0) {
                [tag addEntriesFromDictionary:[self getMonitorInfoTag]];
            }
            [opdata addEntriesFromDictionary:@{@"tags":tag}];
            NSDictionary *data =@{
                @"op":@"cstm",
                @"opdata":opdata,
            };
            model.data =[FTBaseInfoHander ft_convertToJsonData:data];
            if(obj.timeMillis && obj.timeMillis>1000000000000){
            model.tm = obj.timeMillis*1000;
            }else{
            model.tm = [FTBaseInfoHander ft_getCurrentTimestamp];
            }
            [list addObject:model];
        }else{
          ZYLog(@"传入的第 %d 个数据格式有误",idx);
        }
    }];
    if (list.count>0) {
        dispatch_async(self.immediateLabel, ^{
            [self.upTool trackImmediateList:list callBack:^(NSInteger statusCode, id responseObject) {
                callBackStatus? callBackStatus(statusCode,responseObject):nil;
            }];
        });
    }else{
        ZYLog(@"传入的数据格式有误");
        callBackStatus?callBackStatus(InvalidParamsException,nil):nil;
    }
    
}
-(void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(NSString *)parent duration:(long)duration{
    [self flowTrack:product traceId:traceId name:name parent:parent tags:nil duration:duration field:nil];
}

- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(nonnull NSString *)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration field:(nullable NSDictionary *)field{
    @try {
        NSParameterAssert(product);
        NSParameterAssert(traceId);
        NSParameterAssert(name);
        NSParameterAssert(duration);
        if ([FTBaseInfoHander removeFrontBackBlank:product].length == 0 ||  [FTBaseInfoHander removeFrontBackBlank:traceId].length== 0||[FTBaseInfoHander removeFrontBackBlank:name].length==0) {
            ZYDebug(@"产品名、跟踪ID、name、parent 不能为空");
            return;
        }
        if (![self verifyProductStr:product]) {
            return;
        }
        __block NSString *durationStr = [NSString stringWithFormat:@"%ld",duration];
        NSMutableDictionary *opdata = [@{@"product":product,
                                         @"traceId":traceId,
                                         @"name":name,
                                         @"duration":durationStr
        } mutableCopy];
        if (parent.length>0) {
            [opdata setObject:parent forKey:@"parent"];
        }
        if (field.allKeys.count>0) {
            [opdata setObject:field forKey:@"field"];
        }
        NSMutableDictionary *tag = [NSMutableDictionary new];
        if (tags) {
            [tag addEntriesFromDictionary:tags];
        }
        [opdata addEntriesFromDictionary:@{@"tags":tag}];
        [self insertDBWithOpdata:opdata op:@"flowcstm"];
        
    } @catch (NSException *exception) {
        ZYDebug(@"flowTrack product traceId name exception %@",exception);
    }
    
}
- (void)insertDBWithOpdata:(NSDictionary *)dict op:(NSString *)op{
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *opdata = [dict mutableCopy];
    NSMutableDictionary *tag = [NSMutableDictionary new];
    if ([opdata.allKeys containsObject:@"tags"]) {
        [tag addEntriesFromDictionary:opdata[@"tags"]];
    }
    if ([self getMonitorInfoTag].allKeys.count>0) {
        [tag addEntriesFromDictionary:[self getMonitorInfoTag]];
    }
    [opdata setValue:tag forKey:@"tags"];
    NSDictionary *data =@{@"op":op,
                          @"opdata":opdata,
    };
    ZYDebug(@"data == %@",data);
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
}
// 验证指标集名称是否符合要求
- (BOOL)verifyProductStr:(NSString *)product{
    BOOL result= NO;
    @try {
        NSString *regex = @"^[A-Za-z0-9_\\-]{0,35}+$";//$flow_
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
        // 字符串判断，然后BOOL值
        result = [predicate evaluateWithObject:product];
        ZYDebug(@"result : %@",result ? @"指标集命名正确" : @"验证失败");
    }@catch (NSException *exception) {
        ZYDebug(@"verifyProductStr %@",exception);
    }
    return result;
}
- (NSDictionary *)getMonitorInfoTag{
    NSMutableDictionary *tag = [[NSMutableDictionary alloc]init];
    if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag setObject:[NSString stringWithFormat:@"%ld",[FTBaseInfoHander ft_cpuUsage]] forKey:@"cpu_use"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag setObject:[FTBaseInfoHander ft_usedMemory] forKey:@"memory_use"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        __block NSString *network_type,*network_strength;
        if ([NSThread isMainThread]) { // do something in main thread } else { // do something in other
            network_type =[FTNetworkInfo getNetworkType];
            network_strength = [NSString stringWithFormat:@"%d",[FTNetworkInfo getNetSignalStrength]];
        }else{
            dispatch_sync(dispatch_get_main_queue(), ^{
                network_type =[FTNetworkInfo getNetworkType];
                network_strength = [NSString stringWithFormat:@"%d",[FTNetworkInfo getNetSignalStrength]];
            });
        }
        [tag setObject:network_type forKey:@"network_type"];
        [tag setObject:network_strength forKey:@"network_strength"];
        [tag setObject:self.netFlow.flow forKey:@"network_speed"];
        [tag setObject:[NSNumber numberWithBool:[FTNetworkInfo getProxyStatus]] forKey:@"network_proxy"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag setObject:[FTBaseInfoHander ft_getBatteryUse] forKey:@"battery_use"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeGpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
        NSString *usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
        [tag setObject:usage forKey:@"gpu_rate"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        if (self.city && self.city.length>0 ) {
            [tag setObject:self.city forKey:@"city"];
        }
        if (self.province && self.province.length>0) {
            [tag setObject:self.province forKey:@"province"];
        }
    }
    return tag;
}
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
#pragma mark ========== 实时网速 ==========
// 启动获取实时网络定时器
- (void)startFlushTimer {
    if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [self stopFlushTimer];
        dispatch_async(self.timerQueue, ^{
            [self.netFlow startMonitor];
        });
    }
}

// 关闭获取实时网络定时器
- (void)stopFlushTimer {
    if (!_netFlow) {
        return;
    }
    dispatch_async(self.timerQueue, ^{
        [self.netFlow stopMonitor];
    });
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
