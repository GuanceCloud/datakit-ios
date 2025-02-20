//
//  FTRUMTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2021/12/14.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Utils.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent.h"
#import "FTBaseInfoHandler.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "NSDate+FTUtil.h"
#import "NSString+FTAdd.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTRUMManager.h"
#import "FTRUMSessionHandler.h"
#import "FTGlobalRumManager.h"
#import "UIView+FTAutoTrack.h"
#import "FTExternalDataManager.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTURLSessionInterceptor.h"
#import "FTModelHelper.h"
#import "FTURLSessionInstrumentation.h"
#import "FTRUMViewHandler.h"
#import "FTRUMActionHandler.h"
#import "FTRequestBody.h"
#import "FTRUMDataModel.h"
#import "FTTrackDataManager.h"
#import "FTMobileConfig+Private.h"
#import "FTAutoTrackHandler.h"
#import "DemoViewController.h"
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
-(void)tearDown{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [FTMobileAgent shutDown];
}
#pragma mark ========== RUM CONFIG ==========
- (void)testRUMFreezeThreshold{
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"appid"];
    XCTAssertTrue(rumConfig.freezeDurationMs == 250);
    rumConfig.freezeDurationMs = 0;
    XCTAssertTrue(rumConfig.freezeDurationMs == 100);
    rumConfig.freezeDurationMs = 5000;
    XCTAssertTrue(rumConfig.freezeDurationMs == 5000);
}
- (void)testDiscardNew{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.rumCacheLimitCount = 1000;
    rumConfig.rumDiscardType = FTRUMDiscard;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    for (int i = 0; i<10010; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_RUM;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertTrue([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 10000);
}

- (void)testDiscardOldBulk{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.rumCacheLimitCount = 1000;
    rumConfig.rumDiscardType = FTRUMDiscardOldest;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    for (int i = 0; i<10010; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_RUM;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];

    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 10000);
}
- (void)testAddPkgInfo{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [config addPkgInfo:@"test_sdk" value:@"1.0.0"];
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [FTModelHelper addActionWithContext:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count >= 1);
    __block BOOL hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        XCTAssertTrue([tags[FT_SDK_PKG_INFO] isEqualToDictionary:@{@"test_sdk":@"1.0.0"}]);
        hasActionData = YES;
        *stop = YES;
    }];
    XCTAssertTrue(hasActionData);
}
#pragma mark ========== Session ==========

- (void)testSessionIdChecks{
    [self setRumConfig];
    [self addErrorData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[FT_OPDATA];
    NSDictionary *tags = opdata[FT_TAGS];
    XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
}
/**
 * 验证： session持续 15m 无新数据写入 session更新
 */
- (void)testSessionTimeElapse{
    [self setRumConfig];
    [self addErrorData:nil];
    [FTModelHelper startViewWithName:@"FirstView"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    FTRecordModel *oldModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    NSMutableArray<FTRUMHandler*> *viewHandlers = [session valueForKey:@"viewHandlers"];
    //把session上次记录数据改为15分钟前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 60 * 15;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"lastInteractionTime"];
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMSessionHandler *newSession = [rum valueForKey:@"sessionHandler"];
    NSMutableArray *newViewHandlers = [newSession valueForKey:@"viewHandlers"];
    XCTAssertTrue(viewHandlers.count == newViewHandlers.count == 1);
    FTRUMViewHandler *viewHandler = (FTRUMViewHandler *)[viewHandlers lastObject];
    FTRUMViewHandler *newViewHandler = (FTRUMViewHandler *)[newViewHandlers lastObject];
    XCTAssertTrue([viewHandler.view_name isEqualToString:newViewHandler.view_name]);
    XCTAssertFalse([viewHandler.view_id isEqualToString:newViewHandler.view_id]);
    FTRecordModel *newModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:oldModel.data];
    NSDictionary *opdata = dict[FT_OPDATA];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *oldSessionId =tags[FT_RUM_KEY_SESSION_ID];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:newModel.data];
    NSDictionary *newOpdata = newDict[FT_OPDATA];
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
    [self addErrorData:nil];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRecordModel *oldModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] firstObject];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    //把session开始时间改为四小时前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 3600 * 4;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"sessionStartTime"];
    
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRecordModel *newModel = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM] lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:oldModel.data];
    NSDictionary *opdata = dict[FT_OPDATA];
    NSDictionary *tags = opdata[FT_TAGS];
    NSString *oldSessionId =tags[FT_RUM_KEY_SESSION_ID];
    NSDictionary *newDict = [FTJSONUtil dictionaryWithJsonString:newModel.data];
    NSDictionary *newOpdata = newDict[FT_OPDATA];
    NSDictionary *newTags = newOpdata[FT_TAGS];
    NSString *newSessionId =newTags[FT_RUM_KEY_SESSION_ID];
    XCTAssertTrue(oldSessionId);
    XCTAssertTrue(newSessionId);
    XCTAssertFalse([oldSessionId isEqualToString:newSessionId]);
}
- (void)testSessionTimeOutViewUpdate{
    NSString *key = [FTBaseInfoHandler randomUUID];
    [self setRumConfig];
    [FTModelHelper startViewWithName:@"FirstView"];
    [FTModelHelper startAction];
    [FTModelHelper startResource:key];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    NSMutableArray *viewHandlers = [session valueForKey:@"viewHandlers"];

    //把session开始时间改为四小时前 模拟session过期
    NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] + 3600 * 4;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-aTimeInterval];
    [session setValue:newDate forKey:@"sessionStartTime"];
    
    [self addLongTaskData:nil];
    [FTModelHelper stopErrorResource:key];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMSessionHandler *newSession = [rum valueForKey:@"sessionHandler"];
    NSMutableArray *newViewHandlers = [newSession valueForKey:@"viewHandlers"];
    XCTAssertTrue(viewHandlers.count == newViewHandlers.count == 1);
    FTRUMViewHandler *viewHandler = (FTRUMViewHandler *)[viewHandlers lastObject];
    FTRUMViewHandler *newViewHandler = (FTRUMViewHandler *)[newViewHandlers lastObject];
    NSInteger viewResourceCount = [[viewHandler valueForKey:@"viewResourceCount"] integerValue];
    NSInteger viewErrorCount = [[viewHandler valueForKey:@"viewErrorCount"] integerValue];
    NSInteger viewActionCount = [[viewHandler valueForKey:@"viewActionCount"] integerValue];
    NSInteger viewLongTaskCount = [[viewHandler valueForKey:@"viewLongTaskCount"] integerValue];

    NSInteger nViewResourceCount = [[newViewHandler valueForKey:@"viewResourceCount"] integerValue];
    NSInteger nViewErrorCount = [[newViewHandler valueForKey:@"viewErrorCount"] integerValue];
    NSInteger nViewActionCount = [[newViewHandler valueForKey:@"viewActionCount"] integerValue];
    NSInteger nViewLongTaskCount = [[newViewHandler valueForKey:@"viewLongTaskCount"] integerValue];
    XCTAssertTrue(viewResourceCount == 0 );
    XCTAssertTrue(viewErrorCount == 0 );
    XCTAssertTrue(viewActionCount == 0 );
    XCTAssertTrue(viewLongTaskCount == 0 );
    
    XCTAssertTrue(nViewResourceCount == nViewErrorCount == nViewActionCount == 0 );
    XCTAssertTrue(nViewLongTaskCount == 1);
    XCTAssertTrue([viewHandler.view_name isEqualToString:newViewHandler.view_name]);
    XCTAssertFalse([viewHandler.view_id isEqualToString:newViewHandler.view_id]);
}
#pragma mark ========== View ==========

