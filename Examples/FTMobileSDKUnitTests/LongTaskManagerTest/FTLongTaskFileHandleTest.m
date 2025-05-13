//
//  FTLongTaskFileHandleTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/8.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTLongTaskManager+Test.h"
#import "FTRUMDependencies.h"
#import "FTFatalErrorContext.h"
#import "FTConstants.h"
#import "FTLog+Private.h"
typedef void (^FTLongTaskCallBack)(NSString *slowStack, long long duration);
typedef void (^FTWriteCallBack)(NSDictionary *fields, NSDictionary *tags);

@interface FTLongTaskFileHandleTest : XCTestCase<FTRunloopDetectorDelegate,FTRUMDataWriteProtocol>
@property (nonatomic, copy) FTLongTaskCallBack  callBack;
@property (nonatomic, copy) FTWriteCallBack  writeCallBack;

@end

@implementation FTLongTaskFileHandleTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (FTLongTaskManager *)mockLongTaskManager{
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.writer = self;
    FTFatalErrorContext *errorContext = [[FTFatalErrorContext alloc]init];
    errorContext.lastSessionContext = @{FT_RUM_KEY_SESSION_ID:@"test_session_id",
                                        FT_RUM_KEY_SESSION_TYPE:@"test"
    };
    dependencies.fatalErrorContext = errorContext;

    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self enableTrackAppANR:YES enableTrackAppFreeze:YES                                        freezeDurationMs:250];
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dataStorePath = [pathString stringByAppendingPathComponent:@"FTLongTaskTest.txt"];
    longTaskManager.dataStorePath = dataStorePath;
    return longTaskManager;
}
- (void)removeFile:(NSString *)filePath{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
}
- (void)testLongTask_fileHandle{
    // 给定的 filePath 是文件夹时，创建 fileHandle 会失败
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dataStorePath = [pathString stringByAppendingPathComponent:@"FTLongTaskTestFolder"];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dataStorePath withIntermediateDirectories:YES attributes:nil error:&error];
    longTaskManager.dataStorePath = dataStorePath;
    XCTAssertNoThrow([longTaskManager fileHandle]);
    XCTAssertNil([longTaskManager fileHandle]);
    [[NSFileManager defaultManager] removeItemAtPath:dataStorePath error:&error];
    [longTaskManager shutDown];
}
- (void)testLongTask_appendData{
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    [longTaskManager startLongTask:[NSDate date] backtrace:@"test_backtrace"];
    
    // 正常逻辑添加 data
    XCTAssertNoThrow([longTaskManager appendData:[@"test_appendData" dataUsingEncoding:NSUTF8StringEncoding]]) ;
    dispatch_sync(longTaskManager.queue, ^{});
    NSString *dataStorePath = [longTaskManager valueForKey:@"dataStorePath"];
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertTrue([str containsString:@"test_appendData"]);
    
    // 添加 nil
    XCTAssertNoThrow([longTaskManager appendData:nil]) ;
    
    NSError *error;
    if (@available(iOS 13.0, *)) {
        [longTaskManager.fileHandle closeAndReturnError:&error];
    } else {
        [longTaskManager.fileHandle closeFile];
    }
    // 文件已关闭，再次添加 data 会报错
    XCTAssertNoThrow([longTaskManager appendData:[@"test_appendData2" dataUsingEncoding:NSUTF8StringEncoding]]) ;
    dispatch_sync(longTaskManager.queue, ^{});
    NSData *data2 = [NSData dataWithContentsOfFile:dataStorePath];
    NSString *str2= [[NSString alloc]initWithData:data2 encoding:NSUTF8StringEncoding];
    XCTAssertFalse([str2 containsString:@"test_appendData2"]);
    
    [longTaskManager shutDown];
    [self removeFile:longTaskManager.dataStorePath];
}
- (void)testLongTask_deleteFile{
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    [longTaskManager startLongTask:[NSDate date] backtrace:@"test_backtrace_deleteFile"];
    dispatch_sync(longTaskManager.queue, ^{});
    NSString *dataStorePath = [longTaskManager valueForKey:@"dataStorePath"];
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertTrue(data.length>0);
    XCTAssertTrue([str containsString:@"test_backtrace_deleteFile"]);
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"deleteFileInAsyncQueue"];
    // 在 longTaskManager 中的 queue 异步执行 `deleteFile` 方法
    dispatch_async(longTaskManager.queue, ^{
        NSFileHandle *fileHandle = longTaskManager.fileHandle;
        [longTaskManager deleteFile];
        NSFileHandle *newFileHandle = longTaskManager.fileHandle;
        XCTAssertFalse([newFileHandle isEqual:fileHandle]);
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
    NSData *newData = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(newData.length == 0);
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc]initWithDescription:@"deleteFileInSyncQueue"];
    [longTaskManager appendData:[@"deleteFileInSyncQueue" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 在 longTaskManager 中的 queue 同步执行 `deleteFile` 方法
    dispatch_sync(longTaskManager.queue, ^{});
    NSData *data2 = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data2.length>0);
    dispatch_sync(longTaskManager.queue, ^{
        NSFileHandle *fileHandle = longTaskManager.fileHandle;
        [longTaskManager deleteFile];
        NSFileHandle *newFileHandle = longTaskManager.fileHandle;
        XCTAssertFalse([newFileHandle isEqual:fileHandle]);
        [expectation2 fulfill];
    });
    [self waitForExpectations:@[expectation2] timeout:2];
    NSData *data3 = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data3.length == 0);
    
    //  在 longTaskManager 中的 queue 外调用
    XCTAssertNoThrow([longTaskManager deleteFile]);
    
    // 模拟删除一个不存在的 file
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *path = [pathString stringByAppendingPathComponent:@"FTLongTaskTest_NOFILE.txt"];
    longTaskManager.dataStorePath = path;
    
    XCTAssertNoThrow([longTaskManager deleteFile]);
    [longTaskManager shutDown];
}
- (void)testLongTask_start_update_end{
    NSDate *date = [NSDate date];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    XCTAssertNoThrow([longTaskManager startLongTask:date backtrace:nil]);
    XCTAssertNoThrow([longTaskManager updateLongTaskDate:nil]);
    [longTaskManager updateLongTaskDate:[NSDate date]];
    __block BOOL hasCallBack = NO;
    self.callBack = ^(NSString *slowStack, long long duration) {
        XCTAssertTrue(slowStack == nil);
        XCTAssertTrue(duration>1000000000);
        hasCallBack = YES;
    };
    sleep(1);
    [longTaskManager endLongTask];
    self.callBack = nil;
    XCTAssertTrue(hasCallBack);

    [self removeFile:longTaskManager.dataStorePath];
    [longTaskManager shutDown];
}
- (void)testLongTask_reportFatalWatchDogIfFound{
    NSDate *date = [NSDate date];
    FTLongTaskManager *longTaskManager = [self mockLongTaskManager];
    XCTAssertNoThrow([longTaskManager startLongTask:date backtrace:@"reportFatalWatchDogIfFound"]);
    XCTAssertNoThrow([longTaskManager updateLongTaskDate:nil]);
    [longTaskManager updateLongTaskDate:[date dateByAddingTimeInterval:1]];
    dispatch_sync(longTaskManager.queue, ^{});
    __block BOOL hasCallBack = NO;
    self.writeCallBack = ^(NSDictionary *fields, NSDictionary *tags) {
        XCTAssertTrue([fields[FT_KEY_LONG_TASK_STACK] isEqualToString:@"reportFatalWatchDogIfFound"]);
        hasCallBack = YES;
    };
    XCTAssertNoThrow([longTaskManager reportFatalWatchDogIfFound]);
    dispatch_sync(longTaskManager.queue, ^{});
    XCTAssertTrue(hasCallBack);
    [longTaskManager shutDown];
}
-(void)testLongTaskFilePath{
#if TARGET_OS_TV
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#elif TARGET_OS_IOS
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#else
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
#endif
    [FTLog enableLog:YES];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    FTLongTaskManager *longTaskManager = [[FTLongTaskManager alloc]initWithDependencies:dependencies delegate:self enableTrackAppANR:NO enableTrackAppFreeze:NO                                        freezeDurationMs:250];
    NSString *path = longTaskManager.dataStorePath;
    
    XCTAssertTrue([pathString isEqualToString:[path stringByDeletingLastPathComponent]]);
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
-(void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}
-(void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache{
    if(self.writeCallBack){
        self.writeCallBack(fields, tags);
        self.writeCallBack = nil;
    }
}
-(void)lastFatalErrorIfFound:(long long)errorDate{
   
}
@end

