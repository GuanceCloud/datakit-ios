//
//  FTGlobalRumManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/14.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import <TargetConditionals.h>
#import "FTGlobalRumManager+Private.h"
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
#import "FTModuleManager.h"
#import "FTHeatmapIdentifierStore.h"
#import "NSDate+FTUtil.h"
#import "NSDictionary+FTCopyProperties.h"

@interface FTGlobalRumManager ()<FTRunloopDetectorDelegate>
@property (nonatomic, strong) FTRUMManager *rumManager;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTLongTaskManager *longTaskManager;
@property (nonatomic, strong) FTHeatmapIdentifierStore *heatmapIdentifierStore;
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
+ (instancetype)sharedManager {
    return [self sharedInstance];
}

#pragma mark ========== Public RUM compatibility ==========
- (void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    [self.rumManager onCreateView:viewName loadTime:loadTime];
}
- (void)startViewWithName:(NSString *)viewName {
    [self.rumManager startViewWithName:viewName];
}
- (void)startViewWithName:(NSString *)viewName property:(NSDictionary *)property{
    [self.rumManager startViewWithName:viewName property:[property ft_deepCopy]];
}
- (void)stopView{
    [self.rumManager stopView];
}
- (void)stopViewWithProperty:(NSDictionary *)property{
    [self.rumManager stopViewWithProperty:[property ft_deepCopy]];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    [self.rumManager startAction:actionName actionType:actionType property:nil];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    [self.rumManager startAction:actionName actionType:actionType property:[property ft_deepCopy]];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [self.rumManager addErrorWithType:type message:message stack:stack];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(NSDictionary *)property{
    [self.rumManager addErrorWithType:type message:message stack:stack property:[property ft_deepCopy]];
}
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state message:(NSString *)message stack:(NSString *)stack property:(NSDictionary *)property {
    [self.rumManager addErrorWithType:type state:state message:message stack:stack property:[property ft_deepCopy]];
}
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - [duration longLongValue];
    [self.rumManager addLongTaskWithStack:stack duration:duration startTime:startTime];
}
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(NSDictionary *)property{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - [duration longLongValue];
    [self.rumManager addLongTaskWithStack:stack duration:duration startTime:startTime property:[property ft_deepCopy]];
}
- (void)startResourceWithKey:(NSString *)key{
    [self.rumManager startResourceWithKey:key];
}
- (void)startResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    [self.rumManager startResourceWithKey:key property:[property ft_deepCopy]];
}
- (void)addResourceWithKey:(NSString *)key metrics:(FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    [self.rumManager addResourceWithKey:key metrics:metrics content:content];
}
- (void)stopResourceWithKey:(NSString *)key{
    [self.rumManager stopResourceWithKey:key];
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    [self.rumManager stopResourceWithKey:key property:[property ft_deepCopy]];
}

-(void)setRumConfig:(FTRumConfig *)rumConfig writer:(id<FTRUMDataWriteProtocol>)writer{
    FTDisplayRateMonitor *displayMonitor = [self displayMonitorWithRumConfig:rumConfig];
    FTRUMMonitor *monitor = [self rumMonitorWithRumConfig:rumConfig displayMonitor:displayMonitor];
    FTErrorMonitorInfo *errorInfoWrapper = [[FTErrorMonitorInfo alloc]initWithMonitorType:(ErrorMonitorType)rumConfig.errorMonitorType];
    self.dependencies = [self dependenciesWithRumConfig:rumConfig writer:writer monitor:monitor errorInfoWrapper:errorInfoWrapper];
    self.rumManager = [[FTRUMManager alloc]initWithRumDependencies:self.dependencies];
    [self setupAutoTrackWithRumConfig:rumConfig];
    BOOL lastSessionHadCrash = [self setupCrashWithRumConfig:rumConfig writer:writer errorInfoWrapper:errorInfoWrapper dependencies:self.dependencies];
    [self setupLongTaskWithRumConfig:rumConfig dependencies:self.dependencies lastSessionHadCrash:lastSessionHadCrash];
    [self setupWebViewAndExternalDataWithRumConfig:rumConfig];
}
- (FTDisplayRateMonitor *)displayMonitorWithRumConfig:(FTRumConfig *)rumConfig{
    FTDisplayRateMonitor *displayMonitor = nil;
#if FT_HAS_UIKIT
    if (rumConfig.deviceMetricsMonitorType & FTDeviceMetricsMonitorFps) {
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
    dependencies.sampleRate = rumConfig.sampleRate;
    dependencies.enableResourceHostIP = rumConfig.enableResourceHostIP;
    dependencies.enableTraceUserAction = rumConfig.enableTraceUserAction;
    dependencies.errorMonitorInfoWrapper = errorInfoWrapper;
    dependencies.fatalErrorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:errorInfoWrapper];
    return dependencies;
}
#if TARGET_OS_OSX
- (void)setupAutoTrackWithRumConfig:(FTRumConfig *)rumConfig{
    self.heatmapIdentifierStore = [[FTHeatmapIdentifierStore alloc] init];
    [[FTModuleManager sharedInstance] registerService:@protocol(FTHeatmapIdentifierRegistry) instance:self.heatmapIdentifierStore];
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:rumConfig.enableTraceUserView
                                                     action:rumConfig.enableTraceUserAction
                                        addRumDatasDelegate:self.rumManager];
}
#else
- (void)setupAutoTrackWithRumConfig:(FTRumConfig *)rumConfig{
    self.heatmapIdentifierStore = [[FTHeatmapIdentifierStore alloc] init];
    [[FTModuleManager sharedInstance] registerService:@protocol(FTHeatmapIdentifierRegistry) instance:self.heatmapIdentifierStore];
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:rumConfig.enableTraceUserView
                                                     action:rumConfig.enableTraceUserAction
                                        addRumDatasDelegate:self.rumManager
                                                viewHandler:rumConfig.viewTrackingHandler
                                         swiftUIViewHandler:rumConfig.swiftUIViewTrackingHandler
                                              actionHandler:rumConfig.actionTrackingHandler
                                  heatmapIdentifierRegistry:self.heatmapIdentifierStore
    ];
}
#endif
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
    self.heatmapIdentifierStore = nil;
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
