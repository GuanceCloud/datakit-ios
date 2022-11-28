//
//  FTRUMTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2021/12/14.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent.h"
#import "FTBaseInfoHandler.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "FTDateUtil.h"
#import "NSString+FTAdd.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTRUMManager.h"
#import "FTRUMSessionHandler.h"
#import "FTGlobalRumManager.h"
#import "FTTrackDataManger+Test.h"
#import "UIView+FTAutoTrack.h"
#import "FTExternalDataManager.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTURLSessionInterceptor.h"
#import "FTModelHelper.h"
#import "FTURLSessionAutoInstrumentation.h"
#import "FTRUMViewHandler.h"
#import "FTRUMActionHandler.h"
@interface FTRUMTest : XCTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, copy) NSString *track_id;
@end
@implementation FTRUMTest

-(void)setUp{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    self.track_id = [processInfo environment][@"TRACK_ID"];
}
-(void)tearDown{
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [[FTMobileAgent sharedInstance] resetInstance];
}

- (void)testSessionIdChecks{
    [self setRumConfig];
    
    [self addErrorData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
}
/**
 * 验证： session持续15m 无新数据写入 session更新
 */
- (void)testSessionTimeElapse{
    [self setRumConfig];
    [self addErrorData];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    
    FTRecordModel *oldModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session上次记录数据改为15分钟前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 60 * 15;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"lastInteractionTime"];
    
    [self addLongTaskData];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    FTRecordModel *newModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:oldModel.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *oldSessionId =tags[FT_RUM_KEY_SESSION_ID];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:newModel.data];
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
    [self addErrorData];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    FTRecordModel *oldModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] firstObject];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session开始时间改为四小时前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 3600 * 4;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"sessionStartTime"];
    
    [self addLongTaskData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    FTRecordModel *newModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:oldModel.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *oldSessionId =tags[FT_RUM_KEY_SESSION_ID];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:newModel.data];
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
- (void)testAddViewDataAndFormatChecks{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addLongTaskData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
- (void)testWorngFormatViewName{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@""];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [FTModelHelper stopView];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    XCTAssertTrue(newCount == 0);
}
/**
 * 验证 resource，action,error,long_task数据 是否同步到view中
 */
- (void)testViewUpdate{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startView];
    [self addLongTaskData];
    [self addResource];
    [self addErrorData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;
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
            XCTAssertTrue(errorCount == 1);
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == 1);
        }else if([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]&&[tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"click"]){
            trueActionCount ++;
        }
    }];
    XCTAssertTrue(hasViewData);
    XCTAssertTrue(actionCount == trueActionCount);
    [FTModelHelper stopView];
}
/**
 * 验证 source：resource 的数据格式
 */
- (void)testAddResourceDataAndFormatChecks{
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
    [FTModelHelper startView];
    
    [self addResource];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
    [FTModelHelper stopView];
}
- (void)testAddErrorResource{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [self addErrorResource];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
}
/**
 * 验证 source：action 的数据格式
 */
- (void)testAddActionAndActionDataFormatChecks{
    [self setRumConfig];
    
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [FTModelHelper addActionWithType:@"longtap"];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
            if([tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:@"longtap"]){
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
- (void)testWorngFormatActionName{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"view1"];
    
    [[FTExternalDataManager sharedManager] addClickActionWithName:@""];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [[FTExternalDataManager sharedManager] stopView];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertFalse(hasDatas);
}
/**
 * 验证：action 最长持续10s
 */
- (void)testActionTimedOut{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManger;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[session valueForKey:@"viewHandlers"] lastObject];
    FTRUMActionHandler *action = [view valueForKey:@"actionHandler"];
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-11];
    [action setValue:newDate forKey:@"actionStartTime"];

    //把session上次记录数据改为15分钟前 模拟session过期
    
    [self addLongTaskData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
            if([tags[FT_RUM_KEY_ACTION_TYPE] isEqualToString:FT_RUM_KEY_ACTION_TYPE_CLICK]){
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
    [FTModelHelper stopView];
}
/**
 * 验证 resource,error,long_task数据 是否同步到action中
 */
- (void)testActionUpdate{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [self addResource];
    [self addLongTaskData];
    
    [self addErrorData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
            XCTAssertTrue(errorCount == 1);
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == 1);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
    [FTModelHelper stopView];
}
- (void)testAddErrorData{
    [self setRumConfig];
    [self addErrorData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
- (void)testActionWorngFormat{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper addActionWithType:@""];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    [self addErrorData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];

        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
            hasClickAction = YES;
        }
    }];
    XCTAssertFalse(hasClickAction);
    [FTModelHelper stopView];
}

