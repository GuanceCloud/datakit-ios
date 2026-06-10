//
//  FTRUMSessionOnErrorSampleRateTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/3/18.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <TargetConditionals.h>
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
#import "FTInnerLog.h"
#import "NSDate+FTUtil.h"
#import "FTRUMSessionHandler.h"
#import "FTJSONUtil.h"
#import "FTRequestBody.h"
#if !TARGET_OS_TV
#import "FTSessionReplayFeature.h"
#import "FTSessionReplayConfig.h"
#import "FTModuleManager.h"
#import "FTRemoteConfigManager.h"
#import "FTScheduler.h"
#import "FTQueue.h"
#import "FTRecordingCoordinator.h"
#import "FTFeatureStorage.h"
#import "FTFeatureDirectories.h"
#import "FTDirectory.h"
#import "FTFile.h"
#import "FTFileWriter.h"
#import "FTPerformancePreset.h"
#import "FTTmpCacheManager.h"
#import "FTUploadProtocol.h"
#import "FTDateUtil.h"
typedef NS_ENUM(NSInteger, SampleState) {
    SampleStateNormal,
    SampleStateError,
    SampleStateNone
};
@interface FTRemoteConfigManager(Testing)
- (void)setLastRemoteModel:(FTRemoteConfigModel *)lastRemoteModel;
@end

@interface FTSessionReplayFeature(Testing)
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (nonatomic, strong) FTSessionReplayConfig *config;
@property (nonatomic, assign) SampleState sampleState;
@property (nonatomic, strong) id<FTScheduler> scheduler;
- (FTRecordingCoordinator *)ft_recordingCoordinator;
- (void)evaluateRecordingConditions;
@end

@implementation FTSessionReplayFeature(Testing)
@dynamic processorsQueue;
@dynamic config;
- (FTRecordingCoordinator *)ft_recordingCoordinator {
    return [self valueForKey:@"recordingCoordinator"];
}
- (SampleState)sampleState {
    return (SampleState)[self ft_recordingCoordinator].sampleState;
}
- (void)setSampleState:(SampleState)sampleState {
    [[self ft_recordingCoordinator] setSampleState:(FTRecordingSampleState)sampleState];
}
- (id<FTScheduler>)scheduler {
    return [self ft_recordingCoordinator].scheduler;
}
- (void)setScheduler:(id<FTScheduler>)scheduler {
    [self ft_recordingCoordinator].scheduler = scheduler;
}
- (void)evaluateRecordingConditions {
    [[self ft_recordingCoordinator] evaluateRecordingConditions];
}
@end

@interface FTFeatureStorage(Testing)
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation FTFeatureStorage(Testing)
@dynamic queue;
@end

@interface FTTmpCacheManager(Testing)
- (void)cleanupLastProcess;
- (void)receive:(NSString *)key message:(NSDictionary *)message;
@end

@interface FTTestSyncQueue : NSObject<FTQueue>
@end
@implementation FTTestSyncQueue
- (void)run:(void (^)(void))block {
    if (block) {
        block();
    }
}
@end

@interface FTTestSessionReplayScheduler : NSObject<FTScheduler>
@property (nonatomic, strong, readonly) id<FTQueue> queue;
@property (nonatomic, assign) NSInteger startCount;
@property (nonatomic, assign) NSInteger stopCount;
@end
@implementation FTTestSessionReplayScheduler
- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [[FTTestSyncQueue alloc] init];
    }
    return self;
}
- (void)scheduleWithOperation:(void (^)(void))operation {}
- (void)start {
    self.startCount += 1;
}
- (void)stop {
    self.stopCount += 1;
}
@end

@interface FTTestSessionReplayCacheWriter : NSObject<FTCacheWriter>
@property (nonatomic, assign) NSInteger activeCount;
@property (nonatomic, assign) NSInteger inactiveCount;
@property (nonatomic, strong) XCTestExpectation *activeExpectation;
@property (nonatomic, strong) XCTestExpectation *inactiveExpectation;
@end
@implementation FTTestSessionReplayCacheWriter
- (void)write:(NSData *)datas {}
- (void)write:(NSData *)datas forceNewFile:(BOOL)update {}
- (void)active {
    self.activeCount += 1;
    [self.activeExpectation fulfill];
    self.activeExpectation = nil;
}
- (void)inactive {
    self.inactiveCount += 1;
    [self.inactiveExpectation fulfill];
    self.inactiveExpectation = nil;
}
- (void)cleanup {}
@end

@interface FTTestSessionOnErrorDataHandler : NSObject<FTSessionOnErrorDataHandler>
@property (nonatomic, assign) long long errorTimeLine;
@property (nonatomic, assign) long long lastProcessFatalErrorTime;
@end
@implementation FTTestSessionOnErrorDataHandler
- (instancetype)init {
    self = [super init];
    if (self) {
        _lastProcessFatalErrorTime = 0;
    }
    return self;
}
- (void)checkRUMSessionOnErrorDatasExpired {}
- (long long)getErrorTimeLineFromFileCache {
    return self.errorTimeLine;
}
- (long long)getLastProcessFatalErrorTime {
    return self.lastProcessFatalErrorTime;
}
@end

