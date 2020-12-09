//
//  MonitorManagerTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/24.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMonitorManager.h"
#import "FTConstants.h"
#import <CoreMotion/CoreMotion.h>

@interface FTMonitorManagerTest : XCTestCase

@end

@implementation FTMonitorManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
///**
// 测试 FTMonitorInfoType 是否按类型抓取
// */
//-(void)testFTMonitorInfoTypeAll{
//    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
//    
//    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeAll];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self monitorInfoType:FTMonitorInfoTypeAll];
//        [expect fulfill];
//    });
//    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
//        XCTAssertNil(error);
//    }];}
//- (void)testFTMonitorInfoTypeMemory{
//    [self monitorInfoType:FTMonitorInfoTypeMemory];
//}
//-(void)testMangerSetMonitorInfoTypeBattery{
//    [self monitorInfoType:FTMonitorInfoTypeBattery];
//}
//-(void)testFTMonitorInfoTypeCpu{
//    [self monitorInfoType:FTMonitorInfoTypeCpu];
//}
//
//- (void)testFTMonitorInfoTypeBluetooth{
//    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
//    
//    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeBluetooth];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self monitorInfoType:FTMonitorInfoTypeBluetooth];
//        [expect fulfill];
//    });
//    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
//        XCTAssertNil(error);
//    }];
//    
//}
//- (void)testFTMonitorInfoTypeSensorBrightness{
//    [self monitorInfoType:FTMonitorInfoTypeSensorBrightness];
//}
//- (void)testFTMonitorInfoTypeSensorStep{
//    [self monitorInfoType:FTMonitorInfoTypeSensorStep];
//}
//- (void)testFTMonitorInfoTypeSensorProximity{
//    [self monitorInfoType:FTMonitorInfoTypeSensorProximity];
//}
//- (void)testFTMonitorInfoTypeSensorRotation{
//    [self monitorInfoType:FTMonitorInfoTypeSensorRotation];
//}
//- (void)testFTMonitorInfoTypeSensorAcceleration{
//    [self monitorInfoType:FTMonitorInfoTypeSensorAcceleration];
//}
//- (void)testFTMonitorInfoTypeSensorMagnetic{
//    [self monitorInfoType:FTMonitorInfoTypeSensorMagnetic];
//}
//- (void)testFTMonitorInfoTypeSensorLight{
//    [self monitorInfoType:FTMonitorInfoTypeSensorLight];
//}
//- (void)testFTMonitorInfoTypeSensorTorch{
//    [self monitorInfoType:FTMonitorInfoTypeSensorTorch];
//}
//- (void)testFTMonitorInfoTypeFPS{
//    [self monitorInfoType:FTMonitorInfoTypeFPS];
//}
//-(void)testMangerChangeMonitorType{
//    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeAll];
//    NSDictionary *dict =  [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
//    NSDictionary *field =  [dict valueForKey:FT_AGENT_FIELD];
//    
//    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeFPS];
//    
//    NSDictionary *dict2 =  [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
//    NSDictionary *field2 =  [dict2 valueForKey:FT_AGENT_FIELD];
//    
//    XCTAssertTrue([field2.allKeys containsObject:FT_MONITOR_FPS] && field.allKeys.count > field2.allKeys.count);
//    
//}
//

@end
