//
//  FTGlobalRumManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTGlobalRumManager.h"
#import "FTLog+Private.h"
#if !TARGET_OS_TV
#import "FTWKWebViewHandler.h"
#import "FTWKWebViewJavascriptBridge.h"
#endif
#import "FTLongTaskManager.h"
#import "FTJSONUtil.h"
#import "FTTrack.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTAppLaunchTracker.h"
#import "FTTracer.h"
#import "FTSessionTaskHandler.h"
#import "FTURLSessionInterceptor.h"
#import "FTMobileAgent+Private.h"
#import "FTRUMMonitor.h"
#import "FTExternalDataManager+Private.h"
#import "FTEnumConstant.h"
#import "FTConstants.h"
#import "FTThreadDispatchManager.h"
#import "FTBaseInfoHandler.h"
#import "FTCrashMonitor.h"
#import "FTFatalErrorContext.h"
@interface FTGlobalRumManager ()<FTRunloopDetectorDelegate,FTAppLifeCycleDelegate,FTAppLaunchDataDelegate>
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, strong) FTLongTaskManager *longTaskManager;
@end
#if !TARGET_OS_TV
@interface FTGlobalRumManager()<FTWKWebViewRumDelegate>
@property (nonatomic, strong) FTWKWebViewJavascriptBridge *jsBridge;
@end
#endif
@implementation FTGlobalRumManager
static FTGlobalRumManager *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig writer:(id<FTRUMDataWriteProtocol>)writer{
    _rumConfig = rumConfig;
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.monitor = [[FTRUMMonitor alloc]initWithMonitorType:(DeviceMetricsMonitorType)rumConfig.deviceMetricsMonitorType frequency:(MonitorFrequency)rumConfig.monitorFrequency];
    dependencies.writer = writer;
    dependencies.sampleRate = rumConfig.samplerate;
    dependencies.enableResourceHostIP = rumConfig.enableResourceHostIP;
    dependencies.errorMonitorType = (ErrorMonitorType)rumConfig.errorMonitorType;
    dependencies.fatalErrorContext = [FTFatalErrorContext new];
    self.dependencies = dependencies;
    self.rumManager = [[FTRUMManager alloc]initWithRumDependencies:self.dependencies];
    [[FTTrack sharedInstance]startWithTrackView:rumConfig.enableTraceUserView action:rumConfig.enableTraceUserAction];
    [FTTrack sharedInstance].addRumDatasDelegate = self.rumManager;
    if(rumConfig.enableTraceUserAction){
        self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    }
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    if(rumConfig.enableTrackAppCrash){
        [[FTCrashMonitor shared] addErrorDataDelegate:self.rumManager];
    }
    //采集view、resource、jsBridge
    if (rumConfig.enableTrackAppANR||rumConfig.enableTrackAppFreeze) {
        _longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self enableTrackAppANR:rumConfig.enableTrackAppANR enableTrackAppFreeze:rumConfig.enableTrackAppFreeze                                        freezeDurationMs:rumConfig.freezeDurationMs];
    }
#if !TARGET_OS_TV
    [FTWKWebViewHandler sharedInstance].rumTrackDelegate = self;