@interface FTTestTmpCacheContext : NSObject
@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, strong) FTDirectory *realDirectory;
@property (nonatomic, strong) FTTmpCacheManager *manager;
@property (nonatomic, strong) FTTestSessionOnErrorDataHandler *handler;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation FTTestTmpCacheContext
@end

@interface FTTestFeatureStorageContext : NSObject
@property (nonatomic, strong) FTFeatureStorage *storage;
@property (nonatomic, strong) FTDirectory *grantedDirectory;
@property (nonatomic, strong) FTDirectory *errorSampledDirectory;
@end
@implementation FTTestFeatureStorageContext
@end
#endif

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
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    [FTLog enableLog:YES];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
}
- (void)sdkInitWithRumSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.samplerate = sampleRate;
    rumConfig.sessionOnErrorSampleRate = sessionOnErrorSampleRate;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
}
- (void)sdkInitWithRumSampleRate:(int)sampleRate{
    [self sdkInitWithRumSampleRate:sampleRate sessionOnErrorSampleRate: sampleRate == 100?0:100];
}
/// FT_RUM_SESSION_SAMPLE_RATE == 100
/// FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE == 0
- (void)testSessionOnErrorSampleRate_sampling{
    [self sdkInitWithRumSampleRate:100];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"sampling"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
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
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [FTModelHelper startView:@{@"test":@"unSampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_unSampling" stack:@"testSessionOnErrorSampleRate_unSampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"unSampling"}];
    [self waitForTimeInterval:0.2];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test2" message:@"testSessionOnErrorSampleRate_unSampling2" stack:@"testSessionOnErrorSampleRate_unSampling2"];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    NSMutableSet *errorTimestampSet = [NSMutableSet new];
    [FTModelHelper resolveModelArray:newArray timeCallBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, long long time, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            XCTAssertTrue([errorTimestampSet containsObject:@(time)]);
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
            hasView = YES;
            if (fields[FT_SESSION_ERROR_TIMESTAMP] != nil) {
                [errorTimestampSet addObject:fields[FT_SESSION_ERROR_TIMESTAMP]];
            }
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
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [FTModelHelper startResource:@"111"];
    [FTModelHelper stopErrorResource:@"111"];
    [FTModelHelper addActionWithContext:@{@"test":@"resource_error"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
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
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"error"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasError = YES;
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"error"]);
            XCTAssertTrue([fields[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue] == YES);
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
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[NSDate ft_currentNanosecondTimeStamp]];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} dynamicContext:@{} time:[NSDate ft_currentNanosecondTimeStamp]];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    for (FTRecordModel *model in newArray) {
        XCTAssertTrue([model.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
    }
    XCTAssertTrue(newArray.count - oldArray.count == 2);
}
- (void)testRUMWriterSeparatesPayloadTimeFromRecordTime{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]init];
    long long eventTime = 123;
    long long updateTime = [NSDate ft_currentNanosecondTimeStamp];

    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW
                       tags:@{@"view_id":@"time"}
                     fields:@{@"test":@"cache"}
             dynamicContext:@{}
                       time:eventTime
                 updateTime:updateTime];

    NSArray<FTRecordModel *> *records = [[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM_CACHE];
    FTRecordModel *model = records.firstObject;
    NSDictionary *data = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSNumber *payloadTime = data[FT_OPDATA][FT_TIME];
    XCTAssertEqual(model.tm, updateTime);
    XCTAssertEqual(payloadTime.longLongValue, eventTime);

    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] packageId:@"1" enableIntegerCompatible:NO];
    NSString *lineTime = [[lineStr componentsSeparatedByString:@" "] lastObject];
    XCTAssertEqual(lineTime.longLongValue, eventTime);
}
- (void)testRUMWriterSeparatesPayloadTimeFromRecordTimeForNormalRUM{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]init];
    long long eventTime = 123;
    long long updateTime = [NSDate ft_currentNanosecondTimeStamp];

    [writerManager isCacheWriter:NO];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW
                       tags:@{@"view_id":@"time"}
                     fields:@{@"test":@"normal"}
             dynamicContext:@{}
                       time:eventTime
                 updateTime:updateTime];

    NSArray<FTRecordModel *> *records = [[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_RUM];
    XCTAssertEqual(records.count, 1);
    FTRecordModel *model = records.firstObject;
    NSDictionary *data = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSNumber *payloadTime = data[FT_OPDATA][FT_TIME];
    XCTAssertEqualObjects(model.op, FT_DATA_TYPE_RUM);
    XCTAssertEqual(model.tm, updateTime);
    XCTAssertEqual(payloadTime.longLongValue, eventTime);

    FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
    NSString *lineStr = [line getRequestBodyWithEventArray:@[model] packageId:@"1" enableIntegerCompatible:NO];
    NSString *lineTime = [[lineStr componentsSeparatedByString:@" "] lastObject];
    XCTAssertEqual(lineTime.longLongValue, eventTime);
}
- (void)testRUMWriterKeepsNonViewRecordTimeAsEventTime{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]init];
    long long eventTime = 123;
    long long updateTime = [NSDate ft_currentNanosecondTimeStamp];
    NSArray<NSString *> *sources = @[FT_RUM_SOURCE_ACTION, FT_RUM_SOURCE_ERROR, FT_RUM_SOURCE_LONG_TASK];

    [writerManager isCacheWriter:YES];
    for (NSString *source in sources) {
        [writerManager rumWrite:source
                           tags:@{@"view_id":@"time"}
                         fields:@{@"test":@"cache"}
                 dynamicContext:@{}
                           time:eventTime
                     updateTime:updateTime];
    }

    NSArray<FTRecordModel *> *records = [[FTTrackerEventDBTool sharedManager] getFirstRecords:sources.count withType:FT_DATA_TYPE_RUM_CACHE];
    XCTAssertEqual(records.count, sources.count);
    [records enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL *stop) {
        NSDictionary *data = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *opdata = data[FT_OPDATA];
        NSNumber *payloadTime = opdata[FT_TIME];
        XCTAssertEqualObjects(opdata[FT_KEY_SOURCE], sources[idx]);
        XCTAssertEqual(model.tm, eventTime);
        XCTAssertEqual(payloadTime.longLongValue, eventTime);

        FTRequestLineBody *line = [[FTRequestLineBody alloc]init];
        NSString *lineStr = [line getRequestBodyWithEventArray:@[model] packageId:@"1" enableIntegerCompatible:NO];
        NSString *lineTime = [[lineStr componentsSeparatedByString:@" "] lastObject];
        XCTAssertEqual(lineTime.longLongValue, eventTime);
    }];
}
/// Determine whether the type of data added after calling the -switchCacheWriter method is rum_cache after adding error data
- (void)testSwitchCacheWriter_addErrorDataTurnRUMWriter{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]init];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"cache"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];

    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
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
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];

    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"cache"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:1.5];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.5];
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
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
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.5];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"cache"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    [self waitForTimeInterval:0.5];

    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9];

    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
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
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.1];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"3"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9];

    // Simulate entering a new process and exceeding the time interval
    writerManager.processStartTime = [[[NSDate date] dateByAddingTimeInterval:2] timeIntervalSince1970]*1e9;

    [writerManager checkLastProcessErrorSampled];
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(newArray.count == 3);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray.lastObject.op isEqualToString:FT_DATA_TYPE_RUM_CACHE]);
}
- (void)testSampledErrorSessionDatasConsume_lastProcess_immediately{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];

    // Simulate entering a new process
    writerManager.processStartTime = [[NSDate date] timeIntervalSince1970]*1e9;
    [writerManager checkLastProcessErrorSampled];

    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"3"} fields:@{@"test":@"delete"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9 updateTime:0];

    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
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
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"view_id":@"2"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9];
    [self waitForTimeInterval:0.1];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"3"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[NSDate date] timeIntervalSince1970]*1e9];

    // Simulate entering a new process and exceeding the time interval
    writerManager.processStartTime = [[[NSDate date] dateByAddingTimeInterval:2] timeIntervalSince1970]*1e9;

    [writerManager checkLastProcessErrorSampled];
    [writerManager lastFatalErrorIfFound:0];
    [writerManager checkRUMSessionOnErrorDatasExpired];
    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(newArray.count == 2);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM]);
}
// Test the case where the last process has ANR
- (void)testSampledErrorSessionDatasConsume_lastProcess_has_anr{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    FTDataWriterWorker *writerManager = [[FTDataWriterWorker alloc]initWithCacheInvalidTimeInterval:1];
    [writerManager isCacheWriter:YES];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"1"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"2"} fields:@{@"test":@"delete"} dynamicContext:@{} time:123 updateTime:[[NSDate date] timeIntervalSince1970]*1e9];

    [self waitForTimeInterval:0.5];
    NSDate *date = [NSDate date];
    [writerManager rumWrite:FT_RUM_SOURCE_VIEW tags:@{@"view_id":@"3"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[date dateByAddingTimeInterval:0.6] timeIntervalSince1970]*1e9];

    // Simulate entering a new process and exceeding the time interval
    writerManager.processStartTime = [[date dateByAddingTimeInterval:2] timeIntervalSince1970]*1e9;

    [writerManager checkLastProcessErrorSampled];
    NSArray<FTRecordModel *> *array = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(array.count == 3);
    [writerManager rumWrite:FT_RUM_SOURCE_ERROR tags:@{@"anr":@"anr"} fields:@{@"test":@"normal"} dynamicContext:@{} time:[[date dateByAddingTimeInterval:0.5] timeIntervalSince1970]*1e9 updateTime:0 cache:YES];
    NSArray<FTRecordModel *> *array2 = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(array2.count == 4);
    [writerManager lastFatalErrorIfFound:[[date dateByAddingTimeInterval:0.5] timeIntervalSince1970]*1e9];

    [writerManager checkRUMSessionOnErrorDatasExpired];

    NSArray<FTRecordModel *> *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(newArray.count == 3);
    XCTAssertTrue([newArray.firstObject.op isEqualToString:FT_DATA_TYPE_RUM]);
    XCTAssertTrue([newArray[1].op isEqualToString:FT_DATA_TYPE_RUM]);
}

