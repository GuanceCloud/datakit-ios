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
@interface FTMobileAgent ()
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t concurrentLabel;
@property (nonatomic, copy)   NSString *net;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, assign) CFAbsoluteTime launchTime;
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) NSDate *lastAddDBDate;
@property (nonatomic, strong) FTTrack *track;
@property (nonatomic, assign) BOOL running; //正在运行
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
    NSAssert((configOptions.datawayUrl.length!=0 ), @"请设置FT-GateWay metrics 写入地址");
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
            _appRelaunched = NO;
            _running = NO;
            self.launchTime = CFAbsoluteTimeGetCurrent();
            [FTLog enableLog:config.enableLog];
            self.track = [[FTTrack alloc]init];
            [[FTMonitorManager sharedInstance] setMobileConfig:self.config];
            NSString *label = [NSString stringWithFormat:@"io.zy.%p", self];
            self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
            NSString *concurrentLabel = [NSString stringWithFormat:@"io.concurrentLabel.%p", self];
            self.concurrentLabel = dispatch_queue_create([concurrentLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
            [self setUpListeners];
            self.presetProperty = [[FTPresetProperty alloc]initWithAppid:self.config.appid version:self.config.version env:self.config.env];
            [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self];
            self.upTool = [[FTUploadTool alloc]initWithConfig:self.config];
        }
    }@catch(NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
    return self;
}
-(void)resetConfig:(FTMobileConfig *)config{
    [FTLog enableLog:config.enableLog];
    [[FTMonitorManager sharedInstance] setMobileConfig:config];
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
                    NSString *content = [obj valueForKey:@"content"];
                    NSNumber *tm = [obj valueForKey:@"tm"];
                    if (content && content.length>0 && tm) {
                     
                    }else{
                        ZYLog(@"extension 采集数据格式有误。");
                    }
                }];
            }
        };
        dispatch_async(self.serialQueue, block);
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)track:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self track:type tags:tags fields:fields tm:[[NSDate date] ft_dateTimestamp]];
}
- (void)track:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (![type isKindOfClass:NSString.class] || type.length == 0) {
        return;
    }
    NSMutableDictionary *baseTags =[NSMutableDictionary dictionaryWithDictionary:[self.presetProperty getPropertyWithType:type]];
    if([type isEqualToString:@"rum_app_view"]){
        if (self.config.monitorInfoType & FTMonitorInfoTypeFPS) {

        }
    }
    if (tags) {
        [baseTags addEntriesFromDictionary:tags];
    }
    [self insertDBWithItemData:[self getModelWithMeasurement:type op:FT_DATA_TYPE_INFLUXDB tags:baseTags field:fields tm:[[NSDate date] ft_dateTimestamp]] crash:NO];
}
- (void)trackES:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    if (![type isKindOfClass:NSString.class] || type.length == 0 || terminal.length == 0) {
           return;
       }
    BOOL crash = NO;
    NSMutableDictionary *baseTags =[NSMutableDictionary dictionaryWithDictionary:[self.presetProperty getESPropertyWithType:type terminal:terminal]];
    if ([type isEqualToString:@"crash"]) {
        crash = YES;
       NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
        baseTags[@"crash_situation"] = _running?@"run":@"startup";
        baseTags[@"locale"] = preferredLanguage;
    }
    if (tags) {
        [baseTags addEntriesFromDictionary:tags];
    }
    [self insertDBWithItemData:[self getModelWithMeasurement:self.config.source op:FT_DATA_TYPE_ES tags:baseTags field:fields tm:[[NSDate date] ft_dateTimestamp]] crash:crash];
}
-(void)trackStartWithViewLoadTime:(CFTimeInterval)time{
    self.running = YES;
    if ([self judgeIsTraceSampling]) {
        NSString *startType = _appRelaunched?@"hot":@"cold";
        NSDictionary *fields = @{
            @"app_startup_duration":[NSNumber numberWithInt:(time-self.launchTime)*1000*1000],
            @"app_startup_type":startType,
        };
        [self track:FT_RUM_APP_STARTUP tags:nil fields:fields];
    }
    _appRelaunched = YES;

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
- (FTRecordModel *)getModelWithMeasurement:(NSString *)measurement op:(NSString *)op tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *fieldDict = field.mutableCopy;
    NSMutableDictionary *tagsDict = [NSMutableDictionary new];
    if (tags) {
        [tagsDict addEntriesFromDictionary:tags];
    }
    NSMutableDictionary *opdata = @{
        FT_AGENT_MEASUREMENT:measurement,
        FT_AGENT_FIELD:fieldDict,
    }.mutableCopy;
    [opdata setValue:tagsDict forKey:FT_AGENT_TAGS];
    NSDictionary *data =@{
                          FT_AGENT_OPDATA:opdata,
    };
    ZYDebug(@"datas == %@",data);
    model.op = op;
    model.data =[FTJSONUtil ft_convertToJsonData:data];
    if (tm&&tm>0) {
        model.tm = tm;
    }
    return model;
}

- (void)insertDBWithItemData:(FTRecordModel *)model crash:(BOOL)crash{
    
    [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    if (!crash) {
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
}
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
#pragma mark - 网络与App的生命周期
- (void)setUpListeners{
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
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
}
- (void)applicationWillEnterForeground:(NSNotification *)notification{
    if (_appRelaunched){
         self.launchTime = CFAbsoluteTimeGetCurrent();
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
            [self trackStartWithViewLoadTime:CFAbsoluteTimeGetCurrent()];
        }
        [[FTMonitorManager sharedInstance] startMonitorFPS];
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationWillResignActive:(NSNotification *)notification {
    @try {
       _applicationWillResignActive = YES;
       [[FTMonitorManager sharedInstance] stopMonitorFPS];
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

    } @catch (NSException *exception) {
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
- (void)resetInstance{
    [[FTMonitorManager sharedInstance] resetInstance];
    [[FTLocationManager sharedInstance] resetInstance];
    [[FTUncaughtExceptionHandler sharedHandler] removeftSDKInstance:self];
    if (_reachability) {
        SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
    }
    self.config = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.upTool = nil;
    onceToken = 0;
    sharedInstance =nil;
}
@end
