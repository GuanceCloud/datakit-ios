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

@interface UIView (FTSRPrivacy)
@property (nonatomic, strong, readonly) FTSessionReplayPrivacyOverrides *sessionReplayPrivacyOverrides;
@end

NS_ASSUME_NONNULL_END
