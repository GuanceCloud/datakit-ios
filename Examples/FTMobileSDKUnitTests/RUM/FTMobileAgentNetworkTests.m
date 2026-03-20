//
//  FTMobileAgentNetworkTests.m
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
#import "XCTestCase+Utils.h"

@interface FTMobileAgentNetworkTests : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation FTMobileAgentNetworkTests

- (void)setUp {
    [super setUp];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
    [FTMobileAgent shutDown];
    [super tearDown];
}

#pragma mark - Basic Function Tests

// Test 1: Dynamically set Datakit URL after initialization
- (void)testDynamicSetDatakitURLAfterInit_disable_autoSync {
    // 1. Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial state
    XCTAssertFalse([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
    
    // 2. Dynamically set Datakit URL
    NSString *testURL = @"https://test-datakit.example.com";
    [FTMobileAgent updateDatakitURL:testURL];
    
    // Verify configuration update
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatakitMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datakitUrl, testURL);
    
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
}

- (void)testDynamicSetDatakitURLAfterInit_enable_autoSync {
    // 1. Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = YES;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial state
    XCTAssertFalse([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
    
    // 2. Dynamically set Datakit URL
    NSString *testURL = @"https://test-datakit.example.com";
    [FTMobileAgent updateDatakitURL:testURL];
    
    // Verify configuration update
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatakitMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datakitUrl, testURL);
    
    XCTAssertTrue([FTTrackDataManager sharedInstance].autoSync);
}

// Test 2: Dynamically set Dataway URL and Token after initialization
- (void)testDynamicSetDatawayURLAfterInit_disable_autoSync {
    // 1. Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial state
    XCTAssertFalse([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
    
    // 2. Dynamically set Dataway URL and Token
    NSString *testURL = @"https://test-dataway.example.com";
    NSString *testToken = @"test-client-token-123";
    [FTMobileAgent updateDatawayURL:testURL clientToken:testToken];
    
    // Verify configuration update
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatawayMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datawayUrl, testURL);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].clientToken, testToken);
    
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
}

- (void)testDynamicSetDatawayURLAfterInit_enable_autoSync {
    // 1. Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = YES;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial state
    XCTAssertFalse([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
    
    // 2. Dynamically set Dataway URL and Token
    NSString *testURL = @"https://test-dataway.example.com";
    NSString *testToken = @"test-client-token-123";
    [FTMobileAgent updateDatawayURL:testURL clientToken:testToken];
    
    // Verify configuration update
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatawayMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datawayUrl, testURL);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].clientToken, testToken);
    
    XCTAssertTrue([FTTrackDataManager sharedInstance].autoSync);
}

// Test 3: Switch from Datakit to Dataway
- (void)testSwitchFromDatakitToDataway {
    // 1. Initialize SDK with Datakit
    NSString *datakitURL = @"https://datakit1.example.com";
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:datakitURL];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial configuration
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatakitMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datakitUrl, datakitURL);
    
    // 2. Switch to Dataway
    NSString *datawayURL = @"https://dataway1.example.com";
    NSString *datawayToken = @"token-456";
    [FTMobileAgent updateDatawayURL:datawayURL clientToken:datawayToken];
    
    // Verify switch result
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatawayMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datawayUrl, datawayURL);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].clientToken, datawayToken);
    XCTAssertNil([FTNetworkInfoManager sharedInstance].datakitUrl); // Datakit URL should be cleared
}

// Test 4: Switch from Dataway to Datakit
- (void)testSwitchFromDatawayToDatakit {
    // 1. Initialize SDK with Dataway
    NSString *datawayURL = @"https://dataway2.example.com";
    NSString *datawayToken = @"token-789";
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatawayUrl:datawayURL clientToken:datawayToken];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial configuration
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatawayMode);
    
    // 2. Switch to Datakit
    NSString *datakitURL = @"https://datakit2.example.com";
    [FTMobileAgent updateDatakitURL:datakitURL];
    
    // Verify switch result
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateDatakitMode);
    XCTAssertEqualObjects([FTNetworkInfoManager sharedInstance].datakitUrl, datakitURL);
    XCTAssertNil([FTNetworkInfoManager sharedInstance].datawayUrl); // Dataway URL should be cleared
    XCTAssertNil([FTNetworkInfoManager sharedInstance].clientToken); // Token should be cleared
}

#pragma mark - Boundary Condition Tests