- (void)testSessionSampleRateUpdate{
    // 1. SampleRate:0 sessionOnErrorSampleRate:100
    [self sdkInitWithRumSampleRate:0 sessionOnErrorSampleRate:100];
    [FTModelHelper startViewWithName:@"FirstView"];
    FTRUMManager *rum = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *session = [rum valueForKey:@"sessionHandler"];

    // -> SampleRate:100 sessionOnErrorSampleRate:0
    [[FTGlobalRumManager sharedInstance] updateSampleRate:100 sessionOnErrorSampleRate:0];
    [rum syncProcess];
    FTRUMSessionHandler *newSession1 = [rum valueForKey:@"sessionHandler"];
    XCTAssertTrue(session != newSession1);

    // -> SampleRate:0 sessionOnErrorSampleRate:0
    [[FTGlobalRumManager sharedInstance] updateSampleRate:0 sessionOnErrorSampleRate:0];
    [rum syncProcess];

    FTRUMSessionHandler *newSession2 = [rum valueForKey:@"sessionHandler"];
    XCTAssertTrue(newSession1 != newSession2);

    // -> SampleRate:0 sessionOnErrorSampleRate:100
    [[FTGlobalRumManager sharedInstance] updateSampleRate:0 sessionOnErrorSampleRate:100];
    [rum syncProcess];

    FTRUMSessionHandler *newSession3 = [rum valueForKey:@"sessionHandler"];
    XCTAssertTrue(newSession2 != newSession3);

    // -> SampleRate:0 sessionOnErrorSampleRate:100
    [[FTGlobalRumManager sharedInstance] updateSampleRate:0 sessionOnErrorSampleRate:100];
    [rum syncProcess];

    FTRUMSessionHandler *newSession4 = [rum valueForKey:@"sessionHandler"];
    XCTAssertTrue(newSession3 == newSession4);

    // -> SampleRate:50 sessionOnErrorSampleRate:100
    [[FTGlobalRumManager sharedInstance] updateSampleRate:50 sessionOnErrorSampleRate:100];
    [rum syncProcess];

    FTRUMSessionHandler *newSession5 = [rum valueForKey:@"sessionHandler"];
    XCTAssertTrue(newSession4 == newSession5);

    // -> SampleRate:50 sessionOnErrorSampleRate:50
    [[FTGlobalRumManager sharedInstance] updateSampleRate:50 sessionOnErrorSampleRate:50];
    [rum syncProcess];

    FTRUMSessionHandler *newSession6 = [rum valueForKey:@"sessionHandler"];
    XCTAssertTrue(newSession5 == newSession6);
}

