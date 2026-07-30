//
//  FTAppLaunchDurationTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/9/8.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTAppLaunchTracker.h"
#import "FTRUMManager.h"
#import "NSDate+FTUtil.h"
#import "FTMobileConfig.h"
#import "FTConstants.h"
#import "FTActionTrackingHandler.h"
#import "FTFirstFrameReader.h"
#import "FTDateUtil.h"
#if TARGET_OS_IOS
#import <mach/task_policy.h>
#endif

typedef void(^LaunchBlock)( NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *_Nullable fields);
typedef void(^LaunchDataBlock)(NSString *source, NSDictionary *tags, NSDictionary *fields);
@interface FTAppLaunchTracker (Testing)
- (void)reportAppLaunchPhaseDuration:(NSDate *)endDate;
- (void)applicationDidBecomeActive;
- (instancetype)initWithDelegate:(nullable id)delegate
                firstFrameReader:(nullable FTFirstFrameReader *)firstFrameReader;
@end

@interface FTFirstFrameReader (Testing)
- (void)didUpdateFrameAtTimestamp:(CFTimeInterval)timestamp;
@end

@interface FTMockFirstFrameReader : FTFirstFrameReader
@property (nonatomic, copy, nullable) FTFirstFrameCallback callback;
@property (nonatomic, assign) NSUInteger startCount;
@property (nonatomic, assign) NSUInteger stopCount;
- (void)sendFirstFrameAtDate:(NSDate *)date;
@end

@implementation FTMockFirstFrameReader
- (void)startWithCallback:(FTFirstFrameCallback)callback {
    self.startCount += 1;
    self.callback = callback;
}
- (void)stop {
    self.stopCount += 1;
}
- (void)sendFirstFrameAtDate:(NSDate *)date {
    FTFirstFrameCallback callback = self.callback;
    self.callback = nil;
    if (callback) {
        callback(date);
    }
}
@end

@interface FTAppLaunchDurationTest : XCTestCase<FTAppLaunchDataDelegate,FTRUMDataWriteProtocol>
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
@property (nonatomic, copy) LaunchBlock launchBlock;
@property (nonatomic, copy) LaunchDataBlock launchDataBlock;

@end

#if TARGET_OS_IOS && (defined(DEBUG) || defined(FTSDKUNITTEST))
void FTClearLaunchTaskRole(void);
#endif

@implementation FTAppLaunchDurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)testFirstFrameReaderStartedFromBackgroundConsumesOnlyFirstFrame {
    NSDate *now = [NSDate date];
    FTFirstFrameReader *reader = [[FTFirstFrameReader alloc]
                                  initWithDateProvider:^NSDate *{
        return now;
    } mediaTimeProvider:^CFTimeInterval{
        return 100;
    }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"First frame callback"];
    __block NSUInteger callbackCount = 0;
    __block NSDate *firstFrameDate = nil;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [reader startWithCallback:^(NSDate *date) {
            callbackCount += 1;
            firstFrameDate = date;
            [expectation fulfill];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [reader didUpdateFrameAtTimestamp:99.75];
            [reader didUpdateFrameAtTimestamp:100];
        });
    });

    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertEqual(callbackCount, 1);
    XCTAssertEqualWithAccuracy([firstFrameDate timeIntervalSinceDate:now], -0.25, 0.001);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.launchBlock = nil;
    self.launchTracker = nil;
#if TARGET_OS_IOS && (defined(DEBUG) || defined(FTSDKUNITTEST))
    FTClearLaunchTaskRole();
#endif
}
- (void)testLaunchCold{
    XCTestExpectation *expectation= [self expectationWithDescription:@"LaunchBlock timeout"];

    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchCold);
        [expectation fulfill];
    };
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification object:nil];
    sleep(0.1);
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
}

