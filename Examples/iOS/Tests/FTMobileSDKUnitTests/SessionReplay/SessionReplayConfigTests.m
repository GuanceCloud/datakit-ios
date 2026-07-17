//
//  SessionReplayConfigTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/4/2.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTSessionReplayConfig.h"
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTUnsupportedViewRecorder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshotBuilder.h"
#import "FTModuleManager.h"
#import "FTHeatmap.h"
#import "FTSessionReplayFeature.h"
#import "FTFeatureStorage.h"
#import "FTFeatureDirectories.h"
#import "FTDirectory.h"
#import "FTPerformancePreset.h"

@interface SessionReplayHeatmapIdentifierRegistry : NSObject<FTHeatmapIdentifierRegistry>
@property (nonatomic, copy) NSDictionary<NSValue *, FTHeatmapIdentifier *> *identifiers;
@property (nonatomic, assign) BOOL enableHeatmap;
@end

@implementation SessionReplayHeatmapIdentifierRegistry
- (void)setHeatmapIdentifiers:(NSDictionary<NSValue *,FTHeatmapIdentifier *> *)heatmapIdentifiers {
    self.identifiers = [heatmapIdentifiers copy] ?: @{};
}
- (FTHeatmapIdentifier *)heatmapIdentifierForObject:(id)object {
    NSValue *objectIdentifier = [FTHeatmapIdentifier objectIdentifierForObject:object];
    return objectIdentifier ? self.identifiers[objectIdentifier] : nil;
}
@end

static FTFeatureStorage *FTMakeSessionReplayFeatureStorage(NSString *name) {
    NSString *basePath = [NSString stringWithFormat:@"ft-session-replay-heatmap-test/%@/%@", name, NSUUID.UUID.UUIDString];
    FTDirectory *grantedDirectory = [[FTDirectory alloc]initWithSubdirectoryPath:[basePath stringByAppendingPathComponent:@"granted"]];
    FTFeatureDirectories *directories = [[FTFeatureDirectories alloc]initWithGranted:grantedDirectory
                                                                             pending:nil
                                                                        errorSampled:nil];
    NSString *queueLabel = [NSString stringWithFormat:@"com.ft.test.%@", name];
    return [[FTFeatureStorage alloc]initWithFeatureName:name
                                                  queue:dispatch_queue_create(queueLabel.UTF8String, DISPATCH_QUEUE_SERIAL)
                                            directories:directories
                                            performance:[[FTPerformancePreset alloc]init]];
}

@interface SessionReplayConfigTests : XCTestCase

@end