/**
 * 验证 source：view 的数据格式
 */
- (void)testAddViewDataAndFormatChecks{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasView = NO;
    [FTModelHelper resolveModelArray:array callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            [self rumTags:tags];
            XCTAssertTrue([fields.allKeys containsObject:FT_KEY_VIEW_RESOURCE_COUNT]&&[fields.allKeys containsObject:FT_KEY_VIEW_ACTION_COUNT]&&[fields.allKeys containsObject:FT_KEY_VIEW_LONG_TASK_COUNT]&&[fields.allKeys containsObject:FT_KEY_VIEW_ERROR_COUNT]&&[fields.allKeys containsObject:FT_KEY_IS_ACTIVE]&&[fields.allKeys containsObject:FT_KEY_VIEW_UPDATE_TIME]&&[fields.allKeys containsObject:FT_KEY_TIME_SPENT]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]&&[tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
            hasView = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasView);
}
- (void)testWrongFormatViewName{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@""];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [FTModelHelper stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasLaunchData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if([tags[FT_KEY_ACTION_NAME] isEqualToString:@"app_cold_start"]){
                hasLaunchData = YES;
            }
        }
    }];
    XCTAssertTrue(newArray.count == hasLaunchData?1:0);
}
/**
 * 验证 resource，action,error,long_task数据 是否同步到view中
 */
- (void)testViewUpdate{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startView];
    [self addLongTaskData:nil];
    [self addResource];
    [self addErrorData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;
    __block NSInteger actionCount,trueActionCount=0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW] && hasViewData == NO) {
            actionCount = [fields[FT_KEY_VIEW_ACTION_COUNT] integerValue];
            NSInteger errorCount = [fields[FT_KEY_VIEW_ERROR_COUNT] integerValue];
            NSInteger resourceCount = [fields[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
            NSInteger longTaskCount = [fields[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
            hasViewData = YES;
            NSInteger updateTime = [fields[FT_KEY_VIEW_UPDATE_TIME] integerValue];
            XCTAssertTrue(errorCount == 1);
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == 1);
            XCTAssertTrue(updateTime == 4);
        }else if([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]){
            trueActionCount ++;
        }
    }];
    XCTAssertTrue(hasViewData);
    XCTAssertTrue(actionCount == trueActionCount);
    [FTModelHelper stopView];
}
/// 验证开启enableTraceUserView,应用进入后台前台，view会自动更新
- (void)testEnableTraceUserView_whenAppWillEnterForeground{
    [self setRumConfig];
    DemoViewController *vc = [[DemoViewController alloc]init];
    [[FTAutoTrackHandler sharedInstance] notify_viewDidAppear:vc animated:YES];
    
    [self addLongTaskData:nil];
    [self addResource];
    [self addErrorData:nil];
    NSDictionary *dict0 = [[FTGlobalRumManager sharedInstance].rumManager getLinkRUMData];

    NSString *view_id = dict0[FT_KEY_VIEW_ID];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSDictionary *dict = [[FTGlobalRumManager sharedInstance].rumManager getLinkRUMData];

    XCTAssertFalse([dict.allKeys containsObject:FT_KEY_VIEW_ID]);
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSDictionary *dict2 = [[FTGlobalRumManager sharedInstance].rumManager getLinkRUMData];
    NSString *view_id2 = dict2[FT_KEY_VIEW_ID];
    XCTAssertTrue(view_id2);
    XCTAssertFalse([view_id2 isEqualToString:view_id]);
    XCTAssertTrue([dict0[FT_KEY_VIEW_NAME] isEqualToString:dict2[FT_KEY_VIEW_NAME]]);
}
- (void)testDisableTraceUserView_whenAppWillEnterForeground{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.errorMonitorType = FTErrorMonitorAll;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTModelHelper startView];
    [FTModelHelper startView];
    [self addLongTaskData:nil];
    [self addResource];
    [self addErrorData:nil];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSDictionary *dict = [[FTGlobalRumManager sharedInstance].rumManager getLinkRUMData];
    NSString *view_id = dict[FT_KEY_VIEW_ID];
    XCTAssertTrue(view_id);
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSDictionary *dict2 = [[FTGlobalRumManager sharedInstance].rumManager getLinkRUMData];
    XCTAssertTrue([view_id isEqualToString:dict2[FT_KEY_VIEW_ID]]);
}
#pragma mark ========== Resource ==========

