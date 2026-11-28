//
//  FTCrashStateReadTests.m
//  FTMobileSDK
//
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
#import "FTCrashMonitor_AppState.h"
#include <string.h>

@interface FTCrashStateReadTests : XCTestCase
@property (nonatomic, copy) NSString *directory;
@property (nonatomic, copy) NSString *path;
@end

@implementation FTCrashStateReadTests
- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    self.path = [self.directory stringByAppendingPathComponent:@"CrashState.json"];
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:self.directory
        withIntermediateDirectories:YES attributes:nil error:nil]);
}
- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:self.directory error:nil];
    [super tearDown];
}
- (void)writeState {
    NSDictionary *json = @{@"version":@1, @"crashedLastLaunch":@YES,
        @"crashedLastDate":@1700000000, @"activeDurationSinceLastCrash":@1.25,
        @"backgroundDurationSinceLastCrash":@2.5, @"launchesSinceLastCrash":@3,
        @"sessionsSinceLastCrash":@4};
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    XCTAssertTrue([data writeToFile:self.path atomically:YES]);
}
- (BOOL)readPath:(NSString *)path into:(FTCrash_AppState *)state {
    __block BOOL success;
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        success = ftcrashstate_readPersistedState(path.fileSystemRepresentation, state);
    });
    return success;
}
- (void)testReadDoesNotChangeLiveStateOrEnableMonitoring {
    [self writeState];
    FTCrash_AppState before;
    memcpy(&before, ftcrashstate_currentState(), sizeof(before));
    FTCrashMonitorAPI *api = ftcrashcm_appstate_getAPI();
    bool enabledBefore = api->isEnabled();
    FTCrash_AppState snapshot = {0};
    XCTAssertTrue([self readPath:self.path into:&snapshot]);
    XCTAssertTrue(snapshot.crashedLastLaunch);
    XCTAssertEqual(snapshot.crashedLastTimestamp, 1700000000u);
    XCTAssertEqualWithAccuracy(snapshot.activeDurationSinceLastCrash, 1.25, 0.000001);
    XCTAssertEqualWithAccuracy(snapshot.backgroundDurationSinceLastCrash, 2.5, 0.000001);
    XCTAssertEqual(snapshot.launchesSinceLastCrash, 3);
    XCTAssertEqual(snapshot.sessionsSinceLastCrash, 4);
    XCTAssertEqual(snapshot.sessionsSinceLaunch, 0);
    XCTAssertFalse(snapshot.crashedThisLaunch);
    XCTAssertEqual(memcmp(&before, ftcrashstate_currentState(), sizeof(before)), 0);
    XCTAssertEqual(api->isEnabled(), enabledBefore);
}
- (void)testRepeatedReadsDoNotConsumeOrRewriteState {
    [self writeState];
    NSData *bytes = [NSData dataWithContentsOfFile:self.path];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
    for (NSUInteger i = 0; i < 3; i++) {
        FTCrash_AppState snapshot = {0};
        XCTAssertTrue([self readPath:self.path into:&snapshot]);
        XCTAssertTrue(snapshot.crashedLastLaunch);
        XCTAssertEqual(snapshot.crashedLastTimestamp, 1700000000u);
    }
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.path], bytes);
    NSDictionary *after = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
    XCTAssertEqualObjects(after[NSFileModificationDate], attributes[NSFileModificationDate]);
    XCTAssertEqualObjects(after[NSFileSystemFileNumber], attributes[NSFileSystemFileNumber]);
}
- (void)testMissingFileDoesNotCreateDirectoryOrChangeOutput {
    NSString *missing = [[self.directory stringByAppendingPathComponent:@"missing"] stringByAppendingPathComponent:@"CrashState.json"];
    FTCrash_AppState snapshot = {.sessionsSinceLaunch = 77};
    XCTAssertFalse([self readPath:missing into:&snapshot]);
    XCTAssertEqual(snapshot.sessionsSinceLaunch, 77);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:missing.stringByDeletingLastPathComponent]);
}
- (void)testInvalidJSONDoesNotPublishPartialState {
    FTCrash_AppState before;
    memcpy(&before, ftcrashstate_currentState(), sizeof(before));
    NSData *data = [@"{\"crashedLastLaunch\":true,\"version\":99}" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([data writeToFile:self.path atomically:YES]);
    FTCrash_AppState snapshot = {.sessionsSinceLaunch = 77};
    XCTAssertFalse([self readPath:self.path into:&snapshot]);
    XCTAssertEqual(snapshot.sessionsSinceLaunch, 77);
    XCTAssertEqual(memcmp(&before, ftcrashstate_currentState(), sizeof(before)), 0);
    data = [@"{\"crashedLastLaunch\":true," dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([data writeToFile:self.path atomically:YES]);
    XCTAssertFalse([self readPath:self.path into:&snapshot]);
    XCTAssertEqual(snapshot.sessionsSinceLaunch, 77);
    XCTAssertEqual(memcmp(&before, ftcrashstate_currentState(), sizeof(before)), 0);
}
- (void)testNullArgumentsLeaveLiveStateAndOutputUnchanged {
    [self writeState];
    FTCrash_AppState before;
    memcpy(&before, ftcrashstate_currentState(), sizeof(before));
    FTCrash_AppState snapshot = {.sessionsSinceLaunch = 77};
    XCTAssertFalse([self readPath:nil into:&snapshot]);
    XCTAssertFalse([self readPath:self.path into:NULL]);
    XCTAssertEqual(snapshot.sessionsSinceLaunch, 77);
    XCTAssertEqual(memcmp(&before, ftcrashstate_currentState(), sizeof(before)), 0);
}
- (void)testEachReadClearsFieldsAbsentFromTheNextSnapshot {
    [self writeState];
    FTCrash_AppState snapshot = {0};
    XCTAssertTrue([self readPath:self.path into:&snapshot]);
    XCTAssertEqual(snapshot.launchesSinceLastCrash, 3);
    NSData *minimal = [@"{\"version\":1,\"crashedLastLaunch\":false}" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([minimal writeToFile:self.path atomically:YES]);
    XCTAssertTrue([self readPath:self.path into:&snapshot]);
    XCTAssertFalse(snapshot.crashedLastLaunch);
    XCTAssertEqual(snapshot.crashedLastTimestamp, 0u);
    XCTAssertEqual(snapshot.launchesSinceLastCrash, 0);
    XCTAssertEqual(snapshot.sessionsSinceLastCrash, 0);
    XCTAssertEqual(snapshot.activeDurationSinceLastCrash, 0);
    XCTAssertEqual(snapshot.backgroundDurationSinceLastCrash, 0);
}
- (void)testInvalidDocumentTypesDoNotCrashOrPublishState {
    for (NSString *json in @[@"true", @"42", @"4.2", @"null", @"[]", @"\"state\"", @"{\"ignored\":[true]}"]) {
        XCTAssertTrue([[json dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self.path atomically:YES]);
        FTCrash_AppState snapshot = {.sessionsSinceLaunch = 77};
        XCTAssertFalse([self readPath:self.path into:&snapshot]);
        XCTAssertEqual(snapshot.sessionsSinceLaunch, 77);
    }
}
- (void)testInvalidEarlyFactPreservesOtherCrashHistory {
    NSString *json = @"{\"version\":1,\"crashedLastLaunch\":true,\"crashedLastDate\":1700000000,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":4.999}";
    XCTAssertTrue([[json dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self.path atomically:YES]);
    FTCrash_AppState snapshot = {0};
    XCTAssertTrue([self readPath:self.path into:&snapshot]);
    XCTAssertTrue(snapshot.crashedLastLaunch);
    XCTAssertEqual(snapshot.crashedLastTimestamp, 1700000000u);
    XCTAssertFalse(snapshot.previousEarlyCrash);
}
- (void)testConcurrentReadsReturnIndependentSnapshots {
    [self writeState];
    FTCrash_AppState before;
    memcpy(&before, ftcrashstate_currentState(), sizeof(before));
    NSString *otherPath = [self.directory stringByAppendingPathComponent:@"other.json"];
    NSData *other = [@"{\"version\":1,\"crashedLastLaunch\":false,\"launchesSinceLastCrash\":9}" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([other writeToFile:otherPath atomically:YES]);
    dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(size_t index) {
        FTCrash_AppState snapshot = {0};
        NSString *path = index % 2 ? otherPath : self.path;
        XCTAssertTrue(ftcrashstate_readPersistedState(path.fileSystemRepresentation, &snapshot));
        XCTAssertEqual(snapshot.crashedLastLaunch, index % 2 == 0);
        XCTAssertEqual(snapshot.launchesSinceLastCrash, index % 2 ? 9 : 3);
    });
    XCTAssertEqual(memcmp(&before, ftcrashstate_currentState(), sizeof(before)), 0);
}
@end