- (void)testWorngFormatErrorData{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"" message:@"testWorngError" stack:@"error testWorngError"];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"" stack:@"error testWorngError"];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"testWorngError" stack:@""];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ERROR]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertFalse(hasDatas);
}
- (void)testAddLongTaskData{
    [self setRumConfig];
    [self addLongTaskData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_LONG_TASK]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatas);
}
- (void)testWorngFormatLongTaskData{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] onCreateView:@"LongTask" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"LongTask"];
    
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"" duration:@1200000000];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_LONG_TASK]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertFalse(hasDatas);
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
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [self addErrorData];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);
    [FTModelHelper stopView];
}
- (void)testSampleRate100{
    [self setRumConfig];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    
    [FTModelHelper startView];
    [FTModelHelper addAction];
    [self addErrorData];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
    [FTModelHelper startView];
    [self addErrorData];
    [self addResource];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
    XCTAssertTrue(hasResourceData == YES);
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
    [FTModelHelper startView];
    [self addErrorData];
    [self addResource];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
    XCTAssertTrue(hasResourceData == YES);
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
    
    [FTModelHelper startView];
    [self addErrorData];
    
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
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
- (void)addErrorData{
    NSString *error_message = @"-[__NSSingleObjectArrayI objectForKey:]: unrecognized selector sent to instance 0x600002ac5270";
    NSString *error_stack = @"Slide_Address:74940416\nException Stack:\n0   CoreFoundation                      0x00007fff20421af6 __exceptionPreprocess + 242\n1   libobjc.A.dylib                     0x00007fff20177e78 objc_exception_throw + 48\n2   CoreFoundation                      0x00007fff204306f7 +[NSObject(NSObject) instanceMethodSignatureForSelector:] + 0\n3   CoreFoundation                      0x00007fff20426036 ___forwarding___ + 1489\n4   CoreFoundation                      0x00007fff20428068 _CF_forwarding_prep_0 + 120\n5   SampleApp                           0x000000010477fb06 __35-[Crasher throwUncaughtNSException]_block_invoke + 86\n6   libdispatch.dylib                   0x000000010561f7ec _dispatch_call_block_and_release + 12\n7   libdispatch.dylib                   0x00000001056209c8 _dispatch_client_callout + 8\n8   libdispatch.dylib                   0x0000000105622e46 _dispatch_queue_override_invoke + 1032\n9   libdispatch.dylib                   0x0000000105632508 _dispatch_root_queue_drain + 351\n10  libdispatch.dylib                   0x0000000105632e6d _dispatch_worker_thread2 + 135\n11  libsystem_pthread.dylib             0x00007fff611639f7 _pthread_wqthread + 220\n12  libsystem_pthread.dylib             0x00007fff61162b77 start_wqthread + 15";
    NSString *error_type = @"ios_crash";
    
    [[FTExternalDataManager sharedManager] addErrorWithType:error_type  message:error_message stack:error_stack];
}
- (void)addLongTaskData{
    NSString *stack = @"Backtrace of Thread 771:\n0 libsystem_kernel.dylib          0x7fff6112d756 __semwait_signal + 10\n1 libsystem_c.dylib               0x7fff200f7500 usleep + 53\n2 SampleApp                       0x1038b9a96 -[TestANRVC tableView:cellForRowAtIndexPath:] + 230\n3 UIKitCore                       0x7fff248ce1af -[UITableView _createPreparedCellForGlobalRow:withIndexPath:willDisplay:] + 865\n4 UIKitCore                       0x7fff248ce637 -[UITableView _createPreparedCellForRowAtIndexPath:willDisplay:] + 80\n5 UIKitCore                       0x7fff248dab61 -[UITableView _heightForRowAtIndexPath:] + 204\n6 UIKitCore                       0x7fff248eea95 -[UISectionRowData heightForRow:inSection:canGuess:] + 220\n7 UIKitCore                       0x7fff248f40ca -[UITableViewRowData heightForRow:inSection:canGuess:adjustForReorderedRow:] + 238\n8 UIKitCore                       0x7fff248f7c1a -[UITableViewRowData ensureHeightsFaultedInForScrollToIndexPath:boundsHeight:] + 864\n9 UIKitCore                       0x7fff248ad10f -[UITableView _contentOffsetForScrollingToRowAtIndexPath:atScrollPosition:usingPresentationValues:] + 1138\n10 UIKitCore                       0x7fff248ae07c -[UITableView _scrollToRowAtIndexPath:atScrollPosition:animated:usingPresentationValues:] + 142\n11 UIKitCore                       0x7fff248b18dc -[UITableView _selectRowAtIndexPath:animated:scrollPosition:notifyDelegate:isCellMultiSelect:] + 719\n12 UIKitCore                       0x7fff248b2004 -[UITableView selectRowAtIndexPath:animated:scrollPosition:] + 91\n";
    NSNumber *dutation = @5000000000;
    
    
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:stack duration:dutation];
}
- (void)addResource{
    NSString *key = [[NSUUID UUID]UUIDString];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = url;
    model.duration = @1000;
    model.httpStatusCode = 200;
    model.httpMethod = @"GET";
    model.requestHeader = traceHeader;
    model.responseHeader = @{ @"Accept-Ranges": @"bytes",
                              @"Cache-Control": @"max-age=86400", @"Content-Encoding": @"gzip",
                              @"Content-Length": @"11328",
                              @"Content-Type": @"text/html",
                              @"Server": @"Apache",
                              @"Vary": @"Accept-Encoding,User-Agent"
                              
    };
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    FTResourceMetricsModel *metrics = [FTResourceMetricsModel new];
    metrics.duration = @1000;
    metrics.resource_dns = @0;
    metrics.resource_ssl = @12;
    metrics.resource_tcp = @100;
    metrics.resource_ttfb = @101;
    metrics.resource_trans = @102;
    metrics.resource_first_byte = @103;
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:metrics content:model];

}
- (void)addErrorResource{

    NSString *key = [[NSUUID UUID]UUIDString];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    model.duration = @1000;
    model.httpStatusCode = 404;
    model.httpMethod = @"GET";
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:nil content:model];
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

- (void)setRumConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.errorMonitorType = FTErrorMonitorAll;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
}
- (void)testGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    NSString *trackId = self.track_id?:@"unitTests";
    rumConfig.globalContext = @{@"track_id":trackId};
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    
    [self addErrorData];
    [[FTGlobalRumManager sharedInstance].rumManger syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"track_id"] isEqualToString:trackId]);
    XCTAssertTrue([tags[@"custom_keys"] isEqualToString:@"[\"track_id\"]"]);
}

@end
