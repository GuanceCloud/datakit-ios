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
#import "FTJSONUtil.h"
typedef void (^FTLongTaskCallBack)(NSString *slowStack, long long duration);
typedef void (^FTWriteCallBack)(NSDictionary *fields, NSDictionary *tags);

@interface FTLongTaskBacktraceMock : NSObject<FTBacktraceReporting>
@property (nonatomic, copy) NSString *mainThreadBacktrace;
@property (nonatomic, copy) NSString *allThreadsBacktrace;
@property (nonatomic, assign) NSInteger allThreadsCallCount;
@property (nonatomic, assign) NSInteger nilAllThreadsResponseCount;
@end

@implementation FTLongTaskBacktraceMock
- (NSString *)generateMainThreadBacktrace {
    return self.mainThreadBacktrace;
}
- (NSString *)generateAllThreadsBacktrace {
    self.allThreadsCallCount += 1;
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

@end


@implementation FTLongTaskFileHandleTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    dependencies.fatalErrorContext = errorContext;
    if (!backtraceReporting) {
        [FTCrash setupWithMonitoringType:FTCrashCMonitorTypeSystem writer:self enableMonitorMemory:YES enableMonitorCpu:YES];
        backtraceReporting = [FTCrash shared].backtraceReporting;
    }
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self backtraceReporting:backtraceReporting enableTrackAppANR:enableANR enableTrackAppFreeze:enableFreeze freezeDurationMs:freezeDurationMs];
    [longTaskManager.anrDataStore deleteFile];
    return longTaskManager;
}
- (FTLongTaskANRDataStore *)mockANRDataStore{
    FTLongTaskANRDataStore *store = [[FTLongTaskANRDataStore alloc] init];
    [store deleteFile];
    return store;
}
- (void)testLongTask_fileHandle{
    // When the given filePath is a folder, creating fileHandle will fail
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dataStorePath = [pathString stringByAppendingPathComponent:@"FTLongTaskTestFolder"];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dataStorePath withIntermediateDirectories:YES attributes:nil error:&error];
    store.dataStorePath = dataStorePath;
    XCTAssertNoThrow([store fileHandle]);
    XCTAssertNil([store fileHandle]);
    [[NSFileManager defaultManager] removeItemAtPath:dataStorePath error:&error];
    [store deleteFile];
}
- (void)testLongTask_appendData{
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    
    // Normal logic to add data
    XCTAssertNoThrow([store appendData:[@"test_appendData" dataUsingEncoding:NSUTF8StringEncoding]]) ;
    dispatch_sync(store.queue, ^{});
    NSString *dataStorePath = store.dataStorePath;
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertTrue([str containsString:@"test_appendData"]);
    
    // Add nil
    XCTAssertNoThrow([store appendData:nil]) ;
    
    NSError *error;
    if (@available(iOS 13.0, *)) {
        [store.fileHandle closeAndReturnError:&error];
    } else {
        [store.fileHandle closeFile];
    }
    // File is closed, adding data again will cause an error
    XCTAssertNoThrow([store appendData:[@"test_appendData2" dataUsingEncoding:NSUTF8StringEncoding]]) ;
    dispatch_sync(store.queue, ^{});
    NSData *data2 = [NSData dataWithContentsOfFile:dataStorePath];
    NSString *str2= [[NSString alloc]initWithData:data2 encoding:NSUTF8StringEncoding];
    XCTAssertFalse([str2 containsString:@"test_appendData2"]);
    
    [store deleteFile];
}
- (void)testLongTask_deleteFile{
    FTLongTaskANRDataStore *store = [self mockANRDataStore];
    [store appendData:[@"deleteFile" dataUsingEncoding:NSUTF8StringEncoding]];

    dispatch_sync(store.queue, ^{});
    NSString *dataStorePath = store.dataStorePath;
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
//    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertTrue(data.length>0);
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"deleteFileInAsyncQueue"];
    // Execute `deleteFile` method asynchronously in ANR data store's queue
    dispatch_async(store.queue, ^{
        NSFileHandle *fileHandle = store.fileHandle;
        [store deleteFile];
        NSFileHandle *newFileHandle = store.fileHandle;
        XCTAssertFalse([newFileHandle isEqual:fileHandle]);
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
    NSData *newData = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(newData.length == 0);
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc]initWithDescription:@"deleteFileInSyncQueue"];
    [store appendData:[@"deleteFileInSyncQueue" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Execute `deleteFile` method synchronously in ANR data store's queue
    dispatch_sync(store.queue, ^{});
    NSData *data2 = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data2.length>0);
    dispatch_sync(store.queue, ^{
        NSFileHandle *fileHandle = store.fileHandle;
        [store deleteFile];
        NSFileHandle *newFileHandle = store.fileHandle;
        XCTAssertFalse([newFileHandle isEqual:fileHandle]);
        [expectation2 fulfill];
    });
    [self waitForExpectations:@[expectation2] timeout:2];
    NSData *data3 = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data3.length == 0);
    
    // Call outside of ANR data store's queue
    XCTAssertNoThrow([store deleteFile]);
    
    // Simulate deleting a non-existent file
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *path = [pathString stringByAppendingPathComponent:@"FTLongTaskTest_NOFILE.txt"];
    store.dataStorePath = path;
    
    XCTAssertNoThrow([store deleteFile]);
}
- (void)testLongTask_start_update_end{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    XCTAssertNoThrow([longTaskManager startLongTask:startTime]);
    XCTAssertNoThrow([longTaskManager updateLongTaskDate:0]);
    [longTaskManager updateLongTaskDate:[NSDate ft_currentNanosecondTimeStamp]];
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertTrue(slowStack != nil);
        XCTAssertTrue(duration>1000000000);
        hasCallBack = YES;
    };
    sleep(1);
    [longTaskManager endLongTask];
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
    [longTaskManager startLongTask:startTime];
    [longTaskManager updateLongTaskDate:startTime + 3100000000LL];
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    [longTaskManager updateLongTaskDate:startTime + 3600000000LL];
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    [longTaskManager endLongTask];
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
    [longTaskManager startLongTask:startTime];
    [longTaskManager updateLongTaskDate:startTime + 3100000000LL];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:longTaskManager.anrDataStore.dataStorePath];
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
    [longTaskManager startLongTask:startTime];
    [longTaskManager updateLongTaskDate:startTime + 3100000000LL];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:longTaskManager.anrDataStore.dataStorePath];
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
    [longTaskManager startLongTask:startTime];
    [longTaskManager updateLongTaskDate:startTime + 3100000000LL];
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 1);
    [longTaskManager updateLongTaskDate:startTime + 3600000000LL];
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 2);
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    [longTaskManager endLongTask];
    XCTAssertEqualObjects(reportedANRStack, backtraceMock.mainThreadBacktrace);
    self.callBack = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_endAnrDoesNotGenerateRecoveredAllThreadsBacktrace{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"recoveredAllThreadsBacktrace";
    self.backtraceMock = backtraceMock;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    [longTaskManager startLongTask:startTime];
    __block NSString *reportedANRStack = nil;
    self.callBack = ^(NSString *slowStack, long long duration) {
        reportedANRStack = slowStack;
    };
    [longTaskManager endLongTask];
    XCTAssertEqual(backtraceMock.allThreadsCallCount, 0);
    XCTAssertEqualObjects(reportedANRStack, backtraceMock.mainThreadBacktrace);
    self.callBack = nil;
    self.backtraceMock = nil;
    [longTaskManager shutDown];
}
- (void)testLongTask_rewritesANRDataWhenAllThreadsBacktraceCapturedAfterInitialWrite{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    backtraceMock.allThreadsBacktrace = @"allThreadsBacktrace\nThread 1:";
    backtraceMock.nilAllThreadsResponseCount = 1;
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableFreeze:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - 6000000000LL;
    [longTaskManager startLongTask:startTime];
    [longTaskManager updateLongTaskDate:startTime + 3100000000LL];
    [longTaskManager updateLongTaskDate:startTime + 3600000000LL];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:longTaskManager.anrDataStore.dataStorePath];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [content componentsSeparatedByString:@"\n___boundary.info.date___\n"];
    XCTAssertTrue(array.count == 3);
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
    XCTAssertEqualObjects(dict[@"allThreadsBacktrace"], @"allThreadsBacktrace\nThread 1:");
    FTLongTaskANRData *anrData = [longTaskManager.anrDataStore readANRData];
    XCTAssertEqual(anrData.lastUpdateTimeNs, startTime + 3600000000LL);
    [longTaskManager shutDown];
}
- (void)testLongTask_reportFatalANRDataIfFound{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    XCTAssertNoThrow([longTaskManager startLongTask:startTime]);
    XCTAssertNoThrow([longTaskManager updateLongTaskDate:0]);
    [longTaskManager updateLongTaskDate:startTime + 3100000000LL];
    [longTaskManager updateLongTaskDate:startTime + 5100000000LL];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    __block BOOL hasCallBack = NO;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) {
        XCTAssertTrue(fields[FT_KEY_LONG_TASK_STACK]);
        hasCallBack = YES;
    };
    XCTAssertNoThrow([longTaskManager reportPreviousANRIfFound]);
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    XCTAssertTrue(hasCallBack);
    [longTaskManager shutDown];
}
- (void)testLongTask_reportPreviousANRDeletesMalformedANRDataAndNotifiesNoFatal{
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    [longTaskManager.anrDataStore appendData:[@"broken ANR data" dataUsingEncoding:NSUTF8StringEncoding]];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    self.lastFatalErrorDate = -1;
    [longTaskManager reportPreviousANRIfFound];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:longTaskManager.anrDataStore.dataStorePath];
    XCTAssertTrue(data.length == 0);
    XCTAssertEqual(self.lastFatalErrorDate, 0);
    [longTaskManager shutDown];
}
- (void)testLongTask_freezeOnlyDoesNotWriteANRDataButReportsFreeze{
    FTLongTaskBacktraceMock *backtraceMock = [[FTLongTaskBacktraceMock alloc] init];
    backtraceMock.mainThreadBacktrace = @"mainThreadBacktrace";
    FTLongTaskManager *longTaskManager = [self mockLongTaskManagerWithBacktraceReporting:backtraceMock enableANR:NO enableFreeze:YES freezeDurationMs:250];
    NSString *dataStorePath = longTaskManager.anrDataStore.dataStorePath;
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - NSEC_PER_SEC;
    [longTaskManager startLongTask:startTime];
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertEqualObjects(slowStack, @"mainThreadBacktrace");
        XCTAssertTrue(duration > 250 * NSEC_PER_MSEC);
        hasCallBack = YES;
    };
    [longTaskManager endLongTask];
    dispatch_sync(longTaskManager.anrDataStore.queue, ^{});
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data.length == 0);
    XCTAssertTrue(hasCallBack);
    self.callBack = nil;
    [longTaskManager shutDown];
}
- (void)testLongTaskDetector_customFreezeDurationUpdatesLimitMillisecond{
    FTLongTaskDetector *detector = [[FTLongTaskDetector alloc] initWithDelegate:(id<FTLongTaskProtocol>)self];
    detector.limitFreezeMillisecond = 300;
    XCTAssertEqual([[detector valueForKey:@"limitMillisecond"] longValue], 300);
    detector.limitFreezeMillisecond = 6000;
    XCTAssertEqual([[detector valueForKey:@"limitMillisecond"] longValue], FT_ANR_THRESHOLD_MS);
}
-(void)testLongTaskFilePath{
#if TARGET_OS_TV
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#elif TARGET_OS_IOS
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
#endif
    pathString = [pathString stringByAppendingPathComponent:@"com.ft.sdk"];
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.fatalErrorContext = [[FTFatalErrorContext alloc]initWithErrorInfoProvider:nil];
    [dependencies.fatalErrorContext setLastSessionState:[[FTRUMSessionState alloc] init]];
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self backtraceReporting:[FTCrash shared].backtraceReporting enableTrackAppANR:NO enableTrackAppFreeze:NO freezeDurationMs:250];
    NSString *path = longTaskManager.anrDataStore.dataStorePath;
    
    XCTAssertTrue([pathString isEqualToString:[path stringByDeletingLastPathComponent]]);
    [longTaskManager shutDown];
}
-(void)longTaskStackDetected:(NSString *)slowStack duration:(long long)duration time:(long long)time{
    if(self.callBack){
        self.callBack(slowStack, duration);
    }
}
-(void)anrStackDetected:(NSString *)slowStack time:(NSDate *)time{
    if(self.callBack){
        self.callBack(slowStack, 0);
    }
}
-(void)anrStackDetected:(NSString *)slowStack appState:(NSString *)appState time:(long long)time{
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
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}

@end