@implementation SessionReplayConfigTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testConfigCopy{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.sampleRate = 50;
    config.imagePrivacy = FTImagePrivacyLevelMaskNone;
    config.textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAllInputs;
    config.touchPrivacy = FTTouchPrivacyLevelShow;
    config.enableHeatmap = YES;
    config.enableSwiftUI = YES;
    
    FTSessionReplayConfig *copyConfig = [config copy];
    XCTAssertTrue(config != copyConfig);
    XCTAssertTrue(config.sampleRate == copyConfig.sampleRate);
    XCTAssertTrue(config.imagePrivacy == copyConfig.imagePrivacy);
    XCTAssertTrue(config.textAndInputPrivacy == copyConfig.textAndInputPrivacy);
    XCTAssertTrue(config.touchPrivacy == copyConfig.touchPrivacy);
    XCTAssertTrue(config.enableSwiftUI == copyConfig.enableSwiftUI);
    XCTAssertTrue(copyConfig.enableHeatmap);
}
- (void)testConfigDefaultHeatmapDisabled{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    XCTAssertFalse(config.enableHeatmap);
}
- (void)testInvalidPrivacyLevelsUseSafeDebugDescriptionDefaults{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    NSArray<NSArray *> *textCases = @[
        @[@(FTTextAndInputPrivacyLevelMaskAll), @"MaskAll"],
        @[@(FTTextAndInputPrivacyLevelMaskAllInputs), @"MaskAllInputs"],
        @[@(FTTextAndInputPrivacyLevelMaskSensitiveInputs), @"MaskSensitiveInputs"],
        @[@((FTTextAndInputPrivacyLevel)-1), @"MaskAll"],
        @[@(FTTextAndInputPrivacyLevelMaskSensitiveInputs + 1), @"MaskAll"],
        @[@(NSUIntegerMax), @"MaskAll"],
    ];
    for (NSArray *testCase in textCases) {
        config.textAndInputPrivacy = [testCase[0] unsignedIntegerValue];
        XCTAssertTrue([config.debugDescription containsString:[@"textAndInputPrivacy:" stringByAppendingString:testCase[1]]]);
    }

    NSArray<NSArray *> *touchCases = @[
        @[@(FTTouchPrivacyLevelHide), @"Hide"],
        @[@(FTTouchPrivacyLevelShow), @"Show"],
        @[@((FTTouchPrivacyLevel)-1), @"Hide"],
        @[@(FTTouchPrivacyLevelShow + 1), @"Hide"],
        @[@(NSUIntegerMax), @"Hide"],
    ];
    for (NSArray *testCase in touchCases) {
        config.touchPrivacy = [testCase[0] unsignedIntegerValue];
        XCTAssertTrue([config.debugDescription containsString:[@"touchPrivacy:" stringByAppendingString:testCase[1]]]);
    }

    NSArray<NSArray *> *imageCases = @[
        @[@(FTImagePrivacyLevelMaskAll), @"MaskAll"],
        @[@(FTImagePrivacyLevelMaskNone), @"MaskNone"],
        @[@(FTImagePrivacyLevelMaskNonBundledOnly), @"MaskNonBundledOnly"],
        @[@((FTImagePrivacyLevel)-1), @"MaskAll"],
        @[@(FTImagePrivacyLevelMaskNonBundledOnly + 1), @"MaskAll"],
        @[@(NSUIntegerMax), @"MaskAll"],
    ];
    for (NSArray *testCase in imageCases) {
        config.imagePrivacy = [testCase[0] unsignedIntegerValue];
        XCTAssertTrue([config.debugDescription containsString:[@"imagePrivacy:" stringByAppendingString:testCase[1]]]);
    }
}
#if TARGET_OS_IOS
- (void)testSessionReplayFeatureSyncsHeatmapEnabledToRegistryOnStart {
    NSObject *staleObject = [NSObject new];
    FTHeatmapIdentifier *staleIdentifier = [[FTHeatmapIdentifier alloc]initWithRawValue:@"stale-id"];
    SessionReplayHeatmapIdentifierRegistry *registry = [SessionReplayHeatmapIdentifierRegistry new];
    registry.identifiers = @{
        [FTHeatmapIdentifier objectIdentifierForObject:staleObject]: staleIdentifier,
    };
    [[FTModuleManager sharedInstance] registerService:@protocol(FTHeatmapIdentifierRegistry) instance:registry];
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.enableHeatmap = YES;
    FTSessionReplayFeature *feature = [[FTSessionReplayFeature alloc]initWithConfig:config];
    FTFeatureStorage *recordStorage = FTMakeSessionReplayFeatureStorage(@"session-replay-records");
    FTFeatureStorage *resourceStorage = FTMakeSessionReplayFeatureStorage(@"session-replay-resources");

    [feature startWithRecordStorage:recordStorage resourceStorage:resourceStorage resourceDataStore:nil];

    XCTAssertTrue(registry.enableHeatmap);
    XCTAssertEqual(registry.identifiers.count, 0);
}

