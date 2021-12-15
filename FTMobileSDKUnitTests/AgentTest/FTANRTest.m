//
//  FTANRTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/10/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestANRVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTDateUtil.h>
#import <FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTMobileAgent/FTConstants.h>
#import "FTTrackDataManger+Test.h"
#import <KIF/KIF.h>

@interface FTANRTest : KIFTestCase

@end
@implementation FTANRTest
-(void)tearDown{
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:2];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)initSDKWithEnableTrackAppANR:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    if (enable) {
        rumConfig.enableTrackAppANR = enable;
        rumConfig.enableTrackAppFreeze = enable;
    }
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)testTrackAnrBlock{
    [self initSDKWithEnableTrackAppANR:YES];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_RUM];

    [[tester waitForViewWithAccessibilityLabel:@"TrackAppFreezeAndANR"] tap];
    [tester waitForTimeInterval:1];

    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_RUM];
        XCTAssertTrue(newCount-lastCount>0);

        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];

        for (NSInteger i=0; i<datas.count; i++) {
           FTRecordModel *model = datas[i];
           NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
            NSDictionary *opdata = [dict valueForKey:@"opdata"];

            NSString *measurement = opdata[@"measurement"];
            if ([measurement isEqualToString:@"long_task"]) {
                NSDictionary *field = [opdata valueForKey:@"field"];
                XCTAssertTrue([field.allKeys containsObject:@"long_task_stack"]&&[field.allKeys containsObject:@"duration"]);
            }
        }
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}

- (void)testNoTrackAnrBlock{
    [self initSDKWithEnableTrackAppANR:NO];
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppFreezeAndANR"] tap];
    [tester waitForTimeInterval:1];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        BOOL noLongTask = YES;
        for (NSInteger i=0; i<datas.count; i++) {
           FTRecordModel *model = datas[i];
           NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
            NSDictionary *opdata = [dict valueForKey:@"opdata"];

            NSString *measurement = opdata[@"measurement"];
            if ([measurement isEqualToString:@"long_task"]) {
                noLongTask = NO;
            }
        }
        XCTAssertTrue(noLongTask == YES);
        [expect fulfill];
        
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