/**
 * 验证 source：resource 的数据格式
 */
- (void)testAddResourceDataAndFormatChecks{
    [self resourceDataAndFormatChecks:NO];
}
-(void)testLowercaseResponseHeader{
    [self resourceDataAndFormatChecks:YES];
}
-(void)testErrorResourceBindView{
    [self setRumConfig];
    [FTModelHelper startViewWithName:@"FirstView"];
    [FTModelHelper startAction];
    NSString *key = [FTBaseInfoHandler randomUUID];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    [FTModelHelper stopView];
    [FTModelHelper startView];
    [FTModelHelper stopView];
    [FTModelHelper startView];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    model.httpStatusCode = 404;
    model.httpMethod = @"GET";
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:nil content:model];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block BOOL hasResource = NO;
    [FTModelHelper resolveModelArray:array idxCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop, NSUInteger idx) {
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            XCTAssertTrue([tags[FT_KEY_ERROR_TYPE] isEqualToString:FT_NETWORK_ERROR]);
            XCTAssertTrue([tags[FT_KEY_VIEW_NAME] isEqualToString:@"FirstView"]);
            hasResource = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResource);
}
-(void)resourceDataAndFormatChecks:(BOOL)lowercase{
    NSArray *resourceTag = @[FT_KEY_RESOURCE_URL,
                             FT_KEY_RESOURCE_URL_HOST,
                             FT_KEY_RESOURCE_URL_PATH,
                             FT_KEY_RESOURCE_URL_PATH_GROUP,
                             FT_KEY_RESOURCE_TYPE,
                             FT_KEY_RESOURCE_METHOD,
                             FT_KEY_RESOURCE_STATUS,
                             FT_KEY_RESOURCE_STATUS_GROUP,
                             FT_KEY_RESPONSE_CONTENT_ENCODING,
                             FT_KEY_RESOURCE_TYPE,
                             FT_KEY_RESPONSE_CONTENT_ENCODING,
                             FT_KEY_RESPONSE_CONNECTION
                             
    ];
    NSArray *resourceField = @[FT_DURATION,
                               FT_KEY_RESOURCE_SIZE,
                               FT_KEY_RESOURCE_DNS,
                               FT_KEY_RESOURCE_TCP,
                               FT_KEY_RESOURCE_SSL,
                               FT_KEY_RESOURCE_TTFB,
                               FT_KEY_RESOURCE_TRANS,
                               FT_KEY_RESOURCE_FIRST_BYTE,
    ];
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    if(lowercase){
        [self addLowercaseResource];
    }else{
        [self addResource];
    }
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResource = NO;
    __block FTRecordModel *resourceModel;
    __block NSDictionary *fieldDict;
    [FTModelHelper resolveModelArray:array idxCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop, NSUInteger idx) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            [self rumTags:tags];
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_NAME]);
            [resourceTag enumerateObjectsUsingBlock:^(NSString   *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                XCTAssertTrue([tags.allKeys containsObject:obj]);
            }];
            [resourceField enumerateObjectsUsingBlock:^(NSString   *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                XCTAssertTrue([fields.allKeys containsObject:obj]);
            }];
            resourceModel = array[idx];
            fieldDict = fields;
            hasResource = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResource);
    FTRequestLineBody *lineBody = [[FTRequestLineBody alloc]init];
    lineBody.events = @[resourceModel];
    NSString *lineStr = [lineBody getRequestBodyWithEventArray:@[resourceModel] packageId:@"1.1.1" enableIntegerCompatible:NO];
    NSArray *nameAry = @[FT_KEY_RESOURCE_SIZE,FT_KEY_RESOURCE_DNS,FT_KEY_RESOURCE_TTFB,FT_KEY_RESOURCE_SSL,FT_KEY_RESOURCE_TCP,FT_KEY_RESOURCE_DNS,FT_KEY_RESOURCE_FIRST_BYTE,FT_DURATION,FT_KEY_RESOURCE_TRANS];
    for (NSString *name in nameAry) {
        NSString *line = [NSString stringWithFormat:@"%@=%@i",name,fieldDict[name]];
        XCTAssertTrue([lineStr containsString:line]);
    }
    
    [FTModelHelper stopView];
}

