//
//  FTAutoTrackTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by hulilei on 2019/12/25.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#import <KIF/KIF.h>
#import <XCTest/XCTest.h>
#import "FTViewControllerSwizzling.h"
#import "UIViewController+FTAutoTrack.h"
#import "UIView+FTAutoTrack.h"
#import "UITestVC.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent.h"
#import <objc/runtime.h>
#import "FTAutoTrackHandler.h"
#import "FTMobileAgent+Private.h"
#import "FTBaseInfoHandler.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "FTDateUtil.h"
#import "DemoViewController.h"
#import "FTConstants.h"
#import "FTGlobalRumManager+Private.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
#import "TestSessionDelegate.h"
#import "FTNetworkMock.h"
#import "AddRumDatasHandlerMock.h"

@interface UIViewController (FTLoadingStateTesting)
- (id)ft_viewLoadingStateCreateIfNeeded:(BOOL)createIfNeeded;
@end

@interface FTAutoTrackHandler (SwiftUIRUMViewTesting)
- (void)notifyOnAppearWithIdentity:(NSString *)identity name:(NSString *)name property:(nullable NSDictionary *)property loadTime:(NSNumber *)loadTime;
- (void)notifyOnDisappearWithIdentity:(NSString *)identity;
@end

@interface FTAutoTrackLoadingTimeTestViewController : UIViewController
@property (nonatomic, assign) NSTimeInterval viewDidLoadDelay;
@property (nonatomic, assign) NSTimeInterval viewWillAppearDelay;
@property (nonatomic, assign) NSTimeInterval viewWillLayoutSubviewsDelay;
@property (nonatomic, assign) NSTimeInterval viewDidAppearDelay;
@end

@implementation FTAutoTrackLoadingTimeTestViewController
- (void)loadView{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    self.view.backgroundColor = [UIColor whiteColor];
}
- (void)viewDidLoad{
    [super viewDidLoad];
    if (self.viewDidLoadDelay > 0) {
        [NSThread sleepForTimeInterval:self.viewDidLoadDelay];
    }
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (self.viewWillAppearDelay > 0) {
        [NSThread sleepForTimeInterval:self.viewWillAppearDelay];
    }
}
- (void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];
    if (self.viewWillLayoutSubviewsDelay > 0) {
        [NSThread sleepForTimeInterval:self.viewWillLayoutSubviewsDelay];
    }
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (self.viewDidAppearDelay > 0) {
        [NSThread sleepForTimeInterval:self.viewDidAppearDelay];
    }
}
@end

@interface FTAutoTrackNoSuperViewDidAppearViewController : UIViewController
@property (nonatomic, assign) NSTimeInterval viewDidLoadDelay;
@end

@implementation FTAutoTrackNoSuperViewDidAppearViewController
- (void)loadView{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
}
- (void)viewDidLoad{
    [super viewDidLoad];
    if (self.viewDidLoadDelay > 0) {
        [NSThread sleepForTimeInterval:self.viewDidLoadDelay];
    }
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}
- (void)viewDidAppear:(BOOL)animated{
    // Intentionally does not call super. The concrete class lifecycle swizzle must report this view.
}
@end


// A deterministic clock advances only inside the simulated application callbacks.
static uint64_t FTLoadingNodeNow;
static NSUInteger FTLoadingNodeClockReads;
@interface FTLoadingNodeParent : UIViewController
@property (nonatomic) BOOL failLoad;
@property (nonatomic) NSUInteger throwStage;
@property (nonatomic) BOOL hideLoadedView;
@property (nonatomic) BOOL revealLoadedViewDuringLayout;
@property (nonatomic) BOOL repeatSuper;
@property (nonatomic) NSUInteger windowChecks;
@property (nonatomic) BOOL reenterAppearance;
@end
@implementation FTLoadingNodeParent
- (void)loadView { self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    FTLoadingNodeNow += 3000000;
    if (self.failLoad) [NSException raise:@"FTLoadingTestException" format:@"application failure"];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated];
    if (self.throwStage == 1) [NSException raise:@"FTLoadingTestException" format:@"appearance failure"];
}
- (void)viewWillLayoutSubviews { [super viewWillLayoutSubviews];
    if (self.revealLoadedViewDuringLayout) self.hideLoadedView = NO;
    if (self.throwStage == 2) [NSException raise:@"FTLoadingTestException" format:@"layout failure"];
}
- (BOOL)isViewLoaded { self.windowChecks++; return !self.hideLoadedView && [super isViewLoaded]; }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.reenterAppearance) {
        self.reenterAppearance = NO;
        [self viewDidAppear:animated];
    }
    if (self.throwStage == 3) [NSException raise:@"FTLoadingTestException" format:@"didAppear failure"];
    FTLoadingNodeNow += 100000000;
}
@end
@interface FTLoadingNodeChild : FTLoadingNodeParent @end
@implementation FTLoadingNodeChild
- (void)viewDidLoad {
    FTLoadingNodeNow += 2000000;
    [super viewDidLoad];
    if (self.repeatSuper) [super viewDidLoad];
    FTLoadingNodeNow += 5000000;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; }
