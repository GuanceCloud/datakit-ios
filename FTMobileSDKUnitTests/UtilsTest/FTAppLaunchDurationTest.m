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
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
@interface FTAppLaunchDurationTest : KIFTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
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
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testLaunchCold{
    [self setSDK];
    self.expectation= [self expectationWithDescription:@"异步操作timeout"];
    [[NSNotificationCenter defaultCenter] addObserver:self
selector:@selector(applicationDidBecomeActive:)
    name:UIApplicationDidBecomeActiveNotification
object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        XCTAssertNil(error);
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)applicationDidBecomeActive:(NSNotification *)noti{
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
    if(self.expectation){
        [self.expectation fulfill];
    }
}
- (void)testSetSdkAfterLaunch{
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self setSDK];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];

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