#endif
    [FTExternalDataManager sharedManager].delegate = self.rumManager;
}
#pragma mark ========== jsBridge ==========
#if !TARGET_OS_TV
-(void)ftAddScriptMessageHandlerWithWebView:(WKWebView *)webView{
    if (![webView isKindOfClass:[WKWebView class]]) {
        return;
    }
    self.jsBridge = [FTWKWebViewJavascriptBridge bridgeForWebView:webView];
    [self.jsBridge registerHandler:@"sendEvent" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self dealReceiveScriptMessage:data callBack:responseCallback];
    }];
}
- (void)dealReceiveScriptMessage:(id )message callBack:(WVJBResponseCallback)callBack{
    @try {
        NSDictionary *messageDic = [message isKindOfClass:NSDictionary.class]?message:[FTJSONUtil dictionaryWithJsonString:message];
        
        if (![messageDic isKindOfClass:[NSDictionary class]]) {
            FTInnerLogError(@"Message body is formatted failure from JS SDK");
            return;
        }
        NSString *name = messageDic[@"name"];
        if ([name isEqualToString:@"rum"]||[name isEqualToString:@"log"]) {
            NSDictionary *data = messageDic[@"data"];
            NSString *measurement = data[FT_MEASUREMENT];
            NSMutableDictionary *tags = [data[FT_TAGS] mutableCopy];
            NSString *version = [tags valueForKey:FT_SDK_VERSION];
            if(version&&version.length>0){
                NSString *info = [FTJSONUtil convertToJsonDataWithObject:@{@"web":version}];
                [tags setValue:info forKey:FT_SDK_PKG_INFO];
            }
            NSDictionary *fields = data[FT_FIELDS];
            long long time = [data[@"time"] longLongValue];
            long long fixTime = time * 1000000;
            // web 端 time 数据以毫秒为单位，native 需要纳秒，需要转换单位
            // 判断是否越界
            if (time == fixTime/1000000) {
                time = fixTime;
            }
            if (measurement && fields.count>0) {
                if ([name isEqualToString:@"rum"]) {
                    [self.rumManager addWebViewData:measurement tags:tags fields:fields tm:time];
                }
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
#endif
#pragma mark ========== FTRunloopDetectorDelegate ==========
- (void)longTaskStackDetected:(NSString*)slowStack duration:(long long)duration time:(long long)time{
    [self.rumManager addLongTaskWithStack:slowStack duration:[NSNumber numberWithLongLong:duration] startTime:time];
}
- (void)anrStackDetected:(NSString*)slowStack time:(nonnull NSDate *)time{
    [self.rumManager addErrorWithType:@"anr_error" message:@"ios_anr" stack:slowStack date:time];
}
#pragma mark ========== RUM-Action: App Launch ==========
-(void)ftAppHotStart:(NSDate *)launchTime duration:(NSNumber *)duration{
    [self.rumManager addLaunch:FTLaunchHot launchTime:launchTime duration:duration];
}
-(void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming{
    [self.rumManager addLaunch:isPreWarming?FTLaunchWarm:FTLaunchCold launchTime:launchTime duration:duration];
}
#pragma mark ========== RUM-View: App Life Cycle ==========
-(void)applicationWillEnterForeground{
    @try {
        self.rumManager.appState = FTAppStateStartUp;
        if(!self.rumConfig.enableTraceUserView){
            return;
        }
        if (self.rumManager.viewReferrer) {
            NSString *viewID = [FTBaseInfoHandler randomUUID];
            NSString *viewReferrer =self.rumManager.viewReferrer;
            self.rumManager.viewReferrer = @"";
            [self.rumManager onCreateView:viewReferrer loadTime:@0];
            [self.rumManager startViewWithViewID:viewID viewName:viewReferrer property:nil];
        }
    }@catch (NSException *exception) {
        FTInnerLogError(@"applicationWillEnterForeground exception %@",exception);
    }
}
-(void)applicationDidBecomeActive{
    self.rumManager.appState = FTAppStateRun;
}
-(void)applicationDidEnterBackground{
    @try {
        self.rumManager.appState = FTAppStateUnknown;
        if(!self.rumConfig.enableTraceUserView){
            return;
        }
        [self.rumManager stopViewWithProperty:nil];
    }@catch (NSException *exception) {
        FTInnerLogError(@"applicationDidEnterBackground exception %@",exception);
    }
}
#pragma mark ========== 注销 ==========
- (void)shutDown{
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
#if !TARGET_OS_TV
    [FTWKWebViewHandler sharedInstance].enableTrace = NO;
#endif
    [_longTaskManager shutDown];
    onceToken = 0;
    sharedInstance = nil;
    FTInnerLogInfo(@"[RUM] SHUT DOWN");
}
@end
