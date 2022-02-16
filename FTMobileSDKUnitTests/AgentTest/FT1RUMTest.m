//
//  FTRUMTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2021/12/14.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FT1RUMTest.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTBaseInfoHandler.h>
#import <FTConstants.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTDateUtil.h>
#import "NSString+FTAdd.h"
#import <FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTRUMManager.h>
#import <FTRUMSessionHandler.h>
#import <FTGlobalRumManager.h>
#import "FTTrackDataManger+Test.h"
#import "UIView+FTAutoTrack.h"
@interface FT1RUMTest()
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end
@implementation FT1RUMTest

-(void)setUp{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
}
-(void)tearDown{
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:2];
    [[FTMobileAgent sharedInstance] resetInstance];
}

- (void)testSessionIdChecks{
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];

    [tester waitForTimeInterval:2];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSDictionary *tags = opdata[FT_TAGS];
        XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
        
    }];
}
/**
 * 验证： session持续15m 无新数据写入 session更新
 */
- (void)testSessionTimeElapse{
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    
   
    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];

    [tester waitForTimeInterval:2];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session上次记录数据改为15分钟前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 60 * 15;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"lastInteractionTime"];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];

    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *old = [oldArray lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:old.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *oldSessionId =tags[FT_RUM_KEY_SESSION_ID];
    FTRecordModel *new = [newArray lastObject];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:new.data];
    NSDictionary *newOpdata = newDict[@"opdata"];
    NSDictionary *newTags = newOpdata[FT_TAGS];
    NSString *newSessionId =newTags[FT_RUM_KEY_SESSION_ID];
    XCTAssertTrue(oldSessionId);
    XCTAssertTrue(newSessionId);
    XCTAssertFalse([oldSessionId isEqualToString:newSessionId]);
}
/**
 * 验证： session 持续四小时  session更新
 */
- (void)testSessionTimeOut{
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];

    [tester waitForTimeInterval:2];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session开始时间改为四小时前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 3600 * 4;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"sessionStartTime"];
   
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];

    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *old = [oldArray lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:old.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *oldSessionId =tags[FT_RUM_KEY_SESSION_ID];
    FTRecordModel *new = [newArray lastObject];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:new.data];
    NSDictionary *newOpdata = newDict[@"opdata"];
    NSDictionary *newTags = newOpdata[FT_TAGS];
    NSString *newSessionId =newTags[FT_RUM_KEY_SESSION_ID];
    XCTAssertTrue(oldSessionId);
    XCTAssertTrue(newSessionId);
    XCTAssertFalse([oldSessionId isEqualToString:newSessionId]);
}
/**
 * 验证 source：view 的数据格式
 */
