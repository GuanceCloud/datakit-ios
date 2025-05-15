//
//  FTLongTaskTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/10/26.
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
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
}
- (void)testTrackLongTask{
    [self initSDKWithEnableTrackAppANR:NO longTask:YES];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppLongTask"] tap];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
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
    
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
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
    
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
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
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
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
 格式 ：
 dictStr  :{startDate:
            duration:
            sessionContext:
            backtrace:
            isANR:
  (optional)view:{tags:
                  fields:
                  time:}
            }
 boundary : "\n___boundary.info.date___\n"
 updateDate:
            date1\n
            date2\n
 */
- (void)testDataSoreANRDataFormat{
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    [FTModelHelper startViewWithName:@"TestAnrFormat"];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTLongTaskManager *longTaskManager = [[FTGlobalRumManager sharedInstance] valueForKey:@"longTaskManager"];
    NSString *dataStorePath = [longTaskManager valueForKey:@"dataStorePath"];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
        XCTAssertTrue(data.length>100);
        NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if(str.length>0){
            XCTAssertTrue([str containsString:@"\n___boundary.info.date___\n"]);
            NSArray *array = [str componentsSeparatedByString:@"\n___boundary.info.date___\n"];
            XCTAssertTrue(array.count == 2);
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:array[0]];
            XCTAssertTrue([dict.allKeys containsObject:@"startDate"]&&
                          [dict.allKeys containsObject:@"duration"]&&
                          [dict.allKeys containsObject:@"sessionContext"]&&
                          [dict.allKeys containsObject:@"backtrace"]&&
                          [dict.allKeys containsObject:@"isANR"]);
            XCTAssertTrue([dict.allKeys containsObject:@"view"]);
            NSDictionary *view = dict[@"view"];
            NSDictionary *sessionContext = dict[@"sessionContext"];
            NSString *viewId = view[FT_TAGS][FT_KEY_VIEW_ID];
            NSString *sessionViewId = sessionContext[FT_KEY_VIEW_ID];
            XCTAssertTrue([viewId isEqualToString:sessionViewId]);
            NSArray *dates = [array[1] componentsSeparatedByString:@"\n"];
            [dates enumerateObjectsUsingBlock:^(NSString  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if(obj.length>0){
                    long long updateDate = [obj longLongValue];
                    XCTAssertTrue(updateDate - startTime < 3000000000);
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
// longtask 没有结束时用户手动关闭SDK
// 验证：无数据添加，无缓存、无文件
- (void)testShutdownWhenLongTaskNotEnd{
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    FTLongTaskManager *longTaskManager = [[FTGlobalRumManager sharedInstance] valueForKey:@"longTaskManager"];
    NSString *dataStorePath = [longTaskManager valueForKey:@"dataStorePath"];
    long long startTime = [NSDate ft_currentNanosecondTimeStamp];
    [tester waitForTimeInterval:0.2];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:dataStorePath];
        XCTAssertTrue(data.length>0);
        CFTimeInterval duration = [FTTestUtils functionElapsedTime:^{
            [FTMobileAgent shutDown];
        }];
        XCTAssertTrue(duration<0.1);
    });
    [self mockAnr];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
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
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    pathString = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:pathString error:&error];
    [[NSFileManager defaultManager] createFileAtPath:pathString contents:nil attributes:nil];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:pathString];
    NSString *str = @"{\"startDate\":1715416161781327872,\"isANR\":false,\"sessionContext\":{\"session_id\":\"28a4b4960c5e410b9dc08ef7b27019ac\",\"view_referrer\":\"DemoViewController\",\"view_name\":\"CrashVC\",\"session_type\":\"user\",\"view_id\":\"3fe57956e0db4bef9b58f6fbb2d616a7\"},\"backtrace\":\"test_backtrace\",\"view\":{\"time\":1715416158025487872,\"tags\":{\"session_id\":\"28a4b4960c5e410b9dc08ef7b27019ac\",\"view_referrer\":\"UITabBarController\",\"view_name\":\"DemoViewController\",\"session_type\":\"user\",\"view_id\":\"d2dfb5994596450e9f9b9521008dafc0\"},\"fields\":{\"fps_mini\":3.8665922570805944,\"cpu_tick_count\":457,\"view_long_task_count\":0,\"cpu_tick_count_per_second\":208.70286551518785,\"is_active\":false,\"view_action_count\":1,\"view_update_time\":1,\"memory_max\":97737536,\"fps_avg\":56.242399636138515,\"time_spent\":2189715981,\"loading_time\":30997702002,\"view_resource_count\":0,\"memory_avg\":67175594.666666672,\"view_error_count\":0}},\"duration\":263450026,\"errorMonitorInfo\":{\"locale\":\"en\",\"cpu_use\":1,\"memory_total\":\"16.00G\",\"memory_use\":0.56642818450927734,\"battery_use\":0}}\n___boundary.info.date___\n1715416162300324864\n1715416162555699712\n1715416162809228032\n1715416167127158272\n1715416167382233088\n1715416167635441920\n";
    if (@available(iOS 13.0, *)) {
        [fileHandle seekToOffset:0 error:&error];
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    } else {
        [fileHandle seekToFileOffset:0];
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
                   
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasLongTask = NO,hasAnr = NO,hasView = NO;
    [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
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
    [FTMobileAgent shutDown];

}
- (void)test_reportFatalWatchDogIfFound_noAnr{
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    pathString = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:pathString error:&error];
    [[NSFileManager defaultManager] createFileAtPath:pathString contents:nil attributes:nil];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:pathString];
    NSString *str = @"{\"startDate\":1715416161781327872,\"isANR\":false,\"sessionContext\":{\"session_id\":\"28a4b4960c5e410b9dc08ef7b27019ac\",\"view_referrer\":\"DemoViewController\",\"view_name\":\"CrashVC\",\"session_type\":\"user\",\"view_id\":\"3fe57956e0db4bef9b58f6fbb2d616a7\"},\"backtrace\":\"test_backtrace\",\"view\":{\"time\":1715416158025487872,\"tags\":{\"session_id\":\"28a4b4960c5e410b9dc08ef7b27019ac\",\"view_referrer\":\"UITabBarController\",\"view_name\":\"DemoViewController\",\"session_type\":\"user\",\"view_id\":\"d2dfb5994596450e9f9b9521008dafc0\"},\"fields\":{\"fps_mini\":3.8665922570805944,\"cpu_tick_count\":457,\"view_long_task_count\":0,\"cpu_tick_count_per_second\":208.70286551518785,\"is_active\":false,\"view_action_count\":1,\"view_update_time\":1,\"memory_max\":97737536,\"fps_avg\":56.242399636138515,\"time_spent\":2189715981,\"loading_time\":30997702002,\"view_resource_count\":0,\"memory_avg\":67175594.666666672,\"view_error_count\":0}},\"duration\":263450026,\"errorMonitorInfo\":{\"locale\":\"en\",\"cpu_use\":1,\"memory_total\":\"16.00G\",\"memory_use\":0.56642818450927734,\"battery_use\":0}}\n___boundary.info.date___\n1715416162300324864\n1715416162555699712\n1715416162809228032\n";
    if (@available(iOS 13.0, *)) {
        [fileHandle seekToOffset:0 error:&error];
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    } else {
        [fileHandle seekToFileOffset:0];
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
                   
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasLongTask = NO,hasAnr = NO,hasView = NO;
    [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
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
