//
//  PerformanceTracingTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool.h"
#import "FTDateUtil.h"
@interface PerformanceTracingTest : XCTestCase

@end

@implementation PerformanceTracingTest


- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTMobileAgent sharedInstance] shutDown];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
- (void)setNetworkTraceType:(FTNetworkTraceType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = type;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}
- (void)testDDtraceGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testZipkinMultiHeaderGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinMultiHeader];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testZipkinSingleHeaderGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinSingleHeader];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testTraceparentGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeTraceparent];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testSkywalkingGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeSkywalking];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testJaegerGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[NSUUID UUID].UUIDString url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}

@end