- (void)viewWillLayoutSubviews { [super viewWillLayoutSubviews]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; }
@end
@interface FTLoadingNodeInherited : FTLoadingNodeChild @end
@implementation FTLoadingNodeInherited @end

static FTViewControllerSwizzling *testBundleViewControllerSwizzling = nil;
static dispatch_group_t testBundleViewControllerSwizzlingGroup = nil;

@interface FTAutoTrackViewLoadingTimeMock : AddRumDatasHandlerMock
@property (nonatomic, strong, nullable) NSNumber *capturedLoadStartEpochNs;
- (NSUInteger)viewCreateCountForViewName:(NSString *)viewName;
@end

@implementation FTAutoTrackViewLoadingTimeMock {
    NSMutableArray<NSString *> *_createdViewNames;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _createdViewNames = [NSMutableArray array];
    }
    return self;
}

- (void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime {
    [super onCreateView:viewName loadTime:loadTime];
    [_createdViewNames addObject:viewName];
}

- (void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime loadStartEpochNs:(NSNumber *)loadStartEpochNs {
    self.capturedLoadStartEpochNs = loadStartEpochNs;
    [self onCreateView:viewName loadTime:loadTime];
}

- (NSUInteger)viewCreateCountForViewName:(NSString *)viewName {
    NSPredicate *matchingName = [NSPredicate predicateWithFormat:@"SELF == %@", viewName];
    return [_createdViewNames filteredArrayUsingPredicate:matchingName].count;
}

@end

@interface FTAutoTrackAllViewControllerHandler : NSObject<FTUIKitViewTrackingHandler>
@property (nonatomic) uint64_t clockAdvance;
@property (nonatomic) BOOL rejectView;
@property (nonatomic, copy) void (^onView)(UIViewController *viewController);
@end

@implementation FTAutoTrackAllViewControllerHandler
- (FTRUMView *)rumViewForViewController:(UIViewController *)viewController{
    if (self.onView) self.onView(viewController);
    FTLoadingNodeNow += self.clockAdvance;
    return self.rejectView ? nil : [[FTRUMView alloc] initWithViewName:@"custom-handler-view"];
}
@end

@interface FTAutoTrackTest : KIFTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) NSString *akId;
@property (nonatomic, copy) NSString *akSecret;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *token;
@end

@implementation FTAutoTrackTest

- (void)setUp {
    
    // Put setup code here. This method is called before the invocation of each
   
}
- (FTAutoTrackHandler *)resetAutoTrackHandlerForSwiftUITest{
    FTAutoTrackHandler *handler = [FTAutoTrackHandler sharedInstance];
    [handler shutDown];
    NSMutableArray *stack = [handler valueForKey:@"stack"];
    [stack removeAllObjects];
    return handler;
}
- (FTAutoTrackViewLoadingTimeMock *)startUIKitAutoTrackWithMockHandler{
    FTAutoTrackViewLoadingTimeMock *mock = [FTAutoTrackViewLoadingTimeMock new];
    FTAutoTrackHandler *handler = [self resetAutoTrackHandlerForSwiftUITest];
    // Waiting pumps the main run loop and can finish a previous test's UI
    // transition. Keep collection disabled until instrumentation is ready.
    [self prepareLoadingTimeTestBundleInstrumentation];
    [handler startWithTrackView:YES
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:nil
             swiftUIViewHandler:nil
                  actionHandler:nil
   heatmapIdentifierRegistry:nil];
    return mock;
}
- (void)prepareLoadingTimeTestBundleInstrumentation{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testBundleViewControllerSwizzlingGroup = dispatch_group_create();
        dispatch_group_enter(testBundleViewControllerSwizzlingGroup);
        NSString *testBundleExecutablePath = [NSBundle bundleForClass:FTAutoTrackLoadingTimeTestViewController.class].executablePath;
        testBundleViewControllerSwizzling = [[FTViewControllerSwizzling alloc] initWithInAppIncludes:@[testBundleExecutablePath]
                                                                                  scanLoadedFrameworks:NO];
        [testBundleViewControllerSwizzling swizzleLoadedViewControllerClassesWithCompletion:^{
            dispatch_group_leave(testBundleViewControllerSwizzlingGroup);
        }];
    });

    XCTestExpectation *expectation = [self expectationWithDescription:@"Loading-time test bundle instrumentation"];
    dispatch_group_notify(testBundleViewControllerSwizzlingGroup, dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:5];
}
- (UIWindow *)attachViewControllerViewToWindow:(UIViewController *)viewController{
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    [window addSubview:viewController.view];
    XCTAssertEqual(viewController.view.window, window);
    return window;
}
- (void)tearDown {
    //    [[FTMobileAgent sharedInstance] resetInstance];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [FTMobileAgent shutDown];
    [FTMobileAgent clearAllData];
}
- (void)setSdkWithRum:(BOOL)hasRum{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    FTTraceConfig *trace = [[FTTraceConfig alloc]init];
    trace.enableAutoTrace = YES;
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:trace];\
    if(hasRum){
        FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
        rumConfig.enableTraceUserAction = YES;
        rumConfig.enableTraceUserView = YES;
        rumConfig.enableTraceUserResource = YES;
        rumConfig.enableTrackAppCrash = YES;
        [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    }
}
- (void)testSwiftUIRUMViewAppearReportsLoadTimeAndProperty{
    AddRumDatasHandlerMock *mock = [AddRumDatasHandlerMock new];
    FTAutoTrackHandler *handler = [self resetAutoTrackHandlerForSwiftUITest];
    [handler startWithTrackView:NO
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:nil
             swiftUIViewHandler:nil
                  actionHandler:nil];

    [handler notifyOnAppearWithIdentity:@"swiftui-home"
                                   name:@"Home"
                               property:@{@"source": @"swiftui"}
                               loadTime:@123];

    XCTAssertEqual(mock.viewCreateCount, 1);
    XCTAssertEqualObjects(mock.lastCreateViewName, @"Home");
    XCTAssertEqualObjects(mock.lastLoadTime, @123);
    XCTAssertEqual(mock.viewStartCount, 1);
    XCTAssertEqualObjects(mock.lastStartViewName, @"Home");
    XCTAssertEqualObjects(mock.lastStartProperty[@"source"], @"swiftui");
}
- (void)testSwiftUIRUMViewRepeatedAppearDoesNotStartDuplicateView{
    AddRumDatasHandlerMock *mock = [AddRumDatasHandlerMock new];
    FTAutoTrackHandler *handler = [self resetAutoTrackHandlerForSwiftUITest];
    [handler startWithTrackView:NO
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:nil
             swiftUIViewHandler:nil
                  actionHandler:nil];

    [handler notifyOnAppearWithIdentity:@"swiftui-home" name:@"Home" property:nil loadTime:@123];
    [handler notifyOnAppearWithIdentity:@"swiftui-home" name:@"Home" property:nil loadTime:@456];

    XCTAssertEqual(mock.viewCreateCount, 1);
    XCTAssertEqual(mock.viewStartCount, 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @123);
}
- (void)testSwiftUIRUMViewReappearAfterDisappearStartsNewViewWithZeroLoadTime{
    AddRumDatasHandlerMock *mock = [AddRumDatasHandlerMock new];
    FTAutoTrackHandler *handler = [self resetAutoTrackHandlerForSwiftUITest];
    [handler startWithTrackView:NO
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:nil
             swiftUIViewHandler:nil
                  actionHandler:nil];

    [handler notifyOnAppearWithIdentity:@"swiftui-home" name:@"Home" property:nil loadTime:@123];
    [handler notifyOnDisappearWithIdentity:@"swiftui-home"];
    [handler notifyOnAppearWithIdentity:@"swiftui-home" name:@"Home" property:nil loadTime:@0];

    XCTAssertEqual(mock.viewCreateCount, 2);
    XCTAssertEqual(mock.viewStartCount, 2);
    XCTAssertEqual(mock.viewStopCount, 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @0);
}