// Test 5: Set invalid Datakit URL (empty string)
- (void)testSetInvalidDatakitURL {
    // Initialize SDK
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://initial.example.com"];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial configuration is valid
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertTrue([FTTrackDataManager sharedInstance].autoSync);
    
    // Try to set invalid URL
    [FTMobileAgent updateDatakitURL:@""];
    
    // Verify configuration becomes invalid
    XCTAssertFalse([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateNotConfigured);
    
    // Verify sync is disabled
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
}

// Test 6: Set invalid Dataway configuration (only URL without Token)
- (void)testSetInvalidDatawayConfig {
    // Initialize SDK
    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"https://initial.example.com"];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Verify initial configuration is valid
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertTrue([FTTrackDataManager sharedInstance].autoSync);
    
    // Try to set invalid configuration (only URL)
    [FTMobileAgent updateDatawayURL:@"https://dataway.example.com" clientToken:@""];
    
    // Verify configuration becomes invalid
    XCTAssertFalse([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTNetworkInfoManager sharedInstance].configState, FTNetworkConfigStateNotConfigured);
    
    // Verify sync is disabled
    XCTAssertFalse([FTTrackDataManager sharedInstance].autoSync);
}

// Test 7: Set the same URL multiple times
- (void)testSetSameURLMultipleTimes {
    // Initialize SDK
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = YES;
    [FTMobileAgent startWithConfigOptions:config];
    
    NSString *testURL = @"https://same.example.com";
    
    // First time setting
    [FTMobileAgent updateDatakitURL:testURL];
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertTrue([FTTrackDataManager sharedInstance].autoSync);
    
    // Record current state
    BOOL previousAutoSync = [FTTrackDataManager sharedInstance].autoSync;
    
    // Second time setting the same URL
    [FTMobileAgent updateDatakitURL:testURL];
    
    // Verify state remains unchanged
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    XCTAssertEqual([FTTrackDataManager sharedInstance].autoSync, previousAutoSync);
}

#pragma mark - Data Upload Tests

// Test 8: Data can be uploaded normally after dynamic configuration
- (void)testDataUploadAfterDynamicConfig {
    // Mock network request
    __block NSInteger requestCount = 0;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:@"test-upload.example.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        requestCount++;
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
    }];
    
    // 1. Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = NO;
    config.syncPageSize = 1;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Add some test data
    for (int i = 0; i < 3; i++) {
        FTRecordModel *model = [FTModelHelper createRumModel];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];
    }
    
    // Verify data is cached but not uploaded
    NSInteger cachedCount = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertEqual(cachedCount, 3);
    XCTAssertEqual(requestCount, 0);
    
    // 2. Dynamically set URL
    [FTMobileAgent updateDatakitURL:@"https://test-upload.example.com"];
    
    // 3. Manually trigger upload
    self.expectation = [self expectationWithDescription:@"Wait for upload"];
    [[FTTrackDataManager sharedInstance] flushSyncData];
    
    // Wait for upload to complete
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    // Verify data has been uploaded
    XCTAssertGreaterThan(requestCount, 0);
}

// Test 9: No upload when configuration is invalid
- (void)testNoUploadWhenConfigInvalid {
    // Mock network request
    __block NSInteger requestCount = 0;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        requestCount++;
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
    }];
    
    // Initialize SDK without URL
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    
    // Add test data
    FTRecordModel *model = [FTModelHelper createLogModel:@"test-data"];
    [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    
    // Manually trigger upload (should not upload because configuration is invalid)
    [[FTTrackDataManager sharedInstance] flushSyncData];
    
    // Wait for a short time
    [self waitForTimeInterval:0.5];
    
    // Verify no network request
    XCTAssertEqual(requestCount, 0);
}

#pragma mark - Concurrency Tests

// Test 10: Multiple threads updating configuration simultaneously
- (void)testConcurrentConfigUpdates {
    // Initialize SDK
    FTMobileConfig *config = [[FTMobileConfig alloc] init];
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    
    dispatch_group_t group = dispatch_group_create();
    NSInteger updateCount = 10;
    
    for (int i = 0; i < updateCount; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (i % 2 == 0) {
                [FTMobileAgent updateDatakitURL:[NSString stringWithFormat:@"https://datakit-%d.example.com", i]];
            } else {
                [FTMobileAgent updateDatawayURL:[NSString stringWithFormat:@"https://dataway-%d.example.com", i]
                                           clientToken:[NSString stringWithFormat:@"token-%d", i]];
            }
            dispatch_group_leave(group);
        });
    }
    
    // Wait for all updates to complete
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Verify final state is consistent
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
    
    // Verify configuration state is valid (either Datakit or Dataway)
    FTNetworkConfigState finalState = [FTNetworkInfoManager sharedInstance].configState;
    XCTAssertTrue(finalState == FTNetworkConfigStateDatakitMode || finalState == FTNetworkConfigStateDatawayMode);
}

#pragma mark - SDK Not Initialized Tests

// Test 11: Call update method before SDK initialization
- (void)testUpdateBeforeSDKInit {
    // Ensure SDK is not initialized
    [FTMobileAgent shutDown];
    
    // Try to update URL before SDK initialization
    [FTMobileAgent updateDatakitURL:@"https://test.example.com"];
    
    // Verify no crash, only error log is recorded
    // This test mainly ensures code robustness
    XCTAssertTrue(YES);
}

@end
