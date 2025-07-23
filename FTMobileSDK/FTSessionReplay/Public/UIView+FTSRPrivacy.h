//
//  UIView+FTSRPrivacy.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/11.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

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
