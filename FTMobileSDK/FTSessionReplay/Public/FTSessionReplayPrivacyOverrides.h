//
//  FTSessionReplayPrivacyOverrides.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/11.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSessionReplayConfig.h"
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,FTTouchPrivacyLevelOverride) {
    /// Do not override/remove override settings
    FTTouchPrivacyLevelOverrideNone,
    /// Show all user touches
    FTTouchPrivacyLevelOverrideShow,
    /// Hide all user touches
    FTTouchPrivacyLevelOverrideHide,
};

typedef NS_ENUM(NSUInteger,FTTextAndInputPrivacyLevelOverride) {
    /// Do not override/remove override settings
    FTTextAndInputPrivacyLevelOverrideNone,
    /// Show all text except sensitive inputs. For example: password fields
    FTTextAndInputPrivacyLevelOverrideMaskSensitiveInputs,
    /// Hide all input fields. For example: textfields, switches, checkboxes
    FTTextAndInputPrivacyLevelOverrideMaskAllInputs,
    /// Hide all text and inputs. For example: label
    FTTextAndInputPrivacyLevelOverrideMaskAll,
};
/// Available privacy levels for image masking in session replay
typedef NS_ENUM(NSUInteger,FTImagePrivacyLevelOverride){
    /// Do not override/remove override settings
    FTImagePrivacyLevelOverrideNone,
    /// Only SF symbols and images loaded using [UIImage imageNamed:]/UIImage(named:) that are bundled in the application will be recorded
    FTImagePrivacyLevelOverrideMaskNonBundledOnly,
    /// No images will be recorded
    FTImagePrivacyLevelOverrideMaskAll,
    /// All images will be recorded, including images downloaded from the internet or generated during application runtime
    FTImagePrivacyLevelOverrideMaskNone,
};
///  Manage session replay privacy override settings
@interface FTSessionReplayPrivacyOverrides : NSObject

/// Touch privacy override (e.g., hide or show touch interactions on specific views).
@property (nonatomic, assign) FTTouchPrivacyLevelOverride touchPrivacy;

/// Text and input privacy override (e.g., mask or unmask specific text fields, labels, etc.)
@property (nonatomic, assign) FTTextAndInputPrivacyLevelOverride textAndInputPrivacy;

/// Image privacy override (e.g., mask or unmask specific images).
@property (nonatomic, assign) FTImagePrivacyLevelOverride imagePrivacy;

/// Hide view (e.g., mark view as hidden, render as opaque wireframe in replay).
@property (nonatomic, assign) BOOL hide;
@end

NS_ASSUME_NONNULL_END