- (void)withLoadingNodeClock:(dispatch_block_t)body {
    Method method = class_getClassMethod(FTDateUtil.class, @selector(systemTime));
    IMP original = method_getImplementation(method);
    NSThread *testThread = NSThread.currentThread;
    FTLoadingNodeNow = 0;
    FTLoadingNodeClockReads = 0;
    IMP replacement = imp_implementationWithBlock(^uint64_t(id receiver) {
        if (NSThread.currentThread == testThread) {
            FTLoadingNodeClockReads++;
            return FTLoadingNodeNow;
        }
        return ((uint64_t (*)(id, SEL))original)(receiver, @selector(systemTime));
    });
    method_setImplementation(method, replacement);
    @try { body(); }
    @finally { method_setImplementation(method, original); imp_removeBlock(replacement); }
}
- (void)testUIKitLoadingNodesUseOutermostBoundaries {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        for (Class cls in @[FTLoadingNodeChild.class, FTLoadingNodeInherited.class]) {
            FTLoadingNodeParent *vc = [cls new];
            FTLoadingNodeNow = 0;
            FTLoadingNodeClockReads = 0;
            [vc view];
            XCTAssertEqual(FTLoadingNodeNow, 10000000ULL);
            XCTAssertEqual(FTLoadingNodeClockReads, 2U);
            FTLoadingNodeNow = 1000000000;
            [vc viewWillAppear:NO];
            FTLoadingNodeNow += 50000000;
            vc.reenterAppearance = YES;
            NSUInteger count = mock.viewCreateCount;
            [vc viewDidAppear:NO];
            XCTAssertEqualObjects(mock.lastLoadTime, @60000000);
            XCTAssertEqual(mock.viewCreateCount, count + 1);
            XCTAssertEqual(FTLoadingNodeClockReads, 4U);
            [vc viewDidDisappear:NO];
        }
    }];
}
- (void)testUIKitLoadingNodesSkipUnusedLayoutSampling {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        [vc view];
        UIWindow *window = [self attachViewControllerViewToWindow:vc];
        [vc viewWillAppear:NO];
        NSUInteger reads = FTLoadingNodeClockReads;
        vc.windowChecks = 0;
        for (NSUInteger i = 0; i < 10; i++) [vc viewWillLayoutSubviews];
        XCTAssertEqual(vc.windowChecks, 0U);
        XCTAssertEqual(FTLoadingNodeClockReads, reads);
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @60000000);
        XCTAssertEqual(vc.view.window, window);
    }];
}
- (void)testUIKitLoadingNodesRecoverAfterApplicationException {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        [vc view];
        vc.failLoad = YES;
        XCTAssertThrowsSpecificNamed([vc viewDidLoad], NSException, @"FTLoadingTestException");
        [vc viewWillAppear:NO];
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
        [vc viewDidDisappear:NO];
        vc.failLoad = NO;
        FTLoadingNodeNow = 0;
        [vc viewDidLoad];
        [vc viewWillAppear:NO];
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @60000000);
    }];
}
- (void)testUIKitLoadingNodesRepeatedSuperAndLayoutFallback {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        vc.repeatSuper = YES;
        [vc view];
        XCTAssertEqual(FTLoadingNodeNow, 13000000ULL);
        [vc viewWillLayoutSubviews]; // Not attached: cannot start appearance.
        FTLoadingNodeNow = 1000000000;
        UIWindow *window = [self attachViewControllerViewToWindow:vc];
        [vc viewWillLayoutSubviews];
        NSUInteger reads = FTLoadingNodeClockReads;
        vc.windowChecks = 0;
        [vc viewWillLayoutSubviews];
        XCTAssertEqual(vc.windowChecks, 0U);
        XCTAssertEqual(FTLoadingNodeClockReads, reads);
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @63000000);
        XCTAssertEqual(vc.view.window, window);
    }];
}

