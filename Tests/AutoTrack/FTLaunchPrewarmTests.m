//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "FTAppLaunchTracker.h"
#import "FTDateUtil.h"
#import "FTConstants.h"
#import "FTRumConfig.h"
#import "FTSDKAgent.h"
#import "FTMobileAgent.h"
#import "FTRumConfig+Private.h"
#import "FTRUMManager.h"
#import "FTRUMWriteData.h"
#import "FTAutoTrackHandler.h"
#import "FTFirstFrameReader.h"

// Declarations keep the numeric regression runnable against the original SDK baseline.
@interface FTSDKAgent (PrewarmBaseline)
+ (void)prewarmCheckStart;
+ (void)prewarmCheckEnd;
@end
@interface FTMobileAgent (PrewarmBaseline)
+ (void)prewarmCheckStart;
+ (void)prewarmCheckEnd;
@end
@interface FTRUMManager (PrewarmBaseline)
- (void)addLaunch:(NSString *)name type:(NSString *)type launchTime:(NSDate *)time duration:(NSNumber *)duration property:(NSDictionary *)property endDate:(NSDate *)endDate;
@end

@interface FTAppLaunchTracker (PrewarmTests)
+ (NSDictionary *)resetPrewarmCheckForTesting;
+ (void)restorePrewarmCheckForTesting:(NSDictionary *)state;
+ (void)prewarmCheckStart;
+ (void)prewarmCheckEnd;
- (void)reportAppLaunchPhaseDuration:(NSDate *)date;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationDidBecomeActive;
- (instancetype)initWithDelegate:(id)delegate firstFrameReader:(FTFirstFrameReader *)reader;
- (void)shutDown;
@end
extern void FTSetApplicationDidBecomeActive(NSDate *date);
extern NSDate *FTGetApplicationDidBecomeActive(void);
extern void FTSetModuleInitializationTimestamp(NSDate *date);
extern NSDate *FTGetModuleInitializationTimestamp(void);
extern void FTSetRuntimeInit(NSDate *date);
extern NSDate *FTGetRuntimeInit(void);
extern void FTSetIsActivePrewarm(BOOL value);
extern BOOL FTGetIsActivePrewarm(void);

@interface FTPrewarmWriter : NSObject <FTRUMDataWriteProtocol>
@property NSMutableArray<FTRUMWriteData *> *events;
@end
@implementation FTPrewarmWriter
- (instancetype)init { if ((self = [super init])) _events=[NSMutableArray new]; return self; }
- (BOOL)writeRUMData:(FTRUMWriteData *)data { [self.events addObject:data]; return YES; }
@end

@interface FTQueuedLaunchFrameReader : FTFirstFrameReader
@property (copy) FTFirstFrameCallback queuedCallback;
@property NSUInteger starts;
@property NSUInteger stops;
@end
@implementation FTQueuedLaunchFrameReader
- (void)startWithCallback:(FTFirstFrameCallback)callback { self.starts++; self.queuedCallback=callback; }
// Preserve a captured callback to simulate completion already queued before shutdown.
- (void)stop { self.stops++; }
@end

