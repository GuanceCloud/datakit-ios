//
//  FTSessionReplayConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

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
    /// Only SF symbols and images loaded using [UIImage imageNamed:]/UIImage(named:) that are bundled in the application will be recorded
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

/// Sampling configuration, property value: 0 to 100, 100 means 100% collection, no data sample compression.
@property (nonatomic, assign) int sampleRate;

/// After enabling, unsampled sessions record 1 minute before errors occur.
@property (nonatomic, assign) int sessionReplayOnErrorSampleRate;

/// Privacy level for content masking in session replay. Default is FTSRPrivacyMask
@property (nonatomic, assign) FTSRPrivacy privacy DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use `touchPrivacy`, `textAndInputPrivacy`, `imagePrivacy` instead");

/// Available privacy level for touch masking in session replay. Default: FTTouchPrivacyLevelHide
@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;

/// Available privacy level for text and input masking in session replay. Default: FTTextAndInputPrivacyLevelMaskAll
@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;

/// Available privacy level for image masking in session replay. Default: FTImagePrivacyLevelMaskAll
@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;

/// Session Replay requires the association of the specified RUM key.
@property (nonatomic, copy) NSArray *enableLinkRUMKeys;

@end

NS_ASSUME_NONNULL_END