#if !TARGET_OS_TV
- (FTTestFeatureStorageContext *)sessionReplayStorageContextWithName:(NSString *)name {
    FTTestFeatureStorageContext *context = [[FTTestFeatureStorageContext alloc] init];
    NSString *basePath = [NSString stringWithFormat:@"ft-session-replay-test/%@/%@", name, NSUUID.UUID.UUIDString];
    context.grantedDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:[basePath stringByAppendingPathComponent:@"granted"]];
    context.errorSampledDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:[basePath stringByAppendingPathComponent:@"cache"]];
    FTFeatureDirectories *directories = [[FTFeatureDirectories alloc] initWithGranted:context.grantedDirectory
                                                                              pending:nil
                                                                         errorSampled:context.errorSampledDirectory];
    context.storage = [[FTFeatureStorage alloc] initWithFeatureName:name
                                                              queue:dispatch_queue_create([[NSString stringWithFormat:@"com.ft.test.%@", name] UTF8String], DISPATCH_QUEUE_SERIAL)
                                                        directories:directories
                                                        performance:[[FTPerformancePreset alloc] init]];
    dispatch_sync(context.storage.queue, ^{
    });
    return context;
}

- (void)waitForSessionReplayFeatureAsyncWork:(FTSessionReplayFeature *)feature {
    dispatch_sync(feature.processorsQueue, ^{
    });
}

- (void)waitForSessionReplayFeatureAsyncWork:(FTSessionReplayFeature *)feature storages:(NSArray<FTFeatureStorage *> *)storages {
    [self waitForSessionReplayFeatureAsyncWork:feature];
    for (FTFeatureStorage *storage in storages) {
        [self waitForStorageQueueDrain:storage];
    }
}

- (void)waitForStorageQueueDrain:(FTFeatureStorage *)storage {
    dispatch_sync(storage.queue, ^{
    });
}

