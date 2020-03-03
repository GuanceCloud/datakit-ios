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
#import "FTLocationManager.h"
#import "FTGPUUsage.h"
@interface FTMobileAgent ()
@property (nonatomic, assign) BOOL isForeground;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t timerQueue;
@property (nonatomic, copy) NSString *net;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) FTLocationManager *locationManger;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, strong) FTLocationManager *manger;
@property (nonatomic, copy)  NSString *location;
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
     [FTMobileAgent sharedInstance];
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
       
        if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            self.netFlow = [FTNetMonitorFlow new];
            [self startFlushTimer];
        }
        if(self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll){
            self.manger = [[FTLocationManager alloc]init];
            __weak typeof(self) weakSelf = self;
             self.manger.updateLocationBlock = ^(NSString * _Nonnull location, NSError * _Nonnull error) {
                 weakSelf.location = location;
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
    [self stopFlushTimer];
}
- (void)track:(NSString *)field  values:(NSDictionary *)values{
    [self track:field tags:nil values:values];
}
- (void)track:(NSString *)field tags:(nullable NSDictionary*)tags values:(NSDictionary *)values{
    @try {
        if (field == nil || [field length] == 0 || values == nil || [values allKeys].count == 0) {
            ZYDebug(@"文件名 事件名不能为空");
            return;
        }
     NSMutableDictionary *opdata =  [NSMutableDictionary dictionaryWithDictionary:@{
       @"field":field,
       @"values":values
     }];
        NSMutableDictionary *tag = [NSMutableDictionary new];
        if (tags) {
            [tag addEntriesFromDictionary:tags];
        }
        if ([self getMonitorInfoTag].allKeys.count>0) {
            [tag addEntriesFromDictionary:[self getMonitorInfoTag]];
        }
        [opdata addEntriesFromDictionary:@{@"tags":tag}];
        FTRecordModel *model = [FTRecordModel new];
        NSDictionary *data =@{
                            @"opdata":opdata,
                            };
        model.data =[FTBaseInfoHander ft_convertToJsonData:data];
        [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
        ZYDebug(@"data == %@",data);
    }
      @catch (NSException *exception) {
        ZYDebug(@"track field tags values exception %@",exception);
      }
}
-(void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(NSString *)parent duration:(long)duration{
    [self flowTrack:product traceId:traceId name:name parent:parent tags:nil duration:duration values:nil];
}

- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(nonnull NSString *)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration values:(nullable NSDictionary *)values{
    @try {
        if (product == nil || [product length] == 0 || traceId == nil || [traceId length] == 0||name ==nil||[name length]==0) {
                ZYDebug(@"产品名、跟踪ID、name、parent 不能为空");
                return;
        }
        if (![self verifyProductStr:product]) {
            return;
        }
        FTRecordModel *model = [FTRecordModel new];
       __block NSString *durationStr = [NSString stringWithFormat:@"%ld",duration];
        if (values.allKeys.count>0) {
            [values enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if (obj!=nil && ![obj isKindOfClass:NSNull.class]) {
                    durationStr =[durationStr stringByAppendingFormat:@",%@=\"%@\"",key,obj];
                }
            }];
        }
           NSMutableDictionary *opdata = [@{@"product":product,
                                    @"traceId":traceId,
                                    @"name":name,
                                    @"duration":durationStr
           } mutableCopy];
           if (parent.length>0) {
               [opdata setObject:parent forKey:@"parent"];
           }
            NSMutableDictionary *tag = [NSMutableDictionary new];
            if (tags) {
                [tag addEntriesFromDictionary:tags];
            }
           if ([self getMonitorInfoTag].allKeys.count>0) {
                [tag addEntriesFromDictionary:[self getMonitorInfoTag]];
            }
           NSDictionary *data =@{
                               @"opdata":opdata,
                               };
           model.data =[FTBaseInfoHander ft_convertToJsonData:data];
           [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    } @catch (NSException *exception) {
         ZYDebug(@"flowTrack product traceId name exception %@",exception);
    }

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
          }
          if (self.config.monitorInfoType & FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
              [tag setObject:[FTBaseInfoHander ft_getBatteryUse] forKey:@"battery_use"];
          }
          if (self.config.monitorInfoType & FTMonitorInfoTypeGpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
              NSString *usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
              [tag setObject:usage forKey:@"gpu_rate"];
          }
        if (self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            if (self.location && self.location.length>0) {
                [tag setObject:self.location forKey:@"location_city"];

            }
        }
    return tag;
}
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(NSDictionary *)exts{
    if (name.length == 0 || Id.length == 0) {
        ZYDebug(@"绑定用户失败！！！ 用户名和用户Id 不能为空");
        return;
    }
    [[FTTrackerEventDBTool sharedManger] insertUserDataWithName:name Id:Id exts:exts];
}
- (void)logout{
    NSUserDefaults *defatluts = [NSUserDefaults standardUserDefaults];
    [defatluts removeObjectForKey:FT_SESSIONID];
    [defatluts synchronize];
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
