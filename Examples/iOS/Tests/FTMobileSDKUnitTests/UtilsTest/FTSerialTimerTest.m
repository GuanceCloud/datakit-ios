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

//
//  FTSerialTimerTest.m
//  FTMobileSDKUnitTests
//
//

#import <XCTest/XCTest.h>
#import "FTSerialTimer.h"

@interface FTSerialTimerTest : XCTestCase

@end

@implementation FTSerialTimerTest

- (void)testDefaultQueueScheduleAfterFiresOnce{
    XCTestExpectation *expectation = [self expectationWithDescription:@"timer fired on default queue"];
    __block NSInteger fireCount = 0;
    FTSerialTimer *timer = [[FTSerialTimer alloc] initWithEventHandler:^{
        fireCount += 1;
        [expectation fulfill];
    }];

    [timer scheduleAfter:0.02 leeway:0];

    [self waitForExpectations:@[expectation] timeout:1];
    [NSThread sleepForTimeInterval:0.05];
    XCTAssertEqual(fireCount, 1);
    [timer invalidate];
}

- (void)testScheduleAfterFiresOnce{
    XCTestExpectation *expectation = [self expectationWithDescription:@"timer fired"];
    dispatch_queue_t queue = dispatch_queue_create("com.ft.test.serial_timer.fire", DISPATCH_QUEUE_SERIAL);
    __block NSInteger fireCount = 0;
    FTSerialTimer *timer = [[FTSerialTimer alloc] initWithQueue:queue eventHandler:^{
        fireCount += 1;
        [expectation fulfill];
    }];

    [timer scheduleAfter:0.02 leeway:0];

    [self waitForExpectations:@[expectation] timeout:1];
    [NSThread sleepForTimeInterval:0.05];
    dispatch_sync(queue, ^{
        XCTAssertEqual(fireCount, 1);
    });
    [timer invalidate];
}

- (void)testCancelPreventsPendingFire{
    XCTestExpectation *unexpectedFire = [self expectationWithDescription:@"timer should not fire after cancel"];
    unexpectedFire.inverted = YES;
    dispatch_queue_t queue = dispatch_queue_create("com.ft.test.serial_timer.cancel", DISPATCH_QUEUE_SERIAL);
    __block NSInteger fireCount = 0;
    FTSerialTimer *timer = [[FTSerialTimer alloc] initWithQueue:queue eventHandler:^{
        fireCount += 1;
        [unexpectedFire fulfill];
    }];

    [timer scheduleAfter:0.05 leeway:0];
    [timer cancel];

    [self waitForExpectations:@[unexpectedFire] timeout:0.2];
    dispatch_sync(queue, ^{
        XCTAssertEqual(fireCount, 0);
    });
    [timer invalidate];
}

- (void)testInvalidatePreventsPendingAndFutureFires{
    XCTestExpectation *unexpectedFire = [self expectationWithDescription:@"timer should not fire after invalidate"];
    unexpectedFire.inverted = YES;
    dispatch_queue_t queue = dispatch_queue_create("com.ft.test.serial_timer.invalidate", DISPATCH_QUEUE_SERIAL);
    __block NSInteger fireCount = 0;
    FTSerialTimer *timer = [[FTSerialTimer alloc] initWithQueue:queue eventHandler:^{
        fireCount += 1;
        [unexpectedFire fulfill];
    }];

    [timer scheduleAfter:0.05 leeway:0];
    [timer invalidate];
    [timer scheduleAfter:0.01 leeway:0];
    [timer cancel];

    [self waitForExpectations:@[unexpectedFire] timeout:0.2];
    dispatch_sync(queue, ^{
        XCTAssertEqual(fireCount, 0);
    });
}

- (void)testConcurrentScheduleCancelAndInvalidateIsSafe{
    XCTestExpectation *expectation = [self expectationWithDescription:@"concurrent timer operations finished"];
    dispatch_queue_t timerQueue = dispatch_queue_create("com.ft.test.serial_timer.concurrent.timer", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t operationQueue = dispatch_queue_create("com.ft.test.serial_timer.concurrent.operation", DISPATCH_QUEUE_CONCURRENT);
    FTSerialTimer *timer = [[FTSerialTimer alloc] initWithQueue:timerQueue eventHandler:^{
    }];
    dispatch_group_t group = dispatch_group_create();

    for (NSInteger i = 0; i < 300; i++) {
        dispatch_group_async(group, operationQueue, ^{
            NSInteger action = i % 3;
            if (action == 0) {
                [timer scheduleAfter:0.001 leeway:0];
            } else if (action == 1) {
                [timer cancel];
            } else {
                [timer invalidate];
            }
        });
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [timer invalidate];
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
}

@end