- (NSString *)createErrorWindowCacheFileInContext:(FTTestFeatureStorageContext *)context errorTime:(long long)errorTime offsetSeconds:(long long)offsetSeconds {
    return [self createSessionReplayCacheFileInDirectory:context.errorSampledDirectory time:errorTime + offsetSeconds * 1000LL * 1000LL * 1000LL];
}

- (void)sendRumErrorAtTime:(long long)errorTime storages:(NSArray<FTFeatureStorage *> *)storages {
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRumError message:@{@"error_date":@(errorTime)} sync:YES];
    for (FTFeatureStorage *storage in storages) {
        [self waitForStorageQueueDrain:storage];
    }
}

- (FTTestTmpCacheContext *)tmpCacheContextWithName:(NSString *)name {
    FTTestTmpCacheContext *context = [[FTTestTmpCacheContext alloc] init];
    NSString *basePath = [NSString stringWithFormat:@"ft-session-replay-tmp-cache-test/%@/%@", name, NSUUID.UUID.UUIDString];
    FTDirectory *rootDirectory = [[FTDirectory alloc] initWithSubdirectoryPath:basePath];
    context.cacheDirectory = [rootDirectory createSubdirectoryWithPath:@"cache"];
    context.realDirectory = [rootDirectory createSubdirectoryWithPath:@"normal"];
    context.queue = dispatch_queue_create([[NSString stringWithFormat:@"com.ft.test.tmp-cache.%@", name] UTF8String], DISPATCH_QUEUE_SERIAL);
    context.handler = [[FTTestSessionOnErrorDataHandler alloc] init];

    dispatch_suspend(context.queue);
    context.manager = [[FTTmpCacheManager alloc] initWithCacheFileWriter:[[FTTestSessionReplayCacheWriter alloc] init]
                                                          cacheDirectory:context.cacheDirectory
                                                               directory:context.realDirectory
                                                                   queue:context.queue];
    [context.manager setValue:context.handler forKey:@"sessionOnErrorHandler"];
    dispatch_resume(context.queue);
    [self waitForTmpCacheQueueDrain:context];
    return context;
}

- (void)waitForTmpCacheQueueDrain:(FTTestTmpCacheContext *)context {
    dispatch_sync(context.queue, ^{
    });
}

- (NSString *)sessionReplayCacheFileNameForTime:(long long)time {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)time / 1e9];
    return [NSString stringWithFormat:@"%.f", round(date.timeIntervalSinceReferenceDate * 1000)];
}

- (NSString *)createSessionReplayCacheFileInDirectory:(FTDirectory *)directory time:(long long)time {
    NSString *fileName = [self sessionReplayCacheFileNameForTime:time];
    FTFile *file = [directory createFile:fileName];
    [file write:[fileName dataUsingEncoding:NSUTF8StringEncoding]];
    return fileName;
}

- (void)testTmpCacheManagerUploadCleanupOnlyDeletesExpiredFiles {
    FTTestTmpCacheContext *context = [self tmpCacheContextWithName:@"upload-cleanup"];
    long long now = [NSDate ft_currentNanosecondTimeStamp];
    NSString *expiredFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:now - 61LL * 1000LL * 1000LL * 1000LL];
    NSString *recentFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:now - 30LL * 1000LL * 1000LL * 1000LL];
    context.handler.errorTimeLine = now;

    [context.manager cleanup];
    [self waitForTmpCacheQueueDrain:context];

    XCTAssertFalse([context.cacheDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:expiredFile]);
    XCTAssertTrue([context.cacheDirectory hasFileWithName:recentFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:recentFile]);
}

- (void)testTmpCacheManagerCurrentErrorMovesOnlyErrorWindowFiles {
    FTTestTmpCacheContext *context = [self tmpCacheContextWithName:@"current-error"];
    long long errorTime = [NSDate ft_currentNanosecondTimeStamp];
    NSString *expiredFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:errorTime - 61LL * 1000LL * 1000LL * 1000LL];
    NSString *windowFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:errorTime - 30LL * 1000LL * 1000LL * 1000LL];
    NSString *afterErrorFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:errorTime + 1LL * 1000LL * 1000LL * 1000LL];

    [context.manager receive:FTMessageKeyRumError message:@{@"error_date":@(errorTime)}];
    [self waitForTmpCacheQueueDrain:context];

    XCTAssertFalse([context.cacheDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.cacheDirectory hasFileWithName:windowFile]);
    XCTAssertTrue([context.realDirectory hasFileWithName:windowFile]);
    XCTAssertTrue([context.cacheDirectory hasFileWithName:afterErrorFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:afterErrorFile]);
}

- (void)testTmpCacheManagerLastProcessWithoutFatalDeletesPreviousProcessFiles {
    FTTestTmpCacheContext *context = [self tmpCacheContextWithName:@"last-process-no-fatal"];
    long long processStartTime = [[FTDateUtil processStartTimestamp] ft_nanosecondTimeStamp];
    NSString *previousProcessFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:processStartTime - 1LL * 1000LL * 1000LL * 1000LL];
    NSString *currentProcessFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:[NSDate ft_currentNanosecondTimeStamp]];
    context.handler.lastProcessFatalErrorTime = 0;

    [context.manager cleanupLastProcess];
    [self waitForTmpCacheQueueDrain:context];

    XCTAssertFalse([context.cacheDirectory hasFileWithName:previousProcessFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:previousProcessFile]);
    XCTAssertTrue([context.cacheDirectory hasFileWithName:currentProcessFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:currentProcessFile]);
}

