//
//  FTLongTaskTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2020/10/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestLongTaskVC.h"
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import <KIF/KIF.h>
#import "FTModelHelper.h"
#import "FTRUMManager.h"
#import "FTGlobalRumManager.h"
#import "FTLongTaskManager.h"
#import "FTTestUtils.h"
@interface FTLongTaskTest : KIFTestCase

@end
@implementation FTLongTaskTest
-(void)setUp{
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    pathString = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:pathString error:&error];
}
-(void)tearDown{
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:2];
}
- (void)initSDKWithEnableTrackAppANR:(BOOL)enable longTask:(BOOL)longTask{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appID = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appID];
    rumConfig.enableTrackAppANR = enable;
    rumConfig.enableTrackAppFreeze = longTask;
    rumConfig.enableTrackAppCrash = YES;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
}
- (void)testTrackLongTask{
    [self initSDKWithEnableTrackAppANR:YES longTask:YES];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppLongTask"] tap];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"Request timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] syncProcess];
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
        XCTAssertTrue(newCount-lastCount>0);
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        [FTModelHelper resolveModelArray:datas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
            if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
                XCTAssertTrue([fields.allKeys containsObject:FT_KEY_LONG_TASK_STACK]&&[fields.allKeys containsObject:FT_DURATION]);
            }
        }];
        NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        pathString = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:pathString]);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [FTMobileAgent shutDown];
}

- (void)testNoTrackLongTask{
    [self initSDKWithEnableTrackAppANR:NO longTask:NO];
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppLongTask"] tap];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] syncProcess];
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
        __block BOOL noLongTask = YES;
        __block long long longStarTime = 0;
        [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
            if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
                noLongTask = NO;
                longStarTime = time;
            }
            if(noLongTask == NO && [source isEqualToString:FT_RUM_SOURCE_VIEW]){
                XCTAssertTrue(time<longStarTime);
                *stop = YES;
            }
        }];
        XCTAssertTrue(noLongTask == YES);
        [expect fulfill];
        
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [FTMobileAgent shutDown];

}
- (void)testTrackAnrAndAnrStartTime{
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    [self mockAnr];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] syncProcess];
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        __block BOOL noAnr = YES;
        [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
            if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
                noAnr = NO;
                XCTAssertTrue(startTime-time<1000000000 || time-startTime<1000000000);
                *stop = YES;
            }
        }];
        XCTAssertTrue(noAnr == NO);
        [expect fulfill];
        
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [FTMobileAgent shutDown];

}
- (void)testNoTrackAnr{
    [self initSDKWithEnableTrackAppANR:NO longTask:NO];
    [self mockAnr];
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] syncProcess];
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        __block BOOL noAnr = YES;
        [FTModelHelper resolveModelArray:datas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
            if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
                noAnr = NO;
                *stop = YES;
            }
        }];
        XCTAssertTrue(noAnr == YES);
        [expect fulfill];
        
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [FTMobileAgent shutDown];
}
- (void)testLongTaskStartTime{
    [self initSDKWithEnableTrackAppANR:NO longTask:NO];
    __block long long startTime;
    CFTimeInterval duration = [FTTestUtils functionElapsedTime:^{
        startTime = [NSDate ft_currentNanosecondTimeStamp]-1000000000;
        [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"test_stack" duration:@(1000000000)];
    }]*1000000000;
    
    [[FTMobileAgent sharedInstance] syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL noLongTask = YES;
    [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]&&[fields[FT_KEY_LONG_TASK_STACK] isEqualToString:@"test_stack"]) {
            noLongTask = NO;
            XCTAssertTrue(time-startTime<duration);
            *stop = YES;
        }
    }];
    XCTAssertTrue(noLongTask == NO);
    [FTMobileAgent shutDown];
}
/**
 Format ：
 version: 2.0.0
 dictStr  :{startDate:
            duration:
            sessionContext:
            mainThreadBacktrace:
            allThreadsBacktrace:
            errorContextModel:
            isANR:
 errorContextModel:{appState:
                    lastSessionState:
                    lastViewContext:
                    dynamicContext:
                    globalAttributes:
                    errorMonitorInfo:}
 boundary : "\n___boundary.info.date___\n"
 updateDate:
            date1\n
            date2\n
 */