- (void)testUIKitLoadingNodesLayoutCannotStartInsideSuperclass {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        [vc view];
        UIWindow *window = [self attachViewControllerViewToWindow:vc];
        [vc viewDidLoad];
        vc.hideLoadedView = YES;
        vc.revealLoadedViewDuringLayout = YES;
        vc.windowChecks = 0;
        [vc viewWillLayoutSubviews];
        XCTAssertEqual(vc.windowChecks, 1U);
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
        XCTAssertEqual(vc.view.window, window);
    }];
}
- (void)testUIKitLoadingNodesReleaseEveryLifecycleOwnerAfterException {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        for (NSUInteger stage = 1; stage <= 3; stage++) {
            FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
            [vc view];
            UIWindow *window = [self attachViewControllerViewToWindow:vc];
            vc.throwStage = stage;
            if (stage == 1) XCTAssertThrowsSpecificNamed([vc viewWillAppear:NO], NSException, @"FTLoadingTestException");
            if (stage == 2) XCTAssertThrowsSpecificNamed([vc viewWillLayoutSubviews], NSException, @"FTLoadingTestException");
            if (stage == 3) XCTAssertThrowsSpecificNamed([vc viewDidAppear:NO], NSException, @"FTLoadingTestException");
            [vc viewDidDisappear:NO];
            vc.throwStage = 0;
            FTLoadingNodeNow = 0;
            [vc viewDidLoad];
            if (stage == 2) [vc viewWillLayoutSubviews]; else [vc viewWillAppear:NO];
            FTLoadingNodeNow += 50000000;
            [vc viewDidAppear:NO];
            XCTAssertEqualObjects(mock.lastLoadTime, @60000000);
            XCTAssertEqual(vc.view.window, window);
            [vc viewDidDisappear:NO];
        }
    }];
}
- (void)testUIKitLoadingNodesCustomRuleDoesNotChangeEndpointOrConsumeRejectedView {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackAllViewControllerHandler *rule = [FTAutoTrackAllViewControllerHandler new];
    rule.clockAdvance = 200000000;
    rule.rejectView = YES;
    [[FTAutoTrackHandler sharedInstance] setValue:rule forKey:@"uiKitViewTrackingHandler"];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        [vc view];
        [vc viewWillAppear:NO];
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO];
        XCTAssertEqual(mock.viewCreateCount, 0);
        rule.rejectView = NO;
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastCreateViewName, @"custom-handler-view");
        XCTAssertEqualObjects(mock.lastLoadTime, @60000000);
        XCTAssertEqual(mock.viewCreateCount, 1);
        [vc viewDidDisappear:NO];
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @0);
    }];
}
- (void)testUIKitLoadingNodesPreferredStartAndBackgroundInvalidation {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        [vc view];
        UIWindow *window = [self attachViewControllerViewToWindow:vc];
        [vc viewDidLoad]; // Discard lifecycle callbacks caused by attaching the test window.
        FTLoadingNodeNow = 1000000000;
        [vc viewWillLayoutSubviews];
        FTLoadingNodeNow += 20000000;
        [vc viewWillAppear:NO];
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @60000000);
        [vc viewDidDisappear:NO];
        [vc viewDidLoad];
        [vc viewWillAppear:NO];
        [UIViewController ft_invalidatePendingViewLoadDurations];
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
        XCTAssertEqual(vc.view.window, window);
    }];
}

