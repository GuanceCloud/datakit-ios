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
#import "FTDateUtil.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTTrackDataManager+Test.h"
#import <KIF/KIF.h>
#import "FTModelHelper.h"
@interface FTLongTaskTest : KIFTestCase

@end
@implementation FTLongTaskTest
-(void)tearDown{
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:2];
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)initSDKWithEnableTrackAppANR:(BOOL)enable longTask:(BOOL)longTask{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appID = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appID];
    rumConfig.enableTrackAppANR = enable;
    rumConfig.enableTrackAppFreeze = longTask;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)testTrackLongTask{
    [self initSDKWithEnableTrackAppANR:NO longTask:YES];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppLongTask"] tap];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
}
- (void)testTrackAnrAndAnrStartTime{
    [self initSDKWithEnableTrackAppANR:YES longTask:NO];
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppCrash"] tap];
    long long startTime = [FTDateUtil currentTimeNanosecond];
    [tester waitForTimeInterval:0.2];
    [[tester waitForViewWithAccessibilityLabel:@"anr"] tap];
    
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
}
- (void)testNoTrackAnr{
    [self initSDKWithEnableTrackAppANR:NO longTask:NO];
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppCrash"] tap];
    [tester waitForTimeInterval:0.2];
    [[tester waitForViewWithAccessibilityLabel:@"anr"] tap];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
}
- (void)testLongTaskStartTime{
    [self initSDKWithEnableTrackAppANR:NO longTask:NO];
    long long startTime = [FTDateUtil currentTimeNanosecond]-1000000;
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"test_stack" duration:@(1000000)];
    
    [[FTMobileAgent sharedInstance] syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL noLongTask = YES;
    [FTModelHelper resolveModelArray:datas timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time,BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            noLongTask = NO;
            XCTAssertTrue(time-startTime<10000);
            *stop = YES;
        }
    }];
    XCTAssertTrue(noLongTask == NO);
    
}
@end
