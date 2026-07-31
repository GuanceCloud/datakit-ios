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
#import "DemoViewController.h"
#import "FTConstants.h"
#import "FTGlobalRumManager+Private.h"
#import "FTRUMManager.h"
#import "FTModelHelper.h"
#import "TestSessionDelegate.h"
#import "FTNetworkMock.h"
#import "AddRumDatasHandlerMock.h"

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

static FTViewControllerSwizzling *testBundleViewControllerSwizzling = nil;
static dispatch_group_t testBundleViewControllerSwizzlingGroup = nil;

@interface FTAutoTrackViewLoadingTimeMock : AddRumDatasHandlerMock
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

- (NSUInteger)viewCreateCountForViewName:(NSString *)viewName {
    NSPredicate *matchingName = [NSPredicate predicateWithFormat:@"SELF == %@", viewName];
    return [_createdViewNames filteredArrayUsingPredicate:matchingName].count;
}

@end

@interface FTAutoTrackAllViewControllerHandler : NSObject<FTUIKitViewTrackingHandler>
@end

@implementation FTAutoTrackAllViewControllerHandler
- (FTRUMView *)rumViewForViewController:(UIViewController *)viewController{
    return [[FTRUMView alloc] initWithViewName:@"custom-handler-view"];
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
    [handler startWithTrackView:YES
                         action:NO
            addRumDatasDelegate:mock
                    viewHandler:nil
             swiftUIViewHandler:nil
                  actionHandler:nil
                 displayMonitor:nil];
    [self prepareLoadingTimeTestBundleInstrumentation];
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
    FTAutoTrackLoadingTimeTestViewController *viewController = [FTAutoTrackLoadingTimeTestViewController new];
    viewController.viewDidLoadDelay = 0.02;
    viewController.viewWillAppearDelay = 0.02;
    viewController.viewWillLayoutSubviewsDelay = 0.05;
    viewController.viewDidAppearDelay = 0.05;

    [viewController view];
    [viewController viewWillAppear:NO];
    XCTAssertNil(viewController.ft_loadDuration);

    [viewController viewWillLayoutSubviews];
    [viewController viewDidAppear:NO];

    XCTAssertEqual([mock viewCreateCountForViewName:NSStringFromClass(viewController.class)], 1);
    XCTAssertGreaterThan([mock.lastLoadTime unsignedLongLongValue], (uint64_t)80000000);
    XCTAssertLessThan([mock.lastLoadTime unsignedLongLongValue], (uint64_t)120000000);
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
                 displayMonitor:nil];

    [[UIViewController new] viewDidAppear:NO];

    XCTAssertEqual(mock.viewCreateCount, 1);
    XCTAssertEqualObjects(mock.lastCreateViewName, @"custom-handler-view");
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
