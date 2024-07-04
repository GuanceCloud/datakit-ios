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
    FTSRPrivacyMaskNone,
    FTSRPrivacyMaskOnlyInput,
    FTSRPrivacyMaskAllText,
};
@interface FTSessionReplayConfig : NSObject
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int sampleRate;

@property (nonatomic, assign) FTSRPrivacy privacy;
@end

NS_ASSUME_NONNULL_END