- (void)testTmpCacheManagerLastProcessPersistedErrorTimelineMovesOnlyErrorWindowFiles {
    FTTestTmpCacheContext *context = [self tmpCacheContextWithName:@"last-process-error-timeline"];
    long long processStartTime = [[FTDateUtil processStartTimestamp] ft_nanosecondTimeStamp];
    long long errorTime = processStartTime - 30LL * 1000LL * 1000LL * 1000LL;
    NSString *expiredFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:errorTime - 61LL * 1000LL * 1000LL * 1000LL];
    NSString *windowFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:errorTime - 30LL * 1000LL * 1000LL * 1000LL];
    NSString *afterErrorPreviousProcessFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:errorTime + 1LL * 1000LL * 1000LL * 1000LL];
    NSString *currentProcessFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:[NSDate ft_currentNanosecondTimeStamp]];
    context.handler.errorTimeLine = errorTime;
    context.handler.lastProcessFatalErrorTime = 0;

    [context.manager cleanupLastProcess];
    [self waitForTmpCacheQueueDrain:context];

    XCTAssertFalse([context.cacheDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.cacheDirectory hasFileWithName:windowFile]);
    XCTAssertTrue([context.realDirectory hasFileWithName:windowFile]);
    XCTAssertFalse([context.cacheDirectory hasFileWithName:afterErrorPreviousProcessFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:afterErrorPreviousProcessFile]);
    XCTAssertTrue([context.cacheDirectory hasFileWithName:currentProcessFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:currentProcessFile]);
}

- (void)testTmpCacheManagerLastProcessFatalMovesOnlyErrorWindowFiles {
    FTTestTmpCacheContext *context = [self tmpCacheContextWithName:@"last-process-fatal"];
    long long processStartTime = [[FTDateUtil processStartTimestamp] ft_nanosecondTimeStamp];
    long long fatalErrorTime = processStartTime - 30LL * 1000LL * 1000LL * 1000LL;
    NSString *expiredFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:fatalErrorTime - 61LL * 1000LL * 1000LL * 1000LL];
    NSString *windowFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:fatalErrorTime - 30LL * 1000LL * 1000LL * 1000LL];
    NSString *afterErrorPreviousProcessFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:fatalErrorTime + 1LL * 1000LL * 1000LL * 1000LL];
    NSString *currentProcessFile = [self createSessionReplayCacheFileInDirectory:context.cacheDirectory time:[NSDate ft_currentNanosecondTimeStamp]];
    context.handler.lastProcessFatalErrorTime = fatalErrorTime;

    [context.manager cleanupLastProcess];
    [self waitForTmpCacheQueueDrain:context];

    XCTAssertFalse([context.cacheDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:expiredFile]);
    XCTAssertFalse([context.cacheDirectory hasFileWithName:windowFile]);
    XCTAssertTrue([context.realDirectory hasFileWithName:windowFile]);
    XCTAssertFalse([context.cacheDirectory hasFileWithName:afterErrorPreviousProcessFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:afterErrorPreviousProcessFile]);
    XCTAssertTrue([context.cacheDirectory hasFileWithName:currentProcessFile]);
    XCTAssertFalse([context.realDirectory hasFileWithName:currentProcessFile]);
}

- (void)testSessionReplayRecordingStartsForErrorSampleState{
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:[[FTSessionReplayConfig alloc] init]];
    FTTestSessionReplayScheduler *scheduler = [[FTTestSessionReplayScheduler alloc] init];
    feature.scheduler = scheduler;
    feature.sampleState = SampleStateError;

    [feature startRecording];

    XCTAssertEqual(scheduler.startCount, 1);
    XCTAssertEqual(scheduler.stopCount, 0);
}

- (void)testSessionReplayRecordingStopsForNoneSampleState{
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:[[FTSessionReplayConfig alloc] init]];
    FTTestSessionReplayScheduler *scheduler = [[FTTestSessionReplayScheduler alloc] init];
    feature.scheduler = scheduler;
    feature.sampleState = SampleStateError;
    [feature startRecording];

    feature.sampleState = SampleStateNone;
    [feature evaluateRecordingConditions];

    XCTAssertEqual(scheduler.startCount, 1);
    XCTAssertEqual(scheduler.stopCount, 1);
}

