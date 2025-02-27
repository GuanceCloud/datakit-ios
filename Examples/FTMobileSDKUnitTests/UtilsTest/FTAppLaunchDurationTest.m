//
//  FTAppLaunchDurationTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/9/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTAppLaunchTracker.h"
#import "FTRUMManager.h"
#import "NSDate+FTUtil.h"
#import "FTMobileConfig.h"
#import "FTConstants.h"
typedef void(^LaunchBlock)( NSNumber * _Nullable duration, FTLaunchType type);
typedef void(^LaunchDataBlock)(NSString *source, NSDictionary *tags, NSDictionary *fields);

@interface FTAppLaunchDurationTest : XCTestCase<FTAppLaunchDataDelegate,FTRUMDataWriteProtocol>
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
@property (nonatomic, copy) LaunchBlock launchBlock;
@property (nonatomic, copy) LaunchDataBlock launchDataBlock;

@end

@implementation FTAppLaunchDurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.launchBlock = nil;
    self.launchTracker = nil;
}
- (void)testLaunchCold{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type) {
        XCTAssertTrue(type == FTLaunchCold);
        [expectation fulfill];
    };
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
}

- (void)testStartSdkAfterLaunch{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type) {
        XCTAssertTrue(type == FTLaunchCold);
        [expectation fulfill];
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
}
- (void)testLaunchHot{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type) {
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
- (void)testLaunchPrewarm{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type) {
        if(type == FTLaunchWarm){
            [expectation fulfill];
        }
    };
    setenv("ActivePrewarm", "1", 1);
    [NSClassFromString(@"FTAppLaunchTracker") load];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
    setenv("ActivePrewarm", "", 1);
    [NSClassFromString(@"FTAppLaunchTracker") load];
}
- (void)testLaunchWarmDataNotHasViewData{
    [self launchData:FTLaunchWarm];
}
#endif
- (void)testLaunchColdDataNotHasViewData{
    [self launchData:FTLaunchCold];
}
- (void)testLaunchHotData{
    [self launchData:FTLaunchHot];
}
- (void)launchData:(FTLaunchType)type{
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.writer = self;
    dependencies.errorMonitorType = ErrorMonitorAll;
    dependencies.sampleRate = 100;
    FTRUMManager *manager = [[FTRUMManager alloc]initWithRumDependencies:dependencies];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchDataBlock = ^(NSString *source, NSDictionary *tags, NSDictionary *fields) {
        if([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            switch (type) {
                case FTLaunchHot:
                    XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_LAUNCH_HOT]);
                    XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                    break;
                case FTLaunchWarm:
                    XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_LAUNCH_WARM]);
                    XCTAssertFalse([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                    break;
                case FTLaunchCold:
                    XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_LAUNCH_COLD]);
                    XCTAssertFalse([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                    break;
            }
            [expectation fulfill];
        }
    };
    [manager startViewWithName:@"Test"];
    [manager addLaunch:type launchTime:[NSDate date] duration:@123];
    [manager syncProcess];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming {
    NSNumber *maxDuration = [launchTime ft_nanosecondTimeIntervalToDate:[NSDate date]];
    XCTAssertTrue(maxDuration.longLongValue>duration.longLongValue);
    if(self.launchBlock){
        self.launchBlock(duration, isPreWarming?FTLaunchWarm:FTLaunchCold);
    }
}
- (void)ftAppHotStart:(NSDate *)launchTime duration:(NSNumber *)duration{ 
    NSNumber *maxDuration = [launchTime ft_nanosecondTimeIntervalToDate:[NSDate date]];
    XCTAssertTrue(maxDuration.longLongValue>duration.longLongValue);
    if(self.launchBlock){
        self.launchBlock(duration, FTLaunchHot);
    }
}
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    if(self.launchDataBlock){
        self.launchDataBlock(source, tags, fields);
    }
}
    
- (void)rumWrite:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields {
    if(self.launchDataBlock){
        self.launchDataBlock(source, tags, fields);
    }
}
    

@end
