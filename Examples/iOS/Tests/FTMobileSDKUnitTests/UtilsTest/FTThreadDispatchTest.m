//
//  FTThreadDispatchTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/20.
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
#import "FTThreadDispatchManager.h"
#import "FTModuleManager.h"
#import "FTMessageReceiver.h"

@interface FTBlockingMessageReceiver : NSObject<FTMessageReceiver>
@property (nonatomic, assign) BOOL blocksReceive;
@property (nonatomic, assign) NSInteger receiveCount;
@property (nonatomic, strong) dispatch_semaphore_t didEnterReceive;
@property (nonatomic, strong) dispatch_semaphore_t unblockReceive;
@end

@implementation FTBlockingMessageReceiver
- (instancetype)init{
    self = [super init];
    if (self) {
        _didEnterReceive = dispatch_semaphore_create(0);
        _unblockReceive = dispatch_semaphore_create(0);
    }
    return self;
}
- (void)receive:(NSString *)key message:(NSDictionary *)message{
    @synchronized (self) {
        self.receiveCount += 1;
    }
    if (self.blocksReceive) {
        dispatch_semaphore_signal(self.didEnterReceive);
        dispatch_semaphore_wait(self.unblockReceive, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    }
}
@end

@interface FTThreadDispatchTest : XCTestCase

@end

@implementation FTThreadDispatchTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
/**
 * Main thread synchronous execution
 */
- (void)testPerformBlockDispatchMainSyncSafe{
    __block NSString *string = @"1";
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        XCTAssertFalse([NSThread currentThread].isMainThread);
        [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
            XCTAssertTrue([NSThread currentThread].isMainThread);
            [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
                XCTAssertTrue([NSThread currentThread].isMainThread);
                [NSThread sleepForTimeInterval:0.5];
                string = [string stringByAppendingString:@"2"];
            }];
            string = [string stringByAppendingString:@"3"];
        }];
        [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
            XCTAssertTrue([NSThread currentThread].isMainThread);
            string = [string stringByAppendingString:@"4"];
        }];
        XCTAssertTrue([string isEqualToString:@"1234"]);
    });
}
/**
 * Main thread asynchronous execution
 */
- (void)testPerformBlockDispatchMainAsync{
    __block NSString *string = @"1";
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        XCTAssertFalse([NSThread currentThread].isMainThread);
        [FTThreadDispatchManager performBlockDispatchMainAsync:^{
            XCTAssertTrue([NSThread currentThread].isMainThread);
            [FTThreadDispatchManager performBlockDispatchMainAsync:^{
                XCTAssertTrue([NSThread currentThread].isMainThread);
                string = [string stringByAppendingString:@"2"];
                XCTAssertFalse([string isEqualToString:@"132"]);
            }];
            string = [string stringByAppendingString:@"3"];
        }];
        [FTThreadDispatchManager performBlockDispatchMainAsync:^{
            XCTAssertTrue([NSThread currentThread].isMainThread);
                [NSThread sleepForTimeInterval:0.5];
                string = [string stringByAppendingString:@"4"];
        }];
       
        XCTAssertFalse([string isEqualToString:@"1234"]);

    });
}
- (void)testRemoveMessageReceiverDoesNotWaitForBusyMessageBus{
    FTModuleManager *manager = [FTModuleManager sharedInstance];
    FTBlockingMessageReceiver *receiver = [[FTBlockingMessageReceiver alloc]init];
    [manager addMessageReceiver:receiver];
    [manager postMessageWithKey:@"ft_test_message_bus_flush_add" message:@{} sync:YES];

    receiver.blocksReceive = YES;
    [manager postMessageWithKey:@"ft_test_message_bus_block" message:@{}];
    long entered = dispatch_semaphore_wait(receiver.didEnterReceive, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    XCTAssertEqual(entered, 0);

    XCTestExpectation *removeReturned = [self expectationWithDescription:@"remove should not wait for message-bus work"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [manager removeMessageReceiver:receiver];
        [removeReturned fulfill];
    });

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[removeReturned] timeout:0.2];
    XCTAssertEqual(result, XCTWaiterResultCompleted);

    dispatch_semaphore_signal(receiver.unblockReceive);
    [manager postMessageWithKey:@"ft_test_message_bus_flush_remove" message:@{} sync:YES];
}
- (void)testRemoveMessageReceiverTakesEffectBeforeFollowingSyncPost{
    FTModuleManager *manager = [FTModuleManager sharedInstance];
    FTBlockingMessageReceiver *receiver = [[FTBlockingMessageReceiver alloc]init];
    [manager addMessageReceiver:receiver];
    [manager postMessageWithKey:@"ft_test_message_bus_flush_add" message:@{} sync:YES];
    NSInteger countAfterAdd = receiver.receiveCount;

    [manager removeMessageReceiver:receiver];
    [manager postMessageWithKey:@"ft_test_message_bus_after_remove" message:@{} sync:YES];

    XCTAssertEqual(receiver.receiveCount, countAfterAdd);
}
@end