- (void)testFeatureStorageUpdatesCacheWriterActiveStateForTrackingConsent{
    FTTestFeatureStorageContext *context = [self sessionReplayStorageContextWithName:@"session-replay-storage"];
    XCTAssertNotNil(context.storage.cacheWriter);

    long long activeErrorTime = [NSDate ft_currentNanosecondTimeStamp];
    NSString *activeWindowFile = [self createErrorWindowCacheFileInContext:context errorTime:activeErrorTime offsetSeconds:-30];
    [context.storage updateTrackingConsent:FTTrackingConsentErrorSampled];
    [self waitForStorageQueueDrain:context.storage];
    [self sendRumErrorAtTime:activeErrorTime storages:@[context.storage]];
    XCTAssertFalse([context.errorSampledDirectory hasFileWithName:activeWindowFile]);
    XCTAssertTrue([context.grantedDirectory hasFileWithName:activeWindowFile]);

    long long inactiveErrorTime = activeErrorTime + 2LL * 1000LL * 1000LL * 1000LL;
    NSString *inactiveWindowFile = [self createErrorWindowCacheFileInContext:context errorTime:inactiveErrorTime offsetSeconds:-30];
    [context.storage updateTrackingConsent:FTTrackingConsentGranted];
    [self waitForStorageQueueDrain:context.storage];
    [self sendRumErrorAtTime:inactiveErrorTime storages:@[context.storage]];
    XCTAssertTrue([context.errorSampledDirectory hasFileWithName:inactiveWindowFile]);
    XCTAssertFalse([context.grantedDirectory hasFileWithName:inactiveWindowFile]);
}

- (void)testFeatureStorageRegistersCacheWriterBeforeReturningErrorSampledWriter{
    FTTestFeatureStorageContext *context = [self sessionReplayStorageContextWithName:@"session-replay-register-before-return"];
    long long errorTime = [NSDate ft_currentNanosecondTimeStamp];
    NSString *windowFile = [self createErrorWindowCacheFileInContext:context errorTime:errorTime offsetSeconds:-30];

    dispatch_suspend(context.storage.queue);
    id<FTWriter> writer = [context.storage writerForTrackingConsent:FTTrackingConsentErrorSampled];
    XCTAssertNotNil(writer);
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRumError message:@{@"error_date":@(errorTime)} sync:YES];
    dispatch_resume(context.storage.queue);
    [self waitForStorageQueueDrain:context.storage];

    XCTAssertFalse([context.errorSampledDirectory hasFileWithName:windowFile]);
    XCTAssertTrue([context.grantedDirectory hasFileWithName:windowFile]);
    [context.storage updateTrackingConsent:FTTrackingConsentGranted];
}

- (void)testFeatureStorageWebViewGrantedWriterUsesWebPrefix{
    FTTestFeatureStorageContext *context = [self sessionReplayStorageContextWithName:@"session-replay-web-granted-prefix"];
    id<FTWriter> writer = [context.storage webViewWriterForTrackingConsent:FTTrackingConsentGranted];

    [writer write:[@"web-granted" dataUsingEncoding:NSUTF8StringEncoding] forceNewFile:YES];
    [self waitForStorageQueueDrain:context.storage];

    NSArray<FTFile *> *files = context.grantedDirectory.files;
    XCTAssertEqual(files.count, 1);
    NSString *fileName = files.firstObject.url.lastPathComponent;
    XCTAssertTrue([fileName hasPrefix:@"w_"], @"fileName:%@", fileName);
}

- (void)testFeatureStorageWebViewErrorSampledWriterUsesWebPrefix{
    FTTestFeatureStorageContext *context = [self sessionReplayStorageContextWithName:@"session-replay-web-cache-prefix"];
    id<FTWriter> writer = [context.storage webViewWriterForTrackingConsent:FTTrackingConsentErrorSampled];

    [writer write:[@"web-error-sampled" dataUsingEncoding:NSUTF8StringEncoding] forceNewFile:YES];
    [self waitForStorageQueueDrain:context.storage];

    NSArray<FTFile *> *files = context.errorSampledDirectory.files;
    XCTAssertEqual(files.count, 1);
    NSString *fileName = files.firstObject.url.lastPathComponent;
    XCTAssertTrue([fileName hasPrefix:@"w_"], @"fileName:%@", fileName);
    [context.storage updateTrackingConsent:FTTrackingConsentGranted];
}