- (void)testAddErrorResource{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [self addErrorResource];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:array callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            [self rumTags:tags];
            NSInteger errorCount = [fields[FT_KEY_VIEW_ERROR_COUNT] integerValue];
            NSInteger resourceCount = [fields[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
            XCTAssertTrue(errorCount == 1);
            XCTAssertTrue(resourceCount == 1);
            *stop = YES;
        }
    }];
}
- (void)testStopResourceInBackground{
    [self setRumConfig];
    DemoViewController *vc = [[DemoViewController alloc]init];
    [[FTAutoTrackHandler sharedInstance] notify_viewDidAppear:vc animated:YES];

    NSString *key = [FTBaseInfoHandler randomUUID];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMSessionHandler *sessionHandler = [[FTGlobalRumManager sharedInstance].rumManager valueForKey:@"sessionHandler"];
    NSArray *viewHandlers = [sessionHandler valueForKey:@"viewHandlers"];
    XCTAssertTrue(viewHandlers.count>0);

    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = url;
    model.httpStatusCode = 404;
    model.httpMethod = @"GET";
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:nil content:model];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newViewHandlers = [sessionHandler valueForKey:@"viewHandlers"];
    XCTAssertTrue(newViewHandlers.count == 0);
}
// 当下一个 View Start，不再更新当前 View 的 duration（不再有新的 View 数据，直至 resource 结束）
- (void)testGivenViewUnfinishedResource{
    [self setRumConfig];
    [FTModelHelper startViewWithName:@"TestDuration"];
    NSString *key = [FTBaseInfoHandler randomUUID];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    [FTModelHelper stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    __block NSString *modelId,*viewId;
    [FTModelHelper resolveModelArray:array modelIdCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop, NSString *modelID) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            if([tags[FT_KEY_VIEW_NAME] isEqualToString:@"TestDuration"]){
                modelId = modelID;
                viewId = tags[FT_KEY_VIEW_ID];
                *stop = YES;
            }
        }
    }];
    [FTModelHelper startViewWithName:@"NextView"];
    [FTModelHelper stopView];
    [FTModelHelper startViewWithName:@"NextView"];
    [FTModelHelper stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>array.count);
    [FTModelHelper resolveModelArray:newArray modelIdCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop, NSString *modelID) {
        if ([tags[FT_KEY_VIEW_ID] isEqualToString:viewId]) {
            XCTAssertTrue([modelID isEqualToString:modelId]);
            *stop = YES;
        }
    }];
}
- (void)testErrorDurationResource{
    [self setRumConfig];
    [FTModelHelper startView];
    NSString *key = [FTBaseInfoHandler randomUUID];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    model.httpStatusCode = 404;
    model.httpMethod = @"GET";
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:nil content:model];
    NSString *key2 = [FTBaseInfoHandler randomUUID];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key2];
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"expectation"];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[FTExternalDataManager sharedManager] stopResourceWithKey:key2];
        [[FTExternalDataManager sharedManager] addResourceWithKey:key2 metrics:nil content:model];
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation]];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    [FTModelHelper resolveModelArray:datas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            NSNumber *duration = [fields valueForKey:FT_DURATION];
            XCTAssertTrue(duration.integerValue>0);
        }
    }];
}
- (void)testEnableResourceHostIP{
    [self enableResourceHostIP:YES];
}
- (void)testDisableResourceHostIP{
    [self enableResourceHostIP:NO];
}
- (void)enableResourceHostIP:(BOOL)enable{
    [self setRumConfigEnableResourceHostIP:enable];
    [FTModelHelper startView];
    XCTestExpectation *expect = [self expectationWithDescription:@"testEnableResourceHostIP"];
    NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *dataTask = [urlSession dataTaskWithURL:[NSURL URLWithString:@"https://www.baidu.com"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expect fulfill];
    }];
    [dataTask resume];
    [urlSession finishTasksAndInvalidate];
    [self waitForExpectations:@[expect]];
    sleep(1);
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]&&[tags[FT_KEY_RESOURCE_URL_HOST] isEqualToString:@"www.baidu.com"]) {
            if(enable){
                XCTAssertNotNil(fields[FT_KEY_RESOURCE_HOST_IP]);
            }else{
                XCTAssertNil(fields[FT_KEY_RESOURCE_HOST_IP]);
            }
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
- (void)testNoRUMView_resource{
    [self setRumConfig];
    [self addResource:nil endContext:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasResourceData = YES;
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
    [FTModelHelper startViewWithName:@"testNoRUMView_resource"];
    [self addResource:nil endContext:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    __block NSInteger hasViewData = NO;
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    [FTModelHelper resolveModelArray:array callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            hasViewData = YES;
            XCTAssertTrue([tags[FT_KEY_VIEW_NAME] isEqualToString:@"testNoRUMView_resource"]);
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);
}
#pragma mark ========== Action ==========

/**
 * 验证 source：action 的数据格式
 */
- (void)testAddActionAndActionDataFormatChecks{
    [self setRumConfig];
    
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper startView];
    [FTModelHelper startActionWithType:@"longTap"];
    [FTModelHelper startView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if([tags[FT_KEY_ACTION_TYPE] isEqualToString:@"longTap"]){
                [self rumTags:tags];
                XCTAssertTrue([fields.allKeys containsObject:FT_KEY_ACTION_LONG_TASK_COUNT]&&[fields.allKeys containsObject:FT_KEY_ACTION_RESOURCE_COUNT]&&[fields.allKeys containsObject:FT_KEY_ACTION_ERROR_COUNT]);
                XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_ID]&&[tags.allKeys containsObject:FT_KEY_ACTION_NAME]&&[tags.allKeys containsObject:FT_KEY_ACTION_TYPE]);
                XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
                //            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_REFERRER]);
                XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
                XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
                *stop = YES;
            }
        }
    }];
}
- (void)testWrongFormatActionName{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"view1"];
    
    [[FTExternalDataManager sharedManager] startAction:@"" actionType:@"click" property:nil];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTExternalDataManager sharedManager] stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if(![tags[FT_KEY_ACTION_NAME] isEqualToString:@"app_cold_start"])
            {   hasDatas = YES;
                [tags[FT_KEY_ACTION_NAME] isEqualToString:@""];
                *stop = YES;
            }
        }
    }];
    XCTAssertTrue(hasDatas);
}
- (void)testActionWrongFormat{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startActionWithType:@""];
    [self waitForTimeInterval:0.1];
    [FTModelHelper startActionWithType:@"AA"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [self addErrorData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if(![tags[FT_KEY_ACTION_NAME] isEqualToString:@"app_cold_start"]){
                hasClickAction = YES;
                XCTAssertTrue([tags[FT_KEY_ACTION_TYPE] isEqualToString:@""]);
            }
        }
    }];
    XCTAssertTrue(hasClickAction);
    [FTModelHelper stopView];
}
- (void)testAddAction_NOView{
    [self setRumConfig];
    [FTMobileAgent clearAllData];
    NSDictionary *property = @{@"action_property":@"testAddAction_NOView"};
    [FTModelHelper addActionWithContext:property];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count >= 1);
    __block BOOL hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            XCTAssertTrue([fields[@"action_property"] isEqualToString:@"testAddAction_NOView"]);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
}
- (void)testAddAction_HasView{
    [self setRumConfig];
    [FTMobileAgent clearAllData];
    [FTModelHelper startView];
    NSDictionary *property = @{@"action_property":@"testAddAction_HasView"};
    [FTModelHelper addActionWithContext:property];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count >= 2);
    __block BOOL hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            XCTAssertTrue([fields[@"action_property"] isEqualToString:@"testAddAction_HasView"]);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
}
// addAction 添加的 Action 不影响 StartA
- (void)testAddAction_HasStartAction{
    [self setRumConfig];
    [FTMobileAgent clearAllData];
    [FTModelHelper startView];
    NSDictionary *property = @{@"action_property":@"addAction"};
    [[FTExternalDataManager sharedManager] startAction:@"testAddAction_HasStartAction" actionType:@"click" property:nil];
    [FTModelHelper addActionWithContext:property];
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[session valueForKey:@"viewHandlers"] lastObject];
    FTRUMActionHandler *action = [view valueForKey:@"actionHandler"];
    NSString *actionName = [action valueForKey:@"action_name"];
    NSNumber *actionLongTaskCount = [action valueForKey:@"actionLongTaskCount"];
    
    XCTAssertTrue([actionName isEqualToString:@"testAddAction_HasStartAction"]);
    XCTAssertTrue([actionLongTaskCount isEqual:@1]);

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count > 0);
    __block BOOL hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            XCTAssertTrue([fields[@"action_property"] isEqualToString:@"addAction"]);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
}
// 验证：action 最长持续 5s
- (void)testStartAddAction_AppendingResource_maxDuration{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [FTModelHelper startResource:@"aaa"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[session valueForKey:@"viewHandlers"] lastObject];
    FTRUMActionHandler *action = [view valueForKey:@"actionHandler"];
    
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-6];
    [action setValue:newDate forKey:@"actionStartTime"];
    
    //把 action 上次记录数据改为 6 秒前 模拟 action 过期
    
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    __block BOOL hasLongTask = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_KEY_ACTION_TYPE_CLICK]){
                XCTAssertTrue([fields[FT_KEY_ACTION_LONG_TASK_COUNT] isEqual:@0]);
                XCTAssertTrue([fields[FT_DURATION] isEqual:@5000000000]);
                hasClickAction = YES;
            }
        }else if([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]){
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_ACTION_ID]);
            hasLongTask  = YES;
        }
    }];
    XCTAssertTrue(hasClickAction);
    XCTAssertTrue(hasLongTask);
    [FTModelHelper stopView];
}
- (void)testStartAction_0_1s_ActionAbandon{
    [self setRumConfig];
    [FTModelHelper startView];
    [[FTExternalDataManager sharedManager] startAction:@"action1" actionType:@"click" property:nil];
    [[FTExternalDataManager sharedManager] startAction:@"action2" actionType:@"click" property:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[session valueForKey:@"viewHandlers"] lastObject];
    FTRUMActionHandler *action = [view valueForKey:@"actionHandler"];
    NSString *actionName = [action valueForKey:@"action_name"];
    XCTAssertTrue([actionName isEqualToString:@"action1"]);
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_KEY_ACTION_TYPE_CLICK]){
                hasClickAction = YES;
            }
        }
    }];
    XCTAssertFalse(hasClickAction);
    [FTModelHelper stopView];
}
// start action 0.1s 后新的 event 进入，数据不会绑定到 action 上并且 action 会被 close
- (void)testStartAction_0_1s_NoDataBind{
    [self setRumConfig];
    [FTModelHelper startView];
    [[FTExternalDataManager sharedManager] startAction:@"testStartAction_0_1s_NoDataBind" actionType:@"click" property:nil];
    [self waitForTimeInterval:0.2];
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[session valueForKey:@"viewHandlers"] lastObject];
    FTRUMActionHandler *action = [view valueForKey:@"actionHandler"];
    NSLog(@"action_name: %@",action.context.action_name);
    XCTAssertNil(action);

    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasClickAction = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if([tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_KEY_ACTION_TYPE_CLICK]){
                hasClickAction = YES;
                NSInteger longTaskCount = [fields[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
                XCTAssertTrue(longTaskCount == 0);
            }
        }
    }];
    XCTAssertTrue(hasClickAction);
    [FTModelHelper stopView];
}
/**
 * 验证 resource,error,long_task数据 是否同步到action中
 */