@interface FTLaunchPrewarmTests : XCTestCase <FTAppLaunchDataDelegate>
@property NSDictionary *fields;
@property NSNumber *duration;
@property NSDate *time;
@property BOOL prewarm;
@property NSUInteger reports;
@property NSTimeInterval sdkOffset;
@property BOOL endMarkerAfterEndpoint;
@property NSInteger markerPattern;
@property BOOL reportThroughAutoTrack;
@end
@implementation FTLaunchPrewarmTests
- (void)ftAppColdStart:(NSDate *)time duration:(NSNumber *)duration isPreWarming:(BOOL)prewarm fields:(NSDictionary *)fields {
    self.time=time; self.duration=duration; self.prewarm=prewarm; self.fields=fields; self.reports++;
}
- (void)ftAppHotStart:(NSDate *)time duration:(NSNumber *)duration { XCTFail(@"Unexpected hot start"); }
- (void)exerciseThreshold:(NSInteger)threshold load:(NSTimeInterval)load manual:(uint64_t)manual system:(BOOL)system active:(BOOL)active assertions:(void (^)(void))assertions {
    NSDate *oldLoad=FTGetRuntimeInit(), *oldModule=FTGetModuleInitializationTimestamp(), *oldActive=FTGetApplicationDidBecomeActive(), *oldSDK=FTAppLaunchTracker.sdkStartDate;
    BOOL oldSystem=FTGetIsActivePrewarm();
    Method process=class_getClassMethod(FTDateUtil.class,@selector(processStartTimestamp));
    Method date=class_getClassMethod(FTDateUtil.class,@selector(date));
    IMP fakeDate=imp_implementationWithBlock(^NSDate *(id receiver){return [NSDate dateWithTimeIntervalSince1970:self.endMarkerAfterEndpoint ? 1010 : 1003];});
    IMP oldDate=method_setImplementation(date,fakeDate);
    Method clock=class_getClassMethod(FTDateUtil.class,@selector(continuousTime));
    __block uint64_t tick=1000000000;
    IMP replacement=imp_implementationWithBlock(^NSDate *(id receiver){ return [NSDate dateWithTimeIntervalSince1970:1000]; });
    IMP fakeClock=imp_implementationWithBlock(^uint64_t(id receiver){ return tick; });
    IMP oldProcess=method_setImplementation(process,replacement), oldClock=method_setImplementation(clock,fakeClock);
    NSDictionary *markerState = nil;
    @try {
        if ([FTAppLaunchTracker respondsToSelector:@selector(resetPrewarmCheckForTesting)]) markerState = [FTAppLaunchTracker resetPrewarmCheckForTesting];
        FTSetRuntimeInit([NSDate dateWithTimeIntervalSince1970:1000+load]);
        FTSetModuleInitializationTimestamp([NSDate dateWithTimeIntervalSince1970:1000+load+0.125]);
        FTSetApplicationDidBecomeActive(nil); FTSetIsActivePrewarm(system);
        FTAppLaunchTracker.sdkStartDate=[NSDate dateWithTimeIntervalSince1970:1000+(self.sdkOffset ?: 8)];
        if (manual && [FTAppLaunchTracker respondsToSelector:@selector(prewarmCheckStart)]) {
            [FTAppLaunchTracker prewarmCheckEnd]; // End before Start must not seal the pair.
            if (self.markerPattern == 6) tick=0;
            if (self.markerPattern != 1) {
                if (self.markerPattern == 4) {
                    dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) {
                        [FTMobileAgent prewarmCheckStart];
                    });
                } else {
                    [FTMobileAgent prewarmCheckStart];
                }
            }
            if (self.markerPattern == 2) tick=0;
            else if (self.markerPattern != 3) tick+=manual;
            if (self.markerPattern == 0 || self.markerPattern == 4) [FTAppLaunchTracker prewarmCheckStart]; // First Start wins.
            [FTSDKAgent prewarmCheckEnd];
            if (self.markerPattern == 0 || self.markerPattern == 4) {
                tick+=10000000000;
                [FTAppLaunchTracker prewarmCheckEnd]; // First End wins.
            }
        }
        FTAppLaunchTracker *tracker=[FTAppLaunchTracker new];
        if ([tracker respondsToSelector:NSSelectorFromString(@"setLaunchPrewarmInterval:")]) [tracker setValue:@(threshold) forKey:@"launchPrewarmInterval"];
        [tracker setValue:[NSDate dateWithTimeIntervalSince1970:1008.5] forKey:@"didFinishLaunchingTimestamp"];
        tracker.delegate=self; self.reports=0;
        NSDate *end=[NSDate dateWithTimeIntervalSince1970:1009];
        if(active) FTSetApplicationDidBecomeActive(end);
        if (!self.reportThroughAutoTrack) {
            [tracker reportAppLaunchPhaseDuration:end];
            [tracker reportAppLaunchPhaseDuration:[end dateByAddingTimeInterval:10000]];
            XCTAssertEqual(self.reports,1u);
            XCTAssertEqualObjects(self.time,[NSDate dateWithTimeIntervalSince1970:1000]);
        }
        assertions();
    } @finally {
        method_setImplementation(date,oldDate); imp_removeBlock(fakeDate);
        method_setImplementation(process,oldProcess); method_setImplementation(clock,oldClock);
        imp_removeBlock(replacement); imp_removeBlock(fakeClock);
        FTSetRuntimeInit(oldLoad); FTSetModuleInitializationTimestamp(oldModule); FTSetApplicationDidBecomeActive(oldActive); FTSetIsActivePrewarm(oldSystem); FTAppLaunchTracker.sdkStartDate=oldSDK;
        if (markerState) [FTAppLaunchTracker restorePrewarmCheckForTesting:markerState];
    }
}
- (void)testBeforeLoadWinsWhenBothChecksMatch {
    [self exerciseThreshold:1500 load:2 manual:5000000000 system:NO active:NO assertions:^{
        XCTAssertTrue(self.prewarm); XCTAssertEqualObjects(self.duration,@7000000000LL);
        XCTAssertEqualObjects(self.fields[@"prewarm_type"],@"custom");
        XCTAssertNil(self.fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_RUNTIME_INIT_TIME],(@{@"start":@2000000000LL,@"duration":@125000000}));
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_UIKITI_INIT_TIME][@"duration"],@5875000000LL);
        XCTAssertNil(self.fields[FT_KEY_APP_LAUNCH_TYPE]);
    }];
}
- (void)testManualMatchRemovesEntireLoadToSDKNotJustManualInterval {
    [self exerciseThreshold:1500 load:0.25 manual:2000000000 system:NO active:NO assertions:^{
        XCTAssertTrue(self.prewarm); XCTAssertEqualObjects(self.duration,@1250000000LL);
        XCTAssertEqualObjects(self.fields[@"prewarm_type"],@"custom");
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME][@"duration"],@250000000);
        XCTAssertNil(self.fields[FT_KEY_LAUNCH_RUNTIME_INIT_TIME]); XCTAssertNil(self.fields[FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_APP_INIT_TIME],(@{@"start":@8000000000LL,@"duration":@500000000}));
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME],(@{@"start":@8500000000LL,@"duration":@500000000}));
    }];
}
- (void)testDisabledPreservesRawTimingEvenWithManualMarkers {
    [self exerciseThreshold:0 load:2 manual:2000000000 system:NO active:NO assertions:^{
        XCTAssertFalse(self.prewarm); XCTAssertNil(self.fields[@"prewarm_type"]); XCTAssertEqualObjects(self.duration,@9000000000LL);
        XCTAssertNotNil(self.fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]); XCTAssertNotNil(self.fields[FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
    }];
}
- (void)testSystemSignalHasPriorityAndKeepsExistingTotal {
    [self exerciseThreshold:1500 load:2 manual:2000000000 system:YES active:NO assertions:^{
        XCTAssertTrue(self.prewarm); XCTAssertEqualObjects(self.fields[@"prewarm_type"],@"system"); XCTAssertEqualObjects(self.duration,@9000000000LL);
        XCTAssertNil(self.fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]); XCTAssertNil(self.fields[FT_KEY_LAUNCH_RUNTIME_INIT_TIME]); XCTAssertNotNil(self.fields[FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
    }];
}
- (void)testDisabledSystemPrewarmPreservesOriginalFieldsAndTiming {
    [self exerciseThreshold:0 load:2 manual:2000000000 system:YES active:NO assertions:^{
        XCTAssertTrue(self.prewarm);
        XCTAssertNil(self.fields[@"prewarm_type"]);
        XCTAssertEqualObjects(self.duration,@9000000000LL);
        XCTAssertNil(self.fields[FT_KEY_APP_LAUNCH_TYPE]);
        XCTAssertNil(self.fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertNil(self.fields[FT_KEY_LAUNCH_RUNTIME_INIT_TIME]);
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_UIKITI_INIT_TIME],(@{@"start":@2125000000LL,@"duration":@5875000000LL}));
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_APP_INIT_TIME],(@{@"start":@8000000000LL,@"duration":@500000000}));
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME],(@{@"start":@8500000000LL,@"duration":@500000000}));
    }];
}
- (void)testManualNanosecondThresholdBoundary {
    for(NSNumber *ns in @[@1499999999ULL,@1500000000ULL,@1500000001ULL]) {
        BOOL match=ns.unsignedLongLongValue>1500000000;
        [self exerciseThreshold:1500 load:0.25 manual:ns.unsignedLongLongValue system:NO active:NO assertions:^{
            XCTAssertEqual(self.prewarm,match); XCTAssertEqualObjects(self.duration,match?@1250000000LL:@9000000000LL);
        }];
    }
}
- (void)testBeforeLoadThresholdBoundaryAndMissingManualPair {
    for(NSNumber *load in @[@1.25,@1.5,@1.75]) {
        BOOL match=load.doubleValue>1.5;
        [self exerciseThreshold:1500 load:load.doubleValue manual:0 system:NO active:NO assertions:^{
            XCTAssertEqual(self.prewarm,match); XCTAssertEqualObjects(self.duration,match?@7250000000LL:@9000000000LL);
        }];
    }
}
- (void)testLateInitializationDoesNotInventLaterPhases {
    [self exerciseThreshold:1500 load:0.25 manual:2000000000 system:NO active:YES assertions:^{
        XCTAssertEqualObjects(self.duration,@1250000000LL); XCTAssertTrue(self.prewarm);
        XCTAssertNil(self.fields[FT_KEY_LAUNCH_APP_INIT_TIME]); XCTAssertNil(self.fields[FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME]);
    }];
}
- (void)testConfigDefaultCopyAndDictionaryRoundTrip {
    FTRumConfig *config=[[FTRumConfig alloc] initWithAppid:@"prewarm-tests"];
    XCTAssertEqualObjects([config valueForKey:@"launchPrewarmInterval"],@0);
    [config setValue:@1500 forKey:@"launchPrewarmInterval"];
    XCTAssertEqualObjects([[config copy] valueForKey:@"launchPrewarmInterval"],@1500);
    FTRumConfig *decoded=[[FTRumConfig alloc] initWithDictionary:[config convertToDictionary]];
    XCTAssertEqualObjects([decoded valueForKey:@"launchPrewarmInterval"],@1500);
    XCTAssertTrue([config.debugDescription containsString:@"launchPrewarmInterval"]);
    FTRumConfig *invalid=[[FTRumConfig alloc] initWithDictionary:@{@"launchPrewarmInterval":@"1500"}];
    XCTAssertEqualObjects([invalid valueForKey:@"launchPrewarmInterval"],@0);
    [config setValue:@(NSIntegerMax) forKey:@"launchPrewarmInterval"];
    XCTAssertEqualObjects([config valueForKey:@"launchPrewarmInterval"],@1500);
    [config setValue:@(-1) forKey:@"launchPrewarmInterval"];
    XCTAssertEqualObjects([config valueForKey:@"launchPrewarmInterval"],@1500);
}
- (void)testMarkersArrivingAfterCapturedEndpointDoNotReclassifyLaunch {
    self.endMarkerAfterEndpoint=YES;
    [self exerciseThreshold:1500 load:0.25 manual:2000000000 system:NO active:NO assertions:^{
        XCTAssertFalse(self.prewarm); XCTAssertNil(self.fields[@"prewarm_type"]);
        XCTAssertEqualObjects(self.duration,@9000000000LL);
    }];
}
- (void)testSDKStartAfterEndpointCannotProduceNegativeCorrection {
    self.sdkOffset=12;
    [self exerciseThreshold:1500 load:0.25 manual:2000000000 system:NO active:YES assertions:^{
        XCTAssertFalse(self.prewarm); XCTAssertEqualObjects(self.duration,@9000000000LL);
    }];
}
- (void)testMissingLoadDoesNotManufactureCorrection {
    [self exerciseThreshold:1500 load:-1 manual:2000000000 system:NO active:NO assertions:^{
        XCTAssertFalse(self.prewarm); XCTAssertEqualObjects(self.duration,@9000000000LL);
    }];
}
- (void)testLaunchSourceSerializationAndViewEndpointThroughDelayedRUMQueue {
    FTRUMDependencies *dependencies=[FTRUMDependencies new];
    FTPrewarmWriter *writer=[FTPrewarmWriter new];
    dependencies.sampleRate=100; dependencies.writer=writer;
    FTRUMManager *manager=[[FTRUMManager alloc] initWithRumDependencies:dependencies];
    NSDate *start=[NSDate dateWithTimeIntervalSince1970:1000];
    NSDate *end=[NSDate dateWithTimeIntervalSince1970:1009];
    // Queue processing occurs after capture; the real endpoint must survive calibration.
    [manager addLaunch:@"app_warm_start" type:FT_LAUNCH_WARM launchTime:start duration:@1250000000LL
              property:@{@"prewarm_type":@"custom"} endDate:end];
    [manager syncProcess];
    FTRUMWriteData *action=nil, *view=nil;
    for (FTRUMWriteData *event in writer.events) {
        if ([event.source isEqualToString:@"action"]) action=event;
        if ([event.source isEqualToString:@"view"]) view=event;
    }
    XCTAssertNotNil(action); XCTAssertEqualObjects(action.tags[@"prewarm_type"],@"custom");
    XCTAssertNil(action.fields[@"prewarm_type"]); XCTAssertEqualObjects(action.fields[@"duration"],@1250000000LL);
    XCTAssertEqual(action.time,1000000000000LL);
    XCTAssertNotNil(view); XCTAssertEqualObjects(view.fields[@"time_spent"],@9000000000LL);
    XCTAssertNil(view.tags[@"prewarm_type"]); XCTAssertNil(dependencies.sessionReplayStats);
    [manager addLaunch:@"app_hot_start" type:FT_LAUNCH_HOT launchTime:end duration:@1000000000
              property:@{@"prewarm_type":@"custom"}];
    [manager syncProcess];
    for (FTRUMWriteData *event in writer.events) {
        if ([event.tags[@"action_type"] isEqualToString:FT_LAUNCH_HOT]) {
            XCTAssertNil(event.tags[@"prewarm_type"]);
            // A caller-owned hot-action property remains custom data, not an SDK source tag.
            XCTAssertEqualObjects(event.fields[@"prewarm_type"],@"custom");
        }
    }
    [manager shutDown];
}
- (void)testRUMConfigReachesSynchronousLateInitializationAndWritesOnlyLaunchTag {
    self.reportThroughAutoTrack=YES;
    [self exerciseThreshold:1500 load:2 manual:0 system:NO active:YES assertions:^{
        FTRUMDependencies *dependencies=[FTRUMDependencies new];
        FTPrewarmWriter *writer=[FTPrewarmWriter new];
        dependencies.sampleRate=100; dependencies.writer=writer;
        FTRUMManager *manager=[[FTRUMManager alloc] initWithRumDependencies:dependencies];
        FTRumConfig *config=[[FTRumConfig alloc] initWithAppid:@"prewarm-config"];
        config.enableTraceUserAction=YES;
        [config setValue:@1500 forKey:@"launchPrewarmInterval"];
        FTAutoTrackHandler *handler=[FTAutoTrackHandler sharedInstance];
        @try {
            [handler startWithRumConfig:config addRumDatasDelegate:manager heatmapIdentifierRegistry:nil];
            [manager syncProcess];
            NSUInteger launches=0;
            for (FTRUMWriteData *event in writer.events) {
                if ([event.source isEqualToString:@"action"]) {
                    launches++;
                    XCTAssertEqualObjects(event.tags[@"action_type"],FT_LAUNCH_WARM);
                    XCTAssertEqualObjects(event.tags[@"prewarm_type"],@"custom");
                    XCTAssertEqualObjects(event.fields[@"duration"],@7000000000LL);
                    XCTAssertNil(event.fields[@"app_launch_type"]);
                    XCTAssertNil(event.fields[@"prewarm_type"]);
                } else {
                    XCTAssertNil(event.tags[@"prewarm_type"]);
                }
            }
            XCTAssertEqual(launches,1u);
            NSDictionary *replayStats=@{@"segment_count":@3};
            dependencies.sessionReplayStats=replayStats;
            [manager addErrorWithType:@"anr_error" stateStr:@"run" message:@"controlled ANR" stack:@"test" property:nil time:1009000000000LL];
            [manager addLongTaskWithStack:@"controlled freeze" duration:@2000000000LL startTime:1009000000000LL];
            [manager syncProcess];
            NSUInteger errors=0, longTasks=0;
            for (FTRUMWriteData *event in writer.events) {
                if ([event.source isEqualToString:@"error"]) errors++;
                if ([event.source isEqualToString:@"long_task"]) longTasks++;
                if (![event.source isEqualToString:@"action"]) XCTAssertNil(event.tags[@"prewarm_type"]);
            }
            XCTAssertEqual(errors,1u); XCTAssertEqual(longTasks,1u);
            XCTAssertEqualObjects(dependencies.sessionReplayStats,replayStats);
        } @finally { [handler shutDown]; [manager shutDown]; }
    }];
}
- (void)testZeroBeforeLoadIntervalStillAllowsManualInference {
    [self exerciseThreshold:1500 load:0 manual:2000000000 system:NO active:NO assertions:^{
        XCTAssertTrue(self.prewarm); XCTAssertEqualObjects(self.duration,@1000000000LL);
        XCTAssertEqualObjects(self.fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME][@"duration"],@0);
    }];
}
- (void)testMissingStartReverseEqualAndUnavailableClocksDoNotMatch {
    for (NSNumber *pattern in @[@1,@2,@3,@6]) {
        self.markerPattern=pattern.integerValue;
        [self exerciseThreshold:1500 load:0.25 manual:2000000000 system:NO active:NO assertions:^{
            XCTAssertFalse(self.prewarm); XCTAssertEqualObjects(self.duration,@9000000000LL);
        }];
    }
}
- (void)testConcurrentDuplicateStartsKeepFirstValidPair {
    self.markerPattern=4;
    [self exerciseThreshold:1500 load:0.25 manual:2000000000 system:NO active:NO assertions:^{
        XCTAssertTrue(self.prewarm); XCTAssertEqualObjects(self.duration,@1250000000LL);
    }];
}
- (void)testShutdownReinitializationKeepsOneInitialLaunchAndHotLaunchMonitoring {
    self.reportThroughAutoTrack=YES;
    for (NSNumber *mode in @[@0,@1,@2]) {
        BOOL system=mode.integerValue==1;
        NSInteger threshold=mode.integerValue==2 ? 1500 : 0;
        [self exerciseThreshold:threshold load:2 manual:0 system:system active:YES assertions:^{
            FTAutoTrackHandler *handler=[FTAutoTrackHandler sharedInstance];
            FTPrewarmWriter *writer=[FTPrewarmWriter new];
            FTRUMDependencies *dependencies=[FTRUMDependencies new];
            dependencies.sampleRate=100; dependencies.writer=writer;
            FTRUMManager *first=[[FTRUMManager alloc] initWithRumDependencies:dependencies];
            FTRUMManager *second=nil;
            FTRUMManager *third=nil;
            FTRumConfig *config=[[FTRumConfig alloc] initWithAppid:@"launch-reinitialization"];
            config.enableTraceUserAction=YES;
            config.launchPrewarmInterval=threshold;
            Method clock=class_getClassMethod(FTDateUtil.class,@selector(systemTime));
            __block uint64_t tick=10000000000ULL;
            IMP fake=imp_implementationWithBlock(^uint64_t(id receiver){ return tick; });
            IMP original=method_setImplementation(clock,fake);
            @try {
                [handler startWithRumConfig:config addRumDatasDelegate:first heatmapIdentifierRegistry:nil];
                [first syncProcess];
                FTAppLaunchTracker *oldTracker=[handler valueForKey:@"launchTracker"];
                [handler shutDown]; [first shutDown];
                second=[[FTRUMManager alloc] initWithRumDependencies:dependencies];
                [handler startWithRumConfig:config addRumDatasDelegate:second heatmapIdentifierRegistry:nil];
                [second syncProcess];
                // A captured old lifecycle callback must not publish into the new RUM manager.
                [oldTracker applicationDidEnterBackground];
                [oldTracker applicationWillEnterForeground];
                tick+=1000000000ULL;
                [oldTracker applicationDidBecomeActive];
                // The replacement remains subscribed to real lifecycle notifications.
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
                tick+=250000000ULL;
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
                [second syncProcess];
                // Reinitialize while already backgrounded: the new tracker did not
                // observe entry, but must measure the next foreground-to-active pair.
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
                [handler shutDown]; [second shutDown];
                third=[[FTRUMManager alloc] initWithRumDependencies:dependencies];
                [handler startWithRumConfig:config addRumDatasDelegate:third heatmapIdentifierRegistry:nil];
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
                tick+=500000000ULL;
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
                [third syncProcess];
                NSUInteger initial=0, hot=0;
                for (FTRUMWriteData *event in writer.events) {
                    if (![event.source isEqualToString:@"action"]) continue;
                    if ([event.tags[@"action_type"] isEqualToString:FT_LAUNCH_HOT]) {
                        hot++;
                        XCTAssertEqualObjects(event.fields[FT_DURATION],hot==1 ? @250000000 : @500000000);
                    } else {
                        initial++;
                        XCTAssertEqualObjects(event.fields[FT_DURATION],threshold ? @7000000000LL : @9000000000LL);
                        XCTAssertEqualObjects(event.tags[@"action_type"],(system || threshold) ? FT_LAUNCH_WARM : FT_LAUNCH_COLD);
                    }
                }
                XCTAssertEqual(initial,1u);
                XCTAssertEqual(hot,2u);
            } @finally {
                [handler shutDown]; [first shutDown]; [second shutDown]; [third shutDown];
                method_setImplementation(clock,original); imp_removeBlock(fake);
            }
        }];
    }
}
- (void)testShutdownBeforeFirstFrameIgnoresLateCallbackWithoutConsumingInitialLaunch {
    self.reportThroughAutoTrack=YES;
    [self exerciseThreshold:0 load:2 manual:0 system:NO active:NO assertions:^{
        FTQueuedLaunchFrameReader *oldReader=[FTQueuedLaunchFrameReader new];
        FTQueuedLaunchFrameReader *newReader=[FTQueuedLaunchFrameReader new];
        FTAppLaunchTracker *oldTracker=[[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:oldReader];
        [oldTracker shutDown];
        FTAppLaunchTracker *replacement=[[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:newReader];
        NSDate *end=[NSDate dateWithTimeIntervalSince1970:1009];
        @try {
            XCTAssertEqual(oldReader.stops,1u);
            XCTAssertEqual(newReader.starts,1u);
            oldReader.queuedCallback(end);
            XCTAssertEqual(self.reports,0u);
            newReader.queuedCallback(end);
            XCTAssertEqual(self.reports,1u);
            XCTAssertEqualObjects(self.duration,@9000000000LL);
            oldReader.queuedCallback([end dateByAddingTimeInterval:20]);
            newReader.queuedCallback([end dateByAddingTimeInterval:30]);
            XCTAssertEqual(self.reports,1u);
            FTQueuedLaunchFrameReader *laterReader=[FTQueuedLaunchFrameReader new];
            FTAppLaunchTracker *later=[[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:laterReader];
            XCTAssertEqual(laterReader.starts,0u);
            [later shutDown];
        } @finally { [oldTracker shutDown]; [replacement shutDown]; }
    }];
}
- (void)testCompetingTrackersClaimInitialLaunchOnlyOnce {
    self.reportThroughAutoTrack=YES;
    [self exerciseThreshold:0 load:2 manual:0 system:NO active:NO assertions:^{
        NSMutableArray *trackers=[NSMutableArray new];
        for (NSUInteger i=0;i<32;i++) {
            FTAppLaunchTracker *tracker=[FTAppLaunchTracker new]; tracker.delegate=self;
            [trackers addObject:tracker];
        }
        NSDate *end=[NSDate dateWithTimeIntervalSince1970:1009];
        dispatch_apply(trackers.count,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^(size_t index) {
            [trackers[index] reportAppLaunchPhaseDuration:end];
        });
        XCTAssertEqual(self.reports,1u);
        XCTAssertEqualObjects(self.duration,@9000000000LL);
    }];
}
@end
