//
//  FTSessionReplayConfig.h
//  SessionReplay
//
//  Created by hulilei on 2024/7/4.
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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Available privacy levels for content masking in session replay. Deprecated, recommend using fine-grained privacy levels for settings
typedef NS_ENUM(NSUInteger,FTSRPrivacy){
    /// Mask all content.
    FTSRPrivacyMask,
    /// Record all content except sensitive input controls.
    FTSRPrivacyAllow,
    /// Mask input elements, but record all other content.
    FTSRPrivacyMaskUserInput,
};

/// Available privacy levels for touch masking in session replay.
typedef NS_ENUM(NSUInteger,FTTouchPrivacyLevel){
    /// Show all user touches
    FTTouchPrivacyLevelShow,
    /// Hide all user touches
    FTTouchPrivacyLevelHide,
};

/// Available privacy levels for image masking in session replay
typedef NS_ENUM(NSUInteger,FTImagePrivacyLevel){
    /// Only platform system symbols and images bundled in the application will be recorded
    FTImagePrivacyLevelMaskNonBundledOnly,
    /// No images will be recorded
    FTImagePrivacyLevelMaskAll,
    /// All images will be recorded, including images downloaded from the internet or generated during application runtime
    FTImagePrivacyLevelMaskNone,
};

/// Available privacy levels for text and input masking in session replay
typedef NS_ENUM(NSUInteger,FTTextAndInputPrivacyLevel){
    /// Show all text except sensitive inputs. For example: password fields
    FTTextAndInputPrivacyLevelMaskSensitiveInputs,
    /// Mask all input fields. For example: textfields, switches, checkboxes
    FTTextAndInputPrivacyLevelMaskAllInputs,
    /// Mask all text and inputs. For example: label
    FTTextAndInputPrivacyLevelMaskAll,
};

/// Session Replay configuration
@interface FTSessionReplayConfig : NSObject

/// Session Replay sampling rate in percent. Values range from 0 to 100 and may contain a fractional part. Default: 100.
@property (nonatomic, assign) float sessionReplaySamplingRate;

/// After enabling, unsampled sessions record 1 minute before errors occur.
/// Values range from 0 to 100 and may contain a fractional part. Default: 0.
@property (nonatomic, assign) float sessionReplayOnErrorSamplingRate;

/// Available privacy level for touch masking in session replay. Default: FTTouchPrivacyLevelHide
@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;

/// Available privacy level for text and input masking in session replay. Default: FTTextAndInputPrivacyLevelMaskAll
@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;

/// Available privacy level for image masking in session replay. Default: FTImagePrivacyLevelMaskAll
@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;

/// Session Replay requires the association of the specified RUM key.
@property (nonatomic, copy) NSArray *enableLinkRUMKeys;

/// Experimental: Enables SwiftUI recording in Session Replay. Default: NO.
/// Some SwiftUI components may be unavailable or represented differently from UIKit views.
@property (nonatomic, assign) BOOL enableSwiftUI;

/// Experimental: Enables heatmap identifier generation and RUM Action correlation. Default: NO.
/// Correlation depends on Session Replay snapshots and may be unavailable for views that are not recorded or dynamic view hierarchies.
@property (nonatomic, assign) BOOL enableHeatmap;

@end

/// Deprecated Session Replay configuration APIs retained for backward compatibility.
@interface FTSessionReplayConfig (Deprecated)

/// Deprecated. Use `sessionReplaySamplingRate`. Setting this property validates and updates `sessionReplaySamplingRate`; reading it returns an integer-percent projection.
@property (nonatomic, assign) int sampleRate DEPRECATED_MSG_ATTRIBUTE("Use sessionReplaySamplingRate.");
/// Deprecated. Use `sessionReplayOnErrorSamplingRate`. Setting this property validates and updates `sessionReplayOnErrorSamplingRate`; reading it returns an integer-percent projection.
@property (nonatomic, assign) int sessionReplayOnErrorSampleRate DEPRECATED_MSG_ATTRIBUTE("Use sessionReplayOnErrorSamplingRate.");
/// Privacy level for content masking in session replay. Default is FTSRPrivacyMask
@property (nonatomic, assign) FTSRPrivacy privacy DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use `touchPrivacy`, `textAndInputPrivacy`, `imagePrivacy` instead");

@end

NS_ASSUME_NONNULL_END

#endif