- (void)testStartAction_0_1s_DataBind{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [self addResource];
    [self addLongTaskData:nil];
    [self addErrorData:nil];
    [FTModelHelper stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            NSInteger errorCount = [fields[FT_KEY_ACTION_ERROR_COUNT] integerValue];
            NSInteger resourceCount = [fields[FT_KEY_ACTION_RESOURCE_COUNT] integerValue];
            NSInteger longTaskCount = [fields[FT_KEY_ACTION_LONG_TASK_COUNT] integerValue];
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
- (void)testStartAction_noView{
    [self setRumConfig];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper addActionWithContext:@{@"test":@"noView"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block NSInteger hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
    [FTModelHelper startViewWithName:@"testNoRUMView_action"];
    [self addResource:nil endContext:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    __block NSInteger hasViewData = NO;
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    [FTModelHelper resolveModelArray:array callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW] && [tags[FT_KEY_VIEW_NAME] isEqualToString:@"testNoRUMView_action"]) {
            hasViewData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);
}
- (void)testStartAction_stopBy_stopViewORStartNewView{
    [self setRumConfig];
    [FTModelHelper startAction];
    [FTModelHelper startView];
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>=3);
    __block NSInteger hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            NSInteger longTaskCount = [fields[FT_KEY_VIEW_LONG_TASK_COUNT] integerValue];
            XCTAssertTrue(longTaskCount == 0);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
    [FTMobileAgent clearAllData];
    [FTModelHelper startAction];
    [FTModelHelper startResource:@"aaa"];
    [self waitForTimeInterval:0.2];
    [FTModelHelper stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    hasActionData = NO;
    [FTModelHelper resolveModelArray:array callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            NSInteger resourceCount = [fields[FT_KEY_VIEW_RESOURCE_COUNT] integerValue];
            XCTAssertTrue(resourceCount == 0);
            int duration = [fields[FT_DURATION] intValue];
            XCTAssertTrue(duration>200000000);
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);
}
#pragma mark ========== Error ==========

- (void)testAddErrorData{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [self addErrorData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasErrorData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_NAME]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testAddErrorSituation{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" state:FTAppStateUnknown message:@"message" stack:@"stack" property:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasErrorData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            XCTAssertTrue([tags[FT_KEY_ERROR_SITUATION] isEqualToString:@"unknown"]);
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testWrongFormatErrorData{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"" message:@"testWrongError" stack:@"error testWrongError"];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"" stack:@"error testWrongError"];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"testWrongError" stack:@""];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block int hasDatasCount = 0;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            hasDatasCount ++;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatasCount == 1);
}
#pragma mark ========== Long Task ==========

- (void)testAddLongTaskData{
    [self setRumConfig];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [self addLongTaskData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_ACTION_NAME]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_ID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_VIEW_NAME]);
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatas);
}
- (void)testWrongFormatLongTaskData{
    [self setRumConfig];
    [[FTExternalDataManager sharedManager] onCreateView:@"LongTask" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"LongTask"];
    
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"" duration:@1200000000];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertFalse(hasDatas);
}
#pragma mark ========== RUM Config ==========
- (void)testSampleRate0{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.samplerate = 0;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [self addErrorData:nil];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);
    [FTModelHelper stopView];
}
- (void)testSampleRate100{
    [self setRumConfig];
    
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    
    [FTModelHelper startView];
    [FTModelHelper startAction];
    [self addErrorData:nil];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count > oldArray.count);
}
/**
 * 验证  FTTraceConfig enableLinkRumData
 * 需要设置 networkTraceType = FTNetworkTraceTypeDDtrace
 */
