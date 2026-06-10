//
//  SessionReplayConfigTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/4/2.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTSessionReplayConfig.h"
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTUnsupportedViewRecorder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshotBuilder.h"

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
