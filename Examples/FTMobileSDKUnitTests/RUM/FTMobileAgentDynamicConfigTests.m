//
//  FTMobileAgentDynamicConfigTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/03/06.
//  Copyright © 206 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTMobileAgent.h"
#import "FTNetworkInfoManager.h"
#import "FTTrackDataManager+Test.h"
#import "FTTrackerEventDBTool+Test.h"
#import "FTModelHelper.h"
#import "OHHTTPStubs.h"
#import "FTTestUtils.h"

@interface FTMobileAgentDynamicConfigTests : XCTestCase
@end

@implementation FTMobileAgentDynamicConfigTests

- (void)setUp {
    [super setUp];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
    [FTMobileAgent shutDown];
    [super tearDown];
}

#pragma mark - Helper Methods

- (void)verifyDataUploadAfterConfig {
    // Mock network request
    __block NSInteger requestCount = 0;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:@"delayed-config.example.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        requestCount++;
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
    }];
    
    //  Add test data
    FTRecordModel *model = [FTModelHelper createRUMModel:@"test-upload-data"];
    [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];
    
    // Manually trigger upload
    [[FTTrackDataManager sharedInstance] flushSyncData];
    
    // Wait for upload to complete
    [self waitForTimeInterval:0.5];
    
    // Verify there are network requests
    XCTAssertGreaterThan(requestCount, 0, @"Data should be uploaded");
}

#pragma mark - Main Test Scenarios

// Scenario 1: Delayed configuration - configure after initialization
- (void)testDelayedConfigurationScenario {
    // Step 1: Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:nil];
    config.autoSync = YES;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify: Initial state is not configured
    XCTAssertFalse([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertFalse([[FTTrackDataManager sharedInstance] autoSync]);
    
    // Step 2: Dynamically configure after user operation
    [FTMobileAgent updateDatakitURL:@"https://delayed-config.example.com"];
    
    // Verify: Configuration takes effect, sync is automatically enabled
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertTrue([[FTTrackDataManager sharedInstance] autoSync]);
    
    // Step 3: Verify data can be uploaded normally
    [self verifyDataUploadAfterConfig];
}

// Scenario 2: Configuration switching - switch servers at runtime
- (void)testRuntimeSwitchScenario {
    // Step 1: Initialize with Datakit
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://primary.example.com"];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify: Initial configuration is correct
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateDatakitMode);
    
    // Step 2: Switch to backup Dataway at runtime
    [FTMobileAgent updateDatawayURL:@"https://backup.example.com" clientToken:@"backup-token"];
    
    // Verify: Switch successful
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateDatawayMode);
    XCTAssertNil([[FTNetworkInfoManager sharedInstance] datakitUrl]);
    
    // Step 3: Switch back to Datakit
    [FTMobileAgent updateDatakitURL:@"https://recovery.example.com"];
    
    // Verify: Switch back successful
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateDatakitMode);
    XCTAssertNil([[FTNetworkInfoManager sharedInstance] datawayUrl]);
}

// Scenario 3: Configuration invalidation and recovery
- (void)testConfigInvalidationAndRecovery {
    // Step 1: Initialize with valid configuration
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://valid.example.com"];
    config.autoSync = YES;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify: Initial configuration is valid
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertTrue([[FTTrackDataManager sharedInstance] autoSync]);
    
    // Step 2: Set invalid configuration (empty URL)
    [FTMobileAgent updateDatakitURL:@""];
    
    // Verify: Configuration becomes invalid, sync is disabled
    XCTAssertFalse([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateNotConfigured);
    XCTAssertFalse([[FTTrackDataManager sharedInstance] autoSync]);
    
    // Step 3: Restore valid configuration
    [FTMobileAgent updateDatakitURL:@"https://recovered.example.com"];
    
    // Verify: Configuration restored to valid, sync re-enabled
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateDatakitMode);
    XCTAssertTrue([[FTTrackDataManager sharedInstance] autoSync]);
}

// Scenario 4: Dataway configuration partial invalidation
- (void)testDatawayPartialInvalidation {
    // Step 1: Initialize with valid Dataway configuration
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatawayUrl:@"https://dataway.example.com" clientToken:@"valid-token"];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify: Initial configuration is valid
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateDatawayMode);
    
    // Step 2: Set invalid Dataway configuration (only URL, no Token)
    [FTMobileAgent updateDatawayURL:@"https://dataway.example.com" clientToken:@""];
    
    // Verify: Configuration becomes invalid
    XCTAssertFalse([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateNotConfigured);
    XCTAssertFalse([[FTTrackDataManager sharedInstance] autoSync]);
    
    // Step 3: Restore valid Token
    [FTMobileAgent updateDatawayURL:@"https://dataway.example.com" clientToken:@"new-valid-token"];
    
    // Verify: Configuration restored to valid
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateDatawayMode);
    XCTAssertTrue([[FTTrackDataManager sharedInstance] autoSync]);
}

