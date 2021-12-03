//
//  FTRUMTests.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/12/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTBaseInfoHandler.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "UITestVC.h"
#import <FTDateUtil.h>
#import "NSString+FTAdd.h"
#import <FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTRUMManager.h>
#import <FTRUMSessionHandler.h>
#import <FTMonitorManager.h>
#import "FTTrackDataManger+Test.h"
#import "UIView+FTAutoTrack.h"
@interface FTRUMTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTRUMTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
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
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 *
 */
- (void)testSessionIdChecks{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    //页面关闭 action 无正在加载的resource action写入
    [self.testVC viewDidDisappear:NO];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSDictionary *tags = opdata[@"tags"];
        XCTAssertTrue([tags.allKeys containsObject:@"session_id"]);
        
    }];
}
/**
 * 验证： session持续15m 无新数据写入 session更新
 */
- (void)testSessionTimeElapse{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self mockBtnClick];
    [self mockBtnClick];
    [NSThread sleepForTimeInterval:2];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRUMManager *rum = [FTMonitorManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session上次记录数据改为15分钟前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 60 * 15;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"lastInteractionTime"];
   
    [self mockBtnClick];
    [self.testVC viewDidDisappear:NO];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *old = [oldArray lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:old.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[@"tags"];
    NSString *oldSessionId =tags[@"session_id"];
    FTRecordModel *new = [newArray lastObject];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:new.data];
    NSDictionary *newOpdata = newDict[@"opdata"];
    NSDictionary *newTags = newOpdata[@"tags"];
    NSString *newSessionId =newTags[@"session_id"];
    XCTAssertTrue(oldSessionId);
    XCTAssertTrue(newSessionId);
    XCTAssertFalse([oldSessionId isEqualToString:newSessionId]);
}
/**
 * 验证： session 持续四小时  session更新
 */
- (void)testSessionTimeOut{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self mockBtnClick];
    [self mockBtnClick];
    [NSThread sleepForTimeInterval:2];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRUMManager *rum = [FTMonitorManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session开始时间改为四小时前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 3600 * 4;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"sessionStartTime"];
   
    [self mockBtnClick];
    [self.testVC viewDidDisappear:NO];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *old = [oldArray lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:old.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[@"tags"];
    NSString *oldSessionId =tags[@"session_id"];
    FTRecordModel *new = [newArray lastObject];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:new.data];
    NSDictionary *newOpdata = newDict[@"opdata"];
    NSDictionary *newTags = newOpdata[@"tags"];
    NSString *newSessionId =newTags[@"session_id"];
    XCTAssertTrue(oldSessionId);
    XCTAssertTrue(newSessionId);
    XCTAssertFalse([oldSessionId isEqualToString:newSessionId]);
}
/**
 * 验证 source：view 的数据格式
 */
- (void)testViewDataFormatChecks{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self addLongTaskData];
    [NSThread sleepForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasView = NO;
    [array enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"view"]) {
            NSDictionary *tags = opdata[@"tags"];
            [self rumTags:tags];
            NSDictionary *field = opdata[@"field"];
            XCTAssertTrue([field.allKeys containsObject:@"view_resource_count"]&&[field.allKeys containsObject:@"view_action_count"]&&[field.allKeys containsObject:@"view_long_task_count"]&&[field.allKeys containsObject:@"view_error_count"]);
            XCTAssertTrue([tags.allKeys containsObject:@"is_active"]&&[tags.allKeys containsObject:@"view_id"]&&[tags.allKeys containsObject:@"view_referrer"]&&[tags.allKeys containsObject:@"view_name"]);
            hasView = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasView);
}
/**
 * 验证 source：resource 的数据格式
 */
