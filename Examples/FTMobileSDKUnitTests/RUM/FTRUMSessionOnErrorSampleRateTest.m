//
//  FTRUMSessionOnErrorSampleRateTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/3/18.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Utils.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent.h"
#import "FTBaseInfoHandler.h"
#import "FTModelHelper.h"
#import "FTConstants.h"
#import "FTRUMManager.h"
#import "FTGlobalRumManager.h"
#import "FTDataWriterManager.h"
#import "XCTestCase+Utils.h"
@interface FTRUMSessionOnErrorSampleRateTest : XCTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTRUMSessionOnErrorSampleRateTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
}
- (void)sdkInitWithRumSampleRate:(int)sampleRate{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.samplerate = sampleRate;
    rumConfig.sessionOnErrorSampleRate = 100;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
}
- (void)testSessionOnErrorSampleRate_sampling{
    [self sdkInitWithRumSampleRate:100];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"sampling"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == NO);
    }];
}
/// 测试 session_error_timestamp == error.timestamp
/// is_error_session == YES
- (void)testSessionOnErrorSampleRate_unSampling{
    [self sdkInitWithRumSampleRate:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"unSampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_unSampling" stack:@"testSessionOnErrorSampleRate_unSampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"unSampling"}];
    [self waitForTimeInterval:0.2];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test2" message:@"testSessionOnErrorSampleRate_unSampling2" stack:@"testSessionOnErrorSampleRate_unSampling2"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    __block NSNumber *errorTimestamp = nil;
    [FTModelHelper resolveModelArray:newArray timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            if ([fields[FT_KEY_ERROR_STACK] isEqualToString:@"testSessionOnErrorSampleRate_unSampling"]) {
                XCTAssertTrue([errorTimestamp longLongValue] == time);
            }else{
                XCTAssertTrue([errorTimestamp longLongValue] != time);
            }
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"unSampling"]);
            errorTimestamp = tags[FT_SESSION_ERROR_TIMESTAMP];
        }
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == YES);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == YES);
    XCTAssertTrue(hasAction == YES);
}
- (void)testSessionOnErrorSampleRate_resource_error{
    [self sdkInitWithRumSampleRate:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [FTModelHelper startResource:@"111"];
    [FTModelHelper stopErrorResource:@"111"];
    [FTModelHelper addActionWithContext:@{@"test":@"resource_error"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"resource_error"]);
        }
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == YES);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == YES);
    XCTAssertTrue(hasAction == YES);
}
- (void)testSessionOnErrorSampleRate_error{
    [self sdkInitWithRumSampleRate:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"error"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"error"]);
        }
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == YES);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == YES);
    XCTAssertTrue(hasAction == YES);
}
/// 判断调用 -switchCacheWriter 方法后，添加的 rum 数据(非error)写入数据库时类型是否为 cache，多次调用是否有影响
- (void)testSwitchCacheWriter{
    FTDataWriterManager *writerManager = [[FTDataWriterManager alloc]init];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [writerManager switchToCacheWriter];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"normal"} time:123];
    [writerManager switchToCacheWriter];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} time:123];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 2);
}
/// 判断调用 -switchCacheWriter 方法后,添加 error 数据后，再添加的数据写入数据库时，数据类型是否为 rum
- (void)testSwitchCacheWriter_addErrorDataTurnRUMWriter{
    FTDataWriterManager *writerManager = [[FTDataWriterManager alloc]init];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [writerManager switchToCacheWriter];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"cache"} time:123];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:123];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 3);
    
}
/// 没有 error 数据写入时，cache 数据的删除
- (void)testSessionOnErrorDatasInvalid_noErrorData{
    FTDataWriterManager *writerManager = [[FTDataWriterManager alloc]initWithCacheInvalidTimeInterval:1];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    
    [writerManager switchToCacheWriter];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"cache"} time:123];
    [self waitForTimeInterval:1.5];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} time:123];
    [self waitForTimeInterval:0.5];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 1);
}
///  error 数据写入后，删除采集时间间隔外的数据，时间间隔内更新 cache 数据的数据类型为 rum
- (void)testSessionOnErrorDatasInvalid_addErrorData{
    FTDataWriterManager *writerManager = [[FTDataWriterManager alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager switchToCacheWriter];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} time:123];
    [self waitForTimeInterval:0.5];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} time:123];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    [self waitForTimeInterval:0.5];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 0);
    XCTAssertTrue(newArray.count == 2);
}
@end
