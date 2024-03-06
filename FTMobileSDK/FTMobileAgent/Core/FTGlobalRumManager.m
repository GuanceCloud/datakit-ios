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
#import "FTInternalLog.h"
#import "FTWKWebViewHandler.h"
#import "FTLongTaskDetector.h"
#import "FTJSONUtil.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTTrack.h"
#import "UIViewController+FTAutoTrack.h"
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
@interface FTGlobalRumManager ()<FTRunloopDetectorDelegate,FTWKWebViewRumDelegate,FTAppLifeCycleDelegate,FTAppLaunchDataDelegate>
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTWKWebViewJavascriptBridge *jsBridge;
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, strong) FTLongTaskDetector *longTaskDetector;
@end

@implementation FTGlobalRumManager
static FTGlobalRumManager *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = rumConfig;
    self.monitor = [[FTRUMMonitor alloc]initWithMonitorType:(DeviceMetricsMonitorType)rumConfig.deviceMetricsMonitorType frequency:(MonitorFrequency)rumConfig.monitorFrequency];
    self.rumManager = [[FTRUMManager alloc]initWithRumSampleRate:rumConfig.samplerate errorMonitorType:(ErrorMonitorType)rumConfig.errorMonitorType monitor:self.monitor writer:[FTMobileAgent sharedInstance]];
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
        _longTaskDetector = [[FTLongTaskDetector alloc]initWithDelegate:self enableTrackAppANR:rumConfig.enableTrackAppANR enableTrackAppFreeze:rumConfig.enableTrackAppFreeze];
        [_longTaskDetector startDetecting];
    }
    [FTWKWebViewHandler sharedInstance].rumTrackDelegate = self;
    [FTExternalDataManager sharedManager].delegate = self.rumManager;
}
#pragma mark ========== jsBridge ==========
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
            NSDictionary *tags = data[FT_TAGS];
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
#pragma mark ========== FTRunloopDetectorDelegate ==========
- (void)longTaskStackDetected:(NSString*)slowStack duration:(long long)duration time:(long long)time{
    [self.rumManager addLongTaskWithStack:slowStack duration:[NSNumber numberWithLongLong:duration] startTime:time];
}
- (void)anrStackDetected:(NSString*)slowStack{
    [self.rumManager addErrorWithType:@"anr_error" message:@"ios_anr" stack:slowStack];
}
#pragma mark ========== APP LAUNCH ==========
-(void)ftAppHotStart:(NSDate *)launchTime duration:(NSNumber *)duration{
    [self.rumManager addLaunch:FTLaunchHot launchTime:launchTime duration:duration];
}
-(void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming{
    [self.rumManager addLaunch:isPreWarming?FTLaunchWarm:FTLaunchCold launchTime:launchTime duration:duration];
}
#pragma mark ========== AUTO TRACK ==========
-(void)applicationWillEnterForeground{
    @try {
        self.rumManager.appState = FTAppStateStartUp;
        if(!self.rumConfig.enableTraceUserView){
            return;
        }
        if (self.rumManager.viewReferrer) {
            NSString *viewID = [FTBaseInfoHandler randomUUID];
            NSNumber *loadDuration = [FTTrack sharedInstance].currentController?[FTTrack sharedInstance].currentController.ft_loadDuration:@-1;
            NSString *viewReferrer =self.rumManager.viewReferrer;
            self.rumManager.viewReferrer = @"";
            [self.rumManager onCreateView:viewReferrer loadTime:loadDuration];
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
    [self.rumManager syncProcess];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [FTWKWebViewHandler sharedInstance].enableTrace = NO;
    [_longTaskDetector stopDetecting];
    onceToken = 0;
    sharedInstance = nil;
    FTInnerLogInfo(@"[RUM] SHUT DOWN");
}
@end