- (void)testResourceDataFormatChecks{
    NSArray *resourceTag = @[@"resource_url",
                             @"resource_url_host",
                             @"resource_url_path",
                             //                             @"resource_url_query",
                             @"resource_url_path_group",
                             @"resource_type",
                             @"resource_method",
                             @"resource_status",
                             @"resource_status_group",
    ];
    NSArray *resourceField = @[@"duration",
                               @"resource_size",
                               @"resource_dns",
                               @"resource_tcp",
                               @"resource_ssl",
                               @"resource_ttfb",
                               @"resource_trans",
                               @"resource_first_byte",
    ];
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (!error) {
            [NSThread sleepForTimeInterval:2];
            NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
            __block BOOL hasView = NO;
            [array enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
                NSString *op = dict[@"op"];
                XCTAssertTrue([op isEqualToString:@"RUM"]);
                NSDictionary *opdata = dict[@"opdata"];
                NSString *measurement = opdata[@"source"];
                if ([measurement isEqualToString:@"resource"]) {
                    NSDictionary *tags = opdata[@"tags"];
                    NSDictionary *field = opdata[@"field"];
                    [self rumTags:tags];
                    [resourceTag enumerateObjectsUsingBlock:^(NSString   *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        XCTAssertTrue([tags.allKeys containsObject:obj]);
                    }];
                    [resourceField enumerateObjectsUsingBlock:^(NSString   *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        XCTAssertTrue([field.allKeys containsObject:obj]);
                    }];
                    hasView = YES;
                    *stop = YES;
                }
            }];
            XCTAssertTrue(hasView);
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 * 验证 source：action 的数据格式
 */
- (void)testActionDataFormatChecks{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self mockBtnClick];
    [self mockBtnClick];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *tags = opdata[@"tags"];
            NSDictionary *field = opdata[@"field"];
            [self rumTags:tags];
            XCTAssertTrue([field.allKeys containsObject:@"action_long_task_count"]&&[field.allKeys containsObject:@"action_resource_count"]&&[field.allKeys containsObject:@"action_error_count"]);
            XCTAssertTrue([tags.allKeys containsObject:@"action_id"]&&[tags.allKeys containsObject:@"action_name"]&&[tags.allKeys containsObject:@"action_type"]);
            XCTAssertTrue([tags.allKeys containsObject:@"view_id"]);
            XCTAssertTrue([tags.allKeys containsObject:@"view_referrer"]);
            XCTAssertTrue([tags.allKeys containsObject:@"view_name"]);
            XCTAssertTrue([tags.allKeys containsObject:@"session_id"]);
        }
    }];
}
/**
 * 验证：action 最长持续10s
 */
- (void)testActionTimedOut{
    [self setRumConfig];
    [self.testVC viewDidDisappear:NO];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self mockBtnClick];
    [NSThread sleepForTimeInterval:10];
    [self addLongTaskData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    __block BOOL hasLongTask = NO;

    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[@"tags"];
        NSDictionary *field = opdata[@"field"];
        if ([measurement isEqualToString:@"action"]) {
            
            if([tags[@"action_type"] isEqualToString:@"click"]){
                XCTAssertTrue([tags[@"action_name"] isEqualToString:@"[UIButton][FirstButton]"]);
                XCTAssertTrue([field[@"action_long_task_count"] isEqual:@0]);
                XCTAssertTrue([field[@"duration"] isEqual:@10000000000]);
                hasClickAction = YES;
            }
        }else if([measurement isEqualToString:@"long_task"]){
            XCTAssertFalse([tags.allKeys containsObject:@"action_id"]);
            hasLongTask  = YES;
        }
    }];
    XCTAssertTrue(hasClickAction);
    XCTAssertTrue(hasLongTask);
}
/**
 * 验证： action: launch_cold
 * 应用启动 --> 第一个页面viewDidAppear
 */
- (void)testRumAppLaunchCold{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self.testVC viewDidDisappear:NO];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block NSInteger count = 0;
    __block BOOL isLaunchCold = NO;
    
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *tags = opdata[@"tags"];
            if([tags[@"action_type"] isEqualToString:@"launch_cold"]){
                isLaunchCold = YES;
            }
            count ++;
        }
    }];
    XCTAssertTrue(count == 1);
    XCTAssertTrue(isLaunchCold);
    
}
/**
 * 验证： action: launch_hot
 */
- (void)testRumAppLaunchHot{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSThread sleepForTimeInterval:1];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    //页面关闭 action 无正在加载的resource action写入
    [self.testVC viewDidDisappear:NO];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block NSInteger count = 0;
    __block BOOL isLaunchHot = NO;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *tags = opdata[@"tags"];
            if([tags[@"action_type"] isEqualToString:@"launch_hot"]){
                isLaunchHot = YES;
            }
            count ++;
        }
    }];
    XCTAssertTrue(count == 2);
    XCTAssertTrue(isLaunchHot);
}
/**
 * 验证： action: click
 */
- (void)testRumClickBtn{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self mockBtnClick];
    [self mockBtnClick];
    [NSThread sleepForTimeInterval:2];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL firstBtnClick = NO;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *tags = opdata[@"tags"];
            if([tags[@"action_name"] isEqualToString:@"[UIButton][FirstButton]"]){
                firstBtnClick = YES;
            }
        }
    }];
    XCTAssertTrue(firstBtnClick);
}
/**
 * 验证 resource，action,error,long_task数据 是否同步到view中
 */