- (void)testSessionReplaySampleRateUpdateTogglesRecordAndResourceCacheWriters{
    FTSessionReplayConfig *config = [[FTSessionReplayConfig alloc] init];
    config.sampleRate = 0;
    config.sessionReplayOnErrorSampleRate = 100;
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc] initWithConfig:config];
    FTTestFeatureStorageContext *recordContext = [self sessionReplayStorageContextWithName:@"session-replay-record"];
    FTTestFeatureStorageContext *resourceContext = [self sessionReplayStorageContextWithName:@"session-replay-resource"];
    [feature startWithRecordStorage:recordContext.storage resourceStorage:resourceContext.storage resourceDataStore:nil];

    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRUMContext message:@{
        FT_RUM_KEY_SESSION_ID:[NSUUID UUID].UUIDString
    } sync:YES];
    [self waitForSessionReplayFeatureAsyncWork:feature storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertEqual(feature.sampleState, SampleStateError);
    long long errorSampledTime = [NSDate ft_currentNanosecondTimeStamp];
    NSString *recordErrorFile = [self createErrorWindowCacheFileInContext:recordContext errorTime:errorSampledTime offsetSeconds:-30];
    NSString *resourceErrorFile = [self createErrorWindowCacheFileInContext:resourceContext errorTime:errorSampledTime offsetSeconds:-30];
    [self sendRumErrorAtTime:errorSampledTime storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertTrue([recordContext.grantedDirectory hasFileWithName:recordErrorFile]);
    XCTAssertTrue([resourceContext.grantedDirectory hasFileWithName:resourceErrorFile]);

    FTRemoteConfigModel *model = [[FTRemoteConfigModel alloc] init];
    model.sessionReplaySampleRate = @(1);
    model.sessionReplayOnErrorSampleRate = @(1);
    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    [self waitForSessionReplayFeatureAsyncWork:feature storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertEqual(feature.sampleState, SampleStateNormal);
    long long grantedTime = errorSampledTime + 2LL * 1000LL * 1000LL * 1000LL;
    NSString *recordGrantedFile = [self createErrorWindowCacheFileInContext:recordContext errorTime:grantedTime offsetSeconds:-30];
    NSString *resourceGrantedFile = [self createErrorWindowCacheFileInContext:resourceContext errorTime:grantedTime offsetSeconds:-30];
    [self sendRumErrorAtTime:grantedTime storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertTrue([recordContext.errorSampledDirectory hasFileWithName:recordGrantedFile]);
    XCTAssertTrue([resourceContext.errorSampledDirectory hasFileWithName:resourceGrantedFile]);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(0);
    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    [self waitForSessionReplayFeatureAsyncWork:feature storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertEqual(feature.sampleState, SampleStateNone);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(1);
    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    [self waitForSessionReplayFeatureAsyncWork:feature storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertEqual(feature.sampleState, SampleStateError);
    long long secondErrorSampledTime = errorSampledTime + 4LL * 1000LL * 1000LL * 1000LL;
    NSString *recordSecondErrorFile = [self createErrorWindowCacheFileInContext:recordContext errorTime:secondErrorSampledTime offsetSeconds:-30];
    NSString *resourceSecondErrorFile = [self createErrorWindowCacheFileInContext:resourceContext errorTime:secondErrorSampledTime offsetSeconds:-30];
    [self sendRumErrorAtTime:secondErrorSampledTime storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertTrue([recordContext.grantedDirectory hasFileWithName:recordSecondErrorFile]);
    XCTAssertTrue([resourceContext.grantedDirectory hasFileWithName:resourceSecondErrorFile]);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(0);
    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    [self waitForSessionReplayFeatureAsyncWork:feature storages:@[recordContext.storage, resourceContext.storage]];
    XCTAssertEqual(feature.sampleState, SampleStateNone);
}

- (void)testSessionReplaySampleRateUpdate{

    FTSessionReplayConfig *config = [[FTSessionReplayConfig alloc]init];
    config.sampleRate = 0;
    config.sessionReplayOnErrorSampleRate = 100;
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc]initWithConfig:config];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRUMContext message:@{FT_RUM_KEY_SESSION_ID:[NSUUID UUID].UUIDString} sync:YES];

    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateError);


    FTRemoteConfigModel *model =  [[FTRemoteConfigModel alloc]init];
    model.sessionReplaySampleRate = @(1);
    model.sessionReplayOnErrorSampleRate = @(1);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateNormal);

    model.sessionReplaySampleRate = @(0.5);
    model.sessionReplayOnErrorSampleRate = @(1);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateNormal);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(0);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateNone);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(1);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateError);
}

- (void)testSessionReplaySampleRateUpdate_rumSessionOnError{
    FTSessionReplayConfig *config = [[FTSessionReplayConfig alloc]init];
    config.sampleRate = 0;
    config.sessionReplayOnErrorSampleRate = 100;
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc]initWithConfig:config];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRUMContext message:@{
        FT_RUM_KEY_SESSION_ID:[NSUUID UUID].UUIDString,
        FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION:@(YES)} sync:YES];

    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateError);

    FTRemoteConfigModel *model =  [[FTRemoteConfigModel alloc]init];
    model.sessionReplaySampleRate = @(1);
    model.sessionReplayOnErrorSampleRate = @(1);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateError);

    model.sessionReplaySampleRate = @(0.5);
    model.sessionReplayOnErrorSampleRate = @(1);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateError);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(0);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateNone);

    model.sessionReplaySampleRate = @(0);
    model.sessionReplayOnErrorSampleRate = @(1);

    [[FTRemoteConfigManager sharedInstance] setLastRemoteModel:model];
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeySRSampleRateUpdate message:@{} sync:YES];
    dispatch_sync(feature.processorsQueue, ^{});
    XCTAssertTrue(feature.sampleState == SampleStateError);

}
#endif
@end