- (void)testViewDataFormatChecks{
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];

    [self addLongTaskData];
    [tester waitForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasView = NO;
    [array enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            NSDictionary *tags = opdata[FT_TAGS];
            [self rumTags:tags];
            NSDictionary *field = opdata[FT_FIELDS];
            XCTAssertTrue([field.allKeys containsObject:FT_KEY_VIEW_RESOURCE_COUNT]&&[field.allKeys containsObject:FT_KEY_VIEW_ACTION_COUNT]&&[field.allKeys containsObject:FT_KEY_VIEW_LONG_TASK_COUNT]&&[field.allKeys containsObject:FT_KEY_VIEW_ERROR_COUNT]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_IS_ACTIVE]&&[tags.allKeys containsObject:FT_KEY_VIEW_ID]&&[tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
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
    NSArray *resourceTag = @[FT_RUM_KEY_RESOURCE_URL,
                             FT_RUM_KEY_RESOURCE_URL_HOST,
                             FT_RUM_KEY_RESOURCE_URL_PATH,
                             //                             FT_RUM_KEY_RESOURCE_URL_QUERY,
                             FT_RUM_KEY_RESOURCE_URL_PATH_GROUP,
                             FT_RUM_KEY_RESOURCE_TYPE,
                             FT_RUM_KEY_RESOURCE_METHOD,
                             FT_RUM_KEY_RESOURCE_STATUS,
                             FT_RUM_KEY_RESOURCE_STATUS_GROUP,
    ];
    NSArray *resourceField = @[FT_DURATION,
                               FT_RUM_KEY_RESOURCE_SIZE,
                               FT_RUM_KEY_RESOURCE_DNS,
                               FT_RUM_KEY_RESOURCE_TCP,
                               FT_RUM_KEY_RESOURCE_SSL,
                               FT_RUM_KEY_RESOURCE_TTFB,
                               FT_RUM_KEY_RESOURCE_TRANS,
                               FT_RUM_KEY_RESOURCE_FIRST_BYTE,
    ];
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
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
                if ([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]) {
                    NSDictionary *tags = opdata[FT_TAGS];
                    NSDictionary *field = opdata[FT_FIELDS];
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
- (void)testErrorResource{
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self errorNetworkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [tester waitForTimeInterval:2];
        NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        [array enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
            NSString *op = dict[@"op"];
            XCTAssertTrue([op isEqualToString:@"RUM"]);
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[@"source"];
            if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
                NSDictionary *tags = opdata[FT_TAGS];
                [self rumTags:tags];
                NSDictionary *field = opdata[FT_FIELDS];
                NSInteger errorCount = [field[FT_KEY_VIEW_ERROR_COUNT] integerValue];
                NSInteger resourceCount = [field[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
                XCTAssertTrue(errorCount == 1);
                XCTAssertTrue(resourceCount == 1);
                *stop = YES;
            }
        }];
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
    
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];

    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            NSDictionary *tags = opdata[FT_TAGS];
            if([tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]){
            NSDictionary *field = opdata[FT_FIELDS];
            [self rumTags:tags];
            XCTAssertTrue([field.allKeys containsObject:FT_RUM_KEY_ACTION_LONG_TASK_COUNT]&&[field.allKeys containsObject:FT_RUM_KEY_ACTION_RESOURCE_COUNT]&&[field.allKeys containsObject:FT_RUM_KEY_ACTION_ERROR_COUNT]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_ACTION_ID]&&[tags.allKeys containsObject:FT_RUM_KEY_ACTION_NAME]&&[tags.allKeys containsObject:FT_RUM_KEY_ACTION_TYPE]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
//            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_REFERRER]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
            *stop = YES;
            }
        }
    }];
}
/**
 * 验证：action 最长持续10s
 */