- (void)testUIKitLoadingNodesNotifyWithoutCallingSuper {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTAutoTrackNoSuperViewDidAppearViewController *vc = [FTAutoTrackNoSuperViewDidAppearViewController new];
        [vc view];
        [vc viewWillAppear:NO];
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO];
        XCTAssertEqualObjects(mock.lastLoadTime, @50000000);
        XCTAssertEqual(mock.viewCreateCount, 1);
    }];
}
- (void)testUIKitLoadingNodesBaseAppearanceReentryAndExceptionCleanup {
    [self assertBaseAppearanceReentryAndExceptionCleanup];
}
- (void)testUIKitLoadingNodesBaseAppearanceAfterPendingHostCallback {
    __block BOOL deliveredPendingAppearance = NO;
    FTLoadingNodeParent *unrelatedController = [FTLoadingNodeParent new];
    // Reproduce a host transition left queued by an earlier UI test.
    dispatch_async(dispatch_get_main_queue(), ^{
        [unrelatedController viewDidAppear:NO];
        deliveredPendingAppearance = YES;
    });
    [self assertBaseAppearanceReentryAndExceptionCleanup];
    XCTAssertTrue(deliveredPendingAppearance);
}
- (void)assertBaseAppearanceReentryAndExceptionCleanup {
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    XCTAssertEqual(mock.viewCreateCount, 0);
    XCTAssertEqual(mock.viewStartCount, 0);
    FTAutoTrackAllViewControllerHandler *rule = [FTAutoTrackAllViewControllerHandler new];
    [[FTAutoTrackHandler sharedInstance] setValue:rule forKey:@"uiKitViewTrackingHandler"];
    [self withLoadingNodeClock:^{
        // Exercise the uninstrumented base lifecycle used by SwiftUI controllers.
        UIViewController *vc = [UIViewController new];
        vc.ft_viewLoadStartTime = @0;
        id state = [vc ft_viewLoadingStateCreateIfNeeded:NO];
        [state setValue:@YES forKey:@"usesSwiftUIBaseLifecycleLoadingTime"];
        FTLoadingNodeNow = 50000000;
        rule.onView = ^(UIViewController *controller) {
            [NSException raise:@"FTLoadingTestException" format:@"custom rule failure"];
        };
        XCTAssertThrowsSpecificNamed([vc viewDidAppear:NO], NSException, @"FTLoadingTestException");
        __block NSUInteger calls = 0;
        rule.onView = ^(UIViewController *controller) {
            calls++;
            if (calls == 1) [controller viewDidAppear:NO];
        };
        FTLoadingNodeNow = 100000000;
        [vc viewDidAppear:NO];
        XCTAssertEqual(calls, 1U);
        XCTAssertEqual(mock.viewCreateCount, 1);
        XCTAssertEqualObjects(mock.lastLoadTime, @50000000);
        rule.onView = nil;
    }];
}
- (void)testUIKitLoadingNodeBenchmark {
    [self startUIKitAutoTrackWithMockHandler];
    XCTAssertTrue(NSThread.isMainThread);
    Class stateClass = NSClassFromString(@"FTViewLoadingState");
    NSLog(@"FTLoadingBenchmark implementation=%@ stateBytes=%zu",
          class_getProperty(stateClass, "viewDidLoadInProgress") ? @"flags" : @"depth",
          class_getInstanceSize(stateClass));
    const NSUInteger iterations = 200000;
    for (Class cls in @[FTLoadingNodeParent.class, FTLoadingNodeChild.class, FTLoadingNodeInherited.class]) {
        FTLoadingNodeParent *vc = [cls new];
        [vc view];
        [vc viewWillAppear:NO];
        for (NSUInteger phase = 0; phase < 2; phase++) {
            if (phase) [vc viewDidAppear:NO];
            for (NSUInteger i = 0; i < 10000; i++) [vc viewWillLayoutSubviews];
            for (NSUInteger sample = 0; sample < 10; sample++) {
                uint64_t start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
                for (NSUInteger i = 0; i < iterations; i++) [vc viewWillLayoutSubviews];
                uint64_t elapsed = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start;
                NSLog(@"FTLoadingBenchmark %@ phase=%lu ns/call=%.2f", NSStringFromClass(cls), (unsigned long)phase, elapsed / (double)iterations);
            }
        }
        [vc viewDidDisappear:NO];
    }
}

