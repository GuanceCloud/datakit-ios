//
//  FTSessionReplayConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,FTSRPrivacy){
    /// 屏蔽所有内容.
    FTSRPrivacyMask,
    /// 除了敏感输入控件外记录所有内容.
    FTSRPrivacyAllow,
    /// 屏蔽输入元素，但记录所有其他内容.
    FTSRPrivacyMaskUserInput,
};

typedef NS_ENUM(NSUInteger,FTTouchPrivacyLevel){
    /// 屏蔽所有用户点击
    FTTouchPrivacyLevelHide,
    /// 采集用户点击
    FTTouchPrivacyLevelShow,
};

typedef NS_ENUM(NSUInteger,FTImagePrivacyLevel){
    ///
    FTImagePrivacyLevelMaskNonBundledOnly,
    /// 采集用户点击
    FTImagePrivacyLevelMaskAll,
    /// 屏蔽所有用户点击
    FTImagePrivacyLevelMaskNone,
};
typedef NS_ENUM(NSUInteger,FTTextAndInputPrivacyLevel){
    ///
    FTTextAndInputPrivacyLevelMaskSensitiveInputs,
    /// 采集用户点击
    FTTextAndInputPrivacyLevelMaskAllInputs,
    /// 屏蔽所有用户点击
    FTTextAndInputPrivacyLevelMaskAll,
};

@interface FTSessionReplayConfig : NSObject
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int sampleRate;

/// 会话重播中内容屏蔽的隐私级别。 默认为 FTSRPrivacyMask
@property (nonatomic, assign) FTSRPrivacy privacy;

@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;

@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;

@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;

@end

NS_ASSUME_NONNULL_END
