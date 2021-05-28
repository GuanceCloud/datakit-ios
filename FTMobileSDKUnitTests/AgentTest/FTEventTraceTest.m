//
//  FTEventTraceTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTRecordModel.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTBaseInfoHander.h>
#import "UITestVC.h"
#import "FTTrackerEventDBTool+Test.h"
#import <FTJSONUtil.h>
@interface FTEventTraceTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTEventTraceTest

- (void)setUp {
   
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)setConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.source = @"iOSTest";
    config.eventFlowLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[UITestVC alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
}
- (void)testTraceEventLaunch{
    [self setConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];

    [NSThread sleepForTimeInterval:2];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>0);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"message"];
    NSDictionary *contentDict =[FTJSONUtil dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"launch"]);
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [NSThread sleepForTimeInterval:2];
    NSInteger newCount2 =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount2>0);
    NSArray *array2 = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model2 = [array2 lastObject];
    NSDictionary *dict2 = [FTJSONUtil dictionaryWithJsonString:model2.data];
    NSDictionary *op2 = dict2[@"opdata"];
    NSDictionary *field2 = op2[@"field"];
    NSString *content2 = field2[@"message"];
    NSDictionary *contentDict2 =[FTJSONUtil dictionaryWithJsonString:content2];
    XCTAssertTrue([[contentDict2 valueForKey:@"event"] isEqualToString:@"launch"]);
    [[FTMobileAgent sharedInstance] resetInstance];
    
}
- (void)testTraceEventEnter{
    [self setConfig];

    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    
    [self.testVC view];
    [self.testVC viewDidAppear:NO];

    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    __block BOOL enter = NO;
    [array enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *op = dict[@"opdata"];
        NSDictionary *field = op[@"field"];
        NSString *content = field[@"message"];
        NSDictionary *contentDict =[FTJSONUtil dictionaryWithJsonString:content];
        if ([[contentDict valueForKey:@"event"] isEqualToString:@"enter"]) {
            enter = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(enter == YES);
    [[FTMobileAgent sharedInstance] resetInstance];

}

- (void)testTraceEventLeave{
    [self setConfig];

    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];

    [self.testVC viewDidDisappear:NO];
    [NSThread sleepForTimeInterval:2];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>count);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"message"];
    NSDictionary *contentDict =[FTJSONUtil dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"leave"]);
    [[FTMobileAgent sharedInstance] resetInstance];

}
- (void)testTraceEventOpen{
    [self setConfig];

    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];

    [NSThread sleepForTimeInterval:2];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>0);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    __block BOOL open = NO;
    [array enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *op = dict[@"opdata"];
        NSDictionary *field = op[@"field"];
        NSString *content = field[@"message"];
        NSDictionary *contentDict =[FTJSONUtil dictionaryWithJsonString:content];
        if ([[contentDict valueForKey:@"event"] isEqualToString:@"open"]) {
            open = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(open == YES);
    [[FTMobileAgent sharedInstance] resetInstance];

}
- (void)testTraceEventClick{
    [self setConfig];

    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];

    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [NSThread sleepForTimeInterval:2];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>count);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *field = op[@"field"];
    NSString *content = field[@"message"];
    NSDictionary *contentDict =[FTJSONUtil dictionaryWithJsonString:content];
    XCTAssertTrue([[contentDict valueForKey:@"event"] isEqualToString:@"click"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}

@end
