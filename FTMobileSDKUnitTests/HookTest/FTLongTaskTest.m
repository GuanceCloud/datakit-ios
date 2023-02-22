//
//  FTLongTaskTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/10/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestANRVC.h"
#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool.h"
#import "FTDateUtil.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTTrackDataManger+Test.h"
#import <KIF/KIF.h>
#import "FTModelHelper.h"
@interface FTLongTaskTest : KIFTestCase

@end
@implementation FTLongTaskTest
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
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];

    [[tester waitForViewWithAccessibilityLabel:@"TrackAppFreezeAndANR"] tap];

    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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

- (void)testNoTrackAnrBlock{
    [self initSDKWithEnableTrackAppANR:NO];
    [[tester waitForViewWithAccessibilityLabel:@"TrackAppFreezeAndANR"] tap];

    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] syncProcess];
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        __block BOOL noLongTask = YES;
        [FTModelHelper resolveModelArray:datas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
            if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
                noLongTask = NO;
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
@end
