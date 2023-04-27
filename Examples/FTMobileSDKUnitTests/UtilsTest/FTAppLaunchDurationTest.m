//
//  FTAppLaunchDurationTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/9/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import "FTMobileAgent.h"
#import "FTTrackDataManager+Test.h"
#import "FTTrackerEventDBTool.h"
#import "FTDateUtil.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
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
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testLaunchCold{
    [self setSDK];
    [[NSNotificationCenter defaultCenter] addObserver:self
selector:@selector(applicationDidBecomeActive:)
    name:UIApplicationDidBecomeActiveNotification
object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)applicationDidBecomeActive:(NSNotification *)noti{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *measurement = opdata[@"source"];
    BOOL haslaunch = NO;
    if ([measurement isEqualToString:FT_RUM_SOURCE_ACTION]) {
        haslaunch = YES;
        XCTAssertTrue([tags[FT_KEY_ACTION_TYPE]
                       isEqualToString:@"launch_cold"]);
    }
    XCTAssertTrue(haslaunch);
}
- (void)testSetSdkAfterLaunch{
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self setSDK];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *measurement = opdata[@"source"];
    BOOL haslaunch = NO;
    if ([measurement isEqualToString:FT_RUM_SOURCE_ACTION]) {
        haslaunch = YES;
        XCTAssertTrue([tags[FT_KEY_ACTION_TYPE]
                       isEqualToString:@"launch_cold"]);
    }
    XCTAssertTrue(haslaunch);
}
- (void)testLaunchHot{
    [self setSDK];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *measurement = opdata[@"source"];
    BOOL haslaunch = NO;
    if ([measurement isEqualToString:FT_RUM_SOURCE_ACTION]) {
        haslaunch = YES;
        XCTAssertTrue([tags[FT_KEY_ACTION_TYPE]
                       isEqualToString:@"launch_hot"]);
    }
    XCTAssertTrue(haslaunch);
}

@end
