//
//  FTSessionReplayConfig.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayConfig.h"
#import "FTSessionReplayConfig+Private.h"
NSString * const FTTextAndInputPrivacyLevelStringMap[] = {
    [FTTextAndInputPrivacyLevelMaskAll] = @"MaskAll",
    [FTTextAndInputPrivacyLevelMaskAllInputs] = @"MaskAllInputs",
    [FTTextAndInputPrivacyLevelMaskSensitiveInputs] = @"MaskSensitiveInputs",
};
NSString * const FTTouchPrivacyLevelStringMap[] = {
    [FTTouchPrivacyLevelHide] = @"Hide",
    [FTTouchPrivacyLevelShow] = @"Show",
};
NSString * const FTImagePrivacyLevelStringMap[] = {
    [FTImagePrivacyLevelMaskAll] = @"MaskAll",
    [FTImagePrivacyLevelMaskNone] = @"MaskNone",
    [FTImagePrivacyLevelMaskNonBundledOnly] = @"MaskNonBundledOnly",
};
@implementation FTSessionReplayConfig
-(instancetype)init{
    self = [super init];
    if(self){
        _sampleRate = 100;
        _privacy = FTSRPrivacyMask;
    }
    return self;
}
-(void)setAdditionalNodeRecorders:(NSArray<id<FTSRWireframesRecorder>> *)additionalNodeRecorders{
    _additionalNodeRecorders = additionalNodeRecorders;
}
-(void)setPrivacy:(FTSRPrivacy)privacy{
    _privacy = privacy;
    switch (privacy) {
        case FTSRPrivacyMask:
            _imagePrivacy = FTImagePrivacyLevelMaskAll;
            _touchPrivacy = FTTouchPrivacyLevelHide;
            _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAll;
            break;
     
        case FTSRPrivacyAllow:
            _imagePrivacy = FTImagePrivacyLevelMaskNone;
            _touchPrivacy = FTTouchPrivacyLevelShow;
            _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskSensitiveInputs;
            break;
        case FTSRPrivacyMaskUserInput:
            _imagePrivacy = FTImagePrivacyLevelMaskNonBundledOnly;
            _touchPrivacy = FTTouchPrivacyLevelHide;
            _textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskAllInputs;
            break;
    }
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"====== Config ======\n sampleRate:%d\n textAndInputPrivacy:%@\n touchPrivacy:%@\n imagePrivacy:%@\n ================== ",self.sampleRate,FTTextAndInputPrivacyLevelStringMap[self.textAndInputPrivacy],FTTouchPrivacyLevelStringMap[self.touchPrivacy],FTImagePrivacyLevelStringMap[self.imagePrivacy]];
}
@end
