//
//  FTRecordingCoordinatorTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/9/14.
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
#import "FTRecordingCoordinator.h"
#import "FTSessionReplayConfig.h"
#import "FTScheduler.h"
#import "FTQueue.h"
#import "FTSessionReplayTouches.h"
#import "FTWindowObserver.h"
#import "FTRecorder.h"

@interface FTRecordingCoordinatorTestQueue : NSObject<FTQueue>
@end

@implementation FTRecordingCoordinatorTestQueue
- (void)run:(void (^)(void))block {
    if (block) {
        block();
    }
}
@end

@interface FTRecordingCoordinatorTestScheduler : NSObject<FTScheduler>
@property (nonatomic, strong, readonly) id<FTQueue> queue;
@property (nonatomic, assign) NSInteger startCount;
@property (nonatomic, assign) NSInteger stopCount;
@end

@implementation FTRecordingCoordinatorTestScheduler
- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [FTRecordingCoordinatorTestQueue new];
    }
    return self;
}
- (void)scheduleWithOperation:(void (^)(void))operation {}
- (void)start {
    self.startCount += 1;
}
- (void)stop {
    self.stopCount += 1;
}
@end

@interface FTRecordingCoordinatorTestRecorder : FTRecorder
@property (nonatomic, assign) NSInteger forceFullSnapshotCount;
@end

@implementation FTRecordingCoordinatorTestRecorder
- (void)forceFullSnapshot {
    self.forceFullSnapshotCount += 1;
}
@end

@interface FTRecordingCoordinatorTests : XCTestCase
@end

@implementation FTRecordingCoordinatorTests

- (FTRecordingCoordinator *)coordinatorWithScheduler:(FTRecordingCoordinatorTestScheduler *)scheduler {
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    FTSessionReplayTouches *touches = [[FTSessionReplayTouches alloc]initWithWindowObserver:[FTWindowObserver new]];
    return [[FTRecordingCoordinator alloc]
        initWithConfig:config
        processorsQueue:dispatch_queue_create("com.ft.test.recording-coordinator", DISPATCH_QUEUE_SERIAL)
        scheduler:scheduler
        touches:touches
        trackingConsentDidChange:nil];
}

- (void)testExternalRecorderOwnersPauseUntilLastOwnerReleases {
    FTRecordingCoordinatorTestScheduler *scheduler = [FTRecordingCoordinatorTestScheduler new];
    FTRecordingCoordinator *coordinator = [self coordinatorWithScheduler:scheduler];
    FTRecordingCoordinatorTestRecorder *recorder = [FTRecordingCoordinatorTestRecorder new];
    coordinator.recorder = recorder;
    [coordinator setSampleState:FTRecordingSampleStateNormal];
    [coordinator startRecording];
    XCTAssertEqual(scheduler.startCount, 1);

    [coordinator setExternalRecorderActive:YES forOwner:@"flutter-engine"];
    XCTAssertEqual(scheduler.stopCount, 1);

    [coordinator setExternalRecorderActive:YES forOwner:@"unity-player"];
    [coordinator setExternalRecorderActive:NO forOwner:@"flutter-engine"];
    XCTAssertEqual(scheduler.stopCount, 1);
    XCTAssertEqual(scheduler.startCount, 1);

    [coordinator setExternalRecorderActive:NO forOwner:@"unity-player"];
    XCTAssertEqual(recorder.forceFullSnapshotCount, 1);
    XCTAssertEqual(scheduler.startCount, 2);
}

- (void)testInvalidExternalRecorderOwnerIsIgnoredWithoutThrowing {
    FTRecordingCoordinatorTestScheduler *scheduler = [FTRecordingCoordinatorTestScheduler new];
    FTRecordingCoordinator *coordinator = [self coordinatorWithScheduler:scheduler];
    [coordinator setSampleState:FTRecordingSampleStateNormal];
    [coordinator startRecording];
    NSInteger startCount = scheduler.startCount;
    NSInteger stopCount = scheduler.stopCount;

    XCTAssertNoThrow([coordinator setExternalRecorderActive:YES forOwner:(NSString *)nil]);
    XCTAssertNoThrow([coordinator setExternalRecorderActive:YES forOwner:@""]);
    XCTAssertNoThrow([coordinator setExternalRecorderActive:YES forOwner:@" \n\t "]);
    XCTAssertEqual(scheduler.startCount, startCount);
    XCTAssertEqual(scheduler.stopCount, stopCount);
}

@end