- (void)testViewUpdate{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self mockBtnClick];
    [self addLongTaskData];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    __block NSInteger resErrorCount = 0;
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (error) {
            resErrorCount = 1;
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [self addErrorData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasViewData = NO;
    __block NSInteger actionCount,trueActionCount=0;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"view"] && hasViewData == NO) {
            NSDictionary *field = opdata[@"field"];
            actionCount = [field[@"view_action_count"] integerValue];
            NSInteger errorCount = [field[@"view_error_count"] integerValue];
            NSInteger resourceCount = [field[@"view_resource_count"] integerValue];
            NSInteger longTaskCount = [field[@"view_long_task_count"] integerValue];
            hasViewData = YES;
            XCTAssertTrue(errorCount == (1+resErrorCount));
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == (1-resErrorCount));
        }else if([measurement isEqualToString:@"action"]){
            trueActionCount ++;
        }
    }];
    XCTAssertTrue(hasViewData);
    XCTAssertTrue(actionCount == trueActionCount);

}
/**
 * 验证 resource,error,long_task数据 是否同步到action中
 */
- (void)testActionUpdate{
    [self setRumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    __block NSInteger resErrorCount = 0;
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error || httpResponse.statusCode>=400) {
            resErrorCount = 1;
        }
        [expectation fulfill];
    }];
    [self addLongTaskData];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [self addErrorData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasActionData = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *field = opdata[@"field"];
            NSInteger errorCount = [field[@"action_error_count"] integerValue];
            NSInteger resourceCount = [field[@"action_resource_count"] integerValue];
            NSInteger longTaskCount = [field[@"action_long_task_count"] integerValue];
            XCTAssertTrue(errorCount == (1+resErrorCount));
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == (1-resErrorCount));
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);

}
- (void)testErrorData{
    [self setRumConfig];
    [self addErrorData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasErrorData = NO;

    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"error"]) {
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testSampleRate0{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.samplerate = 0;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];

    [self.testVC viewDidAppear:NO];
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self addErrorData];
    
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);
}
- (void)testSampleRate100{
    [self setRumConfig];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];

    [self.testVC viewDidAppear:NO];
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self addErrorData];
    
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count > oldArray.count);
}
/**
 * 验证  FTTraceConfig enableLinkRumData
 * 需要设置 networkTraceType = FTNetworkTraceTypeDDtrace
 */
