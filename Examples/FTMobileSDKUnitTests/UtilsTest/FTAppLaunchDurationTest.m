//
//  FTAppLaunchDurationTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/9/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import "FTAppLaunchTracker.h"
#import "FTRUMManager.h"
typedef void(^LaunchBlock)( NSNumber * _Nullable duration, FTLaunchType type);

@interface FTAppLaunchDurationTest : KIFTestCase<FTAppLaunchDataDelegate>
@property (nonatomic, strong) FTAppLaunchTracker *launchtracker;
@property (nonatomic, copy) LaunchBlock launchBlock;
@end

@implementation FTAppLaunchDurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testLaunchCold{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchBlock = ^(NSNumber * _Nullable duration, FTLaunchType type) {
        XCTAssertTrue(type == FTLaunchCold);
        [expectation fulfill];
    };
    self.launchtracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
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
    self.launchtracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
}
- (void)testLaunchHot{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.launchtracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
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
    self.launchtracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.launchBlock = nil;
    setenv("ActivePrewarm", "", 1);
    [NSClassFromString(@"FTAppLaunchTracker") load];
}
- (void)ftAppColdStart:(nonnull NSNumber *)duration isPreWarming:(BOOL)isPreWarming { 
    if(self.launchBlock){
        self.launchBlock(duration, isPreWarming?FTLaunchWarm:FTLaunchCold);
    }
}
- (void)ftAppHotStart:(nonnull NSNumber *)duration { 
    if(self.launchBlock){
        self.launchBlock(duration, FTLaunchHot);
    }
}

@end