- (void)testUIKitLoadingTimeUsesLayoutFallbackUntilViewDidAppearAndIgnoresPreloadGap{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];
    viewController.viewDidLoadDelay = 0.01;
    viewController.viewWillLayoutSubviewsDelay = 0.02;

    [viewController view];
    [viewController viewWillLayoutSubviews];
    [tester waitForTimeInterval:0.1];
    UIWindow *window = [self attachViewControllerViewToWindow:viewController];
    [viewController viewWillLayoutSubviews];
    XCTAssertNil(viewController.ft_loadDuration);

    [viewController viewDidAppear:NO];

    XCTAssertEqual(viewController.view.window, window);
    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastCreateViewName, NSStringFromClass(viewController.class));
    XCTAssertGreaterThan([mock.lastLoadTime unsignedLongLongValue], (uint64_t)20000000);
    XCTAssertLessThan([mock.lastLoadTime unsignedLongLongValue], (uint64_t)80000000);
    XCTAssertNotNil(mock.capturedLoadStartEpochNs);
    XCTAssertLessThan(mock.capturedLoadStartEpochNs.longLongValue, [NSDate ft_currentNanosecondTimeStamp]);
    XCTAssertNil(viewController.ft_viewLoadStartTime);
    XCTAssertNil(viewController.ft_viewLoadStartEpochNs);
}
- (void)testUIKitLoadingTimeIgnoresLayoutFallbackBeforeViewIsAttachedToWindow{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];

    [viewController view];
    [viewController viewWillLayoutSubviews];
    [tester waitForTimeInterval:0.1];
    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
}
- (void)testUIKitLoadingTimeUsesViewDidAppearStartAfterViewWillAppear{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    [self withLoadingNodeClock:^{
        FTLoadingNodeChild *vc = [FTLoadingNodeChild new];
        [vc view]; // 2 ms + 3 ms + 5 ms = 10 ms.
        [vc viewWillAppear:NO];
        FTLoadingNodeNow += 20000000;
        [vc viewWillLayoutSubviews];
        FTLoadingNodeNow += 50000000;
        [vc viewDidAppear:NO]; // Application callback advances the clock by another 100 ms.
        XCTAssertEqualObjects(mock.lastLoadTime, @80000000);
        XCTAssertEqual(mock.viewCreateCount, 1);
        XCTAssertEqual(FTLoadingNodeNow, 180000000ULL);
    }];
}
- (void)testUIKitLoadingTimeUsesViewDidAppearStartWithoutLayout{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];
    viewController.viewDidLoadDelay = 0.01;
    viewController.viewWillAppearDelay = 0.02;

    [viewController view];
    [viewController viewWillAppear:NO];
    XCTAssertNil(viewController.ft_loadDuration);

    [viewController viewDidAppear:NO];

    XCTAssertNil(viewController.ft_viewLoadStartTime);
    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertGreaterThan([mock.lastLoadTime unsignedLongLongValue], (uint64_t)20000000);
}
- (void)testUIKitLoadingTimeReportsNegativeOneWhenNoDisplayCallbackCompletes{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];

    [viewController view];
    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
}
- (void)testDefaultUIKitTrackingReportsNegativeOneForNonBlacklistedSystemViewControllers{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    UIViewController *viewController = [UIViewController new];
    UINavigationController *navigationController = [UINavigationController new];

    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));

    [viewController viewDidDisappear:NO];
    [viewController viewDidAppear:NO];
    [navigationController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 2);
    XCTAssertEqualObjects(mock.lastLoadTime, @0);
}
- (void)testUIKitLoadingTimePreScansCustomViewControllersBeforeInstantiation{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackNoSuperViewDidAppearViewController *viewController = [FTAutoTrackNoSuperViewDidAppearViewController new];
    viewController.viewDidLoadDelay = 0.02;

    [viewController view];
    [viewController viewWillAppear:NO];
    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertGreaterThan([mock.lastLoadTime unsignedLongLongValue], (uint64_t)20000000);
}
- (void)testUIKitLoadingTimeReportsNegativeOneWhenAnInstrumentedViewHasNoInitialState{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];

    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
}
- (void)testCustomUIKitTrackingHandlerCanTrackSystemViewControllers{
    AddRumDatasHandlerMock *mock = [AddRumDatasHandlerMock new];
    FTAutoTrackHandler *handler = [self resetAutoTrackHandlerForSwiftUITest];
    FTAutoTrackAllViewControllerHandler *viewHandler = [FTAutoTrackAllViewControllerHandler new];
    [handler startWithTrackView:YES
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:viewHandler
             swiftUIViewHandler:nil
                  actionHandler:nil
   heatmapIdentifierRegistry:nil];

    [[UIViewController new] viewDidAppear:NO];

    XCTAssertEqual(mock.viewCreateCount, 1);
    XCTAssertEqualObjects(mock.lastCreateViewName, @"custom-handler-view");
}
- (void)testCustomUIKitTrackingHandlerReportsNegativeOneForBlacklistedViewControllerWithoutLoadingTime{
    AddRumDatasHandlerMock *mock = [AddRumDatasHandlerMock new];
    FTAutoTrackHandler *handler = [self resetAutoTrackHandlerForSwiftUITest];
    FTAutoTrackAllViewControllerHandler *viewHandler = [FTAutoTrackAllViewControllerHandler new];
    [handler startWithTrackView:YES
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:viewHandler
             swiftUIViewHandler:nil
                  actionHandler:nil
   heatmapIdentifierRegistry:nil];

    UINavigationController *viewController = [UINavigationController new];
    [viewController viewDidAppear:NO];

    XCTAssertEqual(mock.viewCreateCount, 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));

    [viewController viewDidDisappear:NO];
    [viewController viewDidAppear:NO];

    XCTAssertEqual(mock.viewCreateCount, 2);
    XCTAssertEqualObjects(mock.lastLoadTime, @0);
}
- (void)testUIKitLoadingTimeReportsNegativeOneWhenBackgroundInvalidatesPendingLoad{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];

    [viewController view];
    [UIViewController ft_invalidatePendingViewLoadDurations];
    [viewController viewWillAppear:NO];
    [viewController viewWillLayoutSubviews];
    [viewController viewDidAppear:NO];

    XCTAssertNil(viewController.ft_loadDuration);
    XCTAssertNil(viewController.ft_viewLoadStartTime);
    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
}
- (void)testUIKitLoadingTimeReportsNegativeOneWhenBackgroundInvalidatesPendingAppearance{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];

    [viewController view];
    [viewController viewWillAppear:NO];
    XCTAssertNil(viewController.ft_loadDuration);

    [UIViewController ft_invalidatePendingViewLoadDurations];
    [viewController viewDidAppear:NO];

    XCTAssertNil(viewController.ft_loadDuration);
    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @(-1));
}
- (void)testUIKitLoadingTimeReportsZeroWhenViewReloads{
    FTAutoTrackViewLoadingTimeMock *mock = [self startUIKitAutoTrackWithMockHandler];
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];
    viewController.viewWillAppearDelay = 0.01;

    [viewController view];
    [viewController viewWillAppear:NO];
    [viewController viewDidAppear:NO];
    [viewController viewDidDisappear:NO];
    [viewController viewWillAppear:NO];
    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 2);
    XCTAssertEqual(mock.viewStopCount, 1);
    XCTAssertEqualObjects(mock.lastLoadTime, @0);
}
- (void)testAutoTableViewClick{
    [self setSdkWithRum:YES];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    DemoViewController *demovc = [[DemoViewController alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:demovc];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
    
    [demovc view];
    [demovc viewWillAppear:NO];
    [demovc viewDidAppear:NO];
    [[tester waitForViewWithAccessibilityLabel:@"BindUser"] tap];
    [tester waitForTimeInterval:0.1];
    [[tester waitForViewWithAccessibilityLabel:@"UserLogout"] tap];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            XCTAssertTrue([actionName hasPrefix:@"[UITableViewCell]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    
}
- (void)testTapGes{
    [self setSdkWithRum:YES];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:1];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:0.2];
    [[tester waitForViewWithAccessibilityLabel:@"LABLE_CLICK"] tap];
    [tester waitForTimeInterval:0.2];
    [[tester waitForViewWithAccessibilityLabel:@"LABLE_CLICK"] tap];
    [tester waitForTimeInterval:0.2];

    // The current RUM action is persisted when the next RUM event is processed.
    [[FTGlobalRumManager sharedInstance].rumManager stopView];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasLabelClickAction = NO;
    NSMutableArray *clickActionNames = [NSMutableArray array];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            if (actionName) {
                [clickActionNames addObject:actionName];
            }
            if ([actionName isEqualToString:@"[UILabel][label]"]) {
                hasLabelClickAction = YES;
                *stop = YES;
            }
        }
    }];
    
    XCTAssertTrue(newArray.count>0);
    XCTAssertTrue(hasLabelClickAction, @"Expected label click action, got %@", clickActionNames);
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:1];
    
}
- (void)testLongPressGes{
    [self setSdkWithRum:YES];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:1];
    [[tester waitForViewWithAccessibilityLabel:@"IMAGE_CLICK"] longPressAtPoint:CGPointMake(20, 10) duration:1];
    [tester waitForTimeInterval:1];
    [[tester waitForViewWithAccessibilityLabel:@"alert cancel"] tap];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[UIImageView](order_status_top)"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
}
- (void)testButtonClick{
    [self setSdkWithRum:YES];
    [[tester waitForViewWithAccessibilityLabel:@"UITEST"] tap];
    [tester waitForTimeInterval:0.1];
    [[tester waitForViewWithAccessibilityLabel:@"SecondButton"] tap];
    [tester waitForTimeInterval:0.1];
    [[tester waitForViewWithAccessibilityLabel:@"SecondButton"] tap];
    [tester waitForTimeInterval:0.1];
    [[tester waitForViewWithAccessibilityLabel:@"FirstButton"] tap];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            XCTAssertTrue([tags[FT_KEY_ACTION_NAME] isEqualToString:@"[UIButton][ActivityEnd]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    
}

- (void)testCollectionViewCellClick{
    [self setSdkWithRum:YES];
    [[tester waitForViewWithAccessibilityLabel:@"EventFlowLog"] tap];
    [tester waitForTimeInterval:1];
    
    [[tester waitForViewWithAccessibilityLabel:@"cell: 1"] tap];
    [tester waitForTimeInterval:0.2];
    [[tester waitForViewWithAccessibilityLabel:@"cell: 2"] tap];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]&&[tags[FT_KEY_ACTION_TYPE] isEqualToString:@"click"]) {
            NSString *actionName = tags[FT_KEY_ACTION_NAME];
            XCTAssertTrue([actionName isEqualToString:@"[CustomCollectionViewCell]"]);
            *stop = YES;
        }
    }];
    [[tester waitForViewWithAccessibilityLabel:@"home"] tap];
    [tester waitForTimeInterval:0.5];
}
- (void)testResourceUrlHandlerReturnYes{
    [self resourceUrlHandler:YES];
}
- (void)testResourceUrlHandlerReturnNO{
    [self resourceUrlHandler:NO];
}
- (void)resourceUrlHandler:(BOOL)excluded{
    [self setSdkWithRum:NO];
    NSURL * rumUrl = [NSURL URLWithString:[[NSProcessInfo processInfo] environment][@"TRACE_URL"]];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"AA"];
    rumConfig.enableTraceUserAction = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.resourceUrlHandler = ^BOOL(NSURL *url) {
        return excluded;
    };
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async operation timeout"];
    [FTModelHelper startView];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    [tester waitForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    __block BOOL hasRes = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            NSURL *url = [NSURL URLWithString:tags[FT_KEY_RESOURCE_URL]];
            XCTAssertTrue([url.host isEqual:rumUrl.host]);
            hasRes = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasRes != excluded);
}
- (void)testIntakeUrlReturnYes{
    [self intakeUrl:YES];
}
- (void)testIntakeUrlReturnNO{
    [self intakeUrl:NO];
}
- (void)intakeUrl:(BOOL)trace{
    [self setSdkWithRum:YES];
    [[FTMobileAgent sharedInstance] isIntakeUrl:^BOOL(NSURL * _Nonnull url) {
        return trace;
    }];
    XCTestExpectation *expectation= [self expectationWithDescription:@"Async operation timeout"];
    [FTModelHelper startView];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
           XCTAssertNil(error);
       }];
    [tester waitForTimeInterval:0.5];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    __block BOOL hasRes = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_RESOURCE]) {
            hasRes = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasRes == trace);
}
- (void)testActionName{
    [self setSdkWithRum:YES];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[UITestVC alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
    
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    [self.testVC viewDidAppear:NO];
    
    XCTAssertTrue([self.testVC.uiswitch.ft_actionName isEqualToString:@"[UISwitch]Off"]);
    XCTAssertTrue([self.testVC.firstButton.ft_actionName isEqualToString:@"[UIButton][ActivityStart]"]);
    XCTAssertTrue([self.testVC.stepper.ft_actionName isEqualToString:@"[UIStepper]0.00"]);
    XCTAssertTrue([self.testVC.label.ft_actionName isEqualToString:@"[UILabel][label]"]);
    XCTAssertTrue([self.testVC.segmentedControl.ft_actionName isEqualToString:@"[UISegmentedControl]first"]);
    
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    [self networkUpload:session handler:completionHandler];
}
- (void)networkUpload:(NSURLSession *)session handler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    
    NSString * urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,error):nil;
    }];
    
    [task resume];
}
@end
