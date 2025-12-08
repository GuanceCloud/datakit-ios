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
    dependencies.fatalErrorContext = [FTFatalErrorContext new];
    self.dependencies = dependencies;
    self.rumManager = [[FTRUMManager alloc]initWithRumDependencies:self.dependencies];
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:rumConfig.enableTraceUserView action:rumConfig.enableTraceUserAction addRumDatasDelegate:self.rumManager viewHandler:rumConfig.viewTrackingHandler actionHandler:rumConfig.actionTrackingHandler];
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    if(rumConfig.enableTrackAppCrash){
        [FTCrash shared].monitoring = rumConfig.crashMonitoring;
        [[FTCrash shared] addErrorDataDelegate:self.rumManager];
        [[FTCrash shared] install];
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
- (void)dealReceiveScriptMessage:(id )message slotId:(NSUInteger)slotId{
    @try {
        NSDictionary *messageDic = [message isKindOfClass:NSDictionary.class]?message:[FTJSONUtil dictionaryWithJsonString:message];
        
        if (![messageDic isKindOfClass:[NSDictionary class]]) {
            FTInnerLogError(@"Message body is formatted failure from JS SDK");
            return;
        }
        NSString *name = messageDic[@"name"];
        if ([name isEqualToString:@"rum"]) {
            NSDictionary *data = messageDic[@"data"];
            NSString *measurement = data[FT_MEASUREMENT];
            NSMutableDictionary *tags = [data[FT_TAGS] mutableCopy];
            NSString *version = [tags valueForKey:FT_SDK_VERSION];
            if(version&&version.length>0){
                [tags setValue:@{@"web":version} forKey:FT_SDK_PKG_INFO];
            }
            NSDictionary *fields = data[FT_FIELDS];
            long long time = [data[@"time"] longLongValue];
            long long fixTime = time * 1000000;
            // Web time data is in milliseconds, native needs nanoseconds, need to convert units
            // Check if overflow
            if (time == fixTime/1000000) {
                time = fixTime;
            }
            if (measurement && fields.count>0) {
                if ([measurement isEqualToString:FT_RUM_SOURCE_VIEW]) {
                    if (tags[FT_KEY_VIEW_REFERRER] == nil) {
                        [tags setValue:self.rumManager.viewReferrer forKey:FT_KEY_VIEW_REFERRER];
                    }
                }
               [self.rumManager addWebViewData:measurement tags:tags fields:fields tm:time];
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
