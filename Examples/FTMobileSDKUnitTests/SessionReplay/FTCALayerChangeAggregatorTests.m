//
//  FTCALayerChangeAggregatorTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/4/17.
//  Copyright © 2026 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTCALayerChangeAggregator.h"

@interface FTTestScheduledTimer : NSObject <FTScheduledTimer>
@property (nonatomic, assign) NSTimeInterval fireTime;
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, copy) dispatch_block_t action;
- (void)fire;
@end

@implementation FTTestScheduledTimer

- (instancetype)initWithFireTime:(NSTimeInterval)fireTime action:(dispatch_block_t)action {
    if (self = [super init]) {
        _fireTime = fireTime;
        _action = [action copy];
    }
    return self;
}

- (void)cancel {
    self.cancelled = YES;
    self.action = nil;
}

- (void)fire {
    if (self.isCancelled) {
        return;
    }
    
    dispatch_block_t action = self.action;
    [self cancel];
    
    if (action) {
        action();
    }
}

@end

@interface FTTestTimerScheduler : NSObject <FTTimerScheduler>
@property (nonatomic, assign) NSTimeInterval now;
@property (nonatomic, strong) NSMutableArray<FTTestScheduledTimer *> *timers;
- (void)advanceToTime:(NSTimeInterval)time;
@end

@implementation FTTestTimerScheduler

- (instancetype)init {
    if (self = [super init]) {
        _timers = [NSMutableArray array];
    }
    return self;
}

- (id<FTScheduledTimer>)scheduleAfterInterval:(NSTimeInterval)interval action:(dispatch_block_t)action {
    FTTestScheduledTimer *timer = [[FTTestScheduledTimer alloc] initWithFireTime:self.now + MAX(0, interval)
                                                                          action:action];
    [self.timers addObject:timer];
    return timer;
}

- (void)advanceToTime:(NSTimeInterval)time {
    self.now = time;
    
    BOOL firedTimer = NO;
    do {
        firedTimer = NO;
        
        NSArray<FTTestScheduledTimer *> *timers = [self.timers copy];
        for (FTTestScheduledTimer *timer in timers) {
            if (!timer.isCancelled && timer.fireTime <= self.now) {
                [timer fire];
                [self.timers removeObject:timer];
                firedTimer = YES;
            }
        }
    } while (firedTimer);
}

@end

@interface FTCALayerChangeAggregatorTests : XCTestCase
@property (nonatomic, strong) FTTestTimerScheduler *timerScheduler;
@property (nonatomic, strong) FTCALayerChangeAggregator *aggregator;
@property (nonatomic, strong) NSMutableArray<FTCALayerChangeSnapshot *> *snapshots;
@end

@implementation FTCALayerChangeAggregatorTests

- (void)setUp {
    [super setUp];
    
    self.timerScheduler = [[FTTestTimerScheduler alloc] init];
    self.timerScheduler.now = 1;
    self.snapshots = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    self.aggregator = [[FTCALayerChangeAggregator alloc] initWithMinimumDeliveryInterval:0.1
                                                                          timerScheduler:self.timerScheduler
                                                                                 handler:^(FTCALayerChangeSnapshot * _Nonnull snapshot) {
        [weakSelf.snapshots addObject:snapshot];
    }];
}

- (void)tearDown {
    [self.aggregator stop];
    self.aggregator = nil;
    self.timerScheduler = nil;
    self.snapshots = nil;
    
    [super tearDown];
}

- (void)testDefersDeliveryWhenOutsideThrottleWindow {
    [self runOnMainThreadAndWait:^{
        CALayer *layer = [CALayer layer];
        
        [self.aggregator start];
        
        [self.timerScheduler advanceToTime:1.05];
        [self.aggregator layerDidDisplay:layer];
        XCTAssertEqual(self.snapshots.count, 0);
        
        [self.timerScheduler advanceToTime:1.1];
        XCTAssertEqual(self.snapshots.count, 1);
        XCTAssertEqual([self.snapshots.lastObject aspectsForLayer:layer], FTCALayerChangeAspectDisplay);
        
        [self.timerScheduler advanceToTime:1.3];
        [self.aggregator layerDidLayoutSublayers:layer];
        XCTAssertEqual(self.snapshots.count, 1, @"Should not deliver synchronously from the CALayer callback.");
        
        [self.timerScheduler advanceToTime:1.3];
        XCTAssertEqual(self.snapshots.count, 2);
        XCTAssertEqual([self.snapshots.lastObject aspectsForLayer:layer], FTCALayerChangeAspectLayout);
    }];
}

- (void)testMergesChangesRecordedBeforeDeferredDeliveryRuns {
    [self runOnMainThreadAndWait:^{
        CALayer *layer = [CALayer layer];
        
        [self.aggregator start];
        
        [self.timerScheduler advanceToTime:1.5];
        [self.aggregator layerDidDisplay:layer];
        [self.aggregator layerDidLayoutSublayers:layer];
        XCTAssertEqual(self.snapshots.count, 0, @"Should defer delivery until the scheduled timer runs.");
        
        [self.timerScheduler advanceToTime:1.5];
        XCTAssertEqual(self.snapshots.count, 1);
        XCTAssertEqual([self.snapshots.lastObject aspectsForLayer:layer],
                       FTCALayerChangeAspectDisplay | FTCALayerChangeAspectLayout);
    }];
}

- (void)runOnMainThreadAndWait:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
        return;
    }
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Run on main thread"];
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
