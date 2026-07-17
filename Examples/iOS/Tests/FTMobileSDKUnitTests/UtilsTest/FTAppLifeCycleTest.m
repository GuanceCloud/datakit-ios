//
//  FTAppLifeCycleTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/21.
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
#import "FTAppLifeCycle.h"
#import "FTLog.h"
@interface FTAppLifeCycleSelfRemovingDelegate : NSObject<FTAppLifeCycleDelegate>
@property (nonatomic, assign) NSInteger applicationDidBecomeActiveCount;
@end
@implementation FTAppLifeCycleSelfRemovingDelegate
- (void)applicationDidBecomeActive{
    self.applicationDidBecomeActiveCount += 1;
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
@end

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
    XCTAssertTrue(self.applicationDidBecomeActiveCount-count > 0);
}

- (void)testApplicationWillResignActive{
    NSInteger count = self.applicationWillResignActiveCount;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertTrue(self.applicationWillResignActiveCount-count == 1);
}

#if FT_HOST_IOS
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
- (void)testLifecycleDelegateCanRemoveItselfDuringCallback{
    FTAppLifeCycleSelfRemovingDelegate *delegate = [[FTAppLifeCycleSelfRemovingDelegate alloc] init];
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:delegate];

    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];

    XCTAssertEqual(delegate.applicationDidBecomeActiveCount, 1);
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

#if FT_HOST_IOS
- (void)applicationWillEnterForeground{
    self.applicationWillEnterForegroundCount += 1;
}
- (void)applicationDidEnterBackground{
    self.applicationDidEnterBackgroundCount += 1;
}
#endif
@end
