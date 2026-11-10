//
//  FTLongTaskFileHandleTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/8.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTLongTaskManager+Test.h"
#import "FTRUMDependencies.h"
#import "FTFatalErrorContext.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTCrash.h"
#import "FTRUMContext.h"
#import "NSDate+FTUtil.h"
#import "FTLongTaskDetector.h"
#import "FTLongTaskTiming.h"
#import "FTLongTaskEvent.h"
#import "FTRUMViewHandler.h"
#import "FTRUMAppStateHistory.h"
#import "FTJSONUtil.h"
#import <objc/runtime.h>
#import <os/lock.h>

@interface FTLongTaskDetector (FTWaitTest)
- (void)recordRunLoopBeginActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (void)recordRunLoopEndActivity:(CFRunLoopActivity)activity atTimeNs:(long long)timeNs;
- (BOOL)readRunLoopSnapshot:(FTLongTaskRunLoopSnapshot *)snapshot;
@end

@interface FTRUMViewHandler (FTLongTaskEndpointTest)
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context;
@end

@interface FTLongTaskDetectorDelegateMock : NSObject <FTLongTaskTimingDelegate>
@end

@implementation FTLongTaskDetectorDelegateMock
- (uint64_t)longTaskDetector:(FTLongTaskDetector *)detector didObserveTiming:(FTLongTaskTiming)timing {
    return UINT64_MAX;
}
@end

@implementation FTManualTimingDetector
- (BOOL)isMonitoringGeneration:(uint64_t)generation { return YES; }
@end

typedef void (^FTLongTaskCallBack)(NSString *slowStack, long long duration);
typedef void (^FTWriteCallBack)(NSDictionary *fields, NSDictionary *tags);

@interface FTLongTaskBacktraceMock : NSObject<FTBacktraceReporting>
@property (nonatomic, copy) NSString *mainThreadBacktrace;
@property (nonatomic, copy) NSString *allThreadsBacktrace;
@property (nonatomic, assign) NSInteger mainThreadCallCount;
@property (nonatomic, assign) NSInteger allThreadsCallCount;
@property (nonatomic, assign) NSInteger nilAllThreadsResponseCount;
@property (nonatomic, copy) dispatch_block_t onAllThreads;
@end

@implementation FTLongTaskBacktraceMock
- (NSString *)generateMainThreadBacktrace {
    self.mainThreadCallCount += 1;
    return self.mainThreadBacktrace;
}
- (NSString *)generateAllThreadsBacktrace {
    self.allThreadsCallCount += 1;
    if (self.onAllThreads) self.onAllThreads();
    if (self.nilAllThreadsResponseCount > 0) {
        self.nilAllThreadsResponseCount -= 1;
        return nil;
    }
    return self.allThreadsBacktrace;
}
@end

@interface FTLongTaskFileHandleTest : XCTestCase<FTRunloopDetectorDelegate,FTRUMDataWriteProtocol>
@property (nonatomic, copy) FTLongTaskCallBack  callBack;
@property (nonatomic, copy) FTWriteCallBack  writeCallBack;
@property (nonatomic, strong) FTLongTaskBacktraceMock *backtraceMock;
@property (nonatomic, assign) long long lastFatalErrorDate;
@property (nonatomic, strong) FTFatalErrorContext *fatalErrorContext;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *reportedANRTimes;
@property (nonatomic) long long observedEndTimeNs;
@property (nonatomic) NSUInteger assembledErrors;

@end


@implementation FTLongTaskFileHandleTest

- (void)testEffectiveDurationSurvivesHistoricalRecovery {
    FTLongTaskManager *manager = [self mockLongTaskManager];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithDictionary:@{
        @"startDate": @(1000000000LL), @"duration": @(3000000000LL),
        @"effectiveDuration": @(3000000000LL), @"endDate": @(61000000000LL),
        @"mainThreadBacktrace": @"main"
    }];
    data.lastUpdateTimeNs = 61000000000LL;
    __block long long writtenDuration = 0;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) {
        if (fields[FT_DURATION]) writtenDuration = [fields[FT_DURATION] longLongValue];
    };
    XCTAssertEqual([FTTestANRProcessor(manager) reportANRData:data], 0LL);
    XCTAssertEqual(writtenDuration, 3000000000LL);
    self.writeCallBack = nil;
    [manager shutDown];
}