- (void)testTraceLinkRumData{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [self.testVC viewDidAppear:NO];

    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
   __block BOOL isError = NO;
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (error) {
            isError = YES;
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"resource"]) {
            NSDictionary *tags = opdata[@"tags"];
            XCTAssertTrue([tags.allKeys containsObject:@"span_id"]);
            XCTAssertTrue([tags.allKeys containsObject:@"trace_id"]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    if (!isError) {
        XCTAssertTrue(hasResourceData == YES);
    }

}
- (void)testNotTraceLinkRumData{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [self.testVC viewDidAppear:NO];

    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
   __block BOOL isError = NO;
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (error) {
            isError = YES;
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:@"resource"]) {
            NSDictionary *tags = opdata[@"tags"];
            XCTAssertFalse([tags.allKeys containsObject:@"span_id"]);
            XCTAssertFalse([tags.allKeys containsObject:@"trace_id"]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    if (!isError) {
        XCTAssertTrue(hasResourceData == YES);
    }

}
- (void)testRUMGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"session_id":@"testRUMGlobalContext",@"track_id":@"testGlobalTrack"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
    [self.testVC viewDidAppear:NO];
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self addErrorData];
    
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [newArray firstObject];
    NSDictionary *dict =  [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[@"tags"];
    XCTAssertFalse([[tags valueForKey:@"session_id"] isEqualToString:@"testRUMGlobalContext"]);
    XCTAssertTrue([[tags valueForKey:@"track_id"] isEqualToString:@"testGlobalTrack"]);

}
- (void)addErrorData{
    NSString *error_message = @"-[__NSSingleObjectArrayI objectForKey:]: unrecognized selector sent to instance 0x600002ac5270";
    NSString *error_stack = @"Slide_Address:74940416\nException Stack:\n0   CoreFoundation                      0x00007fff20421af6 __exceptionPreprocess + 242\n1   libobjc.A.dylib                     0x00007fff20177e78 objc_exception_throw + 48\n2   CoreFoundation                      0x00007fff204306f7 +[NSObject(NSObject) instanceMethodSignatureForSelector:] + 0\n3   CoreFoundation                      0x00007fff20426036 ___forwarding___ + 1489\n4   CoreFoundation                      0x00007fff20428068 _CF_forwarding_prep_0 + 120\n5   SampleApp                           0x000000010477fb06 __35-[Crasher throwUncaughtNSException]_block_invoke + 86\n6   libdispatch.dylib                   0x000000010561f7ec _dispatch_call_block_and_release + 12\n7   libdispatch.dylib                   0x00000001056209c8 _dispatch_client_callout + 8\n8   libdispatch.dylib                   0x0000000105622e46 _dispatch_queue_override_invoke + 1032\n9   libdispatch.dylib                   0x0000000105632508 _dispatch_root_queue_drain + 351\n10  libdispatch.dylib                   0x0000000105632e6d _dispatch_worker_thread2 + 135\n11  libsystem_pthread.dylib             0x00007fff611639f7 _pthread_wqthread + 220\n12  libsystem_pthread.dylib             0x00007fff61162b77 start_wqthread + 15";
    NSString *error_type = @"ios_crash";
   
   [[FTMonitorManager sharedInstance].rumManger addErrorWithType:error_type situation:RUN message:error_message stack:error_stack];
}
- (void)addLongTaskData{
    NSString *stack = @"Backtrace of Thread 771:\n0 libsystem_kernel.dylib          0x7fff6112d756 __semwait_signal + 10\n1 libsystem_c.dylib               0x7fff200f7500 usleep + 53\n2 SampleApp                       0x1038b9a96 -[TestANRVC tableView:cellForRowAtIndexPath:] + 230\n3 UIKitCore                       0x7fff248ce1af -[UITableView _createPreparedCellForGlobalRow:withIndexPath:willDisplay:] + 865\n4 UIKitCore                       0x7fff248ce637 -[UITableView _createPreparedCellForRowAtIndexPath:willDisplay:] + 80\n5 UIKitCore                       0x7fff248dab61 -[UITableView _heightForRowAtIndexPath:] + 204\n6 UIKitCore                       0x7fff248eea95 -[UISectionRowData heightForRow:inSection:canGuess:] + 220\n7 UIKitCore                       0x7fff248f40ca -[UITableViewRowData heightForRow:inSection:canGuess:adjustForReorderedRow:] + 238\n8 UIKitCore                       0x7fff248f7c1a -[UITableViewRowData ensureHeightsFaultedInForScrollToIndexPath:boundsHeight:] + 864\n9 UIKitCore                       0x7fff248ad10f -[UITableView _contentOffsetForScrollingToRowAtIndexPath:atScrollPosition:usingPresentationValues:] + 1138\n10 UIKitCore                       0x7fff248ae07c -[UITableView _scrollToRowAtIndexPath:atScrollPosition:animated:usingPresentationValues:] + 142\n11 UIKitCore                       0x7fff248b18dc -[UITableView _selectRowAtIndexPath:animated:scrollPosition:notifyDelegate:isCellMultiSelect:] + 719\n12 UIKitCore                       0x7fff248b2004 -[UITableView selectRowAtIndexPath:animated:scrollPosition:] + 91\n";
    NSNumber *dutation = @5000000000;
    
    
    [[FTMonitorManager sharedInstance].rumManger addLongTaskWithStack:stack duration:dutation];
}
- (void)mockBtnClick{
//    [self.testVC.firstButton ]
    [[FTMonitorManager sharedInstance].rumManger addClickActionWithName:self.testVC.firstButton.ft_actionName];
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *urlStr = @"http://www.baidu.com";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,error):nil;
    }];
    
    [task resume];
}
- (void)rumTags:(NSDictionary *)tags{
    NSArray *tagAry = @[@"sdk_name",
                        @"sdk_version",
                        @"app_id",
                        @"env",
                        @"version",
                        @"userid",
                        @"session_id",
                        @"session_type",
                        @"is_signin",
                        @"device",
                        @"model",
                        @"device_uuid",
                        @"os",
                        @"os_version",
                        @"os_version_major",
                        @"screen_size",
    ];
    [tagAry enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        XCTAssertTrue([tags.allKeys containsObject:obj]);
    }];
}
- (void)addESData{
    NSDictionary *field = @{@"action_error_count":@0,
                            @"action_long_task_count":@0,
                            @"action_resource_count":@0,
                            @"duration":@103492975,
    };
    NSDictionary *tags = @{@"action_id":[NSUUID UUID].UUIDString,
                           @"action_name":@"app_cold_start",
                           @"action_type":@"launch_cold",
                           @"session_id":[NSUUID UUID].UUIDString,
                           @"session_type":@"user",
    };
    [[FTMobileAgent sharedInstance] rumWrite:@"action" terminal:@"app" tags:tags fields:field];
}

- (void)setRumConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
}
@end