- (void)testDataSoreANRDataFormat{
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    [FTModelHelper startViewWithName:@"TestAnrFormat"];
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    FTLongTaskManager *longTaskManager = [[FTGlobalRumManager sharedInstance] valueForKey:@"longTaskManager"];
    NSString *dataStorePath = [longTaskManager valueForKey:@"dataStorePath"];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
        XCTAssertTrue(data.length>100);
        NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if(str.length>0){
            XCTAssertTrue([str containsString:@"\n___boundary.info.date___\n"]);
            NSArray *array = [str componentsSeparatedByString:@"\n___boundary.info.date___\n"];
            XCTAssertTrue(array.count == 3);
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[1]];
            XCTAssertTrue([dict.allKeys containsObject:@"startDate"]&&
                          [dict.allKeys containsObject:@"duration"]&&
                          [dict.allKeys containsObject:@"errorContextModel"]&&
                          [dict.allKeys containsObject:@"mainThreadBacktrace"]&&
                          [dict.allKeys containsObject:@"allThreadsBacktrace"]&&
                          [dict.allKeys containsObject:@"isANR"]);
            NSDictionary *view = dict[@"errorContextModel"][@"lastViewContext"];
            NSDictionary *sessionContext = dict[@"errorContextModel"][@"lastSessionState"];
            XCTAssertNotNil(view);
            XCTAssertNotNil(sessionContext);
            NSArray *dates = [array[2] componentsSeparatedByString:@"\n"];
            [dates enumerateObjectsUsingBlock:^(NSString  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if(obj.length>0){
                    long long updateDate = [obj longLongValue];
                    XCTAssertTrue(updateDate - startTime < 4000000000);
                }
            }];
        }
        [expect fulfill];
    });
    [self mockAnr];
    [self waitForExpectationsWithTimeout:8 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [FTMobileAgent shutDown];
}
// When the longtask has not been completed, the user manually call `+shutDown` method closes the SDK.
// Verification: No data addition, no cache, no files, no crashes
- (void)testShutdownWhenLongTaskNotEnd{
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    FTLongTaskManager *longTaskManager = [[FTGlobalRumManager sharedInstance] valueForKey:@"longTaskManager"];
    NSString *dataStorePath = [longTaskManager valueForKey:@"dataStorePath"];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    [tester waitForTimeInterval:0.2];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
        XCTAssertTrue(data.length>0);
        CFTimeInterval duration = [FTTestUtils functionElapsedTime:^{
            [FTMobileAgent shutDown];
        }];
        XCTAssertTrue(duration<0.1);
    });
    [self mockAnr];
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        __block BOOL noAnr = YES;
        [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
            if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
                noAnr = NO;
                XCTAssertTrue(startTime-time<1000000000 || time-startTime<1000000000);
                *stop = YES;
            }
        }];
        XCTAssertTrue(noAnr == YES);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:8 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
    XCTAssertTrue(data.length == 0);
}
- (void)test_reportFatalWatchDogIfFound_fatalAnr{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"longtask" ofType:@"log"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportDir = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *sdkDirectory = [appSupportDir URLByAppendingPathComponent:@"com.ft.sdk"];

    if (![fileManager fileExistsAtPath:sdkDirectory.path]) {
        [fileManager createDirectoryAtURL:sdkDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *fileURL = [sdkDirectory URLByAppendingPathComponent:@"longtask.log"];
    [fileManager copyItemAtPath:path toPath:fileURL.path error:nil];
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
                   
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasLongTask = NO,hasAnr = NO,hasView = NO;
    [FTModelHelper resolveModelArray:datas dataTypeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, NSString * _Nonnull type, BOOL * _Nonnull stop){
        XCTAssertTrue([type isEqualToString:FT_DATA_TYPE_RUM]);
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            hasLongTask = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasAnr = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            XCTAssertTrue([fields[FT_KEY_VIEW_LONG_TASK_COUNT] isEqual:@1]);
            XCTAssertTrue([fields[FT_KEY_VIEW_UPDATE_TIME] isEqual:@2]);
            XCTAssertTrue([fields[FT_KEY_VIEW_ERROR_COUNT] isEqual:@1]);
            hasView = YES;
        }
    }];
    XCTAssertTrue(hasLongTask);
    XCTAssertTrue(hasAnr);
    XCTAssertTrue(hasView);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]);
    [FTMobileAgent shutDown];

}
- (void)test_reportFatalWatchDogIfFound_noAnr{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"longtask_no_anr" ofType:@"log"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportDir = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *sdkDirectory = [appSupportDir URLByAppendingPathComponent:@"com.ft.sdk"];

    if (![fileManager fileExistsAtPath:sdkDirectory.path]) {
        [fileManager createDirectoryAtURL:sdkDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *fileURL = [sdkDirectory URLByAppendingPathComponent:@"longtask.log"];
    [fileManager copyItemAtPath:path toPath:fileURL.path error:nil];

    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    XCTestExpectation *expect = [self expectationWithDescription:@"Request Time!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
                   
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasLongTask = NO,hasAnr = NO,hasView = NO;
    [FTModelHelper resolveModelArray:datas dataTypeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, NSString * _Nonnull type, BOOL * _Nonnull stop){
        XCTAssertTrue([type isEqualToString:FT_DATA_TYPE_RUM]);
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            hasLongTask = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasAnr = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            XCTAssertTrue([fields[FT_KEY_VIEW_LONG_TASK_COUNT] isEqual:@1]);
            XCTAssertTrue([fields[FT_KEY_VIEW_ERROR_COUNT] isEqual:@0]);
            XCTAssertTrue([fields[FT_KEY_VIEW_UPDATE_TIME] isEqual:@2]);
            hasView = YES;
        }
    }];
    XCTAssertTrue(hasLongTask);
    XCTAssertFalse(hasAnr);
    XCTAssertTrue(hasView);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]);
    [FTMobileAgent shutDown];
}
- (void)mockAnr{
    NSLock *lock = [[NSLock alloc]init];
    [lock lock];
    [NSThread sleepForTimeInterval:0.2f];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [NSThread sleepForTimeInterval:6];
        [lock unlock];
    });
    dispatch_async(dispatch_get_main_queue(), ^
                   {
        [lock lock];
    });
    dispatch_async(dispatch_get_main_queue(), ^
                   {
        [lock unlock];
    });
}
@end
