//
//  ZYInterceptor.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTMobileAgent.h"
#import <UIKit/UIKit.h>
#import "ZYLog.h"
#import "ZYTrackerEventDBTool.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "ZYUploadTool.h"
#import "RecordModel.h"
#import "ZYBaseInfoHander.h"
#import <objc/runtime.h>
#import "FTLocationManager.h"
@interface FTMobileAgent ()
@property (nonatomic) BOOL isForeground;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSString *net;
//@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) ZYUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) FTLocationManager *locationManger;
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
        [[ZYTrackerEventDBTool sharedManger] createTable];
        [self setupAppNetworkListeners];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFlush) name:@"FTUploadNotification" object:nil];
        if (self.config.enableAutoTrack) {
        NSString *invokeMethod = @"startWithConfig:";
        Class track =  NSClassFromString(@"FTAutoTrack");
        if (track) {
            id  aaa = [[NSClassFromString(@"FTAutoTrack") alloc]init];

            SEL a = NSSelectorFromString(invokeMethod);
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
            IMP imp = [aaa methodForSelector:a];
            void (*func)(id, SEL,id) = (void (*)(id,SEL,id))imp;
               func(aaa,a,self.config);
            }
        }
        }
        self.upTool = [[ZYUploadTool alloc]initWithConfig:self.config];
       
    }
    return self;
}
- (void)dealMonitorInfoType{
    if (self.config.monitorInfoType & FTMonitorInfoTypeLocation) {
        self.locationManger = [[FTLocationManager alloc]init];
        self.locationManger.updateLocationBlock = ^(NSString * _Nonnull location, NSError * _Nonnull error) {
            
        };
        [self.locationManger startUpdatingLocation];
    }
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
        } else {
            self.net = @"4";//WIFI
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
      }
      @catch (NSException *exception) {
       ZYDebug(@"applicationDidBecomeActive exception %@",exception);
      }
}
- (void)applicationDidEnterBackground:(NSNotification *)notification {
       ZYDebug(@"applicationDidEnterBackground ");
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
        if (tags) {
            [opdata addEntriesFromDictionary:@{@"tags":tags}];
        }
     RecordModel *model = [RecordModel new];
     NSDictionary *data =@{
                            @"op":@"cstm",
                            @"opdata":opdata,
                            };
        model.data =[ZYBaseInfoHander convertToJsonData:data];
        [[ZYTrackerEventDBTool sharedManger] insertItemWithItemData:model];
        ZYDebug(@"data == %@",data);
    }
      @catch (NSException *exception) {
        ZYDebug(@"track field tags values exception %@",exception);
      }
}

- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(NSDictionary *)exts{
    if (name.length == 0 || Id.length == 0) {
        ZYDebug(@"绑定用户失败！！！ 用户名和用户Id 不能为空");
        return;
    }
    [[ZYTrackerEventDBTool sharedManger] insertUserDataWithName:name Id:Id exts:exts];
}
- (void)logout{
    NSUserDefaults *defatluts = [NSUserDefaults standardUserDefaults];
    [defatluts removeObjectForKey:FT_SESSIONID];
    [defatluts synchronize];
}
#pragma mark - 上报策略
//// 启动事件发送定时器
//- (void)startFlushTimer {
//    [self stopFlushTimer];
//    dispatch_async(dispatch_get_main_queue(), ^{
//            self.timer = [NSTimer scheduledTimerWithTimeInterval:10.0
//                                                          target:self
//                                                        selector:@selector(flush)
//                                                        userInfo:nil
//                                                         repeats:YES];
//
//            ZYDebug(@"启动事件发送定时器");
//    });
//}

//// 关闭事件发送定时器
//- (void)stopFlushTimer {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        if (self.timer) {
//            [self.timer invalidate];
//            ZYDebug(@"关闭事件发送定时器");
//        }
//        self.timer = nil;
//    });
//}
- (void)uploadFlush{
    
    dispatch_async(self.serialQueue, ^{
        if (![self.net isEqualToString:@"-1"]) {
          [self.upTool upload];
        }
       });
}

@end
