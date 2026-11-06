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
#import <stdatomic.h>
#import "UIViewController+FTAutoTrack.h"
#import "FTViewControllerSwizzling.h"
#import "FTSwizzler.h"

@interface UIViewController (FTInitializationTesting)
+ (NSArray<NSString *> *)ft_loadingTimeCandidateClassNamesFromClassNames:(NSArray<NSString *> *)classNames;
+ (BOOL)ft_viewLoadingDurationInstrumentedForClass:(Class)controllerClass;
@end

// Refer to these fixtures only by name until the application deliberately creates an instance.
static atomic_uint parentInitializations;
static atomic_uint childInitializations;
static atomic_uint navigationInitializations;

@interface FTUnusedScanParentController : UIViewController @end
@implementation FTUnusedScanParentController
+ (void)initialize {
    if (self == objc_lookUpClass("FTUnusedScanParentController")) {
        atomic_fetch_add(&parentInitializations, 1);
    }
}
@end

@interface FTUnusedScanChildController : FTUnusedScanParentController @end
@implementation FTUnusedScanChildController
+ (void)initialize {
    if (self == objc_lookUpClass("FTUnusedScanChildController")) {
        atomic_fetch_add(&childInitializations, 1);
    }
}
@end

@interface FTUnusedScanNavigationController : UINavigationController @end
@implementation FTUnusedScanNavigationController
+ (void)initialize {
    if (self == objc_lookUpClass("FTUnusedScanNavigationController")) {
        atomic_fetch_add(&navigationInitializations, 1);
    }
}
@end

static atomic_uint macroInitializations;
@interface FTUnusedSwizzleMacroClass : NSObject
+ (NSInteger)ft_classProbeValue;
- (NSInteger)ft_instanceProbeValue;
@end
@implementation FTUnusedSwizzleMacroClass
+ (void)initialize {
    if (self == objc_lookUpClass("FTUnusedSwizzleMacroClass")) {
        atomic_fetch_add(&macroInitializations, 1);
    }
}
+ (NSInteger)ft_classProbeValue { return 40; }
- (NSInteger)ft_instanceProbeValue { return 10; }
@end

@interface FTViewControllerInitializationTests : XCTestCase @end
@implementation FTViewControllerInitializationTests
- (void)setUp {
    [super setUp];
    // The image-wide scan below must leave the separate policy suite's fixtures unused.
    [UIViewController ft_configureViewLoadingTimeEnabled:YES classNameExcludes:[NSSet setWithObjects:
        @"FTLoadingExcludedController", @"FTLoadingInheritedParent", @"FTLoadingInheritedExcludedChild",
        @"FTLoadingEnabledController", @"FTLoadingDependencyController", @"FTLoadingDisabledFreshController", @"FTLoadingRescanController", nil]];
}
- (void)tearDown {
    [UIViewController ft_configureViewLoadingTimeEnabled:YES classNameExcludes:[NSSet set]];
    [super tearDown];
}
- (void)testSwizzleMacrosPreserveLazyInitializationAndOriginalImplementations {
    Class unusedClass = objc_lookUpClass("FTUnusedSwizzleMacroClass");
    XCTAssertEqual(atomic_load(&macroInitializations), 0u);
    static const char instanceKey;
    FTSwizzlerInstanceMethod(unusedClass, @selector(ft_instanceProbeValue), FTSWReturnType(NSInteger),
                            FTSWArguments(), FTSWReplacement({ return FTSWCallOriginal() + 3; }),
                            FTSwizzlerModeOncePerClass, &instanceKey);
    XCTAssertEqual(atomic_load(&macroInitializations), 0u);
    FTSwizzlerClassMethod(unusedClass, @selector(ft_classProbeValue), FTSWReturnType(NSInteger),
                         FTSWArguments(), FTSWReplacement({ return FTSWCallOriginal() + 2; }));
    XCTAssertEqual(atomic_load(&macroInitializations), 0u);
    XCTAssertEqual([unusedClass ft_classProbeValue], 42);
    XCTAssertEqual(atomic_load(&macroInitializations), 1u);
    FTUnusedSwizzleMacroClass *instance = [[unusedClass alloc] init];
    XCTAssertEqual([instance ft_instanceProbeValue], 13);
    XCTAssertEqual(atomic_load(&macroInitializations), 1u);
}

- (void)assertUnusedControllersAreNotInitialized {
    XCTAssertEqual(atomic_load(&parentInitializations), 0u);
    XCTAssertEqual(atomic_load(&childInitializations), 0u);
    XCTAssertEqual(atomic_load(&navigationInitializations), 0u);
}

- (void)testFilteringAndAsynchronousImageScanningPreserveLazyInitialization {
    [self assertUnusedControllersAreNotInitialized];
    NSArray *names = @[@"FTUnusedScanParentController", @"FTUnusedScanChildController",
                       @"FTUnusedScanNavigationController", @"NSObject", @"UIViewController",
                       @"FTNonexistentScanController"];
    NSArray *expected = @[@"FTUnusedScanParentController", @"FTUnusedScanChildController"];
    XCTAssertEqualObjects([UIViewController ft_loadingTimeCandidateClassNamesFromClassNames:names], expected);
    [self assertUnusedControllersAreNotInitialized];
    XCTAssertFalse([UIViewController ft_shouldTrackDefaultViewControllerClass:Nil]);
    XCTAssertFalse([UIViewController ft_shouldTrackDefaultViewControllerClass:objc_lookUpClass("FTUnusedScanNavigationController")]);

    // Two complete scans cover background filtering, main-thread hook installation and repeat scans.
    NSString *imagePath = [NSString stringWithUTF8String:class_getImageName(object_getClass(self))];
    for (NSUInteger scan = 0; scan < 2; scan++) {
        XCTestExpectation *finished = [self expectationWithDescription:@"image scan finished"];
        FTViewControllerSwizzling *scanner = [[FTViewControllerSwizzling alloc] initWithInAppIncludes:@[imagePath]
                                                                               scanLoadedFrameworks:NO];
        [scanner swizzleLoadedViewControllerClassesWithCompletion:^{ [finished fulfill]; }];
        [self waitForExpectations:@[finished] timeout:10];
        [self assertUnusedControllersAreNotInitialized];
        for (NSString *name in expected) {
            XCTAssertTrue([UIViewController ft_viewLoadingDurationInstrumentedForClass:objc_lookUpClass(name.UTF8String)]);
        }
        XCTAssertFalse([UIViewController ft_viewLoadingDurationInstrumentedForClass:objc_lookUpClass("FTUnusedScanNavigationController")]);
    }

    // +initialize remains intact and executes at first legitimate application use, parent first.
    __unused id child = [[objc_lookUpClass("FTUnusedScanChildController") alloc] init];
    XCTAssertEqual(atomic_load(&parentInitializations), 1u);
    XCTAssertEqual(atomic_load(&childInitializations), 1u);
    XCTAssertEqual(atomic_load(&navigationInitializations), 0u);
    __unused id navigation = [[objc_lookUpClass("FTUnusedScanNavigationController") alloc] init];
    XCTAssertEqual(atomic_load(&navigationInitializations), 1u);
}
@end
