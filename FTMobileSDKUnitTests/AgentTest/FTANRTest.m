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
#import "FTUploadTool+Test.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/FTRecordModel.h>
#import <FTMobileAgent/FTJSONUtil.h>
#import <FTMobileAgent/FTConstants.h>

@interface FTANRTest : XCTestCase
@property (nonatomic, strong) TestANRVC *testVC;

@end

@implementation FTANRTest

- (void)setUp {
    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[TestANRVC alloc] init];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    tabBarController.viewControllers = @[firstNavigationController, navigationController];
    window.rootViewController = tabBarController;
    
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    
}
- (void)initSDKWithEnableTrackAppANR:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    if (enable) {
        config.enableTrackAppANR = YES;
        config.enableTrackAppUIBlock = YES;
    }
    config.enableLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
- (void)testTraceAnrBlock{
    [self initSDKWithEnableTrackAppANR:YES];
    [NSThread sleepForTimeInterval:2];
     NSInteger oldLogging = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeLogging];

    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeMetrics];
    [self.testVC testAnrBlock];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FTMobileAgent sharedInstance] _loggingArrayInsertDBImmediately];
        NSInteger anrLogging = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeLogging];
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FTNetworkingTypeMetrics];

        XCTAssertTrue(anrLogging - oldLogging == 1);
        XCTAssertTrue(newCount-lastCount>=2);
        FTRecordModel *anrLog = [[[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeLogging] firstObject];
        NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:anrLog.data];
        NSDictionary *opdata = [dict valueForKey:@"opdata"];
        NSDictionary *field = [opdata valueForKey:@"field"];
        NSString *content = [field valueForKey:@"__content"];
        NSString *op = [dict valueForKey:@"op"];
        XCTAssertTrue([content containsString:@"ANR Stack:"]);
        XCTAssertTrue([op isEqualToString:@"exception"]);

        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstTenData:FTNetworkingTypeMetrics];
        BOOL hasBlock = NO;
        BOOL hasANR = NO;
        for (NSInteger i=0; i<datas.count; i++) {
           FTRecordModel *model = datas[i];
           NSDictionary *dict1 = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
           NSDictionary *opdata1 = [dict1 valueForKey:@"opdata"];
           NSDictionary *field1 = [opdata1 valueForKey:@"field"];
           NSString *event = [field1 valueForKey:@"event"];
           NSString *op = [dict valueForKey:@"op"];
            if ([op isEqualToString:@"block"]) {
                hasBlock = YES;
                NSNumber *fps = [field1 valueForKey:@"fps"];
                XCTAssertTrue([event isEqualToString:@"block"]);
                XCTAssertTrue(fps.floatValue<10);
            }else if([op isEqualToString:@"anr"]){
                hasANR = YES;
                XCTAssertTrue([event isEqualToString:@"anr"]);
            }
        }
        XCTAssertTrue(hasBlock == hasANR == YES);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}

- (void)testNoTraceAnrBlock{
    [self initSDKWithEnableTrackAppANR:NO];
    [NSThread sleepForTimeInterval:2];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC testAnrBlock];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(newCount == lastCount);
        [expect fulfill];
        
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
@end
