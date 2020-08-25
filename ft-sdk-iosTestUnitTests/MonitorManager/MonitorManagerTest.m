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
@interface MonitorManagerTest : XCTestCase

@end

@implementation MonitorManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
/**
 测试 FTMonitorInfoType 是否按类型抓取
*/
-(void)testMangerSetMonitorInfoTypeAll{
    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeAll];
    [[FTMonitorManager sharedInstance] startFlush];
    NSDictionary *dict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    NSDictionary *field =  [dict valueForKey:FT_AGENT_FIELD];
    
}
-(void)testMangerSetMonitorInfoTypeBattery{
    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeBattery];
    [[FTMonitorManager sharedInstance] startFlush];
    NSDictionary *dict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    NSDictionary *field =  [dict valueForKey:FT_AGENT_FIELD];

}
-(void)testMangerSetMonitorInfoTypeCpu{
   
    [self monitorInfoType:FTMonitorInfoTypeCpu];
}
-(void)monitorInfoType:(FTMonitorInfoType)type{
    [[FTMonitorManager sharedInstance] setMonitorType:FTMonitorInfoTypeCpu];
    [[FTMonitorManager sharedInstance] startFlush];
    NSDictionary *dict = [[FTMonitorManager sharedInstance] getMonitorTagFiledDict];
    NSDictionary *field =  [dict valueForKey:FT_AGENT_FIELD];
    NSDictionary *tag =  [dict valueForKey:FT_AGENT_TAGS];
    if(type & FTMonitorInfoTypeLocation ){
        XCTAssertTrue([tag.allKeys containsObject:@"city"]);
    }
    if(type & FTMonitorInfoTypeCamera ){
        XCTAssertTrue([tag.allKeys containsObject:@"camera_front_px"]);
    }
    if(type & FTMonitorInfoTypeNetwork ){
        XCTAssertTrue([tag.allKeys containsObject:@"network_type"]);
    }
    if(type & FTMonitorInfoTypeCpu ){
        XCTAssertTrue([tag.allKeys containsObject:@"cpu_no"]);
    }
    if(type & FTMonitorInfoTypeMemory ){
        XCTAssertTrue([tag.allKeys containsObject:@"memory_total"]);
    }
    if(type & FTMonitorInfoTypeBattery){
        XCTAssertTrue([tag.allKeys containsObject:@"battery_use"]);
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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
