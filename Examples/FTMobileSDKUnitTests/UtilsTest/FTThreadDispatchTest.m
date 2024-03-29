//
//  FTThreadDispatchTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTThreadDispatchManager.h"

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
 * 主线程同步执行
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
 * 主线程异步执行
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
@end
