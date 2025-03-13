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

/// 为任一 UIView 提供访问 FTSessionReplayPrivacyOverrides 的权限
@interface UIView (FTSRPrivacy)

/// UIView 管理会话回放隐私覆盖设置
/// 使用示例:
/// swift: `myView.sessionReplayPrivacyOverrides.textAndInputPrivacy = .maskAll`
/// oc: `myView.sessionReplayPrivacyOverrides.textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAll`
@property (nonatomic, strong, readonly) FTSessionReplayPrivacyOverrides *sessionReplayPrivacyOverrides;
@end

NS_ASSUME_NONNULL_END
