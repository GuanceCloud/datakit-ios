//
//  FTGlobalRumManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTGlobalRumManager.h"
#import "FTLog+Private.h"
#if !TARGET_OS_TV
#import "FTWKWebViewHandler+Private.h"
#import "FTWKWebViewJavascriptBridge.h"
#endif
#import "FTLongTaskManager.h"
#import "FTJSONUtil.h"
#import "FTAutoTrackHandler.h"
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
#import "FTCrash.h"
#import "FTFatalErrorContext.h"
#import "FTModuleManager.h"
@interface FTGlobalRumManager ()<FTRunloopDetectorDelegate,FTAppLifeCycleDelegate>
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
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
static NSObject *sharedInstanceLock;
+ (void)initialize{
    if (self == [FTGlobalRumManager class]) {
        sharedInstanceLock = [[NSObject alloc] init];
    }
}
+ (instancetype)sharedInstance {
    @synchronized(sharedInstanceLock) {
        if(!sharedInstance){
            sharedInstance = [[super allocWithZone:NULL] init];
        }
        return sharedInstance;
    }
}
-(void)setRumConfig:(FTRumConfig *)rumConfig writer:(id<FTRUMDataWriteProtocol>)writer{
    _rumConfig = rumConfig;
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.monitor = [[FTRUMMonitor alloc]initWithMonitorType:(DeviceMetricsMonitorType)rumConfig.deviceMetricsMonitorType frequency:(MonitorFrequency)rumConfig.monitorFrequency];
    dependencies.writer = writer;
    dependencies.sessionOnErrorSampleRate = rumConfig.sessionOnErrorSampleRate;
    dependencies.sampleRate = rumConfig.samplerate;
    dependencies.enableResourceHostIP = rumConfig.enableResourceHostIP;
    dependencies.errorMonitorType = (ErrorMonitorType)rumConfig.errorMonitorType;
    dependencies.appId = rumConfig.appid;
    dependencies.fatalErrorContext = [FTFatalErrorContext new];
    self.dependencies = dependencies;
    self.rumManager = [[FTRUMManager alloc]initWithRumDependencies:self.dependencies];
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:rumConfig.enableTraceUserView action:rumConfig.enableTraceUserAction addRumDatasDelegate:self.rumManager viewHandler:rumConfig.viewTrackingHandler actionHandler:rumConfig.actionTrackingHandler];
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    if(rumConfig.enableTrackAppCrash){
        [[FTCrash shared] addErrorDataDelegate:self.rumManager];
    }
    //Collect view, resource, jsBridge
    if (rumConfig.enableTrackAppANR||rumConfig.enableTrackAppFreeze) {
        _longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self enableTrackAppANR:rumConfig.enableTrackAppANR enableTrackAppFreeze:rumConfig.enableTrackAppFreeze                                        freezeDurationMs:rumConfig.freezeDurationMs];
    }else{
        [dependencies.writer lastFatalErrorIfFound:0];
    }
#if !TARGET_OS_TV
    [[FTWKWebViewHandler sharedInstance] startWithEnableTraceWebView:rumConfig.enableTraceWebView allowWebViewHost:rumConfig.allowWebViewHost rumDelegate:self];
#endif
    [FTExternalDataManager sharedManager].delegate = self.rumManager;
}
#pragma mark ========== jsBridge ==========
#if !TARGET_OS_TV
- (void)dealRUMWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    [self.rumManager addWebViewData:measurement tags:tags fields:fields tm:tm];
}
- (nullable NSString *)getLastHasReplayViewIDWithSRBindInfo:(NSDictionary *)info{
    return [self.rumManager getLastHasReplayViewIDWithSRBindInfo:info];
}
-(NSString *)getLastViewName{
    return self.rumManager.viewReferrer;
}
#endif
#pragma mark ========== FTRunloopDetectorDelegate ==========
- (void)longTaskStackDetected:(NSString*)slowStack duration:(long long)duration time:(long long)time{
    [self.rumManager addLongTaskWithStack:slowStack duration:[NSNumber numberWithLongLong:duration] startTime:time];
}
- (void)anrStackDetected:(NSString*)slowStack time:(nonnull NSDate *)time{
    [self.rumManager addErrorWithType:@"anr_error" message:@"ios_anr" stack:slowStack date:time];
}
#pragma mark ========== RUM-ERROR appState: App Life Cycle ==========
-(void)applicationWillEnterForeground{
    self.rumManager.appState = FTAppStateStartUp;
}
-(void)applicationDidBecomeActive{
    self.rumManager.appState = FTAppStateRun;
}
-(void)applicationDidEnterBackground{
    self.rumManager.appState = FTAppStateUnknown;
}
#pragma mark ========== Shutdown ==========
- (void)shutDown{
    [[FTAutoTrackHandler sharedInstance] shutDown];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [[FTAutoTrackHandler sharedInstance] shutDown];
    [_longTaskManager shutDown];
#if !TARGET_OS_TV
    [FTWKWebViewHandler shutDown];
#endif
    @synchronized(sharedInstanceLock) {
        sharedInstance = nil;
    }
    FTInnerLogInfo(@"[RUM] SHUT DOWN");
}
@end