- (void)testSnapshotWritesHeatmapIdentifiersForRecordedUILabelAndUISwitch {
    UIView *rootView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 240, 120)];
    rootView.backgroundColor = UIColor.whiteColor;
    UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(10, 10, 80, 20)];
    label.text = @"Title";
    [rootView addSubview:label];
    UISwitch *switchView = [[UISwitch alloc]initWithFrame:CGRectMake(120, 10, 51, 31)];
    [rootView addSubview:switchView];
    SessionReplayHeatmapIdentifierRegistry *registry = [SessionReplayHeatmapIdentifierRegistry new];
    [[FTModuleManager sharedInstance] registerService:@protocol(FTHeatmapIdentifierRegistry) instance:registry];
    FTViewTreeSnapshotBuilder *builder = [[FTViewTreeSnapshotBuilder alloc]initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];
    builder.enableHeatmap = YES;
    FTSRContext *context = [FTSRContext new];
    context.viewPath = @"DemoViewController";

    [builder takeSnapshot:@[rootView] referenceView:rootView context:context];

    XCTAssertNotNil([registry heatmapIdentifierForObject:label]);
    XCTAssertNotNil([registry heatmapIdentifierForObject:switchView]);
}
#endif
- (void)testSwiftUIRecordingDisabledByDefault{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    XCTAssertFalse(config.enableSwiftUI);
    
    FTViewTreeSnapshotBuilder *builder = [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:config.enableSwiftUI];
    XCTAssertFalse([self recorders:builder.recorders containClassName:@"FTUIHostingViewRecorder"]);
}
- (void)testEnableSwiftUIKeepsSwiftUIRecorderRegistered{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.enableSwiftUI = YES;
    
    FTViewTreeSnapshotBuilder *builder = [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:config.enableSwiftUI];
    XCTAssertTrue([self recorders:builder.recorders containClassName:@"FTUIHostingViewRecorder"]);
}
- (void)testUnsupportedRecorderIgnoresSwiftUIRootWhenSwiftUIDisabled{
    FTUnsupportedViewRecorder *recorder = [[FTUnsupportedViewRecorder alloc] initWithSwiftUIEnabled:NO];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    FTViewTreeRecordingContext *context = [self swiftUIRootContext];
    FTViewAttributes *attributes = [[FTViewAttributes alloc] initWithView:view frameInRootView:view.frame clip:view.bounds overrides:nil];
    
    FTSRNodeSemantics *semantics = [recorder recorder:view attributes:attributes context:context];
    
    XCTAssertNotNil(semantics);
    XCTAssertEqual(semantics.subtreeStrategy, NodeSubtreeStrategyIgnore);
    XCTAssertEqual(semantics.nodes.count, 1);
}
- (void)testUnsupportedRecorderPlaceholderUsesAttributesClip{
    FTUnsupportedViewRecorder *recorder = [[FTUnsupportedViewRecorder alloc] initWithSwiftUIEnabled:NO];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    FTViewTreeRecordingContext *context = [self swiftUIRootContext];
    FTViewAttributes *attributes = [[FTViewAttributes alloc] initWithView:view
                                                           frameInRootView:CGRectMake(0, 0, 100, 100)
                                                                      clip:CGRectMake(10, 20, 70, 60)
                                                                 overrides:nil];

    FTSRNodeSemantics *semantics = [recorder recorder:view attributes:attributes context:context];
    XCTAssertNotNil(semantics);
    XCTAssertEqual(semantics.nodes.count, 1);

    FTUnsupportedViewBuilder *builder = (FTUnsupportedViewBuilder *)semantics.nodes.firstObject;
    NSArray<FTSRWireframe *> *wireframes = [builder buildWireframesWithBuilder:nil];
    XCTAssertEqual(wireframes.count, 1);

    FTSRPlaceholderWireframe *wireframe = (FTSRPlaceholderWireframe *)wireframes.firstObject;

    XCTAssertTrue([wireframe isKindOfClass:FTSRPlaceholderWireframe.class]);
    XCTAssertNotNil(wireframe.clip);
    XCTAssertEqualObjects(wireframe.clip.left, @10);
    XCTAssertEqualObjects(wireframe.clip.top, @20);
    XCTAssertEqualObjects(wireframe.clip.right, @20);
    XCTAssertEqualObjects(wireframe.clip.bottom, @20);
}
- (void)testUnsupportedRecorderAllowsSwiftUIRootWhenSwiftUIEnabled{
    FTUnsupportedViewRecorder *recorder = [[FTUnsupportedViewRecorder alloc] initWithSwiftUIEnabled:YES];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    FTViewTreeRecordingContext *context = [self swiftUIRootContext];
    FTViewAttributes *attributes = [[FTViewAttributes alloc] initWithView:view frameInRootView:view.frame clip:view.bounds overrides:nil];
    
    FTSRNodeSemantics *semantics = [recorder recorder:view attributes:attributes context:context];
    
    XCTAssertNil(semantics);
}
- (void)testConfigPrivacyReflection{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.privacy = FTSRPrivacyMask;
    
    XCTAssertTrue(config.imagePrivacy == FTImagePrivacyLevelMaskAll);
    XCTAssertTrue(config.touchPrivacy == FTTouchPrivacyLevelHide);
    XCTAssertTrue(config.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskAll);
    
    config.privacy = FTSRPrivacyMaskUserInput;
    XCTAssertTrue(config.imagePrivacy == FTImagePrivacyLevelMaskNonBundledOnly);
    XCTAssertTrue(config.touchPrivacy == FTTouchPrivacyLevelHide);
    XCTAssertTrue(config.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskAllInputs);
   
    config.privacy = FTSRPrivacyAllow;
    XCTAssertTrue(config.imagePrivacy == FTImagePrivacyLevelMaskNone);
    XCTAssertTrue(config.touchPrivacy == FTTouchPrivacyLevelShow);
    XCTAssertTrue(config.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskSensitiveInputs);
}