- (void)testStartSdkAfterLaunch{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchCold);
        [expectation fulfill];
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
}
- (void)testLaunchHot{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        if(type == FTLaunchHot){
            [expectation fulfill];
        }
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
}
#if TARGET_OS_IOS
#if defined(DEBUG) || defined(FTSDKUNITTEST)
- (void)testLaunchPrewarm{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchWarm);
            [expectation fulfill];
    };
    FTSetIsActivePrewarm(YES);
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification object:nil];
    sleep(0.1);
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
    FTSetIsActivePrewarm(NO);
}
#endif
- (void)testLaunchWarmDataHasViewData{
    [self launchData:FTLaunchWarm];
}
#endif
- (void)testLaunchColdDataHasViewData{
    [self launchData:FTLaunchCold];
}
- (void)testLaunchHotData{
    [self launchData:FTLaunchHot];
}
#pragma mark ---- test launch fields ---
#if defined(DEBUG) || defined(FTSDKUNITTEST)
NSDate *FTGetApplicationDidBecomeActive(void);
void FTSetApplicationDidBecomeActive(NSDate *date);
NSDate *FTGetModuleInitializationTimestamp(void);
void FTSetModuleInitializationTimestamp(NSDate *date);
NSDate *FTGetRuntimeInit(void);
void FTSetRuntimeInit(NSDate *date);
BOOL FTGetIsActivePrewarm(void);
void FTSetIsActivePrewarm(BOOL active);
#if TARGET_OS_IOS
void FTSetLaunchTaskRole(NSInteger role);
void FTClearLaunchTaskRole(void);
#endif

- (void)testLaunchTimeSequence_ProcessStart_RuntimeInit_ModuleInit_AppActive_ShouldBeAscendingOrder{
    NSDate *processStartTimestamp = [FTDateUtil processStartTimestamp];
    NSDate *runtimeInit = FTGetRuntimeInit();
    NSDate *moduleInitializationTimestamp = FTGetModuleInitializationTimestamp();
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();

    XCTAssertTrue([processStartTimestamp compare:runtimeInit] == NSOrderedAscending);
    XCTAssertTrue([runtimeInit compare:moduleInitializationTimestamp] == NSOrderedAscending);
    XCTAssertTrue([moduleInitializationTimestamp compare:applicationDidBecomeActive] == NSOrderedAscending);
}

#if TARGET_OS_IOS
- (void)testLaunchColdAppLaunchTypeWhenTaskRoleIsForegroundApplication{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async operation timeout"];
    FTSetLaunchTaskRole(TASK_FOREGROUND_APPLICATION);
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (!applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive([NSDate date]);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchCold);
        XCTAssertEqualObjects(fields[FT_KEY_APP_LAUNCH_TYPE], FT_APP_LAUNCH_TYPE_FOREGROUND);
        [expectation fulfill];
    };
    FTAppLaunchTracker *launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];
    [self waitForExpectations:@[expectation] timeout:2];
    self.launchTracker = launchTracker;
    FTClearLaunchTaskRole();
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}

- (void)testLaunchColdAppLaunchTypeWhenTaskRoleIsNotForegroundApplication{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async operation timeout"];
    FTSetLaunchTaskRole(TASK_BACKGROUND_APPLICATION);
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (!applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive([NSDate date]);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchCold);
        XCTAssertEqualObjects(fields[FT_KEY_APP_LAUNCH_TYPE], FT_APP_LAUNCH_TYPE_BACKGROUND);
        [expectation fulfill];
    };
    FTAppLaunchTracker *launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];
    [self waitForExpectations:@[expectation] timeout:2];
    self.launchTracker = launchTracker;
    FTClearLaunchTaskRole();
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
#endif

