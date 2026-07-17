//
//  UIView+FTSRPrivacy.h
//  SessionReplay
//
//  Created by hulilei on 2025/3/11.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import "FTSessionReplayPrivacyOverrides.h"

NS_ASSUME_NONNULL_BEGIN

/// Provide access to FTSessionReplayPrivacyOverrides for any UIView
@interface UIView (FTSRPrivacy)

/// UIView manages session replay privacy override settings
/// Usage example:
/// swift: `myView.sessionReplayPrivacyOverrides.textAndInputPrivacy = .maskAll`
/// oc: `myView.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAll`
@property (nonatomic, strong, readonly) FTSessionReplayPrivacyOverrides *sessionReplayPrivacyOverrides;
@end

NS_ASSUME_NONNULL_END

#endif
