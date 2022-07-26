//
//  FTAppLifeCycleTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/21.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTAppLifeCycle.h"

@interface FTAppLifeCycleTest : XCTestCase<FTAppLifeCycleDelegate>
@property (nonatomic,assign) NSInteger applicationWillTerminateCount;
@property (nonatomic,assign) NSInteger applicationDidBecomeActiveCount;
@property (nonatomic,assign) NSInteger applicationWillResignActiveCount;
@property (nonatomic,assign) NSInteger applicationWillEnterForegroundCount;
@property (nonatomic,assign) NSInteger applicationDidEnterBackgroundCount;

@end

@implementation FTAppLifeCycleTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}

- (void)testApplicationWillTerminate{

    NSInteger count = self.applicationWillTerminateCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillTerminateNotification object:nil];
    XCTAssertTrue(self.applicationWillTerminateCount-count == 1);
    
}

- (void)testApplicationDidBecomeActive{
    NSInteger count = self.applicationDidBecomeActiveCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    XCTAssertTrue(self.applicationDidBecomeActiveCount-count == 1);
}

- (void)testApplicationWillResignActive{
    NSInteger count = self.applicationWillResignActiveCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertTrue(self.applicationWillResignActiveCount-count == 1);
}

#if TARGET_OS_IOS
- (void)testApplicationWillEnterForeground{
    NSInteger count = self.applicationWillEnterForegroundCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    XCTAssertTrue(self.applicationWillEnterForegroundCount-count == 1);
}
- (void)testApplicationDidEnterBackground{
    NSInteger count = self.applicationDidEnterBackgroundCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    XCTAssertTrue(self.applicationDidEnterBackgroundCount-count == 1);
}
#endif
- (void)testRemoveAppLifecycleDelegate{
    NSInteger count = self.applicationWillTerminateCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillTerminateNotification object:nil];
    XCTAssertTrue(self.applicationWillTerminateCount-count == 1);
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillTerminateNotification object:nil];
    XCTAssertTrue(self.applicationWillTerminateCount-count == 1);

}
- (void)applicationWillTerminate{
    self.applicationWillTerminateCount += 1;
}

- (void)applicationDidBecomeActive{
    self.applicationDidBecomeActiveCount += 1;
}

- (void)applicationWillResignActive{
    self.applicationWillResignActiveCount += 1;
}

#if TARGET_OS_IOS
- (void)applicationWillEnterForeground{
    self.applicationWillEnterForegroundCount += 1;
}
- (void)applicationDidEnterBackground{
    self.applicationDidEnterBackgroundCount += 1;
}
#endif
@end