- (void)testConfigPrivacyOverride{
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskSensitiveInputs;
    config.privacy = FTSRPrivacyAllow;
    
    XCTAssertTrue(config.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskSensitiveInputs);
    
    XCTAssertTrue(config.touchPrivacy == FTTouchPrivacyLevelHide);
    XCTAssertTrue(config.imagePrivacy == FTImagePrivacyLevelMaskAll);
    
    FTSessionReplayConfig *config2 = [FTSessionReplayConfig new];
    config2.imagePrivacy = FTImagePrivacyLevelMaskNonBundledOnly;
    config2.privacy = FTSRPrivacyMaskUserInput;
    
    XCTAssertTrue(config2.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskAll);
    
    XCTAssertTrue(config2.touchPrivacy == FTTouchPrivacyLevelHide);
    XCTAssertTrue(config2.imagePrivacy == FTImagePrivacyLevelMaskNonBundledOnly);
    
    
    FTSessionReplayConfig *config3 = [FTSessionReplayConfig new];
    config3.touchPrivacy = FTTouchPrivacyLevelShow;
    config3.privacy = FTSRPrivacyMaskUserInput;
    
    XCTAssertTrue(config3.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskAll);
    
    XCTAssertTrue(config3.touchPrivacy == FTTouchPrivacyLevelShow);
    XCTAssertTrue(config3.imagePrivacy == FTImagePrivacyLevelMaskAll);
}
- (BOOL)recorders:(NSArray *)recorders containClassName:(NSString *)className{
    for (id recorder in recorders) {
        if ([NSStringFromClass([recorder class]) isEqualToString:className]) {
            return YES;
        }
    }
    return NO;
}
- (FTViewTreeRecordingContext *)swiftUIRootContext{
    FTViewTreeRecordingContext *context = [FTViewTreeRecordingContext new];
    context.viewIDGenerator = [FTSRViewID new];
    context.viewControllerContext = [FTViewControllerContext new];
    context.viewControllerContext.parentType = ViewControllerTypeSwiftUI;
    context.viewControllerContext.isRootView = YES;
    return context;
}
@end
