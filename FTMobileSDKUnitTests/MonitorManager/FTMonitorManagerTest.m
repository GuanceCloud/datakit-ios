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
#define WAIT                                                                \
do {                                                                        \
[self expectationForNotification:@"LCUnitTest" object:nil handler:nil]; \
[self waitForExpectationsWithTimeout:10 handler:nil];                   \
} while(0);
#define NOTIFY                                                                            \
do {                                                                                      \
[[NSNotificationCenter defaultCenter] postNotificationName:@"LCUnitTest" object:nil]; \
} while(0);
@interface FTMonitorManagerTest : XCTestCase

@end

@implementation FTMonitorManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
/**
 测试 FTMonitorInfoType 是否按类型抓取
 */
-(void)testFTMonitorInfoTypeAll{
    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeAll];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           [self monitorInfoType:FTMonitorInfoTypeAll];
           NOTIFY
       });
       WAIT
}
- (void)testFTMonitorInfoTypeMemory{
    [self monitorInfoType:FTMonitorInfoTypeMemory];
}
-(void)testMangerSetMonitorInfoTypeBattery{
    [self monitorInfoType:FTMonitorInfoTypeBattery];
}
-(void)testFTMonitorInfoTypeCpu{
    [self monitorInfoType:FTMonitorInfoTypeCpu];
}
-(void)testFTMonitorInfoTypeGpu{
    [self monitorInfoType:FTMonitorInfoTypeGpu];
}
- (void)testFTMonitorInfoTypeNetwork{
    [self monitorInfoType:FTMonitorInfoTypeNetwork];
}
- (void)testFTMonitorInfoTypeCamera{
    [self monitorInfoType:FTMonitorInfoTypeCamera];
}
- (void)testFTMonitorInfoTypeLocation{
    [self monitorInfoType:FTMonitorInfoTypeLocation];
}
- (void)testFTMonitorInfoTypeSystem{
    [self monitorInfoType:FTMonitorInfoTypeSystem];
}
- (void)testFTMonitorInfoTypeSensor{
    [self monitorInfoType:FTMonitorInfoTypeSensor];
}
- (void)testFTMonitorInfoTypeBluetooth{
    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeBluetooth];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self monitorInfoType:FTMonitorInfoTypeBluetooth];
        NOTIFY
    });
    WAIT
}
- (void)testFTMonitorInfoTypeSensorBrightness{
    [self monitorInfoType:FTMonitorInfoTypeSensorBrightness];
}
- (void)testFTMonitorInfoTypeSensorStep{
    [self monitorInfoType:FTMonitorInfoTypeSensorStep];
}
- (void)testFTMonitorInfoTypeSensorProximity{
    [self monitorInfoType:FTMonitorInfoTypeSensorProximity];
}
- (void)testFTMonitorInfoTypeSensorRotation{
    [self monitorInfoType:FTMonitorInfoTypeSensorRotation];
}
- (void)testFTMonitorInfoTypeSensorAcceleration{
    [self monitorInfoType:FTMonitorInfoTypeSensorAcceleration];
}
- (void)testFTMonitorInfoTypeSensorMagnetic{
    [self monitorInfoType:FTMonitorInfoTypeSensorMagnetic];
}
- (void)testFTMonitorInfoTypeSensorLight{
    [self monitorInfoType:FTMonitorInfoTypeSensorLight];
}
- (void)testFTMonitorInfoTypeSensorTorch{
    [self monitorInfoType:FTMonitorInfoTypeSensorTorch];
}
- (void)testFTMonitorInfoTypeFPS{
    [self monitorInfoType:FTMonitorInfoTypeFPS];
}
-(void)monitorInfoType:(FTMonitorInfoType)type{
    [[FTMonitorManager sharedInstance] setMonitorType:type];
    
    NSDictionary *dict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    NSDictionary *field =  [dict valueForKey:FT_AGENT_FIELD];
    NSDictionary *tag =  [dict valueForKey:FT_AGENT_TAGS];
    if(type & FTMonitorInfoTypeMemory ){
        XCTAssertTrue([tag.allKeys containsObject:@"memory_total"]);
    }
    if(type & FTMonitorInfoTypeBattery){
        XCTAssertTrue([tag.allKeys containsObject:FT_MONITOR_BATTERY_TOTAL]&&[field.allKeys containsObject:FT_MONITOR_BATTERY_USE] && [tag.allKeys containsObject:FT_MONITOR_BATTERY_STATUS]);
    }
    if(type & FTMonitorInfoTypeCpu ){
        XCTAssertTrue([tag.allKeys containsObject:@"cpu_no"]);
    }
    if(type & FTMonitorInfoTypeGpu ){
        XCTAssertTrue([tag.allKeys containsObject:FT_MONITOR_GPU_MODEL] && [field.allKeys containsObject:FT_MONITOR_GPU_RATE]);
    }
    if(type & FTMonitorInfoTypeNetwork ){
        XCTAssertTrue([tag.allKeys containsObject:@"network_type"]);
    }
    if(type & FTMonitorInfoTypeCamera ){
        XCTAssertTrue([tag.allKeys containsObject:@"camera_front_px"]);
    }
    if(type & FTMonitorInfoTypeLocation ){
        XCTAssertTrue([tag.allKeys containsObject:@"city"]);
    }
    if (type & FTMonitorInfoTypeSystem) {
        XCTAssertTrue([tag.allKeys containsObject:FT_MONITOR_DEVICE_NAME]);
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_DEVICE_OPEN_TIME]);
    }
    CMMotionManager *motionManager  = [[CMMotionManager alloc]init];
    if (type & FTMonitorInfoTypeSensor) {
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_SCREEN_BRIGHTNESS]);
        if ([CMPedometer isStepCountingAvailable]) {
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_STEPS]);
        }
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_PROXIMITY]);
        if([motionManager isGyroAvailable]){
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_ROTATION_X] &&[field.allKeys containsObject:FT_MONITOR_ROTATION_Y] && [field.allKeys containsObject:FT_MONITOR_ROTATION_Z]);
        }
        if ([motionManager isAccelerometerAvailable]) {
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_ACCELERATION_X] &&[field.allKeys containsObject:FT_MONITOR_ACCELERATION_Y] && [field.allKeys containsObject:FT_MONITOR_ACCELERATION_Z]);
        }
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_LIGHT]);
        XCTAssertTrue([tag.allKeys containsObject:FT_MONITOR_TORCH]);
        
    }
    if (type & FTMonitorInfoTypeBluetooth) {
        XCTAssertTrue([tag.allKeys containsObject:FT_MONITOR_BT_OPEN]);
    }
    if (type & FTMonitorInfoTypeSensorBrightness) {
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_SCREEN_BRIGHTNESS]);
    }
    if (type & FTMonitorInfoTypeSensorStep) {
        if ([CMPedometer isStepCountingAvailable]) {
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_STEPS]);
        }
    }
    if (type & FTMonitorInfoTypeSensorProximity) {
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_PROXIMITY]);
    }
    if (type & FTMonitorInfoTypeSensorRotation) {
        if([motionManager isGyroAvailable]){
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_ROTATION_X] &&[field.allKeys containsObject:FT_MONITOR_ROTATION_Y] && [field.allKeys containsObject:FT_MONITOR_ROTATION_Z]);
        }
    }
    if (type & FTMonitorInfoTypeSensorAcceleration) {
        if ([motionManager isAccelerometerAvailable]) {
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_ACCELERATION_X] &&[field.allKeys containsObject:FT_MONITOR_ACCELERATION_Y] && [field.allKeys containsObject:FT_MONITOR_ACCELERATION_Z]);
        }
    }
    if (type & FTMonitorInfoTypeSensorMagnetic) {
        if ([motionManager isMagnetometerAvailable]) {
            XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_MAGNETIC_X] &&[field.allKeys containsObject:FT_MONITOR_MAGNETIC_Y] && [field.allKeys containsObject:FT_MONITOR_MAGNETIC_Z]);
        }
    }
    if (type & FTMonitorInfoTypeSensorLight) {
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_LIGHT]);
    }
    if (type & FTMonitorInfoTypeSensorTorch) {
        XCTAssertTrue([tag.allKeys containsObject:FT_MONITOR_TORCH]);
    }
    if (type & FTMonitorInfoTypeFPS) {
        XCTAssertTrue([field.allKeys containsObject:FT_MONITOR_FPS]);
    }
}
-(void)testMangerChangeMonitorType{
    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeAll];
    [[FTMonitorManager sharedInstance] startFlush];
    NSDictionary *dict =  [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    NSDictionary *field =  [dict valueForKey:FT_AGENT_FIELD];

    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeFPS];
    
    NSDictionary *dict2 =  [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    NSDictionary *field2 =  [dict2 valueForKey:FT_AGENT_FIELD];
    
    XCTAssertTrue([field2.allKeys containsObject:FT_MONITOR_FPS] && field.allKeys.count > field2.allKeys.count);

}


@end
