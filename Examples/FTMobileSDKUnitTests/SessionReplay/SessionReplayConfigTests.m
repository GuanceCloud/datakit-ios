//
//  SessionReplayConfigTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/4/2.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTSessionReplayConfig.h"

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
    
    FTSessionReplayConfig *copyConfig = [config copy];
    XCTAssertTrue(config != copyConfig);
    XCTAssertTrue(config.sampleRate == copyConfig.sampleRate);
    XCTAssertTrue(config.imagePrivacy == copyConfig.imagePrivacy);
    XCTAssertTrue(config.textAndInputPrivacy == copyConfig.textAndInputPrivacy);
    XCTAssertTrue(config.touchPrivacy == copyConfig.touchPrivacy);
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
@end
