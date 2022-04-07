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
#import "FTConstants.h"
#import "FTURLProtocol.h"
#import "FTLog.h"
#import "FTDateUtil.h"
#import "FTWKWebViewHandler.h"
#import "FTANRDetector.h"
#import "FTJSONUtil.h"
#import "FTPingThread.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTUncaughtExceptionHandler.h"
#import "FTAppLifeCycle.h"
#import "FTRUMManager.h"
#import "FTAppLaunchTracker.h"
@interface FTGlobalRumManager ()<FTANRDetectorDelegate,FTWKWebViewRumDelegate,FTAppLifeCycleDelegate,FTAppLaunchDataDelegate>
@property (nonatomic, strong) FTPingThread *pingThread;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTWKWebViewJavascriptBridge *jsBridge;
@property (nonatomic, strong) FTTrack *track;
@property (nonatomic, assign) CFTimeInterval launch;
@property (nonatomic, strong) NSDate *launchTime;
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
@end

@implementation FTGlobalRumManager
static FTGlobalRumManager *sharedInstance = nil;
static dispatch_once_t onceToken;
-(instancetype)init{
    self = [super init];
    if (self) {
        _launchTime = [NSDate date];
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
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return self;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = rumConfig;
    if (self.rumConfig.appid.length<=0) {
        ZYErrorLog(@"RumConfig appid 数据格式有误，未能开启 RUM");
        return;
    }
    self.rumManger = [[FTRUMManager alloc]initWithRumConfig:rumConfig];
    self.track = [[FTTrack alloc]init];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    if(rumConfig.enableTrackAppCrash){
        [FTUncaughtExceptionHandler sharedHandler];
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
    if(rumConfig.enableTraceUserResource){
        [FTURLProtocol startMonitor];
    }
    [FTWKWebViewHandler sharedInstance].traceDelegate = self;
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
    [self.rumManger addLongTaskWithStack:stack duration:duration];
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
                    [self.rumManger addWebviewData:measurement tags:tags fields:fields tm:time];
                }else if([name isEqualToString:@"track"]){
                }else if([name isEqualToString:@"log"]){
                    //数据格式需要调整
                }else if([name isEqualToString:@"trace"]){
                    
                }
            }
        }
    } @catch (NSException *exception) {
        ZYErrorLog(@"%@ error: %@", self, exception);
    }
}
#pragma mark ========== FTANRDetectorDelegate ==========
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack{
    [self.rumManger addLongTaskWithStack:slowStack duration:[NSNumber numberWithLongLong:MXRMonitorRunloopOneStandstillMillisecond*MXRMonitorRunloopStandstillCount*1000000]];

}
#pragma mark ========== APP LAUNCH ==========
-(void)ftAppHotStart:(NSNumber *)duration{
    self.rumManger.appState = AppStateRun;
    [self.rumManger addLaunch:YES duration:duration];
}
-(void)ftAppColdStart:(NSNumber *)duration{
    self.rumManger.appState = AppStateRun;
    [self.rumManger addLaunch:NO duration:duration];
    if (self.rumManger.viewReferrer) {
        NSString *viewid = [NSUUID UUID].UUIDString;
        NSNumber *loadDuration = self.currentController?self.currentController.ft_loadDuration:@-1;
        NSString *viewReferrer =self.rumManger.viewReferrer;
        self.rumManger.viewReferrer = @"";
        [self.rumManger onCreateView:viewReferrer loadTime:loadDuration];
        [self.rumManger startViewWithViewID:viewid viewName:viewReferrer];
    }
}
#pragma mark ========== AUTO TRACK ==========
- (void)applicationWillTerminate{
    @try {
        self.rumManger.appState = AppStateStartUp;
        [self.rumManger stopView];
        [self.rumManger applicationWillTerminate];
    }@catch (NSException *exception) {
        ZYErrorLog(@"applicationWillResignActive exception %@",exception);
    }
}
- (void)trackViewDidAppear:(UIViewController *)viewController{
    NSString *viewID = viewController.ft_viewUUID;
    NSString *className = NSStringFromClass(viewController.class);
    [self.rumManger onCreateView:className loadTime:viewController.ft_loadDuration];
    [self.rumManger startViewWithViewID:viewID viewName:className];
}
- (void)trackViewDidDisappear:(UIViewController *)viewController{
    if(self.currentController == viewController){
        [self.rumManger stopViewWithViewID:viewController.ft_viewUUID];
    }
}
#pragma mark ========== 注销 ==========
- (void)resetInstance{
    _rumManger = nil;
    onceToken = 0;
    sharedInstance =nil;
    [FTWKWebViewHandler sharedInstance].enableTrace = NO;
    [[FTANRDetector sharedInstance] stopDetecting];
    [self stopMonitor];
}
@end
