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
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "FTRumConfig.h"
#import "FTRumConfig+Private.h"
#import "FTAutoTrackHandler.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTDefaultUIKitViewTrackingHandler.h"
#import "FTDateUtil.h"
#import "FTViewControllerSwizzling.h"

@interface UIViewController (FTLoadingConfigurationTests)
+ (NSArray<NSString *> *)ft_loadingTimeCandidateClassNamesFromClassNames:(NSArray<NSString *> *)names;
+ (NSUInteger)ft_installViewControllerLifecycleSwizzlesForClassNames:(NSArray<NSString *> *)names;
+ (BOOL)ft_viewLoadingDurationInstrumentedForClass:(Class)cls;
- (id)ft_viewLoadingStateCreateIfNeeded:(BOOL)create;
@end
@interface FTAutoTrackHandler (FTLoadingConfigurationTests)
- (void)notifyOnAppearWithIdentity:(NSString *)identity name:(NSString *)name property:(NSDictionary *)property loadTime:(NSNumber *)loadTime;
- (void)notifyOnDisappearWithIdentity:(NSString *)identity;
@end

// Deliberately not a full backend: observe the real auto-track collector's exact delegate output.
@interface FTLoadingViewEvents : NSObject
@property NSMutableArray<NSNumber *> *loads;
@property NSMutableArray<NSString *> *names;
@property NSUInteger stops;
@end
@implementation FTLoadingViewEvents
- (instancetype)init { if ((self = [super init])) { _loads = [NSMutableArray array]; _names = [NSMutableArray array]; } return self; }
- (void)onCreateView:(NSString *)name loadTime:(NSNumber *)time { [self.loads addObject:time]; }
- (void)startViewWithViewID:(NSString *)viewID viewName:(NSString *)name property:(NSDictionary *)property { [self.names addObject:name]; }
- (void)stopViewWithViewID:(NSString *)viewID property:(NSDictionary *)property { self.stops++; }
@end

static NSUInteger excludedInitializations;
@interface FTLoadingExcludedController : UIViewController @end
@implementation FTLoadingExcludedController
+ (void)initialize { if (self == objc_lookUpClass("FTLoadingExcludedController")) excludedInitializations++; }
@end
@interface FTLoadingInheritedParent : UIViewController @end
@implementation FTLoadingInheritedParent @end
@interface FTLoadingInheritedExcludedChild : FTLoadingInheritedParent @end
@implementation FTLoadingInheritedExcludedChild @end
@interface FTLoadingEnabledController : UIViewController @end
@implementation FTLoadingEnabledController @end
@interface FTLoadingDependencyController : UIViewController @end
@implementation FTLoadingDependencyController @end
@interface FTLoadingDisabledFreshController : UIViewController @end
@implementation FTLoadingDisabledFreshController @end
@interface FTLoadingRescanController : UIViewController @end
@implementation FTLoadingRescanController @end

static uint64_t FTLoadingPolicyClock;
static NSUInteger FTLoadingPolicyClockCalls;
static uint64_t FTLoadingPolicySystemTime(id self, SEL selector) { FTLoadingPolicyClockCalls++; return FTLoadingPolicyClock; }
static NSUInteger FTLoadingPolicyScanCalls;
static BOOL FTLoadingPolicySwiftUIEnabled;
static void FTLoadingPolicyScan(id self, SEL selector) { FTLoadingPolicyScanCalls++; }
static void FTLoadingPolicySetSwiftUIEnabled(id self, SEL selector, BOOL enabled) { FTLoadingPolicySwiftUIEnabled = enabled; }

