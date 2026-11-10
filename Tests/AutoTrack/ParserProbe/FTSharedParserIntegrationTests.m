//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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
#import <objc/runtime.h>
#import "FTMobileAgent.h"
#import "FTMobileConfig.h"
#import "FTRumConfig.h"
#import "FTViewControllerSwizzling.h"
#import "UIViewController+FTAutoTrack.h"

#ifndef FT_PROBE_DEBUG_LOG
#define FT_PROBE_DEBUG_LOG 0
#endif

extern Class FTProbeSelectedDataSource(void);
extern BOOL FTProbeMinimalInitialized(void);
extern NSArray<NSString *> *FTProbeInitializationStack(void);
extern NSString *FTProbeRenderPayload(NSData *payload);

@interface UIViewController (FTParserIntegrationTesting)
+ (BOOL)ft_viewLoadingDurationInstrumentedForClass:(Class)controllerClass;
@end

@interface FTSharedParserIntegrationTests : XCTestCase @end
@implementation FTSharedParserIntegrationTests
- (void)testDefaultPublicSDKStartupPreservesSharedParserAndPayload {
    NSData *payload = [@"{\"businessID\":\"custom_link\",\"text\":\"unchanged-payload\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *original = [payload copy];
    Class classic = objc_lookUpClass("FTProbeClassicController");
    Class minimal = objc_lookUpClass("FTProbeMinimalController");
    // Verify this really is the App image, which the SDK discovers without custom include paths.
    NSString *image = [NSString stringWithUTF8String:class_getImageName(minimal)];
    XCTAssertTrue([image hasPrefix:[NSBundle.mainBundle.bundlePath stringByAppendingString:@"/"]]);
    [classic class]; // Legitimate application use selects Classic first.
    XCTAssertFalse(FTProbeMinimalInitialized());
    XCTAssertEqual(FTProbeSelectedDataSource(), classic);
    XCTAssertEqualObjects(FTProbeRenderPayload(payload), @"custom-link-cell");

    FTMobileConfig *config = [[FTMobileConfig alloc] initWithDatakitUrl:@"http://127.0.0.1:18760/intake"];
    config.autoSync = NO;
    config.enableDataFilter = NO;
    config.enableSDKDebugLog = FT_PROBE_DEBUG_LOG;
    FTRumConfig *rum = [[FTRumConfig alloc] initWithAppid:@"shared-parser-regression"];
    rum.enableTraceUserView = YES;
    rum.enableTraceUserResource = YES;
    // Never set the loading-time switch or exclusion list. The same test builds against develop,
    // where these properties were not public, and against the fixed checkout.
    if ([rum respondsToSelector:NSSelectorFromString(@"enableTraceUserViewLoadingTime")]) {
        XCTAssertTrue([[rum valueForKey:@"enableTraceUserViewLoadingTime"] boolValue]);
        XCTAssertEqual([[rum valueForKey:@"viewLoadingTimeClassNameExcludes"] count], 0u);
    } else {
        XCTAssertTrue([[rum valueForKey:@"enableUIKitViewLoadingTime"] boolValue]);
    }
    @try {
        [FTMobileAgent startWithConfigOptions:config];
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rum];
        XCTestExpectation *scanned = [self expectationWithDescription:@"actual default App and Framework scan"];
        [[FTViewControllerSwizzling sharedInstance] swizzleLoadedViewControllerClassesWithCompletion:^{ [scanned fulfill]; }];
        [self waitForExpectations:@[scanned] timeout:30];

        NSString *render = FTProbeRenderPayload(payload);
        NSDictionary *result = @{@"sdk_debug_log": @(FT_PROBE_DEBUG_LOG),
                                 @"automatic_views": @YES, @"default_loading_time": @YES,
                                 @"exclusions": @[], @"minimal_initialized": @(FTProbeMinimalInitialized()),
                                 @"selected_parser": [NSString stringWithUTF8String:class_getName(FTProbeSelectedDataSource())],
                                 @"render": render, @"payload_unchanged": @([payload isEqualToData:original]),
                                 @"minimal_instrumented": @([UIViewController ft_viewLoadingDurationInstrumentedForClass:minimal]),
                                 @"initialization_stack": FTProbeInitializationStack() ?: @[]};
        NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingSortedKeys error:nil];
        NSLog(@"FT_PARSER_REGRESSION %@", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
        XCTAssertFalse(FTProbeMinimalInitialized());
        XCTAssertEqual(FTProbeSelectedDataSource(), classic);
        XCTAssertEqualObjects(render, @"custom-link-cell");
        XCTAssertEqualObjects(payload, original);
        // Prove the default scan actually found AND hooked the unused controller.
        XCTAssertTrue([UIViewController ft_viewLoadingDurationInstrumentedForClass:minimal]);
    } @finally {
        [FTMobileAgent shutDown];
    }
}
@end
