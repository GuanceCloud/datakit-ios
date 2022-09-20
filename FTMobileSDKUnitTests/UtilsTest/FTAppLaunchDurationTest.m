//
//  FTAppLaunchDurationTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/9/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import "FTTrackDataManger+Test.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTDateUtil.h>
#import <FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTConstants.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>

@interface FTAppLaunchDurationTest : KIFTestCase

@end

@implementation FTAppLaunchDurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}
- (void)setSDK{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
  
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testLaunchCold{
    [self setSDK];
    [tester waitForTimeInterval:5];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *measurement = opdata[@"source"];
    BOOL haslaunch = NO;
    if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
        haslaunch = YES;
        XCTAssertTrue([tags[FT_RUM_KEY_ACTION_TYPE]
                       isEqualToString:@"launch_cold"]);
    }
    XCTAssertTrue(haslaunch);
}
- (void)testSetSdkAfterLaunch{
    [tester waitForTimeInterval:5];
    [self setSDK];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *measurement = opdata[@"source"];
    BOOL haslaunch = NO;
    if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
        haslaunch = YES;
        XCTAssertTrue([tags[FT_RUM_KEY_ACTION_TYPE]
                       isEqualToString:@"launch_cold"]);
    }
    XCTAssertTrue(haslaunch);
}
- (void)testLaunchHot{
    [self setSDK];
    [NSThread sleepForTimeInterval:2];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSThread sleepForTimeInterval:1];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [NSThread sleepForTimeInterval:1];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [NSThread sleepForTimeInterval:1];

    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *measurement = opdata[@"source"];
    BOOL haslaunch = NO;
    if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
        haslaunch = YES;
        XCTAssertTrue([tags[FT_RUM_KEY_ACTION_TYPE]
                       isEqualToString:@"launch_hot"]);
    }
    XCTAssertTrue(haslaunch);
}

@end
