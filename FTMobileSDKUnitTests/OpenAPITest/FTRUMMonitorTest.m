//
//  FTRUMMonitorTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/7/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "FTTrackDataManger+Test.h"
#import <FTDateUtil.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import "FTModelHelper.h"
#import <FTRecordModel.h>
#import <FTConstants.h>
#import <FTJSONUtil.h>
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTLog.h"
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
    [NSThread sleepForTimeInterval:2];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testNoneMonitor{
    [self setRumMonitorNone];
    [FTModelHelper startView];
    [NSThread sleepForTimeInterval:1];
    [FTModelHelper addAction];
    [FTModelHelper addAction];
    [NSThread sleepForTimeInterval:2];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            NSDictionary *field = opdata[FT_FIELDS];
            XCTAssertFalse([field.allKeys containsObject:FT_FPS_MINI]&&[field.allKeys containsObject:FT_FPS_AVG]&&[field.allKeys containsObject:FT_MEMORY_MAX]&&[field.allKeys containsObject:FT_MEMORY_AVG]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
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
    [tester waitForTimeInterval:2];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        ZYDebug(@"op：%@\ndict:%@",op,dict);
        XCTAssertTrue([op isEqualToString:FT_DATA_TYPE_RUM]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            NSDictionary *field = opdata[FT_FIELDS];
            XCTAssertTrue([field.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT]);
            NSNumber *tickCount = field[FT_CPU_TICK_COUNT];
            NSNumber *tickCountPerSecond = field[FT_CPU_TICK_COUNT_PER_SECOND];
            XCTAssertTrue(tickCount.doubleValue < 10000);
            XCTAssertTrue(tickCountPerSecond.doubleValue < 1000);
            XCTAssertFalse([field.allKeys containsObject:FT_FPS_MINI]&&[field.allKeys containsObject:FT_FPS_AVG]&&[field.allKeys containsObject:FT_MEMORY_MAX]&&[field.allKeys containsObject:FT_MEMORY_AVG]);
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
    [tester waitForTimeInterval:2];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            NSDictionary *field = opdata[FT_FIELDS];
            XCTAssertTrue([field.allKeys containsObject:FT_MEMORY_MAX]&&[field.allKeys containsObject:FT_MEMORY_AVG]);
            XCTAssertFalse([field.allKeys containsObject:FT_FPS_MINI]&&[field.allKeys containsObject:FT_FPS_AVG]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
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
    [tester waitForTimeInterval:2];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            NSDictionary *field = opdata[FT_FIELDS];
            ZYDebug(@"field:%@\n",field);
            XCTAssertTrue([field.allKeys containsObject:FT_FPS_MINI]&&[field.allKeys containsObject:FT_FPS_AVG]);
            XCTAssertFalse([field.allKeys containsObject:FT_MEMORY_MAX]&&[field.allKeys containsObject:FT_MEMORY_AVG]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
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
    [tester waitForTimeInterval:2];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [newDatas enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"source"];
        if ([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]) {
            NSDictionary *field = opdata[FT_FIELDS];
            XCTAssertTrue([field.allKeys containsObject:FT_FPS_MINI]&&[field.allKeys containsObject:FT_FPS_AVG]&&[field.allKeys containsObject:FT_MEMORY_MAX]&&[field.allKeys containsObject:FT_MEMORY_AVG]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT]&&[field.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorFrequencyDefault{
    [self setMonitorFrequency:FTMonitorFrequencyDefault];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1];
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManger;
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
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManger;
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
    FTRUMManager *rumManager = [FTGlobalRumManager sharedInstance].rumManger;
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
