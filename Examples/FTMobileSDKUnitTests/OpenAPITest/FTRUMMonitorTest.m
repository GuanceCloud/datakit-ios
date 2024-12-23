//
//  FTRUMMonitorTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/7/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <KIF/KIF.h>
#import "FTMobileAgent+Private.h"
#import "NSDate+FTUtil.h"
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
#import "FTCPUMonitor.h"
#import "FTMemoryMonitor.h"
#import "FTDisplayRateMonitor.h"
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
    [FTMobileAgent shutDown];
}
- (void)testNoneMonitor{
    [self setRumMonitorNone];
    [FTModelHelper startView];
    [NSThread sleepForTimeInterval:0.5];
    [FTModelHelper startAction];
    [FTModelHelper startAction];
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
- (void)testMonitorAll{
    [self setRumMonitorType:FTDeviceMetricsMonitorAll];
    [FTModelHelper startView];
    [tester waitForTimeInterval:1.5];
    [FTModelHelper startAction];
    [FTModelHelper startAction];
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
- (void)testMonitorMemory{
    FTMemoryMonitor *memoryMonitor = [[FTMemoryMonitor alloc]init];
    double memoryUsage = [memoryMonitor memoryUsage];
    __weak typeof(self) weakSelf = self;
    __block double heavyMemoryUsage;
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"Memory Test"];
    NSThread *thread = [[NSThread alloc]initWithBlock:^{
        @autoreleasepool {
            [weakSelf heavyWork];
            NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"]];
            heavyMemoryUsage = [memoryMonitor memoryUsage];
            data = nil;
        }
            [expectation fulfill];
        
    }];
    [thread start];
    [self waitForExpectations:@[expectation] timeout:10];
    [thread cancel];
    double deallocMemoryUsage = [memoryMonitor memoryUsage];
    XCTAssertGreaterThan(heavyMemoryUsage, memoryUsage);
    XCTAssertTrue(heavyMemoryUsage>=deallocMemoryUsage);
}
- (void)testMonitorFPS{
    [self setRumMonitorType:FTDeviceMetricsMonitorFps];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [FTModelHelper startView];
    [tester waitForTimeInterval:0.5];
    [FTModelHelper startAction];
    [FTModelHelper startAction];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newDatas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            XCTAssertTrue([fields.allKeys containsObject:FT_FPS_MINI]&&[fields.allKeys containsObject:FT_FPS_AVG]);
            XCTAssertFalse([fields.allKeys containsObject:FT_MEMORY_MAX]&&[fields.allKeys containsObject:FT_MEMORY_AVG]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT]&&[fields.allKeys containsObject:FT_CPU_TICK_COUNT_PER_SECOND]);
            *stop = YES;
        }
    }];
    [self shutDownSDK];
}
- (void)testMonitorCpuIgnoreResignActive{
    FTCPUMonitor *cpuMonitor = [[FTCPUMonitor alloc]init];
    double baseUsage = [cpuMonitor readCpuUsage];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    [self heavyWork];
    double resignActiveUsage = [cpuMonitor readCpuUsage];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self heavyWork];
    double activeUsage = [cpuMonitor readCpuUsage];
    XCTAssertEqual(resignActiveUsage, baseUsage);
    XCTAssertGreaterThan(activeUsage-resignActiveUsage, resignActiveUsage-baseUsage);
}
- (void)testMonitorFrequencyDefault{
    FTMonitorItem *item = [[FTMonitorItem alloc]initWithCpuMonitor:[FTCPUMonitor new] memoryMonitor:[FTMemoryMonitor new] displayRateMonitor:[FTDisplayRateMonitor new] frequency:MonitorFrequencyMap[FTMonitorFrequencyDefault]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"expectation"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertEqual(item.cpu.sampleValueCount, 2);
    XCTAssertEqual(item.memory.sampleValueCount, 2);
}
- (void)testMonitorFrequencyRare{
    FTMonitorItem *item = [[FTMonitorItem alloc]initWithCpuMonitor:[FTCPUMonitor new] memoryMonitor:[FTMemoryMonitor new] displayRateMonitor:[FTDisplayRateMonitor new] frequency:MonitorFrequencyMap[FTMonitorFrequencyRare]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"expectation"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertEqual(item.cpu.sampleValueCount, 2);
    XCTAssertEqual(item.memory.sampleValueCount, 2);
}
- (void)testMonitorFrequencyFrequent{
    FTMonitorItem *item = [[FTMonitorItem alloc]initWithCpuMonitor:[FTCPUMonitor new] memoryMonitor:[FTMemoryMonitor new] displayRateMonitor:[FTDisplayRateMonitor new] frequency:MonitorFrequencyMap[FTMonitorFrequencyFrequent]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc]initWithDescription:@"expectation"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertEqual(item.cpu.sampleValueCount, 7);
    XCTAssertEqual(item.memory.sampleValueCount, 7);
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
- (void)heavyWork{
    NSTimeInterval time = 1.0;
    NSDate *date = [NSDate date];
    while ([[NSDate new] timeIntervalSinceDate:date] <= time) {
        for (int i=0; i<1000000; i++) {
            NSMutableArray *array = [[NSMutableArray alloc]init];
            [array addObject:@1];
            [array addObject:@2];
            [array addObject:@3];
        }
    }
}
- (void)setRumMonitorNone{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
- (void)setRumMonitorType:(FTDeviceMetricsMonitorType)type{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.deviceMetricsMonitorType = type;
    rumConfig.monitorFrequency = FTMonitorFrequencyFrequent;
    [FTMobileAgent startWithConfigOptions:config];
    
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
@end
