//
//  PerformanceTracingTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2023/2/22.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "FTBaseInfoHandler.h"
@interface PerformanceTracingTest : XCTestCase

@end

@implementation PerformanceTracingTest


- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
    [FTMobileAgent clearAllData];
}
- (void)setNetworkTraceType:(FTNetworkTraceType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTSDKConfig *config = [[FTSDKConfig alloc]initWithDatakitUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = type;
    [FTSDKAgent startWithConfigOptions:config];
    [[FTSDKAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}
- (void)testDDtraceGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithUrl:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testZipkinMultiHeaderGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinMultiHeader];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[FTBaseInfoHandler randomUUID] url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testZipkinSingleHeaderGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeZipkinSingleHeader];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[FTBaseInfoHandler randomUUID] url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testTraceparentGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeTraceparent];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[FTBaseInfoHandler randomUUID] url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testSkywalkingGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeSkywalking];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[FTBaseInfoHandler randomUUID] url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}
- (void)testJaegerGetTraceHeaderPerformance{
    // This is an example of a performance test case.
    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    
    [self measureBlock:^{
        [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:[FTBaseInfoHandler randomUUID] url:[NSURL URLWithString:@"https://www.baidu.com"]];
    }];
}

@end
