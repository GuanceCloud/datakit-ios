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
    /// 不覆盖/移除覆盖设置
    FTTouchPrivacyLevelOverrideNone,
    /// 显示所有用户触摸
    FTTouchPrivacyLevelOverrideShow,
    /// 屏蔽所有用户触摸
    FTTouchPrivacyLevelOverrideHide,
};

typedef NS_ENUM(NSUInteger,FTTextAndInputPrivacyLevelOverride) {
    /// 不覆盖/移除覆盖设置
    FTTextAndInputPrivacyLevelOverrideNone,
    /// 显示除敏感输入外的所有文本。例如: password fields
    FTTextAndInputPrivacyLevelOverrideMaskSensitiveInputs,
    /// 屏蔽所有输入字段。例如:textfields, switches, checkboxes
    FTTextAndInputPrivacyLevelOverrideMaskAllInputs,
    /// 屏蔽所有文本和输入。例如: lable
    FTTextAndInputPrivacyLevelOverrideMaskAll,
};
/// 会话回放中图像屏蔽的可用隐私级别
typedef NS_ENUM(NSUInteger,FTImagePrivacyLevelOverride){
    /// 不覆盖/移除覆盖设置
    FTImagePrivacyLevelOverrideNone,
    /// 只有使用 [UIImage imageNamed:]/UIImage(named:) 加载的SF符号和图像被捆绑在应用程序中才会被记录
    FTImagePrivacyLevelOverrideMaskNonBundledOnly,
    /// 不会记录任何图像
    FTImagePrivacyLevelOverrideMaskAll,
    /// 所有图像都将被记录，包括从互联网下载的图像或在应用程序运行时生成的图像
    FTImagePrivacyLevelOverrideMaskNone,
};
///  管理会话回放隐私覆盖设置
@interface FTSessionReplayPrivacyOverrides : NSObject

/// 触摸隐私覆盖（例如，在特定视图上隐藏或显示触摸交互）。
@property (nonatomic, assign) FTTouchPrivacyLevelOverride touchPrivacy;

/// 文本和输入隐私覆盖（例如，屏蔽或取消屏蔽特定的文本字段、标签等）
@property (nonatomic, assign) FTTextAndInputPrivacyLevelOverride textAndInputPrivacy;

/// 图像隐私覆盖（例如，掩码或取消掩码特定图像）。
@property (nonatomic, assign) FTImagePrivacyLevelOverride imagePrivacy;

/// 隐藏视图（例如，将视图标记为隐藏，在回放中将其呈现为不透明的线框）。
@property (nonatomic, assign) BOOL hide;
@end

NS_ASSUME_NONNULL_END
