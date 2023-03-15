//
//  FTRUMMonitorTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/7/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import "FTMobileAgent+Private.h"
#import "FTTrackDataManager+Test.h"
#import "FTDateUtil.h"
#import "FTTrackerEventDBTool.h"
#import "FTModelHelper.h"
#import "FTRecordModel.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
@interface FTRUMMonitorTest : KIFTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, copy) NSString *track_id;
@end

@implementation FTRUMMonitorTest

- (void)setUp {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    self.track_id = [processInfo environment][@"TRACK_ID"];
}

- (void)tearDown {
    
}
- (void)shutDownSDK{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testNoneMonitor{
    [self setRumMonitorNone];
    [FTModelHelper startView];
    [NSThread sleepForTimeInterval:1];
    [FTModelHelper addAction];
    [FTModelHelper addAction];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newDatas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            XCTAssertFalse([fields.allKeys containsObject:FT_FPS_MINI]);
            XCTAssertFalse([fields.allKeys containsObject:FT_FPS_AVG]);
            XCTAssertFalse([fields.allKeys containsObject:FT_MEMORY_MAX]);
            XCTAssertFalse([fields.allKeys containsObject:FT_MEMORY_AVG]);
            XCTAssertFalse([fields.allKeys containsObject:FT_CPU_TICK_COUNT]);
            XCTAssertFalse([fields.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorCpu{
    [self setRumMonitorType:FTDeviceMetricsMonitorCpu];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    [FTModelHelper addAction];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    [tester waitForTimeInterval:1];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [tester waitForTimeInterval:1];
    [FTModelHelper addAction];
    [FTModelHelper addAction];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newDatas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            XCTAssertTrue([fields.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT]);
            NSNumber *tickCount = fields[FT_CPU_TICK_COUNT];
            NSNumber *tickCountPerSecond = fields[FT_CPU_TICK_COUNT_PER_SECOND];
            XCTAssertTrue(tickCount.doubleValue < 10000);
            XCTAssertTrue(tickCountPerSecond.doubleValue < 1000);
            XCTAssertFalse([fields.allKeys containsObject:FT_FPS_MINI]&&[fields.allKeys containsObject:FT_FPS_AVG]&&[fields.allKeys containsObject:FT_MEMORY_MAX]&&[fields.allKeys containsObject:FT_MEMORY_AVG]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorMemory{
    [self setRumMonitorType:FTDeviceMetricsMonitorMemory];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    [FTModelHelper addAction];
    [FTModelHelper addAction];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newDatas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            XCTAssertTrue([fields.allKeys containsObject:FT_MEMORY_MAX]&&[fields.allKeys containsObject:FT_MEMORY_AVG]);
            XCTAssertFalse([fields.allKeys containsObject:FT_FPS_MINI]&&[fields.allKeys containsObject:FT_FPS_AVG]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorFPS{
    [self setRumMonitorType:FTDeviceMetricsMonitorFps];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    [FTModelHelper addAction];
    [FTModelHelper addAction];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newDatas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            NSLog(@"field:%@\n",fields);
            XCTAssertTrue([fields.allKeys containsObject:FT_FPS_MINI]&&[fields.allKeys containsObject:FT_FPS_AVG]);
            XCTAssertFalse([fields.allKeys containsObject:FT_MEMORY_MAX]&&[fields.allKeys containsObject:FT_MEMORY_AVG]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorAll{
    [self setRumMonitorType:FTDeviceMetricsMonitorAll];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    [FTModelHelper addAction];
    [FTModelHelper addAction];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newDatas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            XCTAssertTrue([fields.allKeys containsObject:FT_FPS_MINI]);
            XCTAssertTrue([fields.allKeys containsObject:FT_FPS_AVG]);
            XCTAssertTrue([fields.allKeys containsObject:FT_MEMORY_MAX]);
            XCTAssertTrue([fields.allKeys containsObject:FT_MEMORY_AVG]);
            XCTAssertTrue([fields.allKeys containsObject:FT_CPU_TICK_COUNT]);
            XCTAssertTrue([fields.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorFrequencyDefault{
    [self setMonitorFrequency:FTMonitorFrequencyDefault];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *sessionHandler = [rumManager valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[sessionHandler valueForKey:@"viewHandlers"] lastObject];
    FTMonitorItem *item = [view valueForKey:@"monitorItem"];
    int count = [item cpu].sampleValueCount;
    [tester waitForTimeInterval:1];
    int newCount = [item cpu].sampleValueCount;
    XCTAssertTrue(newCount-count >= 2 && (newCount-count)<4);
    [self shutDownSDK];
}
- (void)testMonitorFrequencyRare{
    [self setMonitorFrequency:FTMonitorFrequencyRare];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *sessionHandler = [rumManager valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[sessionHandler valueForKey:@"viewHandlers"] lastObject];
    FTMonitorItem *item = [view valueForKey:@"monitorItem"];
    int count = [item cpu].sampleValueCount;
    [tester waitForTimeInterval:1];
    int newCount = [item cpu].sampleValueCount;
    XCTAssertTrue(newCount-count >= 1 && newCount-count<3);
    [self shutDownSDK];
}
- (void)testMonitorFrequencyFrequent{
    [self setMonitorFrequency:FTMonitorFrequencyFrequent];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManager;
    FTRUMSessionHandler *sessionHandler = [rumManager valueForKey:@"sessionHandler"];
    FTRUMViewHandler *view = [[sessionHandler valueForKey:@"viewHandlers"] lastObject];
    FTMonitorItem *item = [view valueForKey:@"monitorItem"];
    int count = [item cpu].sampleValueCount;
    [tester waitForTimeInterval:1];
    int newCount = [item cpu].sampleValueCount;
    XCTAssertTrue(newCount-count >= 10 && newCount-count<12);
    [self shutDownSDK];
}
- (void)testMonitorValueScale{
    FTMonitorValue *value = [[FTMonitorValue alloc]init];
    for (int i = 1; i<=10; i++) {
        [value addSample:i];
    }
    XCTAssertTrue(value.maxValue == 10);
    XCTAssertTrue(value.minValue == 1);
    XCTAssertTrue(value.meanValue == 5.5);
    XCTAssertTrue(value.sampleValueCount == 10);
    XCTAssertTrue(value.greatestDiff == 9);
    FTMonitorValue *newValue = [value scaledDown:2];
    XCTAssertTrue(newValue.maxValue == 5);
}
- (void)setRumMonitorNone{
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
- (void)setRumMonitorType:(FTDeviceMetricsMonitorType)type{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.deviceMetricsMonitorType = type;
    rumConfig.monitorFrequency = FTMonitorFrequencyFrequent;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)setMonitorFrequency:(FTMonitorFrequency)frequency{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.deviceMetricsMonitorType = FTDeviceMetricsMonitorAll;
    rumConfig.monitorFrequency = frequency;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
@end
