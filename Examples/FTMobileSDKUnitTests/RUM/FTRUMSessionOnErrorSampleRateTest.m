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
#import "FTDataWriterWorker.h"
#import "XCTestCase+Utils.h"
#import "FTTrackDataManager.h"
#import "FTLog+Private.h"
@interface FTDataWriterWorker(Testing)
@property (nonatomic, assign) long long processStartTime;
- (void)checkLastProcessErrorSampled;
@end
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
    [FTLog enableLog:YES];
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
    rumConfig.sessionOnErrorSampleRate = sampleRate == 100?0:100;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
}
/// FT_RUM_SESSION_SAMPLE_RATE == 100
/// FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE == 0
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
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == NO);
        }
        XCTAssertTrue([fields[FT_RUM_SESSION_SAMPLE_RATE] intValue] == 100);
        XCTAssertTrue([fields[FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE] intValue] == 0);
    }];
}
/// Test session_error_timestamp == error.timestamp
/// FT_RUM_SESSION_SAMPLE_RATE == 0
/// FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE == 100
/// sampled_for_error_session == YES
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
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
            hasView = YES;
            errorTimestamp == nil?errorTimestamp = fields[FT_SESSION_ERROR_TIMESTAMP]:errorTimestamp;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"unSampling"]);
        }
        XCTAssertTrue([fields[FT_RUM_SESSION_SAMPLE_RATE] intValue] == 0);
        XCTAssertTrue([fields[FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE] intValue] == 100);
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
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"resource_error"]);
        }
        XCTAssertTrue([fields[FT_RUM_SESSION_SAMPLE_RATE] intValue] == 0);
        XCTAssertTrue([fields[FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE] intValue] == 100);
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
            XCTAssertTrue(fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] == nil);
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"error"]);
            XCTAssertTrue(fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] == nil);
        }
        XCTAssertTrue([fields[FT_RUM_SESSION_SAMPLE_RATE] intValue] == 0);
        XCTAssertTrue([fields[FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE] intValue] == 100);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == YES);
    XCTAssertTrue(hasAction == YES);
}
/// Determine whether the type of rum data (non-error) added after calling the -switchCacheWriter method is cache, and whether multiple calls have an impact
- (void)testSwitchCacheWriter{
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]init];
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"normal"} time:123];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} time:123];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 2);
}
/// Determine whether the type of data added after calling the -switchCacheWriter method is rum_cache after adding error data
- (void)testSwitchCacheWriter_addErrorDataTurnRUMWriter{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]init];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"cache"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    NSArray *datas = [newArray subarrayWithRange:NSMakeRange(0, newArray.count-1)];
    [[newArray lastObject].op isEqualToString:FT_DATA_TYPE_RUM_CACHE];
    for (FTRecordModel *model in datas) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 3);
    
}
/// Delete cache data when there is no error data written
- (void)testSessionOnErrorDatasInvalid_noErrorData{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"cache"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:1.5];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.5];
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 1);
}
/// Delete data outside the collection time interval after error data is written, and the data type of cache data updated within the time interval is rum
- (void)testSessionOnErrorDatasInvalid_addErrorData{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.5];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    [self waitForTimeInterval:0.5];
    
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];

    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 0);
    XCTAssertTrue(newArray.count == 2);
}
/// Test the case where the last process exceeds the time interval  
- (void)testSampledErrorSessionDatasConsume_lastProcess_exceed_time_interval{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.1];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"3"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];
    
    // Simulate entering a new process and exceeding the time interval
    writerManager.processStartTime = [[[NSDate date] dateByAddingTimeInterval:2] timeIntervalSince1970]*1e9;
    
    [writerManager checkLastProcessErrorSampled];
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count == 3);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray.lastObject.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
}
- (void)testSampledErrorSessionDatasConsume_lastProcess_immediately{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    
    // Simulate entering a new process
    writerManager.processStartTime = [[NSDate date] timeIntervalSince1970]*1e9;
    [writerManager checkLastProcessErrorSampled];

    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"3"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];

    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count == 3);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    XCTAssertTrue([newArray.lastObject.op isEqualToString:FT_DATA_TYPE_RUM]);
}
// Test the case where the last process has no ANR
- (void)testSampledErrorSessionDatasConsume_lastProcess_no_anr{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.1];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"3"} fields:@{@"test":@"normal"} time:[[NSDate date] timeIntervalSince1970]*1e9];
    
    // Simulate entering a new process and exceeding the time interval
    writerManager.processStartTime = [[[NSDate date] dateByAddingTimeInterval:2] timeIntervalSince1970]*1e9;
    
    [writerManager checkLastProcessErrorSampled];
    [writerManager lastFatalErrorIfFound:0];
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count == 2);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM]);
}
// Test the case where the last process has ANR
- (void)testSampledErrorSessionDatasConsume_lastProcess_has_anr{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"delete"} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];

    [self waitForTimeInterval:0.5];
    NSDate *date = [NSDate date];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"3"} fields:@{@"test":@"normal"} time:[[date dateByAddingTimeInterval:0.6] timeIntervalSince1970]*1e9];

    // Simulate entering a new process and exceeding the time interval
    writerManager.processStartTime = [[date dateByAddingTimeInterval:2] timeIntervalSince1970]*1e9;
    
    [writerManager checkLastProcessErrorSampled];
    NSArray<FTRecordModel *> *array = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(array.count == 3);
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"anr":@"anr"} fields:@{@"test":@"normal"} time:[[date dateByAddingTimeInterval:0.5] timeIntervalSince1970]*1e9 updateTime:0 cache:YES];
    NSArray<FTRecordModel *> *array2 = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(array2.count == 4);
    [writerManager lastFatalErrorIfFound:[[date dateByAddingTimeInterval:0.5] timeIntervalSince1970]*1e9];
    
    [writerManager checkRUMSessionOnErrorDatasExpired];
    
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count == 3);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM]);
}
@end
