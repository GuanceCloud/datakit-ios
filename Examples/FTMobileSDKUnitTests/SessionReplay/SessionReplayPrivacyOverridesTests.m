//
//  SessionReplayPrivacyOverridesTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/3/14.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "UIView+FTSRPrivacy.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"
@interface SessionReplayPrivacyOverridesTests : XCTestCase

@end

@implementation SessionReplayPrivacyOverridesTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testTouchPrivacyOverrides{
    UIView *view = [[UIView alloc]init];
    XCTAssertTrue(view.sessionReplayPrivacyOverrides.touchPrivacy == FTTouchPrivacyLevelOverrideNone);
    view.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideHide;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nTouchPrivacy isEqual:@(FTTouchPrivacyLevelHide)]);
    view.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideShow;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nTouchPrivacy isEqual: @(FTTouchPrivacyLevelShow)]);
    view.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideNone;
    XCTAssertTrue(view.sessionReplayPrivacyOverrides.nTouchPrivacy == nil);
}

- (void)testImagePrivacyOverrides{
    UIView *view = [[UIView alloc]init];
    XCTAssertTrue(view.sessionReplayPrivacyOverrides.imagePrivacy == FTImagePrivacyLevelOverrideNone);
    view.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideMaskAll;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nImagePrivacy isEqual:@(FTImagePrivacyLevelMaskAll)]);
    
    view.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideMaskNone;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nImagePrivacy isEqual: @(FTImagePrivacyLevelMaskNone)]);
    
    view.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideMaskNonBundledOnly;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nImagePrivacy isEqual:@(FTImagePrivacyLevelMaskNonBundledOnly)]);
    
    view.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideNone;
    
    XCTAssertTrue(view.sessionReplayPrivacyOverrides.nImagePrivacy == nil);
}

- (void)testTextAndInputPrivacyOverrides{
    UIView *view = [[UIView alloc]init];
    XCTAssertTrue(view.sessionReplayPrivacyOverrides.textAndInputPrivacy == FTTextAndInputPrivacyLevelOverrideNone);
    
    view.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideMaskAll;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nTextAndInputPrivacy isEqual:@(FTTextAndInputPrivacyLevelMaskAll)]);
    
    view.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideMaskAllInputs;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nTextAndInputPrivacy isEqual: @(FTTextAndInputPrivacyLevelMaskAllInputs)]);
    
    view.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideMaskSensitiveInputs;
    XCTAssertTrue([view.sessionReplayPrivacyOverrides.nTextAndInputPrivacy isEqual:@(FTTextAndInputPrivacyLevelMaskSensitiveInputs)]);
    
    view.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideNone;
    
    XCTAssertTrue(view.sessionReplayPrivacyOverrides.nTextAndInputPrivacy == nil);
}

- (void)testPrivacyOverridesViewMerge{
    UIView *view = [[UIView alloc]init];
    UIView *subView = [[UIView alloc]init];
    
    view.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideHide;
    view.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideMaskSensitiveInputs;
    view.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideMaskNonBundledOnly;
    view.sessionReplayPrivacyOverrides.hide = NO;
    
    subView.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideShow;
    subView.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideMaskAll;
    subView.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideMaskNone;
    subView.sessionReplayPrivacyOverrides.hide = YES;
    
    FTSessionReplayPrivacyOverrides *overrides = [FTSessionReplayPrivacyOverrides mergeChild:subView.sessionReplayPrivacyOverrides parent:view.sessionReplayPrivacyOverrides];
    
    XCTAssertTrue(overrides.hide = YES);
    XCTAssertTrue([overrides.nTextAndInputPrivacy isEqual:@( FTTextAndInputPrivacyLevelMaskAll)]);
    XCTAssertTrue([overrides.nImagePrivacy isEqual: @(FTImagePrivacyLevelMaskNone)]);
    XCTAssertTrue([overrides.nTouchPrivacy isEqual: @(FTTouchPrivacyLevelShow)]);
    XCTAssertTrue(overrides.hide = YES);
}

- (void)testPrivacyOverridesViewMerge_childPrivacyNone{
    UIView *view = [[UIView alloc]init];
    UIView *subView = [[UIView alloc]init];
    
    view.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideHide;
    view.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideMaskSensitiveInputs;
    view.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideMaskNonBundledOnly;
    view.sessionReplayPrivacyOverrides.hide = NO;
    
    subView.sessionReplayPrivacyOverrides.touchPrivacy = FTTouchPrivacyLevelOverrideNone;
    subView.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelOverrideNone;
    subView.sessionReplayPrivacyOverrides.imagePrivacy = FTImagePrivacyLevelOverrideNone;
    subView.sessionReplayPrivacyOverrides.hide = YES;
    
    FTSessionReplayPrivacyOverrides *overrides = [FTSessionReplayPrivacyOverrides mergeChild:subView.sessionReplayPrivacyOverrides parent:view.sessionReplayPrivacyOverrides];
    
    XCTAssertTrue([overrides.nTextAndInputPrivacy isEqual:@( FTTextAndInputPrivacyLevelMaskSensitiveInputs)]);
    XCTAssertTrue([overrides.nImagePrivacy isEqual: @(FTImagePrivacyLevelMaskNonBundledOnly)]);
    XCTAssertTrue([overrides.nTouchPrivacy isEqual: @(FTTouchPrivacyLevelHide)]);
    XCTAssertTrue(overrides.hide = YES);
}
@end
