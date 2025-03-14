//
//  FTSessionReplayConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 会话重播中内容屏蔽的可用隐私级别. 已废弃，建议使用细粒度的隐私级别进行设置
typedef NS_ENUM(NSUInteger,FTSRPrivacy){
    /// 屏蔽所有内容.
    FTSRPrivacyMask,
    /// 除了敏感输入控件外记录所有内容.
    FTSRPrivacyAllow,
    /// 屏蔽输入元素，但记录所有其他内容.
    FTSRPrivacyMaskUserInput,
};

/// 会话回放中触摸屏蔽的可用隐私级别。
typedef NS_ENUM(NSUInteger,FTTouchPrivacyLevel){
    /// 显示所有用户触摸
    FTTouchPrivacyLevelShow,
    /// 屏蔽所有用户触摸
    FTTouchPrivacyLevelHide,
};

/// 会话回放中图像屏蔽的可用隐私级别
typedef NS_ENUM(NSUInteger,FTImagePrivacyLevel){
    /// 只有使用 [UIImage imageNamed:]/UIImage(named:) 加载的SF符号和图像被捆绑在应用程序中才会被记录
    FTImagePrivacyLevelMaskNonBundledOnly,
    /// 不会记录任何图像
    FTImagePrivacyLevelMaskAll,
    /// 所有图像都将被记录，包括从互联网下载的图像或在应用程序运行时生成的图像
    FTImagePrivacyLevelMaskNone,
};

/// 会话回放中文本和输入屏蔽的可用隐私级别
typedef NS_ENUM(NSUInteger,FTTextAndInputPrivacyLevel){
    /// 显示除敏感输入外的所有文本。例如: password fields
    FTTextAndInputPrivacyLevelMaskSensitiveInputs,
    /// 屏蔽所有输入字段。例如:textfields, switches, checkboxes
    FTTextAndInputPrivacyLevelMaskAllInputs,
    /// 屏蔽所有文本和输入。例如: lable
    FTTextAndInputPrivacyLevelMaskAll,
};

/// Session Replay 配置
@interface FTSessionReplayConfig : NSObject

/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int sampleRate;

/// 会话重播中内容屏蔽的隐私级别。 默认为 FTSRPrivacyMask
@property (nonatomic, assign) FTSRPrivacy privacy DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 `touchPrivacy`、`textAndInputPrivacy`、`imagePrivacy` 替换");

/// 会话回放中触摸屏蔽的可用隐私级别。默认：FTTouchPrivacyLevelHide
@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;

/// 会话回放中文本和输入屏蔽的可用隐私级别。 默认：FTTextAndInputPrivacyLevelMaskAll
@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;

/// 会话回放中图像屏蔽的可用隐私级别。默认：FTImagePrivacyLevelMaskAll
@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;

@end

NS_ASSUME_NONNULL_END