- (void)testLaunchWhenSDKInitAfterApplicationDidBecomeActive_cold{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (!applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive([NSDate date]);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_RUNTIME_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_APP_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };
    FTAppLaunchTracker *launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];
    [self waitForExpectations:@[expectation] timeout:2];
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
- (void)testLaunchColdReportOnlyOnce{
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:-0.001];
    FTSetApplicationDidBecomeActive(endDate);

    __block NSUInteger reportCount = 0;
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        reportCount++;
    };
    FTAppLaunchTracker *launchTracker = [FTAppLaunchTracker new];
    launchTracker.delegate = self;
    [launchTracker reportAppLaunchPhaseDuration:endDate];
    [launchTracker reportAppLaunchPhaseDuration:endDate];

    XCTAssertEqual(reportCount, 1);
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
- (void)testLaunchWhenFirstFrameReaderNilReportsOnApplicationDidBecomeActive{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive(nil);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];

    __block NSUInteger reportCount = 0;
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        reportCount++;
        XCTAssertTrue(type == FTLaunchCold);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_APP_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };

    self.launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:nil];
    XCTAssertEqual(reportCount, 0);
    [self.launchTracker applicationDidBecomeActive];

    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertEqual(reportCount, 1);
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
- (void)testLaunchWithFirstFrameReaderWaitsForFirstFrameAfterApplicationDidBecomeActive{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive(nil);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];

    __block NSUInteger reportCount = 0;
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        reportCount++;
        XCTAssertTrue(type == FTLaunchCold);
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };

    FTMockFirstFrameReader *firstFrameReader = [FTMockFirstFrameReader new];
    self.launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:firstFrameReader];
    [self.launchTracker applicationDidBecomeActive];
    XCTAssertEqual(reportCount, 0);
    XCTAssertEqual(firstFrameReader.startCount, 1);
    XCTAssertNotNil(firstFrameReader.callback);
    [firstFrameReader sendFirstFrameAtDate:[NSDate date]];

    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertEqual(reportCount, 1);
    XCTAssertEqual(firstFrameReader.stopCount, 1);
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
- (void)testLaunchSkipsInvalidPhaseButReportsLaunch{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    NSDate *runtimeInit = FTGetRuntimeInit();
    NSDate *moduleInitializationTimestamp = FTGetModuleInitializationTimestamp();
    BOOL isActivePrewarm = FTGetIsActivePrewarm();

    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:-0.001];
    FTSetApplicationDidBecomeActive(endDate);
    FTSetRuntimeInit([endDate dateByAddingTimeInterval:-0.001]);
    FTSetModuleInitializationTimestamp([endDate dateByAddingTimeInterval:-0.002]);
    FTSetIsActivePrewarm(NO);

    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchCold);
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_RUNTIME_INIT_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };
    FTAppLaunchTracker *launchTracker = [FTAppLaunchTracker new];
    launchTracker.delegate = self;
    [launchTracker reportAppLaunchPhaseDuration:endDate];

    [self waitForExpectations:@[expectation] timeout:2];
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
    FTSetRuntimeInit(runtimeInit);
    FTSetModuleInitializationTimestamp(moduleInitializationTimestamp);
    FTSetIsActivePrewarm(isActivePrewarm);
}
- (void)testLaunchSkipsMissingPhaseButReportsLaunch{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];

    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    NSDate *runtimeInit = FTGetRuntimeInit();
    BOOL isActivePrewarm = FTGetIsActivePrewarm();

    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:-0.001];
    FTSetApplicationDidBecomeActive(endDate);
    FTSetRuntimeInit(nil);
    FTSetIsActivePrewarm(NO);

    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type, NSDictionary *fields) {
        XCTAssertTrue(type == FTLaunchCold);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_RUNTIME_INIT_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };
    FTAppLaunchTracker *launchTracker = [FTAppLaunchTracker new];
    launchTracker.delegate = self;
    [launchTracker reportAppLaunchPhaseDuration:endDate];

    [self waitForExpectations:@[expectation] timeout:2];
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
    FTSetRuntimeInit(runtimeInit);
    FTSetIsActivePrewarm(isActivePrewarm);
}
#if TARGET_OS_IOS
- (void)testLaunchWhenSDKInitAfterApplicationDidBecomeActive_prewarm{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    FTSetIsActivePrewarm(YES);
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (!applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive([NSDate date]);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_RUNTIME_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_APP_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };
    FTAppLaunchTracker *launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:[FTFirstFrameReader new]];
    [self waitForExpectations:@[expectation] timeout:2];
    FTSetIsActivePrewarm(NO);
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
#endif
- (void)testLaunchWhenSDKInitBeforeApplicationDidBecomeActive_cold{
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive(nil);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        NSDictionary *preRuntimeInit = fields[FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME];
        NSDictionary *runtimeInit = fields[FT_KEY_LAUNCH_RUNTIME_INIT_TIME];
        NSDictionary *uikitInit = fields[FT_KEY_LAUNCH_UIKITI_INIT_TIME];
        NSDictionary *appInit = fields[FT_KEY_LAUNCH_APP_INIT_TIME];
        NSDictionary *firstFrame = fields[FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME];
        XCTAssertTrue(preRuntimeInit);
        XCTAssertTrue(runtimeInit);
        XCTAssertTrue(uikitInit);
        XCTAssertTrue(appInit);
        XCTAssertTrue(firstFrame);

        XCTAssertTrue([preRuntimeInit[FT_KEY_START] compare:runtimeInit[FT_KEY_START]] == NSOrderedAscending);
        XCTAssertTrue([runtimeInit[FT_KEY_START] compare:uikitInit[FT_KEY_START]] == NSOrderedAscending);
        XCTAssertTrue([uikitInit[FT_KEY_START] compare:appInit[FT_KEY_START]] == NSOrderedAscending);
        XCTAssertTrue([appInit[FT_KEY_START] compare:firstFrame[FT_KEY_START]] == NSOrderedAscending);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };
    FTFirstFrameReader *firstFrameReader = [FTFirstFrameReader new];
    FTAppLaunchTracker *launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:firstFrameReader];
    [self waitForExpectations:@[expectation] timeout:10];
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
#if TARGET_OS_IOS
- (void)testLaunchWhenSDKInitBeforeApplicationDidBecomeActive_prewarm{

    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    FTSetIsActivePrewarm(YES);
    NSDate *applicationDidBecomeActive = FTGetApplicationDidBecomeActive();
    if (applicationDidBecomeActive) {
        FTSetApplicationDidBecomeActive(nil);
    }
    [FTAppLaunchTracker setSdkStartDate:[NSDate date]];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type,NSDictionary *fields) {
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME]);
        XCTAssertFalse([fields.allKeys containsObject:FT_KEY_LAUNCH_RUNTIME_INIT_TIME]);
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_UIKITI_INIT_TIME]);
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_APP_INIT_TIME]);
        XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME]);
        XCTAssertTrue(duration.longLongValue > 0);
        [expectation fulfill];
    };
    FTFirstFrameReader *firstFrameReader = [FTFirstFrameReader new];
    FTAppLaunchTracker *launchTracker = [[FTAppLaunchTracker alloc] initWithDelegate:self firstFrameReader:firstFrameReader];
    [self waitForExpectations:@[expectation] timeout:5];
    FTSetIsActivePrewarm(NO);
    FTSetApplicationDidBecomeActive(applicationDidBecomeActive);
}
#endif
#endif
- (void)launchData:(FTLaunchType)type{
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.writer = self;
    dependencies.sampleRate = 100;
    dependencies.appId = @"testAppId";
    FTRUMManager *manager = [[FTRUMManager alloc]initWithRumDependencies:dependencies];
    NSString *actionName;
    NSString *actionType;
    switch (type) {
        case FTLaunchHot:
            actionName = @"app_hot_start";
            actionType = FT_LAUNCH_HOT;
            break;
        case FTLaunchCold:
            actionName = @"app_cold_start";
            actionType = FT_LAUNCH_COLD;
            break;
        case FTLaunchWarm:
            actionName = @"app_warm_start";
            actionType = FT_LAUNCH_WARM;
    }
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    self.launchDataBlock = ^(NSString *source, NSDictionary *tags, NSDictionary *fields) {
        if([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            switch (type) {
                case FTLaunchHot:
                    XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_LAUNCH_HOT]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_APP_ID]);
                    break;
                case FTLaunchWarm:
                    XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_LAUNCH_WARM]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_APP_ID]);
                    break;
                case FTLaunchCold:
                    XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_LAUNCH_COLD]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_APP_ID]);
                    break;
            }
            [expectation fulfill];
        }
    };
    [manager startViewWithName:@"Test"];

    [manager addLaunch:actionName type:actionType launchTime:[NSDate date] duration:@123 property:nil];
    [manager syncProcess];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming fields:(nonnull NSDictionary *)fields{
    NSNumber *maxDuration = [launchTime ft_nanosecondTimeIntervalToDate:[NSDate date]];
    XCTAssertTrue(maxDuration.longLongValue>duration.longLongValue);
    XCTAssertNotNil(fields);
    if(self.launchBlock){
        self.launchBlock(duration, isPreWarming?FTLaunchWarm:FTLaunchCold,fields);
    }
}
- (void)ftAppHotStart:(NSDate *)launchTime duration:(NSNumber *)duration{
    NSNumber *maxDuration = [launchTime ft_nanosecondTimeIntervalToDate:[NSDate date]];
    XCTAssertTrue(maxDuration.longLongValue>duration.longLongValue);
    if(self.launchBlock){
        self.launchBlock(duration, FTLaunchHot,nil);
    }
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time{
    if(self.launchDataBlock){
        self.launchDataBlock(source, tags, fields);
    }
}

- (void)rumWrite:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime {

}


- (void)rumWrite:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache {

}



@end