@interface FTViewLoadingTimeConfigurationTests : XCTestCase @end
@implementation FTViewLoadingTimeConfigurationTests
- (void)setUp {
    [super setUp];
    [UIViewController ft_configureViewLoadingTimeEnabled:YES classNameExcludes:[NSSet set]];
}
- (void)tearDown {
    [[FTAutoTrackHandler sharedInstance] shutDown];
    [UIViewController ft_configureViewLoadingTimeEnabled:YES classNameExcludes:[NSSet set]];
    [super tearDown];
}
- (FTLoadingViewEvents *)startWithConfig:(FTRumConfig *)config {
    return [self startWithConfig:config automaticView:YES];
}
- (FTLoadingViewEvents *)startWithConfig:(FTRumConfig *)config automaticView:(BOOL)automaticView {
    config.enableTraceUserView = automaticView;
    FTLoadingViewEvents *events = [FTLoadingViewEvents new];
    [[FTAutoTrackHandler sharedInstance] startWithRumConfig:config
                                     addRumDatasDelegate:(id<FTRumDatasProtocol>)events
                               heatmapIdentifierRegistry:nil];
    return events;
}
- (void)appear:(UIViewController *)controller {
    [controller loadViewIfNeeded];
    [controller viewWillAppear:NO];
    [controller viewDidAppear:NO];
}
- (void)testAutomaticViewOffStopsInstalledTimingAndReenableRestoresExactTime {
    Method scan = class_getClassMethod(UIViewController.class, @selector(ft_swizzleLoadedCustomViewControllerClasses));
    IMP originalScan = method_setImplementation(scan, (IMP)FTLoadingPolicyScan);
    Method clock = class_getClassMethod(FTDateUtil.class, @selector(systemTime));
    IMP originalClock = method_setImplementation(clock, (IMP)FTLoadingPolicySystemTime);
    @try {
        Class cls = objc_lookUpClass("FTLoadingDependencyController");
        FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
        FTLoadingViewEvents *enabled = [self startWithConfig:config];
        [UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingDependencyController"]];
        UIViewController *first = [[cls alloc] init];
        FTLoadingPolicyClock = 1000000; [first loadViewIfNeeded];
        FTLoadingPolicyClock = 2000000; [first viewWillAppear:NO];
        FTLoadingPolicyClock = 7000000; [first viewDidAppear:NO];
        [first viewDidDisappear:NO];
        XCTAssertEqualObjects(enabled.loads, (@[@5000000]));

        FTLoadingViewEvents *disabled = [self startWithConfig:config automaticView:NO];
        XCTAssertTrue(config.enableTraceUserViewLoadingTime); // Raw preference remains enabled.
        XCTAssertFalse([UIViewController ft_shouldCollectViewLoadingTimeForClass:cls]);
        XCTAssertNil(first.ft_loadDuration); // Previously collected state must not leak.
        XCTAssertTrue([UIViewController ft_viewLoadingDurationInstrumentedForClass:cls]);
        FTLoadingPolicyClockCalls = 0;
        UIViewController *whileDisabled = [[cls alloc] init];
        [self appear:whileDisabled];
        [whileDisabled viewDidDisappear:NO];
        XCTAssertEqual(FTLoadingPolicyClockCalls, 0u);
        XCTAssertNil(whileDisabled.ft_loadDuration);
        XCTAssertEqual(disabled.names.count, 0u);
        XCTAssertEqual(disabled.loads.count, 0u);
        XCTAssertEqual(disabled.stops, 0u);

        // Explicit SwiftUI View notifications retain their View behavior, but automatic
        // loading-time handling obeys the same effective switch as controller timing.
        FTAutoTrackHandler *handler = [FTAutoTrackHandler sharedInstance];
        [handler notifyOnAppearWithIdentity:@"manual-swift-view" name:@"SwiftScreen" property:nil loadTime:@8000000];
        [handler notifyOnDisappearWithIdentity:@"manual-swift-view"];
        XCTAssertEqualObjects(disabled.loads, (@[@(-1)]));
        XCTAssertEqualObjects(disabled.names, (@[@"SwiftScreen"]));
        XCTAssertEqual(disabled.stops, 1u);

        FTLoadingViewEvents *reenabled = [self startWithConfig:config];
        XCTAssertTrue([UIViewController ft_shouldCollectViewLoadingTimeForClass:cls]);
        XCTAssertEqual([UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingDependencyController"]], 0u);
        UIViewController *fresh = [[cls alloc] init];
        FTLoadingPolicyClock = 100000000; [fresh loadViewIfNeeded];
        FTLoadingPolicyClock = 101000000; [fresh viewWillAppear:NO];
        FTLoadingPolicyClock = 106000000; [fresh viewDidAppear:NO];
        [fresh viewDidDisappear:NO];
        XCTAssertEqualObjects(reenabled.loads, (@[@5000000]));
        XCTAssertEqualObjects(reenabled.names, (@[@"FTLoadingDependencyController"]));
        XCTAssertEqual(reenabled.stops, 1u);
    } @finally {
        method_setImplementation(clock, originalClock);
        method_setImplementation(scan, originalScan);
    }
}
- (void)testShutdownStopsInstalledTimingAndLegacyStartupReenablesIt {
    Method scan = class_getClassMethod(UIViewController.class, @selector(ft_swizzleLoadedCustomViewControllerClasses));
    IMP originalScan = method_setImplementation(scan, (IMP)FTLoadingPolicyScan);
    Method clock = class_getClassMethod(FTDateUtil.class, @selector(systemTime));
    IMP originalClock = method_setImplementation(clock, (IMP)FTLoadingPolicySystemTime);
    @try {
        Class cls = objc_lookUpClass("FTLoadingDependencyController");
        FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
        config.viewLoadingTimeClassNameExcludes = [NSSet setWithObject:@"FTLoadingEnabledController"];
        __unused FTLoadingViewEvents *enabled = [self startWithConfig:config];
        [UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingDependencyController"]];
        [[FTAutoTrackHandler sharedInstance] shutDown];
        XCTAssertFalse([UIViewController ft_shouldCollectViewLoadingTimeForClass:cls]);
        FTLoadingPolicyClockCalls = 0;
        UIViewController *afterShutdown = [[cls alloc] init];
        [self appear:afterShutdown];
        [afterShutdown viewDidDisappear:NO];
        XCTAssertEqual(FTLoadingPolicyClockCalls, 0u);
        XCTAssertNil(afterShutdown.ft_loadDuration);

        FTLoadingViewEvents *events = [FTLoadingViewEvents new];
        [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO
                                          addRumDatasDelegate:(id<FTRumDatasProtocol>)events
                                                 viewHandler:nil swiftUIViewHandler:nil actionHandler:nil];
        XCTAssertTrue([UIViewController ft_shouldCollectViewLoadingTimeForClass:cls]);
        XCTAssertFalse([UIViewController ft_shouldCollectViewLoadingTimeForClass:objc_lookUpClass("FTLoadingEnabledController")]);
        UIViewController *fresh = [[cls alloc] init];
        FTLoadingPolicyClock = 1000000; [fresh loadViewIfNeeded];
        FTLoadingPolicyClock = 2000000; [fresh viewWillAppear:NO];
        FTLoadingPolicyClock = 7000000; [fresh viewDidAppear:NO];
        [fresh viewDidDisappear:NO];
        XCTAssertEqualObjects(events.loads, (@[@5000000]));
        XCTAssertEqualObjects(events.names, (@[@"FTLoadingDependencyController"]));
        XCTAssertEqual(events.stops, 1u);
    } @finally {
        method_setImplementation(clock, originalClock);
        method_setImplementation(scan, originalScan);
    }
}
- (void)testConfigurationDefaultsCopyAndDictionaryRoundTrip {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
    XCTAssertTrue(config.enableTraceUserViewLoadingTime);
    XCTAssertEqualObjects(config.viewLoadingTimeClassNameExcludes, [NSSet set]);
    NSMutableString *pattern = [NSMutableString stringWithString:@"TUIChat"];
    NSMutableSet *excludes = [NSMutableSet setWithObjects:pattern, @"", @42, nil];
    config.enableTraceUserViewLoadingTime = NO;
    config.viewLoadingTimeClassNameExcludes = (id)excludes;
    [excludes removeAllObjects];
    [pattern appendString:@"Changed"];
    FTRumConfig *copy = [config copy];
    XCTAssertFalse(copy.enableTraceUserViewLoadingTime);
    XCTAssertEqualObjects(copy.viewLoadingTimeClassNameExcludes, [NSSet setWithObject:@"TUIChat"]);
    FTRumConfig *restored = [[FTRumConfig alloc] initWithDictionary:[config convertToDictionary]];
    XCTAssertFalse(restored.enableTraceUserViewLoadingTime);
    XCTAssertEqualObjects(restored.viewLoadingTimeClassNameExcludes, copy.viewLoadingTimeClassNameExcludes);
}
- (void)testExactClassNameMatchingDoesNotExcludePartialNamesOrSubclasses {
    [UIViewController ft_configureViewLoadingTimeEnabled:YES
                                     classNameExcludes:[NSSet setWithObjects:@"FTLoadingInheritedParent",
                                                       @"FTLoadingEnabled", @"ftloadingenabledcontroller", nil]];
    XCTAssertFalse([UIViewController ft_shouldCollectViewLoadingTimeForClass:objc_lookUpClass("FTLoadingInheritedParent")]);
    XCTAssertTrue([UIViewController ft_shouldCollectViewLoadingTimeForClass:objc_lookUpClass("FTLoadingInheritedExcludedChild")]);
    XCTAssertTrue([UIViewController ft_shouldCollectViewLoadingTimeForClass:objc_lookUpClass("FTLoadingEnabledController")]);
    NSArray *names = @[@"FTLoadingInheritedParent", @"FTLoadingInheritedExcludedChild", @"FTLoadingEnabledController"];
    XCTAssertEqualObjects([UIViewController ft_loadingTimeCandidateClassNamesFromClassNames:names],
                          (@[@"FTLoadingInheritedExcludedChild", @"FTLoadingEnabledController"]));
}
- (void)testExcludedClassIsNotInitializedOrInstrumentedButStillReportsViews {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
    config.viewLoadingTimeClassNameExcludes = [NSSet setWithObject:@"FTLoadingExcludedController"];
    FTLoadingViewEvents *events = [self startWithConfig:config];
    NSArray *names = @[@"FTLoadingExcludedController"];
    XCTAssertEqual(excludedInitializations, 0u);
    XCTAssertEqualObjects([UIViewController ft_loadingTimeCandidateClassNamesFromClassNames:names], @[]);
    Class cls = objc_lookUpClass("FTLoadingExcludedController");
    XCTAssertFalse([UIViewController ft_isCustomViewControllerClass:cls]); // root-hierarchy path
    XCTAssertEqual([UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:names], 0u);
    XCTAssertFalse([UIViewController ft_viewLoadingDurationInstrumentedForClass:cls]);
    XCTAssertEqual(excludedInitializations, 0u);
    UIViewController *controller = [[cls alloc] init];
    [self appear:controller];
    [controller viewDidDisappear:NO];
    [self appear:controller];
    UIViewController *modal = [[cls alloc] init];
    [self appear:modal];
    [modal viewDidDisappear:NO]; // resumes the original View through RUMView.resetView
    [controller viewDidDisappear:NO];
    XCTAssertEqual(excludedInitializations, 1u);
    XCTAssertEqualObjects(events.loads, (@[@(-1), @(-1), @(-1), @(-1)]));
    XCTAssertEqualObjects(events.names, (@[@"FTLoadingExcludedController", @"FTLoadingExcludedController",
                                          @"FTLoadingExcludedController", @"FTLoadingExcludedController"]));
    XCTAssertEqual(events.stops, 4u);
    XCTAssertNil(controller.ft_loadDuration);
}
- (void)testExcludedChildInheritsHookButDoesNotCollectTimeOrDuplicateViews {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
    config.viewLoadingTimeClassNameExcludes = [NSSet setWithObject:@"FTLoadingInheritedExcludedChild"];
    FTLoadingViewEvents *events = [self startWithConfig:config];
    XCTAssertEqual([UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingInheritedParent"]], 1u);
    UIViewController *controller = [[objc_lookUpClass("FTLoadingInheritedExcludedChild") alloc] init];
    [self appear:controller];
    [controller viewDidDisappear:NO];
    XCTAssertEqualObjects(events.loads, (@[@(-1)]));
    XCTAssertEqualObjects(events.names, (@[@"FTLoadingInheritedExcludedChild"]));
    XCTAssertEqual(events.stops, 1u);
    XCTAssertNil(controller.ft_loadDuration);
}
- (void)testStartupSwitchControlsScanAndSwiftUILoadingButKeepsViewHandlers {
    Method scan = class_getClassMethod(UIViewController.class, @selector(ft_swizzleLoadedCustomViewControllerClasses));
    Method swiftUI = class_getClassMethod(UIViewController.class, @selector(ft_setSwiftUIViewLoadingTimeEnabled:));
    IMP originalScan = method_setImplementation(scan, (IMP)FTLoadingPolicyScan);
    IMP originalSwiftUI = method_setImplementation(swiftUI, (IMP)FTLoadingPolicySetSwiftUIEnabled);
    @try {
        FTLoadingPolicyScanCalls = 0;
        FTLoadingPolicySwiftUIEnabled = YES;
        FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
        config.swiftUIViewTrackingHandler = [FTDefaultSwiftUIViewTrackingHandler new];
        config.enableTraceUserViewLoadingTime = NO;
        __unused FTLoadingViewEvents *disabled = [self startWithConfig:config];
        XCTAssertEqual(FTLoadingPolicyScanCalls, 0u);
        XCTAssertFalse(FTLoadingPolicySwiftUIEnabled);
        XCTAssertNotNil([FTAutoTrackHandler sharedInstance].viewControllerHandler);
        XCTAssertNotNil([FTAutoTrackHandler sharedInstance].uiKitViewTrackingHandler);
        [[FTAutoTrackHandler sharedInstance] shutDown];
        config.enableTraceUserViewLoadingTime = YES;
        __unused FTLoadingViewEvents *enabled = [self startWithConfig:config];
        XCTAssertEqual(FTLoadingPolicyScanCalls, 1u);
        XCTAssertTrue(FTLoadingPolicySwiftUIEnabled);
        __unused FTLoadingViewEvents *viewDisabled = [self startWithConfig:config automaticView:NO];
        XCTAssertEqual(FTLoadingPolicyScanCalls, 1u);
        XCTAssertFalse(FTLoadingPolicySwiftUIEnabled);
        XCTAssertNil([FTAutoTrackHandler sharedInstance].viewControllerHandler);
        XCTAssertFalse([UIViewController ft_shouldCollectViewLoadingTimeForClass:objc_lookUpClass("FTLoadingEnabledController")]);
        __unused FTLoadingViewEvents *viewReenabled = [self startWithConfig:config];
        XCTAssertEqual(FTLoadingPolicyScanCalls, 2u);
        XCTAssertTrue(FTLoadingPolicySwiftUIEnabled);
        config.enableTraceUserViewLoadingTime = NO;
        __unused FTLoadingViewEvents *timingDisabledAgain = [self startWithConfig:config];
        XCTAssertEqual(FTLoadingPolicyScanCalls, 2u);
        XCTAssertFalse(FTLoadingPolicySwiftUIEnabled);
        XCTAssertNotNil([FTAutoTrackHandler sharedInstance].viewControllerHandler);
    } @finally {
        method_setImplementation(scan, originalScan);
        method_setImplementation(swiftUI, originalSwiftUI);
    }
}
- (void)testDisabledTimeKeepsViewsAndDiscardsPreviouslyCollectedTime {
    // Install before disabling to cover an already-instrumented instance as well as inherited hooks.
    [UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingEnabledController"]];
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
    config.enableTraceUserViewLoadingTime = NO;
    FTLoadingViewEvents *events = [self startWithConfig:config];
    XCTAssertEqual([UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingDisabledFreshController"]], 0u);
    XCTAssertFalse([UIViewController ft_viewLoadingDurationInstrumentedForClass:objc_lookUpClass("FTLoadingDisabledFreshController")]);
    XCTAssertEqualObjects([UIViewController ft_loadingTimeCandidateClassNamesFromClassNames:@[@"FTLoadingEnabledController"]], @[]);
    UIViewController *controller = [[objc_lookUpClass("FTLoadingEnabledController") alloc] init];
    controller.ft_loadDuration = @123456;
    [self appear:controller];
    [controller viewDidDisappear:NO];
    [self appear:controller];
    [controller viewDidDisappear:NO];
    XCTAssertEqualObjects(events.loads, (@[@(-1), @(-1)]));
    XCTAssertEqual(events.names.count, 2u);
    XCTAssertEqual(events.stops, 2u);
    XCTAssertNil(controller.ft_loadDuration);
    // The SwiftUI modifier bridge must preserve View events but ignore its supplied duration too.
    FTAutoTrackHandler *handler = [FTAutoTrackHandler sharedInstance];
    [handler notifyOnAppearWithIdentity:@"swift-view" name:@"SwiftScreen" property:nil loadTime:@8000000];
    [handler notifyOnDisappearWithIdentity:@"swift-view"];
    XCTAssertEqualObjects(events.loads.lastObject, @(-1));
    XCTAssertEqualObjects(events.names.lastObject, @"SwiftScreen");
    XCTAssertEqual(events.stops, 3u);
}
- (void)testEnabledNonMatchingClassReportsExactLoadingDuration {
    FTRumConfig *config = [[FTRumConfig alloc] initWithAppid:@"test"];
    config.viewLoadingTimeClassNameExcludes = [NSSet setWithObject:@"ftloadingenabledcontroller"]; // case-sensitive
    FTLoadingViewEvents *events = [self startWithConfig:config];
    [UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:@[@"FTLoadingEnabledController"]];
    UIViewController *controller = [[objc_lookUpClass("FTLoadingEnabledController") alloc] init];
    Method clock = class_getClassMethod(FTDateUtil.class, @selector(systemTime));
    IMP original = method_setImplementation(clock, (IMP)FTLoadingPolicySystemTime);
    @try {
        FTLoadingPolicyClock = 1000000;
        [controller loadViewIfNeeded]; // zero synchronous load duration
        FTLoadingPolicyClock = 2000000;
        [controller viewWillAppear:NO];
        FTLoadingPolicyClock = 7000000;
        [controller viewDidAppear:NO]; // 7ms - 2ms = 5ms
        [controller viewDidDisappear:NO];
        XCTAssertEqualObjects(events.loads, (@[@5000000]));
        XCTAssertEqualObjects(events.names, (@[@"FTLoadingEnabledController"]));
        XCTAssertEqual(events.stops, 1u);
    } @finally {
        method_setImplementation(clock, original);
    }
}
- (void)testZZRefreshScansPreviouslyExcludedClassesAfterConfigurationChange {
    Class cls = objc_lookUpClass("FTLoadingRescanController");
    NSString *path = [NSString stringWithUTF8String:class_getImageName(cls)];
    FTViewControllerSwizzling *scanner = [[FTViewControllerSwizzling alloc] initWithInAppIncludes:@[path]
                                                                         scanLoadedFrameworks:NO];
    [UIViewController ft_configureViewLoadingTimeEnabled:YES classNameExcludes:[NSSet setWithObject:@"FTLoadingRescanController"]];
    XCTestExpectation *first = [self expectationWithDescription:@"initial excluded scan"];
    [scanner swizzleLoadedViewControllerClassesWithCompletion:^{ [first fulfill]; }];
    [self waitForExpectations:@[first] timeout:10];
    XCTAssertFalse([UIViewController ft_viewLoadingDurationInstrumentedForClass:cls]);
    [UIViewController ft_configureViewLoadingTimeEnabled:YES classNameExcludes:[NSSet set]];
    XCTestExpectation *second = [self expectationWithDescription:@"configuration refresh scan"];
    [scanner refreshLoadedViewControllerClasses];
    [scanner swizzleLoadedViewControllerClassesWithCompletion:^{ [second fulfill]; }];
    [self waitForExpectations:@[second] timeout:10];
    XCTAssertTrue([UIViewController ft_viewLoadingDurationInstrumentedForClass:cls]);
}
@end