- (FTLongTaskManager *)timingManagerANR:(BOOL)anr freeze:(BOOL)freeze threshold:(long)threshold {
    self.backtraceMock = [FTLongTaskBacktraceMock new];
    self.backtraceMock.mainThreadBacktrace = @"main";
    self.backtraceMock.allThreadsBacktrace = @"all";
    FTLongTaskManager *manager = [self mockLongTaskManagerWithBacktraceReporting:self.backtraceMock enableANR:anr enableFreeze:freeze freezeDurationMs:threshold];
    return manager;
}
- (uint64_t)sendPhase:(FTLongTaskPhase)phase duration:(uint64_t)duration end:(long long)end to:(FTLongTaskManager *)manager {
    return FTTestObserveLongTask(manager, phase, NSEC_PER_SEC, duration, end);
}
- (void)testEndBeforeFirstCheckpointDoesNotConfirmIncident {
    for (NSString *state in @[@"foreground", @"background"]) {
        for (NSNumber *mode in @[@0, @1, @2]) {
            BOOL anr = mode.integerValue != 0, freeze = mode.integerValue != 1;
            FTLongTaskManager *manager = [self timingManagerANR:anr freeze:freeze threshold:250];
            [self.fatalErrorContext setAppState:state];
            uint64_t firstCheckpoint = freeze ? 251 * NSEC_PER_MSEC : 3001 * NSEC_PER_MSEC;
            XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], firstCheckpoint);
            __block NSUInteger reports = 0;
            self.callBack = ^(NSString *stack, long long duration) { reports += 1; };
            // The worker sees the producer End before processing its first checkpoint.
            long long end = NSEC_PER_SEC + firstCheckpoint + 49 * NSEC_PER_MSEC;
            XCTAssertEqual([self sendPhase:FTLongTaskPhaseEnd duration:firstCheckpoint end:end to:manager], UINT64_MAX);
            [self sendPhase:FTLongTaskPhaseEnd duration:firstCheckpoint end:end + NSEC_PER_SEC to:manager];
            XCTAssertEqual(reports, 0U);
            XCTAssertEqual(self.reportedANRTimes.count, 0U);
            XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 0);
            XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 0);
            XCTAssertNil([manager valueForKey:@"longTaskEvent"]);
            XCTAssertNil([FTTestANRStore(manager) readANRData]);
            self.callBack = nil;
            [manager shutDown];
        }
    }
}
- (void)testConfirmedIncidentSettlesOnceAtEndWithoutRecapturing {
    for (NSString *state in @[@"foreground", @"background"]) {
        [self.reportedANRTimes removeAllObjects];
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        [self.fatalErrorContext setAppState:state];
        [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001 * NSEC_PER_MSEC end:4LL * NSEC_PER_SEC + NSEC_PER_MSEC to:manager];
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 1);
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
        NSMutableArray *durations = [NSMutableArray array];
        self.callBack = ^(NSString *stack, long long duration) { [durations addObject:@(duration)]; };
        [self sendPhase:FTLongTaskPhaseEnd duration:5100 * NSEC_PER_MSEC end:8LL * NSEC_PER_SEC to:manager];
        [self sendPhase:FTLongTaskPhaseEnd duration:5100 * NSEC_PER_MSEC end:9LL * NSEC_PER_SEC to:manager];
        XCTAssertEqualObjects(durations, (@[@(5100 * NSEC_PER_MSEC), @0]));
        XCTAssertEqualObjects(self.reportedANRTimes, (@[@(NSEC_PER_SEC)]));
        XCTAssertEqual(self.observedEndTimeNs, 8LL * NSEC_PER_SEC);
        XCTAssertEqual(self.backtraceMock.mainThreadCallCount, 1);
        XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
        XCTAssertNil([FTTestANRStore(manager) readANRData]);
        self.callBack = nil;
        [manager shutDown];
    }
}
- (void)testTimingOnlyCheckpointKeepsBaseSnapshotUnchanged {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    self.backtraceMock.allThreadsBacktrace = [@"stack\n" stringByPaddingToLength:100000 withString:@"frame\n" startingAtIndex:0];
    FTLongTaskANRDataStore *store = FTTestANRStore(manager);
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:61LL*NSEC_PER_SEC to:manager];
    dispatch_sync(store.queue, ^{});
    NSString *before = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:4002*NSEC_PER_MSEC end:62LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRData *saved = [store readANRData];
    NSString *after = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    NSArray *beforeParts = [before componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    NSArray *afterParts = [after componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertEqualObjects(afterParts[1], beforeParts[1]);
    XCTAssertGreaterThan([afterParts[2] length], 0U);
    XCTAssertLessThan([after lengthOfBytesUsingEncoding:NSUTF8StringEncoding] - [before lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 256U);
    XCTAssertEqual(saved.durationNs, 4002*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 62LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, self.backtraceMock.allThreadsBacktrace);
    [manager shutDown];
}
- (void)testV3RecoveryUsesLastCompleteValidatedTimingPair {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSString *payload = @"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"effectiveDuration\":3100000000,\"endDate\":5000000000}\n___boundary.info.date___\n"
        @"{\"effectiveDuration\":4100000000,\"endDate\":61000000000}\n"
        @"{\"effectiveDuration\":18446744079709551616,\"endDate\":62000000000}\n"
        @"{\"effectiveDuration\":5001000000,\"endDate\":62000000000}\n"
        @"{\"effectiveDuration\":6000000000,\"endDate\":63000000000}";
    XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.startTimeNs, NSEC_PER_SEC);
    XCTAssertEqual(saved.durationNs, 5001*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 62LL*NSEC_PER_SEC);
    XCTAssertEqual(saved.lastUpdateTimeNs, 62LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testV3TimingTailRejectsInvalidPairsAndRegressions {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSString *base = @"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"effectiveDuration\":3100000000,\"endDate\":5000000000}\n___boundary.info.date___\n"
        @"{\"effectiveDuration\":4100000000,\"endDate\":61000000000}\n";
    for (NSString *key in @[@"effectiveDuration", @"endDate"]) {
        NSArray *invalidValues = @[@"", @"null", @"true", @"false", @"\"6000000000\"", @"{}", @"[]", @"-1", @"0", @"0.5", @"6000000000.5", @"9223372036854775808", @"18446744079709551616", @"1e100"];
        if ([key isEqualToString:@"effectiveDuration"]) invalidValues = [invalidValues arrayByAddingObject:@"4000000000"];
        for (NSString *value in invalidValues) {
            NSString *field = value.length ? [NSString stringWithFormat:@"\"%@\":%@,", key, value] : @"";
            NSString *other = [key isEqualToString:@"effectiveDuration"] ? @"\"endDate\":62000000000" : @"\"effectiveDuration\":6000000000";
            NSString *payload = [base stringByAppendingFormat:@"{%@%@}\n", field, other];
            XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil]);
            FTLongTaskANRData *saved = [store readANRData];
            XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC, @"%@=%@", key, value);
            XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
        }
    }
    [store deleteFile];
}
- (void)testTimingAppendPreservesExactLargeNanoseconds {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:1 durationNs:0 mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 1;
    [store writeANRData:data];
    for (NSNumber *duration in @[@1780000000123456789LL, @9223372036854775806LL]) {
        [store appendTimingWithStartTimeNs:1 durationNs:duration.longLongValue endTimeNs:duration.longLongValue + 1];
        FTLongTaskANRData *saved = [store readANRData];
        XCTAssertEqual(saved.startTimeNs, 1LL);
        XCTAssertEqual(saved.durationNs, duration.longLongValue);
        XCTAssertEqual(saved.endTimeNs, duration.longLongValue + 1);
    }
    [store deleteFile];
}
- (void)testTimingAppendPreservesBaseAndReplacementClearsTail {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
    data.durationNs = 5100*NSEC_PER_MSEC; data.endTimeNs = 62LL*NSEC_PER_SEC; data.allThreadsBacktrace = @"all";
    [store writeANRData:data];
    saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 5100*NSEC_PER_MSEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, @"all");
    NSString *content = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([content componentsSeparatedByString:@"\n___boundary.info.date___\n"][2], @"");
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:6100*NSEC_PER_MSEC endTimeNs:63LL*NSEC_PER_SEC];
    saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 6100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 63LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testTimingAppendIsolatesTornTailAndCapturesScalarsBeforeQueueDelay {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    dispatch_sync(store.queue, ^{
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:store.dataStorePath];
        [handle seekToEndOfFile];
        [handle writeData:[@"{\"effectiveDuration\":9999999999" dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    });
    XCTAssertEqual([store readANRData].durationNs, 3100*NSEC_PER_MSEC);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0);
    dispatch_async(store.queue, ^{ dispatch_semaphore_signal(entered); dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER); });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    [store appendTimingWithStartTimeNs:data.startTimeNs durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    data.startTimeNs = 99LL*NSEC_PER_SEC; data.durationNs = 99LL*NSEC_PER_SEC; data.endTimeNs = 199LL*NSEC_PER_SEC;
    dispatch_semaphore_signal(release);
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.startTimeNs, NSEC_PER_SEC);
    XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testTimingAppendRequiresMatchingBaseAndCannotRecreateDeletedFile {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    dispatch_sync(store.queue, ^{});
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    [store appendTimingWithStartTimeNs:2LL*NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    XCTAssertEqual([store readANRData].durationNs, 3100*NSEC_PER_MSEC);
    // External loss of an active file can rebuild its retained base; explicit store deletion cannot.
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:store.dataStorePath error:nil]);
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    XCTAssertEqual([store readANRData].durationNs, 4100*NSEC_PER_MSEC);
    [store deleteFile];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    dispatch_sync(store.queue, ^{});
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
}
- (void)testFailedBaseWriteCannotReceiveTimingAppend {
    FTLongTaskANRDataStore *store = [FTLongTaskANRDataStore new];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]);
    store.dataStorePath = directory; // Atomic data writes cannot replace a directory.
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    dispatch_sync(store.queue, ^{});
    XCTAssertEqual([[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil].count, 0U);
    XCTAssertNil([store readANRData]);
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
}
- (void)testTimingUpdateRetriesFailedBaseBeforeAppending {
    FTLongTaskANRDataStore *store = [FTLongTaskANRDataStore new];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]);
    store.dataStorePath = directory;
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:nil];
    data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    dispatch_sync(store.queue, ^{});
    store.dataStorePath = [directory stringByAppendingPathComponent:@"recovered.log"];
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:4100*NSEC_PER_MSEC endTimeNs:61LL*NSEC_PER_SEC];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 4100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 61LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, @"all");
    NSString *content = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([content componentsSeparatedByString:@"\n___boundary.info.date___\n"][2], @"");
    [store appendTimingWithStartTimeNs:NSEC_PER_SEC durationNs:5100*NSEC_PER_MSEC endTimeNs:62LL*NSEC_PER_SEC];
    saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 5100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 62LL*NSEC_PER_SEC);
    content = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertGreaterThan([[content componentsSeparatedByString:@"\n___boundary.info.date___\n"][2] length], 0U);
    [store deleteFile];
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
}
- (void)testLateFullStackReplacementClearsTimingTail {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    self.backtraceMock.nilAllThreadsResponseCount = 3;
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3100*NSEC_PER_MSEC end:5LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:3600*NSEC_PER_MSEC end:6LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:4200*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRDataStore *store = FTTestANRStore(manager);
    XCTAssertEqual([store readANRData].durationNs, 4200*NSEC_PER_MSEC);
    NSString *before = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertGreaterThan([[before componentsSeparatedByString:@"\n___boundary.info.date___\n"][2] length], 0U);
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:4500*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 4500*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 8LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(saved.allThreadsBacktrace, @"all");
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 4);
    NSString *after = [NSString stringWithContentsOfFile:store.dataStorePath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects([after componentsSeparatedByString:@"\n___boundary.info.date___\n"][2], @"");
    [manager shutDown];
}
- (void)testRecoveredTimingTailUsesEffectiveDurationAndRejectsOverflow {
    for (NSNumber *corrupt in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTLongTaskANRDataStore *store = FTTestANRStore(manager);
        FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:[self.fatalErrorContext currentContextModel]];
        data.usesEffectiveDuration = YES; data.endTimeNs = 5LL*NSEC_PER_SEC;
        [store writeANRData:data];
        dispatch_sync(store.queue, ^{
            NSString *line = [NSString stringWithFormat:@"{\"effectiveDuration\":%@,\"endDate\":61000000000}\n", corrupt.boolValue ? @"18446744079709551616" : @"6000000000"];
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:store.dataStorePath];
            [handle seekToEndOfFile]; [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [handle closeFile];
        });
        __block long long recoveredDuration = -1;
        self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) { recoveredDuration = [fields[FT_DURATION] longLongValue]; };
        self.assembledErrors = 0; self.lastFatalErrorDate = -1;
        [FTTestANRProcessor(manager) reportPreviousANRIfFound];
        dispatch_sync(store.queue, ^{});
        XCTAssertEqual(recoveredDuration, corrupt.boolValue ? 3100*NSEC_PER_MSEC : 6LL*NSEC_PER_SEC);
        XCTAssertEqual(self.assembledErrors, corrupt.boolValue ? 0U : 1U);
        XCTAssertEqual(self.lastFatalErrorDate, corrupt.boolValue ? 0LL : NSEC_PER_SEC);
        self.writeCallBack = nil; [manager shutDown];
    }
}
- (void)testDynamicCheckpointsAndEffectiveDurationPersistence {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:10000];
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], 3001 * NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3001 * NSEC_PER_MSEC end:61LL*NSEC_PER_SEC to:manager], 4001 * NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    FTLongTaskANRData *data = [FTTestANRStore(manager) readANRData];
    XCTAssertTrue(data.usesEffectiveDuration);
    XCTAssertEqual(data.durationNs, 3001 * NSEC_PER_MSEC);
    XCTAssertEqual(data.endTimeNs, 61LL * NSEC_PER_SEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:4001 * NSEC_PER_MSEC end:62LL*NSEC_PER_SEC to:manager], 5001 * NSEC_PER_MSEC);
    data = [FTTestANRStore(manager) readANRData];
    XCTAssertEqual(data.durationNs, 4001 * NSEC_PER_MSEC, @"one-second updates must persist without an extra 1 ms wakeup");
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:5001 * NSEC_PER_MSEC end:63LL*NSEC_PER_SEC to:manager], 6001 * NSEC_PER_MSEC);
    data = [FTTestANRStore(manager) readANRData];
    XCTAssertEqual(data.durationNs, 5001 * NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:64LL*NSEC_PER_SEC to:manager];
    XCTAssertEqualObjects(self.reportedANRTimes, (@[@(NSEC_PER_SEC)]));
    [manager shutDown];
}
- (void)testSuccessfulFullStackUsesOneSecondChecksAndPreservesANRBoundary {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:NO threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3500*NSEC_PER_MSEC end:5LL*NSEC_PER_SEC to:manager], 4500*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:4500*NSEC_PER_MSEC end:6LL*NSEC_PER_SEC to:manager], 5001*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager], 6001*NSEC_PER_MSEC);
    FTLongTaskANRData *saved = [FTTestANRStore(manager) readANRData];
    XCTAssertEqual(saved.durationNs, 5001*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 7LL*NSEC_PER_SEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1, @"successful capture is not retried during timing updates");
    [manager shutDown];
}
- (void)testFreezeOnlyPreservesRealEndpointAndEffectiveDuration {
    FTLongTaskManager *manager = [self timingManagerANR:NO freeze:YES threshold:250];
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], 251 * NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:251*NSEC_PER_MSEC end:61LL*NSEC_PER_SEC to:manager], UINT64_MAX);
    __block long long duration = 0;
    self.callBack = ^(NSString *stack,long long d) { duration=d; };
    [self sendPhase:FTLongTaskPhaseEnd duration:300*NSEC_PER_MSEC end:62LL*NSEC_PER_SEC to:manager];
    XCTAssertEqual(duration, 300*NSEC_PER_MSEC);
    XCTAssertEqual(self.observedEndTimeNs, 62LL*NSEC_PER_SEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 0);
    XCTAssertNil([FTTestANRStore(manager) readANRData]);
    self.callBack=nil; [manager shutDown];
}
- (void)testANROnlyFixedRetryAndMissingMainStack {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:NO threshold:250];
    self.backtraceMock.mainThreadBacktrace=nil;
    self.backtraceMock.nilAllThreadsResponseCount=1;
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager], 3001*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3001*NSEC_PER_MSEC end:4LL*NSEC_PER_SEC to:manager], 3251*NSEC_PER_MSEC);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3101*NSEC_PER_MSEC end:5LL*NSEC_PER_SEC to:manager], 3251*NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 1);
    XCTAssertEqual([self sendPhase:FTLongTaskPhaseCheckpoint duration:3251*NSEC_PER_MSEC end:6LL*NSEC_PER_SEC to:manager], 4251*NSEC_PER_MSEC);
    XCTAssertEqual(self.backtraceMock.allThreadsCallCount, 2);
    FTLongTaskANRData *data=[FTTestANRStore(manager) readANRData];
    XCTAssertEqualObjects(data.allThreadsBacktrace,@"all");
    XCTAssertEqualObjects(data.mainThreadBacktrace,@"");
    [manager shutDown];
}
- (void)testAppStateUsesRealIntervalWhileDurationUsesEffectiveTime {
    FTRUMDependencies *dependencies=[FTRUMDependencies new];dependencies.writer=self;
    dependencies.appStateHistory=[[FTRUMAppStateHistory alloc]initWithState:@"foreground" timeNs:NSEC_PER_SEC];
    [dependencies.appStateHistory recordState:@"background" timeNs:10LL*NSEC_PER_SEC];
    FTRUMViewModel *view=[[FTRUMViewModel alloc]initWithViewID:@"view" viewName:@"view" viewReferrer:@""];
    view.tm=NSEC_PER_SEC;
    FTRUMContext *context=[[FTRUMContext alloc]initWithSampleRate:100 sessionOnErrorSampleRate:0 appId:@"app"];
    FTRUMViewHandler *handler=[[FTRUMViewHandler alloc]initWithModel:view context:context rumDependencies:dependencies needsMonitoring:NO];
    FTRUMDataModel *model=[FTRUMDataModel new];model.type=FTRUMDataLongTask;model.tm=NSEC_PER_SEC;
    model.tags=@{};model.fields=@{FT_DURATION:@(3LL*NSEC_PER_SEC)};
    model.longTaskEvent=[[FTLongTaskEvent alloc]initWithStack:@"main" startTimeNs:NSEC_PER_SEC endTimeNs:61LL*NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC];
    __block NSDictionary *written;
    self.writeCallBack=^(NSDictionary *fields,NSDictionary *tags){written=fields;};
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"],@"foreground_and_background");
    XCTAssertEqual([written[FT_DURATION]longLongValue],3LL*NSEC_PER_SEC);
    // Existing manually reported LongTasks still derive their interval from duration.
    model.longTaskEvent=nil;
    self.writeCallBack=^(NSDictionary *fields,NSDictionary *tags){written=fields;};
    [handler writeErrorData:model context:@{}];
    XCTAssertEqualObjects(written[@"app_state"],@"foreground");
    self.writeCallBack=nil;
}
- (void)testDuplicateEndAndShutdownDuringRecoveredCallback {
    FTLongTaskManager *manager=[self timingManagerANR:YES freeze:YES threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
    __block NSUInteger freezes=0;
    self.callBack=^(NSString *stack,long long d){ freezes++; [manager shutDown]; };
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:9LL*NSEC_PER_SEC to:manager];
    XCTAssertEqual(freezes,1U);
    XCTAssertEqual(self.reportedANRTimes.count,0U);
    self.callBack=nil;
}
- (void)testNewPersistenceIgnoresLegacyTrailerAndRejectsMissingDuration {
    FTLongTaskANRDataStore *store=[self mockANRDataStore];
    FTLongTaskANRData *data=[[FTLongTaskANRData alloc]initWithStartTimeNs:NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration=YES;data.endTimeNs=61LL*NSEC_PER_SEC;
    [store writeANRData:data];
    dispatch_sync(store.queue, ^{
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:store.dataStorePath];
        [handle seekToEndOfFile];
        [handle writeData:[@"1000000000000\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    });
    data=[store readANRData];
    XCTAssertEqual(data.durationNs,3LL*NSEC_PER_SEC);
    XCTAssertEqual(data.lastUpdateTimeNs,61LL*NSEC_PER_SEC);
    [store deleteFile];
    [@"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"endDate\":61000000000}\n___boundary.info.date___\n61000000000\n" writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNil([store readANRData]);[store deleteFile];
}
- (void)testV3RejectsMissingOrInvalidStartTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSArray<NSString *> *invalidStarts = @[@"", @"null", @"true", @"false", @"\"1000000000\"",
        @"{}", @"[]", @"0", @"-1", @"0.5", @"1.5", @"9223372036854775808",
        @"18446744073709551617", @"1e100"];
    for (NSString *start in invalidStarts) {
        NSString *startField = start.length ? [NSString stringWithFormat:@"\"startDate\":%@,", start] : @"";
        NSString *payload = [NSString stringWithFormat:
            @"3.0.0\n___boundary.info.date___\n{%@\"effectiveDuration\":0,\"endDate\":9223372036854775807}\n___boundary.info.date___\n", startField];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
        XCTAssertNil([store readANRData], @"Invalid startDate must reject the complete v3 record: %@", start);
    }
    [store deleteFile];
}
- (void)testV3PreservesExactPositiveIntegerStartTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSNumber *start in @[@1LL, @1000000000LL, @1780000000123456789LL, @9223372036854775807LL]) {
        NSString *payload = [NSString stringWithFormat:
            @"3.0.0\n___boundary.info.date___\n{\"startDate\":%@,\"effectiveDuration\":0,\"endDate\":9223372036854775807}\n___boundary.info.date___\n", start];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
        FTLongTaskANRData *data = [store readANRData];
        XCTAssertNotNil(data);
        XCTAssertTrue(data.usesEffectiveDuration);
        XCTAssertEqual(data.startTimeNs, start.longLongValue);
        XCTAssertEqual(data.endTimeNs, 9223372036854775807LL);
        XCTAssertEqual(data.durationNs, 0LL);
    }
    [store deleteFile];
}
- (void)testV3RejectsInvalidEffectiveDurationAndEndTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSString *key in @[@"effectiveDuration", @"endDate"]) {
        NSMutableArray<NSString *> *invalidValues = [@[@"", @"null", @"true", @"false", @"\"6000000000\"",
            @"{}", @"[]", @"-1", @"-0.5", @"0.5", @"6000000000.5", @"9223372036854775808",
            @"18446744073709551617", @"18446744079709551616", @"1e100"] mutableCopy];
        if ([key isEqualToString:@"endDate"]) [invalidValues addObject:@"0"];
        for (NSString *value in invalidValues) {
            NSString *field = value.length ? [NSString stringWithFormat:@"\"%@\":%@,", key, value] : @"";
            NSString *other = [key isEqualToString:@"effectiveDuration"] ? @"\"endDate\":9223372036854775807" : @"\"effectiveDuration\":0";
            NSString *payload = [NSString stringWithFormat:
                @"3.0.0\n___boundary.info.date___\n{\"startDate\":1,%@%@}\n___boundary.info.date___\n", field, other];
            NSError *error = nil;
            XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
            XCTAssertNil([store readANRData], @"Invalid %@ must reject the v3 record: %@", key, value);
        }
    }
    [store deleteFile];
}
- (void)testV3PreservesExactEffectiveDurationAndEndTimes {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSNumber *duration in @[@0LL, @1LL, @6000000000LL, @1780000000123456789LL, @9223372036854775806LL]) {
        long long end = duration.longLongValue + 1;
        NSString *payload = [NSString stringWithFormat:
            @"3.0.0\n___boundary.info.date___\n{\"startDate\":1,\"effectiveDuration\":%@,\"endDate\":%lld}\n___boundary.info.date___\n", duration, end];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
        FTLongTaskANRData *data = [store readANRData];
        XCTAssertNotNil(data);
        XCTAssertTrue(data.usesEffectiveDuration);
        XCTAssertEqual(data.startTimeNs, 1LL);
        XCTAssertEqual(data.durationNs, duration.longLongValue);
        XCTAssertEqual(data.endTimeNs, end);
        XCTAssertEqual(data.lastUpdateTimeNs, end);
    }
    [store deleteFile];
}
- (void)testOverflowingV3DurationCannotEmitHistoricalTelemetry {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTLongTaskANRDataStore *store = FTTestANRStore(manager);
    NSString *context = [FTJSONUtil convertToJsonDataWithObject:[[self.fatalErrorContext currentContextModel] toDictionary]];
    NSString *payload = [NSString stringWithFormat:
        @"3.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"effectiveDuration\":18446744079709551616,\"endDate\":61000000000,\"mainThreadBacktrace\":\"main\",\"errorContextModel\":%@}\n___boundary.info.date___\n", context];
    NSError *error = nil;
    XCTAssertTrue([payload writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
    __block NSUInteger writes = 0;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) { writes += 1; };
    self.lastFatalErrorDate = -1;
    [FTTestANRProcessor(manager) reportPreviousANRIfFound];
    dispatch_sync(store.queue, ^{});
    XCTAssertEqual(writes, 0U);
    XCTAssertEqual(self.assembledErrors, 0U);
    XCTAssertEqual(self.lastFatalErrorDate, 0LL);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
    self.writeCallBack = nil;
    [manager shutDown];
}
- (void)testPersistenceSnapshotsBeforeItsQueueIsDelayed {
    FTLongTaskANRDataStore *store=[self mockANRDataStore];
    dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
    dispatch_async(store.queue,^{dispatch_semaphore_signal(entered);dispatch_semaphore_wait(release,DISPATCH_TIME_FOREVER);});
    XCTAssertEqual(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC)),0);
    FTLongTaskANRData *data=[[FTLongTaskANRData alloc]initWithStartTimeNs:NSEC_PER_SEC durationNs:3LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration=YES;data.endTimeNs=61LL*NSEC_PER_SEC;
    [store writeANRData:data];
    data.durationNs=99LL*NSEC_PER_SEC;data.endTimeNs=100LL*NSEC_PER_SEC;data.usesEffectiveDuration=NO;
    dispatch_semaphore_signal(release);
    FTLongTaskANRData *saved=[store readANRData];
    XCTAssertTrue(saved.usesEffectiveDuration);
    XCTAssertEqual(saved.durationNs,3LL*NSEC_PER_SEC);
    XCTAssertEqual(saved.endTimeNs,61LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.reportedANRTimes = [NSMutableArray array];
}

- (void)tearDown {
    // File cleanup is asynchronous in production; tests explicitly drain its shared queue.
    FTLongTaskANRDataStore *store = [FTLongTaskANRDataStore new];
    dispatch_sync(store.queue, ^{});
}
- (FTLongTaskManager *)mockLongTaskManager{
    return [self mockLongTaskManagerWithBacktraceReporting:nil enableFreeze:YES];
}
- (FTLongTaskManager *)mockLongTaskManagerWithBacktraceReporting:(id<FTBacktraceReporting>)backtraceReporting enableFreeze:(BOOL)enableFreeze{
    return [self mockLongTaskManagerWithBacktraceReporting:backtraceReporting enableANR:YES enableFreeze:enableFreeze freezeDurationMs:250];
}
- (FTLongTaskManager *)mockLongTaskManagerWithBacktraceReporting:(id<FTBacktraceReporting>)backtraceReporting enableANR:(BOOL)enableANR enableFreeze:(BOOL)enableFreeze freezeDurationMs:(long)freezeDurationMs{
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.writer = self;
    FTFatalErrorContext *errorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:nil];
    [errorContext setLastSessionState:[[FTRUMSessionState alloc] init]];
    self.fatalErrorContext = errorContext;
    dependencies.fatalErrorContext = errorContext;
    if (!backtraceReporting) {
        [FTCrash setupWithMonitoringType:FTCrashCMonitorTypeSystem writer:self enableMonitorMemory:YES enableMonitorCpu:YES];
        backtraceReporting = [FTCrash shared].backtraceReporting;
    }
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self backtraceReporting:backtraceReporting enableTrackAppANR:enableANR enableTrackAppFreeze:enableFreeze freezeDurationMs:freezeDurationMs];
    FTLongTaskDetector *detector = [longTaskManager valueForKey:@"longTaskDetector"];
    [detector stopDetecting];
    FTTestDrainDetector(detector);
    [FTTestANRStore(longTaskManager) deleteFile];
    return longTaskManager;
}
- (FTLongTaskANRDataStore *)mockANRDataStore{
    FTLongTaskANRDataStore *store = [[FTLongTaskANRDataStore alloc] init];
    [store deleteFile];
    return store;
}
- (void)testSnapshotAtomicallyReplacesPreviousRecord {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"main" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 5LL*NSEC_PER_SEC;
    [store writeANRData:data];
    data.durationNs = 5100*NSEC_PER_MSEC;
    data.endTimeNs = 8LL*NSEC_PER_SEC;
    [store writeANRData:data];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertEqual(saved.durationNs, 5100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 8LL*NSEC_PER_SEC);
    [store deleteFile];
}
- (void)testLegacyV2RecoveryStillUsesLastTrailer {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    [@"2.0.0\n___boundary.info.date___\n{\"startDate\":1000000000,\"duration\":3100000000}\n___boundary.info.date___\n4100000000\n6100000000\n" writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    FTLongTaskANRData *saved = [store readANRData];
    XCTAssertFalse(saved.usesEffectiveDuration);
    XCTAssertEqual(saved.startTimeNs, NSEC_PER_SEC);
    XCTAssertEqual(saved.lastUpdateTimeNs, 6100*NSEC_PER_MSEC);
    [store deleteFile];
}
- (void)testDeleteFileFromAndOutsideStoreQueue {
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    for (NSNumber *inside in @[@NO, @YES]) {
        [@"fixture" writeToFile:store.dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        if (inside.boolValue) dispatch_sync(store.queue, ^{ [store deleteFile]; });
        else [store deleteFile];
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:store.dataStorePath]);
    }
}
- (void)testLongTask_start_update_end{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 251*NSEC_PER_MSEC, startTime + 251*NSEC_PER_MSEC);
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertTrue(slowStack != nil);
        XCTAssertEqual(duration, 1001*NSEC_PER_MSEC);
        hasCallBack = YES;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 1001*NSEC_PER_MSEC, startTime + 1001*NSEC_PER_MSEC);
    self.callBack = nil;
    XCTAssertTrue(hasCallBack);

    [longTaskManager shutDown];
}
- (void)testLongTask_updateRetriesAllThreadsBacktraceWhileBlocked{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    self.backtraceMock = backtraceMock;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3600000000LL, startTime + 3600000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    XCTAssertEqualObjects(reportedANRStack, backtraceMock.allThreadsBacktrace);
    self.callBack = nil;
    self.backtraceMock = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_firstANRDataWriteFallsBackToMainThreadBacktraceWhenAllThreadsMissing{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"mainThreadBacktrace"], backtraceMock.mainThreadBacktrace);
    XCTAssertFalse([dict.allKeys containsObject:@"allThreadsBacktrace"]);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    [longTaskManager shutDown];
}
- (void)testLongTask_firstANRDataWriteIncludesAllThreadsBacktraceWhenCaptured{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"allThreadsBacktrace"], backtraceMock.allThreadsBacktrace);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    [longTaskManager shutDown];
}
- (void)testLongTask_emptyAllThreadsBacktraceRetriesWhileBlocked{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3600000000LL, startTime + 3600000000LL);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    XCTAssertEqualObjects(reportedANRStack, backtraceMock.mainThreadBacktrace);
    self.callBack = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_endAnrDoesNotGenerateRecoveredAllThreadsBacktrace{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"blockedAllThreadsBacktrace";
    self.backtraceMock = backtraceMock;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100*NSEC_PER_MSEC, startTime + 3100*NSEC_PER_MSEC);
    backtraceMock.allThreadsBacktrace = @"recoveredAllThreadsBacktrace";
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    XCTAssertEqualObjects(reportedANRStack, @"blockedAllThreadsBacktrace");
    self.callBack = nil;
    self.backtraceMock = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_completedANRIsNotReportedAgainWhenNextCycleCannotStart{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long completedANRTime = [NSDate ft_currentNanosecondTimeStamp] - 6LL * NSEC_PER_SEC;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, completedANRTime, 0, completedANRTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, completedANRTime, 5001*NSEC_PER_MSEC, completedANRTime + 5001*NSEC_PER_MSEC);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, completedANRTime, 6LL*NSEC_PER_SEC, completedANRTime + 6LL*NSEC_PER_SEC);

    [self.fatalErrorContext setLastSessionState:nil];
    long long nextStart = completedANRTime + 7LL*NSEC_PER_SEC;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, nextStart, 0, nextStart);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, nextStart, 251*NSEC_PER_MSEC, nextStart + 251*NSEC_PER_MSEC);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, nextStart, 300*NSEC_PER_MSEC, nextStart + 300*NSEC_PER_MSEC);

    XCTAssertEqualObjects(self.reportedANRTimes, (@[@(completedANRTime)]));
    [longTaskManager shutDown];
}
- (void)testLongTask_rewritesANRDataWhenAllThreadsBacktraceCapturedAfterInitialWrite{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3600000000LL, startTime + 3600000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"allThreadsBacktrace"], @"allThreadsBacktrace\nThread 1:");
    FTLongTaskANRData *anrData = [FTTestANRStore(longTaskManager) readANRData];
    XCTAssertEqual(anrData.lastUpdateTimeNs, startTime + 3600000000LL);
    [longTaskManager shutDown];
}
- (void)testLongTask_reportFatalANRDataIfFound{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
        FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 3100000000LL, startTime + 3100000000LL);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 5100000000LL, startTime + 5100000000LL);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    __block BOOL hasCallBack = NO;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) {
        XCTAssertTrue(fields[FT_KEY_LONG_TASK_STACK]);
        hasCallBack = YES;
    };
    XCTAssertNoThrow([FTTestANRProcessor(longTaskManager) reportPreviousANRIfFound]);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    XCTAssertTrue(hasCallBack);
    [longTaskManager shutDown];
}
- (void)testLongTask_reportPreviousANRDeletesMalformedANRDataAndNotifiesNoFatal{
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    [@"broken ANR data" writeToFile:FTTestANRStore(longTaskManager).dataStorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    self.lastFatalErrorDate = -1;
    [FTTestANRProcessor(longTaskManager) reportPreviousANRIfFound];
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:FTTestANRStore(longTaskManager).dataStorePath];
    XCTAssertTrue(data.length == 0);
    XCTAssertEqual(self.lastFatalErrorDate, 0);
    [longTaskManager shutDown];
}
- (void)testLongTask_freezeOnlyDoesNotWriteANRDataButReportsFreeze{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableANR:NO enableFreeze:YES freezeDurationMs:250];
    NSString *dataStorePath = FTTestANRStore(longTaskManager).dataStorePath;
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - NSEC_PER_SEC;
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseBegin, startTime, 0, startTime);
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseCheckpoint, startTime, 251*NSEC_PER_MSEC, startTime + 251*NSEC_PER_MSEC);
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertEqualObjects(slowStack, @"mainThreadBacktrace");
        XCTAssertTrue(duration > 250 * NSEC_PER_MSEC);
        hasCallBack = YES;
    };
    FTTestObserveLongTask(longTaskManager, FTLongTaskPhaseEnd, startTime, 6LL*NSEC_PER_SEC, startTime + 6LL*NSEC_PER_SEC);
    dispatch_sync(FTTestANRStore(longTaskManager).queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data.length == 0);
    XCTAssertTrue(hasCallBack);
    self.callBack = nil;
    [longTaskManager shutDown];
}
- (void)testShutdownDoesNotWaitForDetectorOrFileQueue {
    for (NSNumber *blockDetector in @[@NO, @YES]) {
        FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
        FTLongTaskDetector *detector = [manager valueForKey:@"longTaskDetector"];
        dispatch_queue_t queue = blockDetector.boolValue ? [detector valueForKey:@"longTaskQueue"] : FTTestANRStore(manager).queue;
        dispatch_semaphore_t entered = dispatch_semaphore_create(0);
        dispatch_semaphore_t release = dispatch_semaphore_create(0);
        dispatch_semaphore_t returned = dispatch_semaphore_create(0);
        dispatch_async(queue, ^{
            dispatch_semaphore_signal(entered);
            dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
        });
        XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [manager shutDown];
            dispatch_semaphore_signal(returned);
        });
        long result = dispatch_semaphore_wait(returned, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
        dispatch_semaphore_signal(release); // Always unblock cleanup, including on assertion failure.
        XCTAssertEqual(result, 0L, @"shutdown must return while the target queue is still blocked");
        FTTestDrainDetector(detector);
        dispatch_sync(FTTestANRStore(manager).queue, ^{});
        XCTAssertTrue(FTTestANRStore(manager).isClosed);
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:FTTestANRStore(manager).dataStorePath]);
    }
}
- (void)testShutdownFromHistoricalProviderReturnsAndSuppressesLateError {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
    __block NSUInteger calls = 0;
    dependencies.issueDataProvider = ^NSDictionary *(FTIssueInfo *issue) {
        calls += 1;
        [manager shutDown];
        return @{};
    };
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:6LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:self.fatalErrorContext.currentContextModel];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 7LL*NSEC_PER_SEC;
    [FTTestANRStore(manager) writeANRData:data];
    self.lastFatalErrorDate = -1;
    [FTTestANRProcessor(manager) reportPreviousANRIfFound];
    dispatch_sync(FTTestANRStore(manager).queue, ^{});
    XCTAssertEqual(calls, 1U);
    XCTAssertEqual(self.assembledErrors, 0U);
    XCTAssertEqual(self.lastFatalErrorDate, -1LL);
    XCTAssertTrue(FTTestANRStore(manager).isClosed);
    dependencies.issueDataProvider = nil;
}
- (void)testShutdownCancelsQueuedHistoricalProcessing {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    FTRUMDependencies *dependencies = [manager valueForKey:@"dependencies"];
    __block NSUInteger calls = 0;
    dependencies.issueDataProvider = ^NSDictionary *(FTIssueInfo *issue) { calls += 1; return @{}; };
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:6LL*NSEC_PER_SEC mainThreadBacktrace:@"main" allThreadsBacktrace:@"all" errorContextModel:self.fatalErrorContext.currentContextModel];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 7LL*NSEC_PER_SEC;
    [FTTestANRStore(manager) writeANRData:data];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0);
    dispatch_async(FTTestANRStore(manager).queue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
    });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    [FTTestANRProcessor(manager) reportPreviousANRIfFound];
    [manager shutDown];
    dispatch_semaphore_signal(release);
    dispatch_sync(FTTestANRStore(manager).queue, ^{});
    XCTAssertEqual(calls, 0U);
    dependencies.issueDataProvider = nil;
}
- (void)testOldStoreCannotOverwriteOrDeleteNewStoreData {
    FTLongTaskANRDataStore *oldStore = [self mockANRDataStore];
    FTLongTaskANRDataStore *newStore = [FTLongTaskANRDataStore new];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), release = dispatch_semaphore_create(0);
    dispatch_async(oldStore.queue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
    });
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0L);
    FTLongTaskANRData *data = [[FTLongTaskANRData alloc] initWithStartTimeNs:NSEC_PER_SEC durationNs:3100*NSEC_PER_MSEC mainThreadBacktrace:@"old" allThreadsBacktrace:nil errorContextModel:nil];
    data.usesEffectiveDuration = YES;
    data.endTimeNs = 5LL*NSEC_PER_SEC;
    [oldStore writeANRData:data];
    [oldStore shutDown];
    data.startTimeNs = 10LL*NSEC_PER_SEC;
    data.durationNs = 5100*NSEC_PER_MSEC;
    data.endTimeNs = 17LL*NSEC_PER_SEC;
    [newStore writeANRData:data];
    [newStore appendTimingWithStartTimeNs:10LL*NSEC_PER_SEC durationNs:6100*NSEC_PER_MSEC endTimeNs:19LL*NSEC_PER_SEC];
    [oldStore writeANRData:data]; // A late write and duplicate shutdown must have no effect.
    [oldStore appendTimingWithStartTimeNs:10LL*NSEC_PER_SEC durationNs:9100*NSEC_PER_MSEC endTimeNs:99LL*NSEC_PER_SEC];
    [oldStore deleteFile];
    [oldStore shutDown];
    dispatch_semaphore_signal(release);
    FTLongTaskANRData *saved = [newStore readANRData];
    XCTAssertEqual(saved.startTimeNs, 10LL*NSEC_PER_SEC);
    XCTAssertEqual(saved.durationNs, 6100*NSEC_PER_MSEC);
    XCTAssertEqual(saved.endTimeNs, 19LL*NSEC_PER_SEC);
    [newStore deleteFile];
}
- (void)testShutdownDuringCaptureCannotPersistOrReport {
    FTLongTaskManager *manager = [self timingManagerANR:YES freeze:YES threshold:250];
    [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
    __block NSUInteger freezes = 0;
    self.callBack = ^(NSString *stack, long long duration) { freezes += 1; };
    self.backtraceMock.onAllThreads = ^{ [manager shutDown]; };
    [self sendPhase:FTLongTaskPhaseCheckpoint duration:5001*NSEC_PER_MSEC end:7LL*NSEC_PER_SEC to:manager];
    [self sendPhase:FTLongTaskPhaseEnd duration:5100*NSEC_PER_MSEC end:8LL*NSEC_PER_SEC to:manager];
    dispatch_sync(FTTestANRStore(manager).queue, ^{});
    XCTAssertEqual(freezes, 0U);
    XCTAssertEqual(self.reportedANRTimes.count, 0U);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:FTTestANRStore(manager).dataStorePath]);
    self.backtraceMock.onAllThreads = nil;
    self.callBack = nil;
}
- (void)testFreezeThresholdCheckpointsAreSelectedByManager {
    NSDictionary<NSNumber *, NSNumber *> *checkpoints = @{@250: @251, @300: @301, @6000: @6001};
    for (NSNumber *threshold in checkpoints) {
        FTLongTaskManager *manager = [self timingManagerANR:NO freeze:YES threshold:threshold.longValue];
        uint64_t checkpoint = [self sendPhase:FTLongTaskPhaseBegin duration:0 end:NSEC_PER_SEC to:manager];
        XCTAssertEqual(checkpoint, checkpoints[threshold].unsignedLongLongValue * NSEC_PER_MSEC);
        [manager shutDown];
    }
}
- (void)testLongTaskDetector_runLoopCallbackDoesNotWaitForStalledSnapshotReader {
    FTLongTaskDetectorDelegateMock *delegate = [[FTLongTaskDetectorDelegateMock alloc] init];
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:delegate];
    Ivar lockIvar = class_getInstanceVariable(FTLongTaskDetector.class, "_runLoopLock");
    os_unfair_lock *oldSnapshotLock = lockIvar ? (os_unfair_lock *)((uint8_t *)(__bridge void *)detector + ivar_getOffset(lockIvar)) : NULL;
    if (oldSnapshotLock) {
        // Simulate the detector being suspended while it owns the snapshot lock.
        os_unfair_lock_lock(oldSnapshotLock);
    }

    dispatch_semaphore_t callbackDone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [detector recordRunLoopBeginActivity:kCFRunLoopBeforeSources atTimeNs:1000LL * NSEC_PER_MSEC];
        dispatch_semaphore_signal(callbackDone);
    });
    long callbackResult = dispatch_semaphore_wait(callbackDone, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
    if (oldSnapshotLock) {
        os_unfair_lock_unlock(oldSnapshotLock);
    }
    if (callbackResult != 0) {
        dispatch_semaphore_wait(callbackDone, DISPATCH_TIME_FOREVER);
    }
    XCTAssertEqual(callbackResult, 0, @"RunLoop callback must not wait for a stalled detector thread");
}
- (void)testLongTaskDetector_runLoopReadKeepsCallbackFieldsTogether {
    FTLongTaskDetectorDelegateMock *delegate = [[FTLongTaskDetectorDelegateMock alloc] init];
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:delegate];
    dispatch_semaphore_t writerDone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (uint64_t generation = 1; generation <= 5000; generation++) {
            CFRunLoopActivity activity = generation & 1 ? kCFRunLoopBeforeSources : kCFRunLoopAfterWaiting;
            [detector recordRunLoopBeginActivity:activity atTimeNs:(long long)generation * NSEC_PER_MSEC];
        }
        dispatch_semaphore_signal(writerDone);
    });

    BOOL consistent = YES;
    for (NSUInteger attempt = 0; attempt < 10000; attempt++) {
        FTLongTaskRunLoopSnapshot snapshot;
        if (![detector readRunLoopSnapshot:&snapshot] || snapshot.sequence == 0) {
            continue;
        }
        uint64_t generation = snapshot.sequence / 2;
        CFRunLoopActivity expectedActivity = generation & 1 ? kCFRunLoopBeforeSources : kCFRunLoopAfterWaiting;
        if (snapshot.activity != expectedActivity || snapshot.startTimeNs != (long long)generation * NSEC_PER_MSEC) {
            consistent = NO;
            break;
        }
    }
    XCTAssertEqual(dispatch_semaphore_wait(writerDone, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0);
    FTLongTaskRunLoopSnapshot finalSnapshot;
    BOOL finalReadValid = [detector readRunLoopSnapshot:&finalSnapshot];
    XCTAssertTrue(finalReadValid);
    if (finalReadValid) {
        XCTAssertEqual(finalSnapshot.sequence / 2, 5000);
        XCTAssertEqual(finalSnapshot.startTimeNs, 5000LL * NSEC_PER_MSEC);
        XCTAssertEqual(finalSnapshot.activity, kCFRunLoopAfterWaiting);
    }
    XCTAssertTrue(consistent);
}
-(void)testLongTaskFilePath{
#if TARGET_OS_TV
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#elif TARGET_OS_IOS
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
#else
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
#endif
    pathString = [pathString stringByAppendingPathComponent:@"com.ft.sdk"];
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.fatalErrorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:nil];
    [dependencies.fatalErrorContext setLastSessionState:[[FTRUMSessionState alloc] init]];
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self backtraceReporting:[FTCrash shared].backtraceReporting enableTrackAppANR:NO enableTrackAppFreeze:NO freezeDurationMs:250];
    NSString *path = FTTestANRStore(longTaskManager).dataStorePath;
    
    XCTAssertTrue([pathString isEqualToString:[path stringByDeletingLastPathComponent]]);
    [longTaskManager shutDown];
}
- (void)recordStack:(NSString *)slowStack duration:(long long)duration {
    if(self.callBack){
        self.callBack(slowStack, duration);
    }
}
- (void)longTaskDetected:(FTLongTaskEvent *)event {
    self.observedEndTimeNs=event.endTimeNs;
    [self recordStack:event.stack duration:event.durationNs];
}
-(void)anrStackDetected:(NSString *)slowStack time:(NSDate *)time{
    if(self.callBack){
        self.callBack(slowStack, 0);
    }
}
-(void)anrStackDetected:(NSString *)slowStack appState:(NSString *)appState time:(long long)time{
    [self.reportedANRTimes addObject:@(time)];
    if(self.callBack){
        self.callBack(slowStack, 0);
    }
}
-(void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time{
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}
-(void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache{
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}
-(void)lastFatalErrorIfFound:(long long)errorDate{
    self.lastFatalErrorDate = errorDate;
}

- (void)rumWrite:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime {
    
}


- (void)rumWriteAssembledData:(nonnull NSString *)source tags:(nonnull NSDictionary *)tags fields:(nonnull NSDictionary *)fields time:(long long)time {
    if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) self.assembledErrors += 1;
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}

@end
