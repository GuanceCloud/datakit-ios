//
//  FTRumApiTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/21.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
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
#import <FTDataBase/FTTrackerEventDBTool.h>
#import "FTExternalDataManager.h"
#import "FTResourceContentModel.h"

@interface FTRumApiTest : XCTestCase

@end

@implementation FTRumApiTest

- (void)setUp {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.monitorInfoType = FTMonitorInfoTypeAll;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testAddViewApi{

    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"view1"];
    
    [NSThread sleepForTimeInterval:0.5];
    [[FTExternalDataManager sharedManager] stopView];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;

    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            hasDatas = YES;
            NSDictionary *tags = opdata[FT_TAGS];
            XCTAssertTrue([tags[FT_KEY_VIEW_NAME] isEqualToString:@"view1"]);
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatas);
}
- (void)testAddWrongViewName{
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@""];
    
    [NSThread sleepForTimeInterval:0.5];
    [[FTExternalDataManager sharedManager] stopView];
    [NSThread sleepForTimeInterval:2];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    XCTAssertTrue(newCount == 0);
}
- (void)testActionApi{
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"view1"];
    
    [[FTExternalDataManager sharedManager] addClickActionWithName:@"testActionApiClick"];
    
    [NSThread sleepForTimeInterval:0.5];
    [[FTExternalDataManager sharedManager] stopView];
    [NSThread sleepForTimeInterval:2];
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
            NSDictionary *tags = opdata[FT_TAGS];
            XCTAssertTrue([tags[FT_RUM_KEY_ACTION_NAME] isEqualToString:@"testActionApiClick"]);
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatas);
}
- (void)testWrongActionName{
    [[FTExternalDataManager sharedManager] onCreateView:@"view1" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"view1"];
    
    [[FTExternalDataManager sharedManager] addClickActionWithName:@""];
    
    [NSThread sleepForTimeInterval:0.5];
    [[FTExternalDataManager sharedManager] stopView];
    [NSThread sleepForTimeInterval:2];
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
- (void)testErrorApi{
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"testErrorApi" stack:@"error testErrorApi"];
    [NSThread sleepForTimeInterval:2];
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
            NSDictionary *fields = opdata[FT_FIELDS];
            XCTAssertTrue([fields[FT_RUM_KEY_ERROR_MESSAGE] isEqualToString:@"testErrorApi"]);
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatas);
}
- (void)testWorngError{
    [[FTExternalDataManager sharedManager] addErrorWithType:@"" message:@"testWorngError" stack:@"error testWorngError"];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"" stack:@"error testWorngError"];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"ios_crash" message:@"testWorngError" stack:@""];

    [NSThread sleepForTimeInterval:2];
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
- (void)testAddLongTaskWithStack{
    [[FTExternalDataManager sharedManager] onCreateView:@"LongTask" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"LongTask"];
    
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"testAddLongTaskWithStack" duration:@1200000000];
    [NSThread sleepForTimeInterval:2];
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
- (void)testWoringLongTask{
    [[FTExternalDataManager sharedManager] onCreateView:@"LongTask" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"LongTask"];
    
    [[FTExternalDataManager sharedManager] addLongTaskWithStack:@"" duration:@1200000000];
    [NSThread sleepForTimeInterval:2];
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
- (void)testResourceApi{
    [[FTExternalDataManager sharedManager] onCreateView:@"LongTask" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"LongTask"];
    NSString *key = [[NSUUID UUID]UUIDString];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"http://www.baidu.com"];
    model.duration = @1000;
    model.httpStatusCode = 200;
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:nil content:model];
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasDatas);
    
}
- (void)testWrongResource{
    [[FTExternalDataManager sharedManager] onCreateView:@"LongTask" loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:@"LongTask"];
    NSString *key = [[NSUUID UUID]UUIDString];
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"http://www.baidu.com"];
    model.duration = @1000;
    model.httpStatusCode = 200;
    [[FTExternalDataManager sharedManager] addResourceWithKey:@"" metrics:nil content:model];
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasDatas = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]) {
            hasDatas = YES;
            *stop = YES;
        }
    }];
    XCTAssertFalse(hasDatas);
}
@end
