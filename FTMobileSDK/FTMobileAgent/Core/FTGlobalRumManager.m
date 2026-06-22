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
#import "FTInnerLog.h"
#if !TARGET_OS_TV
#import "FTWKWebViewHandler+Private.h"
#endif
#import "FTSDKCompat.h"
#import "FTLongTaskManager.h"
#import "FTAutoTrackHandler.h"
#import "FTRUMManager.h"
#import "FTDisplayRateMonitor.h"
#import "FTRumConfig.h"
#import "FTRUMMonitor.h"
#import "FTExternalDataManager+Private.h"
#import "FTInternalConstants.h"
#import "FTCrash.h"
#import "FTFatalErrorContext.h"
#import "FTErrorMonitorInfo.h"
@interface FTGlobalRumManager ()<FTRunloopDetectorDelegate>
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTLongTaskManager *longTaskManager;
@end

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
    FTDisplayRateMonitor *displayMonitor = [self displayMonitorWithRumConfig:rumConfig];
    FTRUMMonitor *monitor = [self rumMonitorWithRumConfig:rumConfig displayMonitor:displayMonitor];
    FTErrorMonitorInfo *errorInfoWrapper = [[FTErrorMonitorInfo alloc]initWithMonitorType:(ErrorMonitorType)rumConfig.errorMonitorType];
    self.dependencies = [self dependenciesWithRumConfig:rumConfig writer:writer monitor:monitor errorInfoWrapper:errorInfoWrapper];
    self.rumManager = [[FTRUMManager alloc]initWithRumDependencies:self.dependencies];
    [self setupAutoTrackWithRumConfig:rumConfig displayMonitor:displayMonitor];
    BOOL lastSessionHadCrash = [self setupCrashWithRumConfig:rumConfig writer:writer errorInfoWrapper:errorInfoWrapper dependencies:self.dependencies];
    [self setupLongTaskWithRumConfig:rumConfig dependencies:self.dependencies lastSessionHadCrash:lastSessionHadCrash];
    [self setupWebViewAndExternalDataWithRumConfig:rumConfig];
}
- (FTDisplayRateMonitor *)displayMonitorWithRumConfig:(FTRumConfig *)rumConfig{
    FTDisplayRateMonitor *displayMonitor = nil;
#if FT_HAS_UIKIT
    if (rumConfig.deviceMetricsMonitorType & DeviceMetricsMonitorFps || rumConfig.enableTraceUserAction) {
        displayMonitor = [[FTDisplayRateMonitor alloc]init];
    }
#endif
    return displayMonitor;
}
- (FTRUMMonitor *)rumMonitorWithRumConfig:(FTRumConfig *)rumConfig displayMonitor:(FTDisplayRateMonitor *)displayMonitor{
    FTRUMMonitor *monitor = [[FTRUMMonitor alloc]initWithMonitorType:(DeviceMetricsMonitorType)rumConfig.deviceMetricsMonitorType frequency:(MonitorFrequency)rumConfig.monitorFrequency];
    monitor.displayMonitor = displayMonitor;
    return monitor;
}
- (FTRUMDependencies *)dependenciesWithRumConfig:(FTRumConfig *)rumConfig
                                          writer:(id<FTRUMDataWriteProtocol>)writer
                                         monitor:(FTRUMMonitor *)monitor
                                errorInfoWrapper:(FTErrorMonitorInfo *)errorInfoWrapper{
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.appId = rumConfig.appid;
    dependencies.monitor = monitor;
    dependencies.writer = writer;
    dependencies.sessionOnErrorSampleRate = rumConfig.sessionOnErrorSampleRate;
    dependencies.sampleRate = rumConfig.samplerate;
    dependencies.enableResourceHostIP = rumConfig.enableResourceHostIP;
    dependencies.errorMonitorInfoWrapper = errorInfoWrapper;
    dependencies.fatalErrorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:errorInfoWrapper];
    return dependencies;
}
- (void)setupAutoTrackWithRumConfig:(FTRumConfig *)rumConfig displayMonitor:(FTDisplayRateMonitor *)displayMonitor{
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:rumConfig.enableTraceUserView
                                                     action:rumConfig.enableTraceUserAction
                                      addRumDatasDelegate:self.rumManager
                                              viewHandler:rumConfig.viewTrackingHandler
                                       swiftUIViewHandler:rumConfig.swiftUIViewTrackingHandler
                                            actionHandler:rumConfig.actionTrackingHandler
                                           displayMonitor:displayMonitor];
}
- (BOOL)setupCrashWithRumConfig:(FTRumConfig *)rumConfig
                          writer:(id<FTRUMDataWriteProtocol>)writer
                errorInfoWrapper:(FTErrorMonitorInfo *)errorInfoWrapper
                    dependencies:(FTRUMDependencies *)dependencies{
    BOOL lastSessionHadCrash = NO;
    if(rumConfig.enableTrackAppCrash){
        [FTCrash setupWithMonitoringType:(FTCrashCMonitorType)rumConfig.crashMonitoring
                                  writer:writer
                     enableMonitorMemory:[errorInfoWrapper enableMonitorMemory]
                        enableMonitorCpu:[errorInfoWrapper enableMonitorCpu]];
        dependencies.fatalErrorContext.onChange = ^(NSDictionary * _Nonnull context) {
            [FTCrash shared].userInfo = context;
        };
        // for sessionOnErrorSampled
        if([FTCrash shared].crashedLastLaunch){
            lastSessionHadCrash = YES;
            long long crashDate = [FTCrash shared].crashedLastTimestamp * 1e9;
            [dependencies.writer lastFatalErrorIfFound:crashDate];
        }
    }
    return lastSessionHadCrash;
}
- (void)setupLongTaskWithRumConfig:(FTRumConfig *)rumConfig dependencies:(FTRUMDependencies *)dependencies lastSessionHadCrash:(BOOL)lastSessionHadCrash{
    if (rumConfig.enableTrackAppANR||rumConfig.enableTrackAppFreeze) {
        _longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies
                                                                  delegate:self
                                                        backtraceReporting:[FTCrash shared].backtraceReporting
                                                         enableTrackAppANR:rumConfig.enableTrackAppANR
                                                      enableTrackAppFreeze:rumConfig.enableTrackAppFreeze
                                                          freezeDurationMs:rumConfig.freezeDurationMs];
    }else if(!lastSessionHadCrash){
        [dependencies.writer lastFatalErrorIfFound:0];
    }
}
- (void)setupWebViewAndExternalDataWithRumConfig:(FTRumConfig *)rumConfig{
#if !TARGET_OS_TV
    [[FTWKWebViewHandler sharedInstance] startWithEnableTraceWebView:rumConfig.enableTraceWebView allowWebViewHost:rumConfig.allowWebViewHost rumDelegate:self.rumManager];
#endif
    [FTExternalDataManager sharedManager].delegate = self.rumManager;
}
-(void)updateSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate{
    [self.rumManager updateSampleRate:sampleRate sessionOnErrorSampleRate:sessionOnErrorSampleRate];
}
#pragma mark ========== FTRunloopDetectorDelegate ==========
- (void)longTaskStackDetected:(NSString*)slowStack duration:(long long)duration time:(long long)time{
    [self.rumManager addLongTaskWithStack:slowStack duration:[NSNumber numberWithLongLong:duration] startTime:time];
}
- (void)anrStackDetected:(NSString*)slowStack appState:(NSString *)appState time:(long long)time{
    [self.rumManager addErrorWithType:@"anr_error" stateStr:appState message:@"ios_anr" stack:slowStack property:nil time:time];
}
#pragma mark ========== Shutdown ==========
- (void)shutDown{
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
