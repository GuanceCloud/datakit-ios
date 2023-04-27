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
#import "FTURLProtocol.h"
#import "FTLog.h"
#import "FTDateUtil.h"
#import "FTWKWebViewHandler.h"
#import "FTANRDetector.h"
#import "FTJSONUtil.h"
#import "FTPingThread.h"
#import "FTWKWebViewJavascriptBridge.h"
#if !FT_MAC
#import "FTTrack.h"
#import "UIViewController+FTAutoTrack.h"
#endif
#import "FTUncaughtExceptionHandler.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTAppLaunchTracker.h"
#import "FTTracer.h"
#import "FTTraceHandler.h"
#import "FTURLSessionInterceptor.h"
#import "FTMobileAgent+Private.h"
#import "FTRUMMonitor.h"
#import "FTExternalDataManager+Private.h"
#import "FTEnumConstant.h"
#import "FTConstants.h"
@interface FTGlobalRumManager ()<FTANRDetectorDelegate,FTWKWebViewRumDelegate,FTAppLifeCycleDelegate,FTAppLaunchDataDelegate>
@property (nonatomic, strong) FTPingThread *pingThread;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTWKWebViewJavascriptBridge *jsBridge;
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@end

@implementation FTGlobalRumManager
static FTGlobalRumManager *sharedInstance = nil;
static dispatch_once_t onceToken;
-(instancetype)init{
    self = [super init];
    if (self) {
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = rumConfig;
    self.monitor = [[FTRUMMonitor alloc]initWithMonitorType:(DeviceMetricsMonitorType)rumConfig.deviceMetricsMonitorType frequency:(MonitorFrequency)rumConfig.monitorFrequency];
    self.rumManager = [[FTRUMManager alloc]initWithRumSampleRate:rumConfig.samplerate errorMonitorType:(ErrorMonitorType)rumConfig.errorMonitorType monitor:self.monitor wirter:[FTMobileAgent sharedInstance]];
#if !FT_MAC
    [[FTTrack sharedInstance]startWithTrackView:rumConfig.enableTraceUserView action:rumConfig.enableTraceUserAction];
    [FTTrack sharedInstance].addRumDatasDelegate = self.rumManager;
#endif
    if(rumConfig.enableTraceUserAction){
        self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    }
    if(rumConfig.enableTrackAppCrash){
        [[FTUncaughtExceptionHandler sharedHandler] addErrorDataDelegate:self.rumManager];
    }
    //采集view、resource、jsBridge
    dispatch_async(dispatch_get_main_queue(), ^{
        if (rumConfig.enableTrackAppFreeze) {
            [self startPingThread];
        }else{
            [self stopPingThread];
        }
        if (rumConfig.enableTrackAppANR) {
            [FTANRDetector sharedInstance].delegate = self;
            [[FTANRDetector sharedInstance] startDetecting];
        }else{
            [[FTANRDetector sharedInstance] stopDetecting];
        }
    });
    [FTWKWebViewHandler sharedInstance].rumTrackDelegate = self;
    [FTExternalDataManager sharedManager].delegate = self.rumManager;
}
-(FTPingThread *)pingThread{
    if (!_pingThread || _pingThread.isCancelled) {
        _pingThread = [[FTPingThread alloc]init];
        __weak typeof(self) weakSelf = self;
        _pingThread.block = ^(NSString * _Nonnull stackStr, NSDate * _Nonnull startDate, NSDate * _Nonnull endDate) {
            [weakSelf trackAppFreeze:stackStr duration:[FTDateUtil nanosecondTimeIntervalSinceDate:startDate toDate:endDate]];
        };
    }
    return _pingThread;
}
-(void)startPingThread{
    if (!self.pingThread.isExecuting) {
        [self.pingThread start];
    }
}
-(void)stopPingThread{
    if (_pingThread && _pingThread.isExecuting) {
        [self.pingThread cancel];
    }
}
- (void)trackAppFreeze:(NSString *)stack duration:(NSNumber *)duration{
    [self.rumManager addLongTaskWithStack:stack duration:duration property:nil];
}
-(void)stopMonitor{
    [self stopPingThread];
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
        NSDictionary *messageDic = [FTJSONUtil dictionaryWithJsonString:message];
        if (![messageDic isKindOfClass:[NSDictionary class]]) {
            ZYErrorLog(@"Message body is formatted failure from JS SDK");
            return;
        }
        NSString *name = messageDic[@"name"];
        if ([name isEqualToString:@"rum"]||[name isEqualToString:@"track"]||[name isEqualToString:@"log"]||[name isEqualToString:@"trace"]) {
            NSDictionary *data = messageDic[@"data"];
            NSString *measurement = data[FT_MEASUREMENT];
            NSDictionary *tags = data[FT_TAGS];
            NSDictionary *fields = data[FT_FIELDS];
            long long time = [data[@"time"] longLongValue];
            time = time>0?:[FTDateUtil currentTimeNanosecond];
            if (measurement && fields.count>0) {
                if ([name isEqualToString:@"rum"]) {
                    [self.rumManager addWebviewData:measurement tags:tags fields:fields tm:time];
                }
            }
        }
    } @catch (NSException *exception) {
        ZYErrorLog(@"%@ error: %@", self, exception);
    }
}
#pragma mark ========== FTANRDetectorDelegate ==========
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack{
    [self.rumManager addLongTaskWithStack:slowStack duration:[NSNumber numberWithLongLong:MXRMonitorRunloopOneStandstillMillisecond*MXRMonitorRunloopStandstillCount*1000000] property:nil];
    
}
#pragma mark ========== APP LAUNCH ==========
-(void)ftAppHotStart:(NSNumber *)duration{
    [self.rumManager addLaunch:FTLaunchHot duration:duration];
    if (self.rumManager.viewReferrer) {
        NSString *viewid = [NSUUID UUID].UUIDString;
        NSNumber *loadDuration = [FTTrack sharedInstance].currentController?[FTTrack sharedInstance].currentController.ft_loadDuration:@-1;
        NSString *viewReferrer =self.rumManager.viewReferrer;
        self.rumManager.viewReferrer = @"";
        [self.rumManager onCreateView:viewReferrer loadTime:loadDuration];
        [self.rumManager startViewWithViewID:viewid viewName:viewReferrer property:nil];
    }
}
-(void)ftAppColdStart:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming{
    [self.rumManager addLaunch:isPreWarming?FTLaunchWarm:FTLaunchCold duration:duration];
}
#pragma mark ========== AUTO TRACK ==========
- (void)applicationWillTerminate{
    @try {
        self.rumManager.appState = AppStateStartUp;
        [self.rumManager stopViewWithProperty:nil];
        [self.rumManager applicationWillTerminate];
    }@catch (NSException *exception) {
        ZYErrorLog(@"applicationWillResignActive exception %@",exception);
    }
}
#pragma mark ========== 注销 ==========
- (void)resetInstance{
    _rumManager = nil;
    onceToken = 0;
    sharedInstance =nil;
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [FTWKWebViewHandler sharedInstance].enableTrace = NO;
    [[FTANRDetector sharedInstance] stopDetecting];
    [self stopMonitor];
}
@end