- (void)testTraceLinkRumData{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
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
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTModelHelper startView];
    [self addErrorData:nil];
    [self addResource];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertTrue([tags.allKeys containsObject:FT_KEY_TRACEID]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData == YES);
}
- (void)testNotTraceLinkRumData{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
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
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [FTModelHelper startView];
    [self addErrorData:nil];
    [self addResource];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasResourceData;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_SPANID]);
            XCTAssertFalse([tags.allKeys containsObject:FT_KEY_TRACEID]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData == YES);
}
- (void)testRUMGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{FT_RUM_KEY_SESSION_ID:@"testRUMGlobalContext",@"track_id":@"testGlobalTrack"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    
    [FTModelHelper startView];
    [self addErrorData:nil];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
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
- (void)testRUMGlobalContext_mutable{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];

    NSMutableDictionary *context = @{@"testRUMGlobalContext_mutable":@"testRUMGlobalContext_mutable"}.mutableCopy;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.globalContext = context;
    [context setValue:@"testRUMGlobalContext" forKey:@"testRUMGlobalContext_mutable"];
    XCTAssertTrue([rumConfig.globalContext[@"testRUMGlobalContext_mutable"] isEqualToString:@"testRUMGlobalContext_mutable"]);
    XCTAssertTrue([context[@"testRUMGlobalContext_mutable"] isEqualToString:@"testRUMGlobalContext"]);
}
- (void)testAppendRUMGlobalContext{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.globalContext = @{@"track_id":@"testGlobalTrack"};
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    
    [FTModelHelper startView];
    [self addErrorData:nil];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict =  [FTJSONUtil dictionaryWithJsonString:model.data];
    NSString *op = dict[@"op"];
    XCTAssertTrue([op isEqualToString:@"RUM"]);
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[FT_TAGS];
    XCTAssertTrue([[tags valueForKey:@"track_id"] isEqualToString:@"testGlobalTrack"]);
    NSString *custom_keys = tags[FT_RUM_CUSTOM_KEYS];
    NSArray *keys = [NSJSONSerialization JSONObjectWithData:[custom_keys dataUsingEncoding:kCFStringEncodingUTF8] options:0 error:nil];
    XCTAssertTrue(keys.count == 1);
    XCTAssertTrue([keys containsObject:@"track_id"]);
    
    [FTMobileAgent appendRUMGlobalContext:@{@"append_global":@"testAppendRUMGlobalContext"}];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];

    [self addErrorData:nil];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    FTRecordModel *newModel = [newArray lastObject];
    NSDictionary *newDict =  [FTJSONUtil dictionaryWithJsonString:newModel.data];
    NSDictionary *nopdata = newDict[@"opdata"];
    NSDictionary *newTags = nopdata[FT_TAGS];
    XCTAssertTrue([[newTags valueForKey:@"track_id"] isEqualToString:@"testGlobalTrack"]);
    NSString *ncustom_keys = newTags[FT_RUM_CUSTOM_KEYS];
    NSArray *newKeys = [NSJSONSerialization JSONObjectWithData:[ncustom_keys dataUsingEncoding:kCFStringEncodingUTF8] options:0 error:nil];
    XCTAssertTrue(newKeys.count == 2);
    XCTAssertTrue([newKeys containsObject:@"track_id"]);
    XCTAssertTrue([newKeys containsObject:@"append_global"]);

}
#pragma mark ========== Property ==========
- (void)testAddActionProperty{
    [self actionProperty:YES];
}
- (void)testAddActionProperty_mutable{
    [self ActionPropertyMutable:YES];
}
- (void)testStartActionProperty{
    [self actionProperty:NO];
}
- (void)testStartActionProperty_mutable{
    [self ActionPropertyMutable:NO];
}
- (void)actionProperty:(BOOL)isAdd{
    [self setRumConfig];
    [FTMobileAgent clearAllData];
    if(isAdd){
        [FTModelHelper addActionWithContext:@{@"action_property":@"testActionProperty1"}];
    }else{
        [[FTExternalDataManager sharedManager] startAction:@"action" actionType:@"click" property:@{@"action_property":@"testActionProperty1"}];
        [self waitForTimeInterval:0.1];
        [self addErrorData:nil];
    }
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasAction = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION] && [tags[FT_KEY_ACTION_TYPE] isEqualToString:FT_KEY_ACTION_TYPE_CLICK]) {
            XCTAssertTrue([fields[@"action_property"] isEqualToString:@"testActionProperty1"]);
            hasAction = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasAction == YES);
}
- (void)ActionPropertyMutable:(BOOL)isAdd{
    [self setRumConfig];
    [FTMobileAgent clearAllData];
    NSDictionary *property = @{@"action_property":@"testActionProperty1"}.mutableCopy;
    if(isAdd){
        [FTModelHelper addActionWithContext:property];
    }else{
        [[FTExternalDataManager sharedManager] startAction:@"action" actionType:@"click" property:property];
    }
    [property setValue:@"add" forKey:@"add"];
    if(!isAdd){
        [self waitForTimeInterval:0.1];
        [self addErrorData:nil];
    }
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasAction = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            XCTAssertTrue([fields[@"action_property"] isEqualToString:@"testActionProperty1"]);
            XCTAssertFalse([fields.allKeys containsObject:@"add"]);
            XCTAssertTrue([property[@"add"] isEqualToString:@"add"]);
            hasAction = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasAction == YES);
}
- (void)testStartViewProperty{
    [self setRumConfig];
    [FTModelHelper startView:@{@"view_context":@"testStartViewProperty"}];
    [self addErrorData:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasViewData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW] && hasViewData == NO) {
            XCTAssertTrue([fields[@"view_context"] isEqualToString:@"testStartViewProperty"]);
            hasViewData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);
    [FTModelHelper stopView];
}
- (void)testStopViewProperty{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addErrorData:nil];
    [FTModelHelper stopView:@{@"view_stop_context":@"testStopViewProperty"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasViewData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW] && hasViewData == NO) {
            XCTAssertTrue([fields[@"view_stop_context"] isEqualToString:@"testStopViewProperty"]);
            hasViewData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);
}
- (void)testViewProperty{
    [self setRumConfig];
    [FTModelHelper startView:@{@"view_start_context":@"testViewProperty"}];
    [self addErrorData:nil];
    [FTModelHelper stopView:@{@"view_stop_context":@"testViewProperty"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasViewData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW] && hasViewData == NO) {
            XCTAssertTrue([fields[@"view_stop_context"] isEqualToString:@"testViewProperty"]);
            XCTAssertTrue([fields[@"view_start_context"] isEqualToString:@"testViewProperty"]);
            hasViewData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);
}
- (void)testViewProperty_mutable{
    [self setRumConfig];
    NSDictionary *property = @{@"view_start_context":@"testViewProperty"}.mutableCopy;
    [FTModelHelper startView:property];
    [property setValue:@"add" forKey:@"add"];
    [self addErrorData:nil];
    NSDictionary *stopProperty = @{@"view_stop_context":@"testViewProperty"}.mutableCopy;
    [FTModelHelper stopView:stopProperty];
    [stopProperty setValue:@"add" forKey:@"view_stop_add"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasViewData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW] && hasViewData == NO) {
            XCTAssertTrue([fields[@"view_stop_context"] isEqualToString:@"testViewProperty"]);
            XCTAssertTrue([fields[@"view_start_context"] isEqualToString:@"testViewProperty"]);
            XCTAssertFalse([fields.allKeys containsObject:@"add"]);
            XCTAssertFalse([fields.allKeys containsObject:@"view_stop_add"]);
            XCTAssertTrue([stopProperty[@"view_stop_add"] isEqualToString:@"add"]);
            XCTAssertTrue([property[@"add"] isEqualToString:@"add"]);
            hasViewData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);
}
- (void)testErrorProperty{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addErrorData:@{@"error_context":@"testErrorProperty"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasErrorData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            XCTAssertTrue([fields[@"error_context"] isEqualToString:@"testErrorProperty"]);
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testErrorProperty_mutable{
    [self setRumConfig];
    [FTModelHelper startView];
    NSDictionary *property = @{@"error_context":@"error_context"}.mutableCopy;
    [self addErrorData:property];
    [property setValue:@"add" forKey:@"add"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasErrorData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ERROR]) {
            XCTAssertTrue([fields[@"error_context"] isEqualToString:@"error_context"]);
            XCTAssertFalse([fields.allKeys containsObject:@"add"]);
            XCTAssertTrue([property[@"add"] isEqualToString:@"add"]);
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testLongTaskProperty{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addLongTaskData:@{@"longtask_context":@"testLongTaskContext"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasErrorData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            XCTAssertTrue([fields[@"longtask_context"] isEqualToString:@"testLongTaskContext"]);
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testLongTaskProperty_mutable{
    [self setRumConfig];
    [FTModelHelper startView];
    NSDictionary *property = @{@"longtask_context":@"testLongTaskContext"}.mutableCopy;
    [self addLongTaskData:property];
    [property setValue:@"add" forKey:@"add"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasErrorData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_LONG_TASK]) {
            XCTAssertTrue([fields[@"longtask_context"] isEqualToString:@"testLongTaskContext"]);
            XCTAssertFalse([fields.allKeys containsObject:@"add"]);
            XCTAssertTrue([property[@"add"] isEqualToString:@"add"]);
            hasErrorData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasErrorData);
}
- (void)testStartResourceProperty{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addResource:@{@"resource_start_context":@"testStartResourceContext"} endContext:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertTrue([fields[@"resource_start_context"] isEqualToString:@"testStartResourceContext"]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
- (void)testStartResourceProperty_mutable{
    [self setRumConfig];
    NSMutableArray *array = @[@1,@2].mutableCopy;
    NSMutableDictionary *property = @{@"resource_start_context":array}.mutableCopy;
    [FTModelHelper startView];
    [self addResource:property endContext:nil];
    [array addObject:@3];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertTrue([fields[@"resource_start_context"] isKindOfClass:NSArray.class]);
            NSArray *context = fields[@"resource_start_context"];
            NSArray *equalArray = @[@1,@2];
            XCTAssertTrue([context isEqualToArray:equalArray]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
- (void)testStopResourceProperty{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addResource:nil endContext:@{@"resource_stop_context":@"testStopResourceContext"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertTrue([fields[@"resource_stop_context"] isEqualToString:@"testStopResourceContext"]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
- (void)testStopResourceProperty_mutable{
    [self setRumConfig];
    [FTModelHelper startView];
    NSDictionary *endProperty = @{@"resource_stop_context":@"testResourceContext"}.mutableCopy;
    [self addResource:nil endContext:endProperty];
    [endProperty setValue:@"add" forKey:@"add"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertTrue([fields[@"resource_stop_context"] isEqualToString:@"testResourceContext"]);
            XCTAssertFalse([fields.allKeys containsObject:@"add"]);
            XCTAssertTrue([endProperty[@"add"] isEqualToString:@"add"]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
- (void)testResourceProperty{
    [self setRumConfig];
    [FTModelHelper startView];
    [self addResource:@{@"resource_start_context":@"testResourceContext"} endContext:@{@"resource_stop_context":@"testResourceContext"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block NSInteger hasResourceData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            XCTAssertTrue([fields[@"resource_start_context"] isEqualToString:@"testResourceContext"]);
            XCTAssertTrue([fields[@"resource_stop_context"] isEqualToString:@"testResourceContext"]);
            hasResourceData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasResourceData);
}
#pragma mark ========== Mock Data ==========

- (void)addErrorData:(NSDictionary *)property{
    NSString *error_message = @"-[__NSSingleObjectArrayI objectForKey:]: unrecognized selector sent to instance 0x600002ac5270";
    NSString *error_stack = @"Slide_Address:74940416\nException Stack:\n0   CoreFoundation                      0x00007fff20421af6 __exceptionPreprocess + 242\n1   libobjc.A.dylib                     0x00007fff20177e78 objc_exception_throw + 48\n2   CoreFoundation                      0x00007fff204306f7 +[NSObject(NSObject) instanceMethodSignatureForSelector:] + 0\n3   CoreFoundation                      0x00007fff20426036 ___forwarding___ + 1489\n4   CoreFoundation                      0x00007fff20428068 _CF_forwarding_prep_0 + 120\n5   SampleApp                           0x000000010477fb06 __35-[Crasher throwUncaughtNSException]_block_invoke + 86\n6   libdispatch.dylib                   0x000000010561f7ec _dispatch_call_block_and_release + 12\n7   libdispatch.dylib                   0x00000001056209c8 _dispatch_client_callout + 8\n8   libdispatch.dylib                   0x0000000105622e46 _dispatch_queue_override_invoke + 1032\n9   libdispatch.dylib                   0x0000000105632508 _dispatch_root_queue_drain + 351\n10  libdispatch.dylib                   0x0000000105632e6d _dispatch_worker_thread2 + 135\n11  libsystem_pthread.dylib             0x00007fff611639f7 _pthread_wqthread + 220\n12  libsystem_pthread.dylib             0x00007fff61162b77 start_wqthread + 15";
    NSString *error_type = @"ios_crash";
    
    [[FTExternalDataManager sharedManager] addErrorWithType:error_type  message:error_message stack:error_stack property:property];
}
- (void)addLongTaskData:(NSDictionary *)property{
    NSString *stack = @"test_long_task";
    NSNumber *duration = @5000000000;
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:stack duration:duration property:property];
}
- (void)addResource{
    [self addResource:nil endContext:nil];
}
- (void)addResource:(NSDictionary *)startContext endContext:(NSDictionary *)endContext{
    NSString *key = [FTBaseInfoHandler randomUUID];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key property:startContext];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = url;
    model.httpStatusCode = 200;
    model.httpMethod = @"GET";
    model.requestHeader = traceHeader;
    model.responseHeader = @{ @"Accept-Ranges": @"bytes",
                              @"Cache-Control": @"max-age=86400",
                              @"Content-Encoding": @"gzip",
                              @"Connection":@"keep-alive",
                              @"Content-Length":@"11328",
                              @"Content-Type": @"text/html",
                              @"Server": @"Apache",
                              @"Vary": @"Accept-Encoding,User-Agent"
                              
    };
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key property:endContext];
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
- (void)addLowercaseResource{
    NSString *key = [FTBaseInfoHandler randomUUID];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    NSDictionary *traceHeader = [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = url;
    model.httpStatusCode = 200;
    model.httpMethod = @"GET";
    model.requestHeader = traceHeader;
    model.responseHeader = @{ @"accept-ranges": @"bytes",
                              @"cache-control": @"max-age=86400",
                              @"content-encoding": @"gzip",
                              @"connection":@"keep-alive",
                              @"content-length":@"11328",
                              @"content-type": @"text/html",
                              @"server": @"Apache",
                              @"Vary": @"Accept-Encoding,User-Agent",
                              
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
    
    NSString *key = [FTBaseInfoHandler randomUUID];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
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
    [self setRumConfigEnableResourceHostIP:NO];
}
- (void)setRumConfigEnableResourceHostIP:(BOOL)enable{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableResourceHostIP = enable;
    rumConfig.errorMonitorType = FTErrorMonitorAll;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
@end