- (void)testActionTimedOut{
    [self setRumConfig];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];

    [tester waitForTimeInterval:10];
    [self addLongTaskData];
    [tester waitForTimeInterval:2];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    __block BOOL hasLongTask = NO;

    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        NSDictionary *field = opdata[FT_FIELDS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            if([tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]){
                XCTAssertTrue([tags[FT_RUM_KEY_ACTION_NAME] isEqualToString:@"[UIButton][FirstButton]"]);
                XCTAssertTrue([field[FT_RUM_KEY_ACTION_LONG_TASK_COUNT] isEqual:@0]);
                XCTAssertTrue([field[FT_DURATION] isEqual:@10000000000]);
                hasClickAction = YES;
            }
        }else if([measurement isEqualToString:FT_MEASUREMENT_RUM_LONG_TASK]){
            XCTAssertFalse([tags.allKeys containsObject:FT_RUM_KEY_ACTION_ID]);
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
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block NSInteger count = 0;
    __block BOOL isLaunchCold = NO;
    
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            NSDictionary *tags = opdata[FT_TAGS];
            if([tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"launch_cold"]){
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
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:1];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSThread sleepForTimeInterval:1];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block NSInteger count = 0;
    __block BOOL isLaunchHot = NO;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            NSDictionary *tags = opdata[FT_TAGS];
            if([tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"launch_hot"]){
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
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];

    [tester waitForTimeInterval:2];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL firstBtnClick = NO;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            NSDictionary *tags = opdata[FT_TAGS];
            if([tags[FT_RUM_KEY_ACTION_NAME] isEqualToString:@"[UIButton][FirstButton]"]){
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
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
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
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasViewData = NO;
    __block NSInteger actionCount,trueActionCount=0;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW] && hasViewData == NO) {
            NSDictionary *field = opdata[FT_FIELDS];
            actionCount = [field[FT_KEY_VIEW_ACTION_COUNT] integerValue];
            NSInteger errorCount = [field[FT_KEY_VIEW_ERROR_COUNT] integerValue];
            NSInteger resourceCount = [field[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
            NSInteger longTaskCount = [field[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
            hasViewData = YES;
            XCTAssertTrue(errorCount == (1+resErrorCount));
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == 1);
        }else if([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]){
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
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
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
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasActionData = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            NSDictionary *field = opdata[FT_FIELDS];
            NSInteger errorCount = [field[FT_RUM_KEY_ACTION_ERROR_COUNT] integerValue];
            NSInteger resourceCount = [field[FT_RUM_KEY_ACTION_RESOURCE_COUNT] integerValue];
            NSInteger longTaskCount = [field[FT_RUM_KEY_ACTION_LONG_TASK_COUNT] integerValue];
            XCTAssertTrue(errorCount == (1+resErrorCount));
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == 1);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
}
- (void)testErrorData{
    [self setRumConfig];
    [self addErrorData];
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasErrorData = NO;

    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ERROR]) {
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
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];
    [self addErrorData];

    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);
}
- (void)testSampleRate100{
    [self setRumConfig];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];

    
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];
    [self addErrorData];

    [tester waitForTimeInterval:2];
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
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
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
    [tester waitForTimeInterval:4];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]) {
            NSDictionary *tags = opdata[FT_TAGS];
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
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
    rumConfig.enableTraceUserResource = YES;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = FTNetworkTraceTypeDDtrace;
    traceConfig.enableLinkRumData = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
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
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData;
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]) {
            NSDictionary *tags = opdata[FT_TAGS];
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_TRACEID]);
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
    rumConfig.globalContext = @{FT_RUM_KEY_SESSION_ID:@"testRUMGlobalContext",@"track_id":@"testGlobalTrack"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [self addErrorData];
    
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [newArray firstObject];
    NSDictionary *dict =  [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    XCTAssertFalse([[tags valueForKey:FT_RUM_KEY_SESSION_ID] isEqualToString:@"testRUMGlobalContext"]);
    XCTAssertTrue([[tags valueForKey:@"track_id"] isEqualToString:@"testGlobalTrack"]);
}
- (void)test1AbleTraceUserView{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:1];
    [self addErrorData];
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count - oldArray.count  == 3);
}
- (void)test0DisableTraceUserView{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:1];
    [self addErrorData];
    [tester waitForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    //一个冷启动、一个error
    XCTAssertTrue(newArray.count == oldArray.count+2);

}
- (void)test3AbleTraceUserAction{

    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"FirstButton"];
    [tester tapViewWithAccessibilityLabel:@"SecondButton"];

    [tester waitForTimeInterval:2];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count > oldArray.count);
}
- (void)test2DisableTraceUserAction{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserAction = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    [tester tapViewWithAccessibilityLabel:@"Row: 1"];
    [tester tapViewWithAccessibilityLabel:@"Row: 2"];

    [tester waitForTimeInterval:2];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    //app_cold_start 冷热启动与 enableTraceUserAction 无关
    XCTAssertTrue(newArray.count == oldArray.count+1);
}
- (void)testAbleTraceUserResource{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [tester waitForTimeInterval:2];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count > oldArray.count);
    
}
- (void)testDisableTraceUserResource{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = NO;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];

    [tester waitForTimeInterval:1];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [tester waitForTimeInterval:2];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    //app_cold_start
    XCTAssertTrue(newArray.count == oldArray.count + 1);
}
- (void)addErrorData{
    NSString *error_message = @"-[__NSSingleObjectArrayI objectForKey:]: unrecognized selector sent to instance 0x600002ac5270";
    NSString *error_stack = @"Slide_Address:74940416\nException Stack:\n0   CoreFoundation                      0x00007fff20421af6 __exceptionPreprocess + 242\n1   libobjc.A.dylib                     0x00007fff20177e78 objc_exception_throw + 48\n2   CoreFoundation                      0x00007fff204306f7 +[NSObject(NSObject) instanceMethodSignatureForSelector:] + 0\n3   CoreFoundation                      0x00007fff20426036 ___forwarding___ + 1489\n4   CoreFoundation                      0x00007fff20428068 _CF_forwarding_prep_0 + 120\n5   SampleApp                           0x000000010477fb06 __35-[Crasher throwUncaughtNSException]_block_invoke + 86\n6   libdispatch.dylib                   0x000000010561f7ec _dispatch_call_block_and_release + 12\n7   libdispatch.dylib                   0x00000001056209c8 _dispatch_client_callout + 8\n8   libdispatch.dylib                   0x0000000105622e46 _dispatch_queue_override_invoke + 1032\n9   libdispatch.dylib                   0x0000000105632508 _dispatch_root_queue_drain + 351\n10  libdispatch.dylib                   0x0000000105632e6d _dispatch_worker_thread2 + 135\n11  libsystem_pthread.dylib             0x00007fff611639f7 _pthread_wqthread + 220\n12  libsystem_pthread.dylib             0x00007fff61162b77 start_wqthread + 15";
    NSString *error_type = @"ios_crash";
   
   [[FTGlobalRumManager sharedInstance].rumManger addErrorWithType:error_type situation:    AppStateRun message:error_message stack:error_stack];
}
- (void)addLongTaskData{
    NSString *stack = @"Backtrace of Thread 771:\n0 libsystem_kernel.dylib          0x7fff6112d756 __semwait_signal + 10\n1 libsystem_c.dylib               0x7fff200f7500 usleep + 53\n2 SampleApp                       0x1038b9a96 -[TestANRVC tableView:cellForRowAtIndexPath:] + 230\n3 UIKitCore                       0x7fff248ce1af -[UITableView _createPreparedCellForGlobalRow:withIndexPath:willDisplay:] + 865\n4 UIKitCore                       0x7fff248ce637 -[UITableView _createPreparedCellForRowAtIndexPath:willDisplay:] + 80\n5 UIKitCore                       0x7fff248dab61 -[UITableView _heightForRowAtIndexPath:] + 204\n6 UIKitCore                       0x7fff248eea95 -[UISectionRowData heightForRow:inSection:canGuess:] + 220\n7 UIKitCore                       0x7fff248f40ca -[UITableViewRowData heightForRow:inSection:canGuess:adjustForReorderedRow:] + 238\n8 UIKitCore                       0x7fff248f7c1a -[UITableViewRowData ensureHeightsFaultedInForScrollToIndexPath:boundsHeight:] + 864\n9 UIKitCore                       0x7fff248ad10f -[UITableView _contentOffsetForScrollingToRowAtIndexPath:atScrollPosition:usingPresentationValues:] + 1138\n10 UIKitCore                       0x7fff248ae07c -[UITableView _scrollToRowAtIndexPath:atScrollPosition:animated:usingPresentationValues:] + 142\n11 UIKitCore                       0x7fff248b18dc -[UITableView _selectRowAtIndexPath:animated:scrollPosition:notifyDelegate:isCellMultiSelect:] + 719\n12 UIKitCore                       0x7fff248b2004 -[UITableView selectRowAtIndexPath:animated:scrollPosition:] + 91\n";
    NSNumber *dutation = @5000000000;
    
    
    [[FTGlobalRumManager sharedInstance].rumManger addLongTaskWithStack:stack duration:dutation];
}

- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *urlStr = @"https://www.baidu.com/more/";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,error):nil;
    }];
    
    [task resume];
}
- (void)errorNetworkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *urlStr = @"https://console-api.guance.com/not/found/";
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
                        FT_RUM_KEY_SESSION_ID,
                        FT_RUM_KEY_SESSION_TYPE,
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
    NSDictionary *field = @{FT_RUM_KEY_ACTION_ERROR_COUNT:@0,
                            FT_RUM_KEY_ACTION_LONG_TASK_COUNT:@0,
                            FT_RUM_KEY_ACTION_RESOURCE_COUNT:@0,
                            FT_DURATION:@103492975,
    };
    NSDictionary *tags = @{FT_RUM_KEY_ACTION_ID:[NSUUID UUID].UUIDString,
                           FT_RUM_KEY_ACTION_NAME:@"app_cold_start",
                           FT_RUM_KEY_ACTION_TYPE:@"launch_cold",
                           FT_RUM_KEY_SESSION_ID:[NSUUID UUID].UUIDString,
                           FT_RUM_KEY_SESSION_TYPE:@"user",
    };
    [[FTMobileAgent sharedInstance] rumWrite:FT_MEASUREMENT_RUM_ACTION terminal:FT_TERMINAL_APP tags:tags fields:field];
}

- (void)setRumConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];

    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
}
@end
