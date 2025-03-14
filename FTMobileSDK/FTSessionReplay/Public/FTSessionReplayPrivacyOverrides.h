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

///  管理会话回放隐私覆盖设置
@interface FTSessionReplayPrivacyOverrides : NSObject

/// 触摸隐私覆盖（例如，在特定视图上隐藏或显示触摸交互）。
@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;

/// 文本和输入隐私覆盖（例如，屏蔽或取消屏蔽特定的文本字段、标签等）
@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;

/// 图像隐私覆盖（例如，掩码或取消掩码特定图像）。
@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;

/// 隐藏视图（例如，将视图标记为隐藏，在回放中将其呈现为不透明的线框）。
@property (nonatomic, assign) BOOL hide;
@end

NS_ASSUME_NONNULL_END