#pragma mark - Boundary Condition Tests

// Test: Set nil URL
- (void)testSetNilURL {
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://initial.example.com"];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Initial state is valid
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    
    // Set nil (will actually become empty string)
    [FTMobileAgent updateDatakitURL:nil];
    
    // Verify configuration becomes invalid
    XCTAssertFalse([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual([[FTNetworkInfoManager sharedInstance] configState], FTNetworkConfigStateNotConfigured);
}

// Test: Repeatedly set same configuration
- (void)testRepeatedSameConfiguration {
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:nil];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    
    NSString *testURL = @"https://repeated.example.com";
    
    // First time setting
    [FTMobileAgent updateDatakitURL:testURL];
    BOOL firstAutoSync = [[FTTrackDataManager sharedInstance] autoSync];
    
    // Second time setting same URL
    [FTMobileAgent updateDatakitURL:testURL];
    BOOL secondAutoSync = [[FTTrackDataManager sharedInstance] autoSync];
    
    // Verify state unchanged
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    XCTAssertEqual(firstAutoSync, secondAutoSync);
    XCTAssertEqualObjects([[FTNetworkInfoManager sharedInstance] datakitUrl], testURL);
}

// Test: Data consistency during configuration switch
- (void)testDataConsistencyDuringSwitch {
    // Mock two different servers
    __block NSInteger server1Count = 0;
    __block NSInteger server2Count = 0;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if ([request.URL.absoluteString containsString:@"server1"]) {
            server1Count++;
            return YES;
        } else if ([request.URL.absoluteString containsString:@"server2"]) {
            server2Count++;
            return YES;
        }
        return NO;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
    }];
    
    // Initialize using server1
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://server1.example.com"];
    config.autoSync = NO;
    config.syncPageSize = 1;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Add some data
    for (int i = 0; i < 3; i++) {
        FTRecordModel *model = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"data-%d", i]];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];
    }
    
    // Wait for upload
    [[FTTrackDataManager sharedInstance] flushSyncData];
    [self waitForTimeInterval:1.0];
    
    // Switch to server2
    [FTMobileAgent updateDatakitURL:@"https://server2.example.com"];
    
    // Add more data
    for (int i = 3; i < 6; i++) {
        FTRecordModel *model = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"data-%d", i]];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];
    }
    
    // Manually trigger upload
    [[FTTrackDataManager sharedInstance] flushSyncData];
    [self waitForTimeInterval:1.0];
    
    // Verify both servers received data
    XCTAssertGreaterThan(server1Count, 0, "server1 should receive data");
    XCTAssertGreaterThan(server2Count, 0, "server2 should receive data");
}

#pragma mark - Concurrency Tests

// Test: Multi-thread concurrent configuration updates
- (void)testConcurrentConfigurationUpdates {
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:nil];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    
    dispatch_group_t group = dispatch_group_create();
    NSInteger threadCount = 5;
    
    for (int i = 0; i < threadCount; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (i % 2 == 0) {
                [FTMobileAgent updateDatakitURL:[NSString stringWithFormat:@"https://concurrent-%d.example.com", i]];
            } else {
                [FTMobileAgent updateDatawayURL:[NSString stringWithFormat:@"https://concurrent-%d.example.com", i]
                                           clientToken:[NSString stringWithFormat:@"token-%d", i]];
            }
            dispatch_group_leave(group);
        });
    }
    
    // Wait for all threads to complete
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Verify final state is consistent and valid
    XCTAssertTrue([[FTNetworkInfoManager sharedInstance] isNetworkConfigured]);
    
    FTNetworkConfigState finalState = [[FTNetworkInfoManager sharedInstance] configState];
    XCTAssertTrue(finalState == FTNetworkConfigStateDatakitMode || 
                  finalState == FTNetworkConfigStateDatawayMode,
                  "Final state should be a valid configuration mode");
}

#pragma mark - SDK State Tests

// Test: Call update method before SDK initialization
- (void)testUpdateBeforeSDKInitialization {
    // Ensure SDK is not initialized
    [FTMobileAgent shutDown];
    
    // These calls should not crash, only log errors
    XCTAssertNoThrow([FTMobileAgent updateDatakitURL:@"https://test.example.com"]);
    XCTAssertNoThrow([FTMobileAgent updateDatawayURL:@"https://test.example.com" clientToken:@"token"]);
}

// Test: Logging after configuration update
- (void)testLoggingAfterConfigurationUpdate {
    // Enable SDK debug logging
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:nil];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Dynamically update configuration
    [FTMobileAgent updateDatakitURL:@"https://logging-test.example.com"];
    
    // This test mainly verifies no crash, logs will be recorded
    // In actual testing, you may need to capture log output for verification
    XCTAssertTrue(YES);
}

#pragma mark - Utility Methods

- (void)waitForTimeInterval:(NSTimeInterval)interval {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for time interval"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:interval + 0.1];
}

@end

